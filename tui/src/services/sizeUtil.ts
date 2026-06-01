import { readdirSync, statSync, lstatSync } from 'node:fs';
import { join } from 'node:path';

export function formatSize(bytes: number): string {
  if (bytes === 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  const value = bytes / Math.pow(1024, i);
  return `${value.toFixed(i > 0 ? 1 : 0)} ${units[i]}`;
}

export function getDirectorySize(dirPath: string, followSymlinks = false): number {
  let total = 0;
  try {
    const entries = readdirSync(dirPath, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = join(dirPath, entry.name);
      try {
        const stat = followSymlinks ? statSync(fullPath) : lstatSync(fullPath);
        if (stat.isDirectory()) {
          total += getDirectorySize(fullPath, followSymlinks);
        } else if (stat.isFile() && !stat.isSymbolicLink()) {
          total += stat.size;
        }
      } catch {
        // Skip inaccessible files
      }
    }
  } catch {
    // Skip inaccessible directories
  }
  return total;
}
