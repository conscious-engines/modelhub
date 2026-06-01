import { homedir } from 'node:os';
import { join } from 'node:path';

export const MODEL_PATHS = {
  lmstudio: join(homedir(), '.lmstudio', 'models'),
  huggingface: join(homedir(), '.cache', 'huggingface', 'hub'),
} as const;
