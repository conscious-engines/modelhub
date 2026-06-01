import React from 'react';
import { Box, Text } from 'ink';
import { Tab } from '../models/types.js';

interface TabBarProps {
  activeTab: Tab;
  onTabChange: (tab: Tab) => void;
}

const TABS: { key: Tab; label: string; num: string }[] = [
  { key: 'local', label: 'Local', num: '1' },
  { key: 'explore', label: 'Explore', num: '2' },
  { key: 'settings', label: 'Settings', num: '3' },
];

export const TabBar: React.FC<TabBarProps> = ({ activeTab }) => {
  return (
    <Box marginBottom={1} paddingX={1}>
      <Box
        flexDirection="row"
        borderStyle="round"
        borderColor="gray"
        paddingX={1}
        alignSelf="flex-start"
      >
        {TABS.map((tab, i) => {
          const isActive = activeTab === tab.key;
          return (
            <Box key={tab.key}>
              {i > 0 && <Text dimColor>{'  │  '}</Text>}
              {isActive ? (
                <Text bold color="black" backgroundColor="white">
                  {' '}{tab.num} {tab.label}{' '}
                </Text>
              ) : (
                <Text color="gray">
                  {' '}{tab.num} {tab.label}{' '}
                </Text>
              )}
            </Box>
          );
        })}
      </Box>
    </Box>
  );
};
