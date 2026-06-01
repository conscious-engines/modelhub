import { useState, useEffect, useCallback } from 'react';
import { AppConfig, DEFAULT_CONFIG } from '../models/types.js';
import { loadConfig, saveConfig } from '../services/configStore.js';

export function useConfig() {
  const [config, setConfig] = useState<AppConfig>(() => loadConfig());

  const updateConfig = useCallback((updates: Partial<AppConfig>) => {
    setConfig(prev => {
      const next = { ...prev, ...updates };
      saveConfig(next);
      return next;
    });
  }, []);

  return { config, updateConfig };
}
