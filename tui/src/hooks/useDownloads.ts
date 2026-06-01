import { useState, useCallback, useEffect, useRef } from 'react';
import { Download } from '../models/types.js';
import { DownloadManager } from '../services/downloadManager.js';

const manager = new DownloadManager();

export function useDownloads() {
  const [downloads, setDownloads] = useState<Download[]>([]);

  useEffect(() => {
    const onProgress = (d: Download) => {
      setDownloads(prev => {
        const idx = prev.findIndex(x => x.id === d.id);
        if (idx === -1) return [...prev, d];
        const next = [...prev];
        next[idx] = d;
        return next;
      });
    };

    const onComplete = (d: Download) => {
      setDownloads(prev => prev.map(x => x.id === d.id ? d : x));
    };

    const onError = (d: Download) => {
      setDownloads(prev => prev.map(x => x.id === d.id ? d : x));
    };

    manager.on('progress', onProgress);
    manager.on('complete', onComplete);
    manager.on('error', onError);

    return () => {
      manager.removeListener('progress', onProgress);
      manager.removeListener('complete', onComplete);
      manager.removeListener('error', onError);
    };
  }, []);

  const startDownload = useCallback(async (modelId: string, filename: string, url: string) => {
    const id = await manager.startDownload(modelId, filename, url);
    const dl = manager.getDownload(id);
    if (dl) {
      setDownloads(prev => [...prev, dl]);
    }
    return id;
  }, []);

  const pause = useCallback((id: string) => {
    manager.pause(id);
    setDownloads(manager.getDownloads());
  }, []);

  const resume = useCallback((id: string) => {
    manager.resume(id);
    setDownloads(manager.getDownloads());
  }, []);

  const cancel = useCallback((id: string) => {
    manager.cancel(id);
    setDownloads(prev => prev.filter(d => d.id !== id));
  }, []);

  return { downloads, startDownload, pause, resume, cancel };
}
