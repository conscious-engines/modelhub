import { ModelSource } from '../models/types.js';
import { MODEL_PATHS } from '../models/paths.js';
import { basename, relative } from 'node:path';

export interface ParsedModelInfo {
  publisher: string;
  name: string;
  fullName: string;
}

export function parseModelPath(modelPath: string, source: ModelSource): ParsedModelInfo {
  if (source === 'lmstudio') {
    const rel = relative(MODEL_PATHS.lmstudio, modelPath);
    const parts = rel.split('/').filter(Boolean);
    if (parts.length >= 2) {
      return {
        publisher: parts[0]!,
        name: parts.slice(1).join('/'),
        fullName: `${parts[0]}/${parts.slice(1).join('/')}`,
      };
    }
    return { publisher: '', name: basename(modelPath), fullName: basename(modelPath) };
  }

  // HuggingFace cache: directories named like "models--author--repo"
  const dirName = basename(modelPath);
  const match = dirName.match(/^models--(.+?)--(.+)$/);
  if (match) {
    const publisher = match[1]!.replace(/--/g, '/');
    const name = match[2]!.replace(/--/g, '/');
    return { publisher, name, fullName: `${publisher}/${name}` };
  }
  return { publisher: '', name: dirName, fullName: dirName };
}
