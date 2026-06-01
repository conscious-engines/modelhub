import { useState, useEffect, useCallback, useRef } from 'react';
import { ModelEntry, AppConfig, SortMode } from '../models/types.js';
import { scanModels } from '../services/modelScanner.js';
import { getLoadedModels, isModelLoaded } from '../services/lmStudioChecker.js';

export function useModels(config: AppConfig) {
  const [models, setModels] = useState<ModelEntry[]>([]);
  const [lmStudioConnected, setLmStudioConnected] = useState(false);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const refresh = useCallback(async () => {
    const scanned = scanModels({
      lmstudio: config.sources.lmstudio,
      huggingface: config.sources.huggingface,
    });

    let loadedModels: string[] = [];
    try {
      loadedModels = await getLoadedModels();
      setLmStudioConnected(true);
    } catch {
      setLmStudioConnected(false);
    }

    const withLoadedState = scanned.map(m => ({
      ...m,
      isLoaded: isModelLoaded(m.name, loadedModels),
    }));

    setModels(withLoadedState);
  }, [config.sources.lmstudio, config.sources.huggingface]);

  useEffect(() => {
    refresh();
    intervalRef.current = setInterval(refresh, 5000);
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, [refresh]);

  return { models, lmStudioConnected, refresh };
}

export function sortModels(models: ModelEntry[], mode: SortMode): ModelEntry[] {
  return [...models].sort((a, b) => {
    switch (mode) {
      case 'name':
        return a.name.localeCompare(b.name);
      case 'size':
        return b.size - a.size;
      case 'date':
        return b.modifiedAt.getTime() - a.modifiedAt.getTime();
    }
  });
}
