import { readdirSync, statSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { ModelEntry, ModelSource } from '../models/types.js';
import { MODEL_PATHS } from '../models/paths.js';
import { parseModelPath } from './modelParser.js';
import { getDirectorySize } from './sizeUtil.js';

function detectFormat(dirPath: string): string | undefined {
  try {
    const files = collectFiles(dirPath, 2);
    for (const f of files) {
      if (f.endsWith('.gguf')) return 'GGUF';
      if (f.endsWith('.safetensors')) return 'safetensors';
      if (f.includes('mlx') || f.includes('MLX')) return 'MLX';
      if (f.endsWith('.bin') && !f.endsWith('tokenizer.bin')) return 'PyTorch';
      if (f.endsWith('.onnx')) return 'ONNX';
    }
    // Check directory name for format hints
    const dirName = dirPath.toLowerCase();
    if (dirName.includes('gguf')) return 'GGUF';
    if (dirName.includes('mlx')) return 'MLX';
    if (dirName.includes('gptq')) return 'GPTQ';
    if (dirName.includes('awq')) return 'AWQ';
  } catch { /* ignore */ }
  return undefined;
}

function detectQuantization(dirPath: string): string | undefined {
  const dirName = dirPath.toLowerCase();
  const quantPatterns = [
    { pattern: /4bit|q4|int4/i, label: '4bit' },
    { pattern: /8bit|q8|int8/i, label: '8bit' },
    { pattern: /fp16|f16/i, label: 'fp16' },
    { pattern: /bf16/i, label: 'bf16' },
  ];
  for (const { pattern, label } of quantPatterns) {
    if (pattern.test(dirName)) return label;
  }
  return undefined;
}

function collectFiles(dirPath: string, maxDepth: number, depth = 0): string[] {
  if (depth >= maxDepth) return [];
  const results: string[] = [];
  try {
    const entries = readdirSync(dirPath, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.name.startsWith('.')) continue;
      if (entry.isFile()) {
        results.push(entry.name);
      } else if (entry.isDirectory() && depth < maxDepth - 1) {
        results.push(...collectFiles(join(dirPath, entry.name), maxDepth, depth + 1));
      }
    }
  } catch { /* ignore */ }
  return results;
}

function buildFormatLabel(dirPath: string): string | undefined {
  const format = detectFormat(dirPath);
  const quant = detectQuantization(dirPath);
  if (!format && !quant) return undefined;
  if (format && quant) return `${format} ${quant}`;
  return format ?? quant;
}

function scanLMStudioModels(): ModelEntry[] {
  const basePath = MODEL_PATHS.lmstudio;
  if (!existsSync(basePath)) return [];

  const models: ModelEntry[] = [];
  try {
    const publishers = readdirSync(basePath, { withFileTypes: true });
    for (const pub of publishers) {
      if (!pub.isDirectory() || pub.name.startsWith('.')) continue;
      const pubPath = join(basePath, pub.name);
      const repos = readdirSync(pubPath, { withFileTypes: true });
      for (const repo of repos) {
        if (!repo.isDirectory() || repo.name.startsWith('.')) continue;
        const repoPath = join(pubPath, repo.name);
        const parsed = parseModelPath(repoPath, 'lmstudio');
        const stat = statSync(repoPath);
        const size = getDirectorySize(repoPath, true);
        models.push({
          id: `lms:${parsed.fullName}`,
          name: parsed.name,
          publisher: parsed.publisher,
          path: repoPath,
          size,
          modifiedAt: stat.mtime,
          source: 'lmstudio',
          isLoaded: false,
          format: buildFormatLabel(repoPath),
        });
      }
    }
  } catch {
    // Directory not accessible
  }
  return models;
}

function scanHuggingFaceModels(): ModelEntry[] {
  const basePath = MODEL_PATHS.huggingface;
  if (!existsSync(basePath)) return [];

  const models: ModelEntry[] = [];
  try {
    const dirs = readdirSync(basePath, { withFileTypes: true });
    for (const dir of dirs) {
      if (!dir.isDirectory() || !dir.name.startsWith('models--')) continue;
      const dirPath = join(basePath, dir.name);
      const parsed = parseModelPath(dirPath, 'huggingface');
      const stat = statSync(dirPath);
      const size = getDirectorySize(dirPath, false);
      models.push({
        id: `hf:${parsed.fullName}`,
        name: parsed.name,
        publisher: parsed.publisher,
        path: dirPath,
        size,
        modifiedAt: stat.mtime,
        source: 'huggingface',
        isLoaded: false,
        format: buildFormatLabel(dirPath),
      });
    }
  } catch {
    // Directory not accessible
  }
  return models;
}

export interface ScanOptions {
  lmstudio?: boolean;
  huggingface?: boolean;
}

export function scanModels(options: ScanOptions = {}): ModelEntry[] {
  const { lmstudio = true, huggingface = true } = options;
  const models: ModelEntry[] = [];
  if (lmstudio) models.push(...scanLMStudioModels());
  if (huggingface) models.push(...scanHuggingFaceModels());
  return models;
}
