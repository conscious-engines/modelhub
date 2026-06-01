import { mkdirSync, writeFileSync, existsSync, symlinkSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { MODEL_PATHS } from '../models/paths.js';

/**
 * Replicates the HuggingFace CLI cache layout:
 * ~/.cache/huggingface/hub/models--author--repo/
 *   ├── blobs/
 *   │   └── <sha256>
 *   ├── refs/
 *   │   └── main
 *   └── snapshots/
 *       └── <commit_hash>/
 *           └── <filename> -> ../../blobs/<sha256>
 */
export function getHFCachePath(modelId: string): string {
  const safeName = modelId.replace(/\//g, '--');
  return join(MODEL_PATHS.huggingface, `models--${safeName}`);
}

export function ensureCacheStructure(modelId: string): {
  blobsDir: string;
  snapshotsDir: string;
  refsDir: string;
  modelDir: string;
} {
  const modelDir = getHFCachePath(modelId);
  const blobsDir = join(modelDir, 'blobs');
  const snapshotsDir = join(modelDir, 'snapshots');
  const refsDir = join(modelDir, 'refs');

  mkdirSync(blobsDir, { recursive: true });
  mkdirSync(snapshotsDir, { recursive: true });
  mkdirSync(refsDir, { recursive: true });

  return { blobsDir, snapshotsDir, refsDir, modelDir };
}

export function writeBlobAndLink(
  modelId: string,
  filename: string,
  data: Buffer,
  commitHash: string,
): string {
  const { blobsDir, snapshotsDir, refsDir } = ensureCacheStructure(modelId);

  const sha256 = createHash('sha256').update(data).digest('hex');
  const blobPath = join(blobsDir, sha256);
  writeFileSync(blobPath, data);

  const snapshotDir = join(snapshotsDir, commitHash);
  mkdirSync(snapshotDir, { recursive: true });

  const linkPath = join(snapshotDir, filename);
  const relativeBlobPath = join('..', '..', 'blobs', sha256);
  if (!existsSync(linkPath)) {
    symlinkSync(relativeBlobPath, linkPath);
  }

  const refsMainPath = join(refsDir, 'main');
  writeFileSync(refsMainPath, commitHash, 'utf-8');

  return blobPath;
}

export function getExistingRef(modelId: string): string | null {
  const { refsDir } = ensureCacheStructure(modelId);
  const mainRef = join(refsDir, 'main');
  if (existsSync(mainRef)) {
    return readFileSync(mainRef, 'utf-8').trim();
  }
  return null;
}
