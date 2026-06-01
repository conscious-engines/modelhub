import { useState, useCallback, useRef } from 'react';
import { HFModelSummary } from '../models/types.js';
import { searchModels, getModelDetail } from '../services/huggingFaceApi.js';

export function useExplore() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<HFModelSummary[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const enrichGeneration = useRef(0);

  const enrichResults = useCallback(async (models: HFModelSummary[]) => {
    const gen = ++enrichGeneration.current;

    const toEnrich = models.filter(m => !m.usedStorage || m.usedStorage === 0);
    if (toEnrich.length === 0) return;

    // Fire all detail requests in parallel (max 6 concurrent)
    const batchSize = 6;
    for (let i = 0; i < toEnrich.length; i += batchSize) {
      if (enrichGeneration.current !== gen) return;
      const batch = toEnrich.slice(i, i + batchSize);
      const results = await Promise.allSettled(
        batch.map(m => getModelDetail(m.modelId))
      );

      if (enrichGeneration.current !== gen) return;

      const updates: Map<string, { usedStorage: number; siblings: { rfilename: string; size?: number }[] }> = new Map();
      batch.forEach((m, idx) => {
        const result = results[idx];
        if (result && result.status === 'fulfilled') {
          updates.set(m.modelId, result.value);
        }
      });

      if (updates.size > 0) {
        setResults(prev => prev.map(m => {
          const update = updates.get(m.modelId);
          if (update) {
            return { ...m, usedStorage: update.usedStorage, siblings: update.siblings };
          }
          return m;
        }));
      }
    }
  }, []);

  const search = useCallback((q: string) => {
    setQuery(q);
    setError(null);

    if (debounceRef.current) clearTimeout(debounceRef.current);
    enrichGeneration.current++;

    if (!q.trim()) {
      setResults([]);
      setLoading(false);
      return;
    }

    setLoading(true);
    debounceRef.current = setTimeout(async () => {
      try {
        const data = await searchModels(q.trim(), 20);
        setResults(data);
        setLoading(false);
        enrichResults(data);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Search failed');
        setResults([]);
        setLoading(false);
      }
    }, 400);
  }, [enrichResults]);

  return { query, results, loading, error, search };
}
