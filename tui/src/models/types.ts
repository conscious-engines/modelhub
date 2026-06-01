export type Tab = 'local' | 'explore' | 'settings';

export type SortMode = 'name' | 'size' | 'date';

export type ModelSource = 'lmstudio' | 'huggingface';

export interface ModelEntry {
  id: string;
  name: string;
  publisher: string;
  path: string;
  size: number;
  modifiedAt: Date;
  source: ModelSource;
  isLoaded: boolean;
  format?: string;
}

export type DownloadState = 'queued' | 'downloading' | 'paused' | 'completed' | 'failed';

export interface Download {
  id: string;
  modelId: string;
  modelName: string;
  author: string;
  url: string;
  totalBytes: number;
  downloadedBytes: number;
  speed: number;
  state: DownloadState;
  error?: string;
}

export type ExploreCompatibility = 'fits' | 'partial' | 'too_large' | 'unknown';

export interface HFModelSummary {
  id: string;
  modelId: string;
  author: string;
  downloads: number;
  likes: number;
  lastModified: string;
  tags: string[];
  libraryName?: string;
  pipelineTag?: string;
  siblings?: { rfilename: string; size?: number }[];
  usedStorage?: number;
}

export interface HFModelDetail extends HFModelSummary {
  description?: string;
  cardData?: Record<string, unknown>;
  totalSize?: number;
}

export type ExploreFilterMode = 'all' | 'fits';

export interface AppConfig {
  sources: {
    lmstudio: boolean;
    huggingface: boolean;
  };
  sortMode: SortMode;
  lmStudioEndpoint: string;
  iconMode: 'auto' | 'nerd' | 'unicode';
  exploreFilter: ExploreFilterMode;
}

export const DEFAULT_CONFIG: AppConfig = {
  sources: {
    lmstudio: true,
    huggingface: true,
  },
  sortMode: 'name',
  lmStudioEndpoint: 'http://localhost:1234',
  iconMode: 'auto',
  exploreFilter: 'all',
};
