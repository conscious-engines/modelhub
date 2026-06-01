import { loadConfig } from './configStore.js';

interface LMStudioModel {
  id: string;
  object: string;
  owned_by: string;
}

interface LMStudioModelsResponse {
  data: LMStudioModel[];
}

export async function getLoadedModels(): Promise<string[]> {
  const config = loadConfig();
  const endpoint = config.lmStudioEndpoint;
  try {
    const response = await fetch(`${endpoint}/v1/models`, {
      signal: AbortSignal.timeout(2000),
    });
    if (!response.ok) return [];
    const data = (await response.json()) as LMStudioModelsResponse;
    return data.data.map(m => m.id);
  } catch {
    return [];
  }
}

export function isModelLoaded(modelName: string, loadedModels: string[]): boolean {
  const normalized = modelName.toLowerCase();
  return loadedModels.some(loaded => {
    const normalizedLoaded = loaded.toLowerCase();
    return normalizedLoaded.includes(normalized) || normalized.includes(normalizedLoaded);
  });
}
