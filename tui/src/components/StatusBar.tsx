import React from 'react';
import { Box, Text } from 'ink';
import { Tab } from '../models/types.js';

interface StatusBarProps {
  activeTab: Tab;
  lmStudioConnected: boolean;
  modelCount: number;
}

function getHints(tab: Tab): string {
  const common = 'q:quit  1/2/3:tabs';
  switch (tab) {
    case 'local':
      return `${common}  /:search  s:sort  f:filter  c:copy  o:open  d:delete`;
    case 'explore':
      return `${common}  /:search  Enter:download  p:pause  r:resume  Esc:cancel  f:filter`;
    case 'settings':
      return `${common}  Enter:toggle  j/k:navigate`;
  }
}

export const StatusBar: React.FC<StatusBarProps> = ({ activeTab, lmStudioConnected, modelCount }) => {
  return (
    <Box flexDirection="row" paddingX={1} marginTop={1}>
      <Text dimColor>{getHints(activeTab)}</Text>
      <Text>{'  '}</Text>
      <Text color={lmStudioConnected ? 'green' : 'red'}>
        {lmStudioConnected ? '● LMS' : '○ LMS'}
      </Text>
      <Text dimColor>  {modelCount} models</Text>
    </Box>
  );
};
