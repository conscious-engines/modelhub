import React from 'react';
import { Box, Text } from 'ink';
import { ModelEntry } from '../models/types.js';
import { icons } from '../utils/icons.js';
import { formatSize } from '../services/sizeUtil.js';

interface ModelRowProps {
  model: ModelEntry;
  isSelected: boolean;
}

function truncPad(str: string, width: number): string {
  if (str.length > width) return str.slice(0, width - 1) + '…';
  return str.padEnd(width);
}

export const ModelRow: React.FC<ModelRowProps> = ({ model, isSelected }) => {
  const sizeStr = formatSize(model.size).padStart(9);
  const pub = `[${model.publisher}]`;
  const fmt = model.format ?? '';

  return (
    <Box>
      <Text color={isSelected ? 'yellow' : undefined}>
        {isSelected ? '❯' : ' '}
      </Text>
      <Text>{model.isLoaded ? ' ' : ' '}</Text>
      {model.isLoaded && <Text color="green">{icons.loaded}</Text>}
      {!model.isLoaded && <Text> </Text>}
      <Text>{'  '}</Text>
      <Text dimColor={!isSelected} color={isSelected ? 'yellow' : undefined}>{truncPad(pub, 15)}</Text>
      <Text>{'  '}</Text>
      <Text bold={isSelected} color={isSelected ? 'yellow' : undefined}>
        {truncPad(model.name, 30)}
      </Text>
      <Text>{'   '}</Text>
      <Text color={isSelected ? 'yellow' : 'magenta'} dimColor={!isSelected}>{truncPad(fmt, 12)}</Text>
      <Text>{'  '}</Text>
      <Text color={isSelected ? 'yellow' : undefined} dimColor={!isSelected}>{sizeStr}</Text>
    </Box>
  );
};
