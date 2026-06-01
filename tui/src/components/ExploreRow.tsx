import React from 'react';
import { Box, Text } from 'ink';
import { HFModelSummary, ExploreCompatibility } from '../models/types.js';
import { icons } from '../utils/icons.js';
import { formatSize } from '../services/sizeUtil.js';
import { estimateModelSize } from '../services/huggingFaceApi.js';

interface ExploreRowProps {
  model: HFModelSummary;
  compatibility: ExploreCompatibility;
  isSelected: boolean;
  isDownloading?: boolean;
  isDownloaded?: boolean;
}

function compatBadge(c: ExploreCompatibility): { icon: string; color: string } {
  switch (c) {
    case 'fits': return { icon: icons.fits, color: 'green' };
    case 'partial': return { icon: icons.partial, color: 'yellow' };
    case 'too_large': return { icon: icons.tooLarge, color: 'red' };
    case 'unknown': return { icon: ' ', color: 'gray' };
  }
}

function truncPad(str: string, width: number): string {
  if (str.length > width) return str.slice(0, width - 1) + '…';
  return str.padEnd(width);
}

function detectFormat(model: HFModelSummary): string {
  if (model.libraryName) {
    const lib = model.libraryName.toLowerCase();
    if (lib === 'mlx') return 'MLX';
    if (lib === 'gguf' || lib === 'llama.cpp') return 'GGUF';
    if (lib === 'transformers') return 'safetensors';
  }
  if (model.siblings) {
    for (const s of model.siblings) {
      if (s.rfilename.endsWith('.gguf')) return 'GGUF';
      if (s.rfilename.endsWith('.safetensors')) return 'safetensors';
      if (s.rfilename.includes('mlx') || s.rfilename.includes('MLX')) return 'MLX';
    }
  }
  const tags = (model.tags ?? []).join(' ').toLowerCase();
  if (tags.includes('gguf')) return 'GGUF';
  if (tags.includes('mlx')) return 'MLX';
  if (tags.includes('safetensors')) return 'safetensors';
  return '';
}

export const ExploreRow: React.FC<ExploreRowProps> = ({ model, compatibility, isSelected, isDownloading, isDownloaded }) => {
  const badge = compatBadge(compatibility);
  const size = estimateModelSize(model);
  const sizeStr = size > 0 ? formatSize(size).padStart(9) : '—'.padStart(9);
  const author = `[${model.author}]`;
  const name = model.modelId.split('/')[1] ?? model.modelId;
  const fmt = detectFormat(model);

  let statusIcon: string;
  let statusColor: string;
  if (isDownloaded) {
    statusIcon = icons.fits;
    statusColor = 'green';
  } else if (isDownloading) {
    statusIcon = '…';
    statusColor = 'cyan';
  } else {
    statusIcon = icons.download;
    statusColor = 'gray';
  }

  return (
    <Box>
      <Text color={isSelected ? 'yellow' : undefined}>
        {isSelected ? '❯' : ' '}
      </Text>
      <Text>  </Text>
      <Text color={badge.color as any}>{badge.icon}</Text>
      <Text>{'  '}</Text>
      <Text dimColor={!isSelected} color={isSelected ? 'yellow' : undefined}>
        {truncPad(author, 15)}
      </Text>
      <Text>{'  '}</Text>
      <Text bold={isSelected} color={isSelected ? 'yellow' : undefined}>
        {truncPad(name, 30)}
      </Text>
      <Text>{'   '}</Text>
      <Text color={isSelected ? 'yellow' : 'magenta'} dimColor={!isSelected}>
        {truncPad(fmt, 12)}
      </Text>
      <Text>{'  '}</Text>
      <Text color={isSelected ? 'yellow' : undefined} dimColor={!isSelected}>
        {sizeStr}
      </Text>
      <Text>  </Text>
      <Text color={statusColor as any}>{statusIcon}</Text>
    </Box>
  );
};
