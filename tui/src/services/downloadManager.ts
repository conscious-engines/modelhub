import { createWriteStream, mkdirSync, existsSync, statSync, unlinkSync } from 'node:fs';
import { join } from 'node:path';
import { EventEmitter } from 'node:events';
import { Writable } from 'node:stream';
import { Download, DownloadState } from '../models/types.js';
import { ensureCacheStructure } from './hfCacheWriter.js';

interface DownloadEvents {
  progress: (download: Download) => void;
  complete: (download: Download) => void;
  error: (download: Download, error: Error) => void;
}

export class DownloadManager extends EventEmitter {
  private downloads: Map<string, Download> = new Map();
  private controllers: Map<string, AbortController> = new Map();
  private tempDir: string;

  constructor() {
    super();
    this.tempDir = join(
      process.env['TMPDIR'] ?? process.env['TMP'] ?? '/tmp',
      'modelhub-downloads',
    );
    mkdirSync(this.tempDir, { recursive: true });
  }

  override emit<K extends keyof DownloadEvents>(
    event: K,
    ...args: Parameters<DownloadEvents[K]>
  ): boolean {
    return super.emit(event, ...args);
  }

  override on<K extends keyof DownloadEvents>(
    event: K,
    listener: DownloadEvents[K],
  ): this {
    return super.on(event, listener as (...args: unknown[]) => void);
  }

  getDownloads(): Download[] {
    return Array.from(this.downloads.values());
  }

  getDownload(id: string): Download | undefined {
    return this.downloads.get(id);
  }

  async startDownload(
    modelId: string,
    filename: string,
    url: string,
  ): Promise<string> {
    const id = `${modelId}:${filename}`;
    const download: Download = {
      id,
      modelId,
      modelName: filename,
      author: modelId.split('/')[0] ?? '',
      url,
      totalBytes: 0,
      downloadedBytes: 0,
      speed: 0,
      state: 'downloading',
    };

    this.downloads.set(id, download);
    const controller = new AbortController();
    this.controllers.set(id, controller);

    this.performDownload(id, modelId, filename, url, controller.signal);
    return id;
  }

  private async performDownload(
    id: string,
    modelId: string,
    filename: string,
    url: string,
    signal: AbortSignal,
  ): Promise<void> {
    const download = this.downloads.get(id)!;
    const tempPath = join(this.tempDir, `${id.replace(/[/:]/g, '_')}.partial`);
    let resumeFrom = 0;

    if (existsSync(tempPath)) {
      resumeFrom = statSync(tempPath).size;
    }

    const headers: Record<string, string> = {};
    if (resumeFrom > 0) {
      headers['Range'] = `bytes=${resumeFrom}-`;
      download.downloadedBytes = resumeFrom;
    }

    try {
      const response = await fetch(url, { signal, headers });
      if (!response.ok && response.status !== 206) {
        throw new Error(`Download failed: ${response.status}`);
      }

      const contentLength = response.headers.get('content-length');
      if (contentLength) {
        download.totalBytes = resumeFrom + parseInt(contentLength, 10);
      }

      const writer = createWriteStream(tempPath, { flags: resumeFrom > 0 ? 'a' : 'w' });
      const reader = response.body?.getReader();
      if (!reader) throw new Error('No response body');

      let lastTime = Date.now();
      let lastBytes = download.downloadedBytes;

      const pump = async (): Promise<void> => {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          if (signal.aborted) break;

          writer.write(value);
          download.downloadedBytes += value.length;

          const now = Date.now();
          const elapsed = (now - lastTime) / 1000;
          if (elapsed >= 0.5) {
            download.speed = (download.downloadedBytes - lastBytes) / elapsed;
            lastTime = now;
            lastBytes = download.downloadedBytes;
            this.emit('progress', { ...download });
          }
        }
      };

      await pump();
      writer.end();

      if (!signal.aborted) {
        download.state = 'completed';
        download.speed = 0;

        // Move to HF cache
        const { blobsDir, snapshotsDir, refsDir } = ensureCacheStructure(modelId);
        const { renameSync, symlinkSync, writeFileSync } = await import('node:fs');
        const { createHash } = await import('node:crypto');
        const { readFileSync } = await import('node:fs');
        const data = readFileSync(tempPath);
        const sha256 = createHash('sha256').update(data).digest('hex');
        const blobPath = join(blobsDir, sha256);
        renameSync(tempPath, blobPath);

        const commitHash = sha256.slice(0, 40);
        const snapshotDir = join(snapshotsDir, commitHash);
        mkdirSync(snapshotDir, { recursive: true });
        const linkPath = join(snapshotDir, filename);
        if (!existsSync(linkPath)) {
          symlinkSync(join('..', '..', 'blobs', sha256), linkPath);
        }
        writeFileSync(join(refsDir, 'main'), commitHash, 'utf-8');

        this.emit('complete', { ...download });
      }
    } catch (err) {
      if (signal.aborted) {
        download.state = 'paused';
        download.speed = 0;
        this.emit('progress', { ...download });
      } else {
        download.state = 'failed';
        download.error = err instanceof Error ? err.message : String(err);
        download.speed = 0;
        this.emit('error', { ...download }, err instanceof Error ? err : new Error(String(err)));
      }
    }
  }

  pause(id: string): void {
    const controller = this.controllers.get(id);
    const download = this.downloads.get(id);
    if (controller && download && download.state === 'downloading') {
      controller.abort();
      download.state = 'paused';
      download.speed = 0;
    }
  }

  async resume(id: string): Promise<void> {
    const download = this.downloads.get(id);
    if (!download || download.state !== 'paused') return;

    download.state = 'downloading';
    const controller = new AbortController();
    this.controllers.set(id, controller);
    this.performDownload(id, download.modelId, download.modelName, download.url, controller.signal);
  }

  cancel(id: string): void {
    const controller = this.controllers.get(id);
    if (controller) controller.abort();

    const tempPath = join(this.tempDir, `${id.replace(/[/:]/g, '_')}.partial`);
    try { unlinkSync(tempPath); } catch { /* ignore */ }

    this.downloads.delete(id);
    this.controllers.delete(id);
  }
}
