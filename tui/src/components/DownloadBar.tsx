import React from 'react';
import { Box, Text } from 'ink';
import { Download } from '../models/types.js';
import { formatSize } from '../services/sizeUtil.js';
import { icons } from '../utils/icons.js';

interface DownloadBarProps {
  download: Download;
}

function progressBar(ratio: number, width: number): string {
  const filled = Math.round(ratio * width);
  const empty = width - filled;
  return '█'.repeat(filled) + '░'.repeat(empty);
}

export const DownloadBar: React.FC<DownloadBarProps> = ({ download }) => {
  const ratio = download.totalBytes > 0
    ? download.downloadedBytes / download.totalBytes
    : 0;
  const percent = Math.round(ratio * 100);
  const speed = download.speed > 0 ? `${formatSize(download.speed)}/s` : '';

  let stateIcon: string;
  let stateColor: string;
  switch (download.state) {
    case 'downloading':
      stateIcon = icons.download;
      stateColor = 'cyan';
      break;
    case 'paused':
      stateIcon = icons.pause;
      stateColor = 'yellow';
      break;
    case 'completed':
      stateIcon = icons.fits;
      stateColor = 'green';
      break;
    case 'failed':
      stateIcon = icons.tooLarge;
      stateColor = 'red';
      break;
    default:
      stateIcon = '…';
      stateColor = 'gray';
  }

  return (
    <Box flexDirection="row" marginBottom={0} paddingX={0}>
      <Text color={stateColor as any}>{stateIcon} </Text>
      <Box width={20}>
        <Text wrap="truncate">{download.modelName}</Text>
      </Box>
      <Text> </Text>
      <Text color="cyan">{progressBar(ratio, 20)}</Text>
      <Text> {percent}%</Text>
      {speed && <Text dimColor> {speed}</Text>}
      {download.state === 'paused' && <Text color="yellow"> [paused]</Text>}
      {download.state === 'failed' && <Text color="red"> {download.error}</Text>}
    </Box>
  );
};
