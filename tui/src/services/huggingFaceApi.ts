import { HFModelSummary, HFModelDetail } from '../models/types.js';

const HF_API = 'https://huggingface.co/api';

interface HFSearchResult {
  _id: string;
  id: string;
  author?: string;
  downloads: number;
  likes: number;
  lastModified: string;
  tags?: string[];
  pipeline_tag?: string;
  library_name?: string;
  siblings?: { rfilename: string; size?: number }[];
  usedStorage?: number;
}

export async function searchModels(
  query: string,
  limit = 50,
  filter?: string,
): Promise<HFModelSummary[]> {
  const params = new URLSearchParams({
    search: query,
    limit: String(limit),
    sort: 'downloads',
    direction: '-1',
  });
  if (filter) params.set('filter', filter);

  const response = await fetch(`${HF_API}/models?${params}`, {
    signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) throw new Error(`HF API error: ${response.status}`);

  const results = (await response.json()) as HFSearchResult[];
  return results.map(r => ({
    id: r._id,
    modelId: r.id,
    author: r.author ?? r.id.split('/')[0] ?? '',
    downloads: r.downloads,
    likes: r.likes,
    lastModified: r.lastModified,
    tags: r.tags ?? [],
    libraryName: r.library_name,
    pipelineTag: r.pipeline_tag,
    siblings: r.siblings,
    usedStorage: r.usedStorage,
  }));
}

export interface ModelDetailResult {
  usedStorage: number;
  siblings: { rfilename: string; size?: number }[];
  sha?: string;
}

export async function getModelDetail(modelId: string): Promise<ModelDetailResult> {
  const response = await fetch(`${HF_API}/models/${modelId}`, {
    signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) throw new Error(`HF API error: ${response.status}`);

  const r = (await response.json()) as {
    sha?: string;
    usedStorage?: number;
    siblings?: { rfilename: string; size?: number }[];
  };

  return {
    usedStorage: r.usedStorage ?? 0,
    siblings: r.siblings ?? [],
    sha: r.sha,
  };
}

export function estimateModelSize(model: HFModelSummary): number {
  if (model.usedStorage && model.usedStorage > 0) return model.usedStorage;
  if (model.siblings) {
    return model.siblings.reduce((sum, s) => sum + (s.size ?? 0), 0);
  }
  return 0;
}
