import React, { useState } from 'react';
import { Box, Text, useInput, useApp } from 'ink';
import { AppConfig, SortMode } from '../models/types.js';
import { icons } from '../utils/icons.js';

interface SettingsPanelProps {
  config: AppConfig;
  onConfigChange: (updates: Partial<AppConfig>) => void;
}

interface SettingItem {
  id: string;
  label: string;
  value: () => string;
  toggle: () => void;
}

export const SettingsPanel: React.FC<SettingsPanelProps> = ({ config, onConfigChange }) => {
  const { exit } = useApp();
  const [selectedIndex, setSelectedIndex] = useState(0);

  const items: SettingItem[] = [
    {
      id: 'lmstudio',
      label: 'LM Studio source',
      value: () => config.sources.lmstudio ? 'ON' : 'OFF',
      toggle: () => onConfigChange({
        sources: { ...config.sources, lmstudio: !config.sources.lmstudio },
      }),
    },
    {
      id: 'huggingface',
      label: 'HuggingFace source',
      value: () => config.sources.huggingface ? 'ON' : 'OFF',
      toggle: () => onConfigChange({
        sources: { ...config.sources, huggingface: !config.sources.huggingface },
      }),
    },
    {
      id: 'sortMode',
      label: 'Default sort',
      value: () => config.sortMode,
      toggle: () => {
        const modes: SortMode[] = ['name', 'size', 'date'];
        const idx = modes.indexOf(config.sortMode);
        onConfigChange({ sortMode: modes[(idx + 1) % modes.length] });
      },
    },
    {
      id: 'iconMode',
      label: 'Icon style',
      value: () => config.iconMode,
      toggle: () => {
        const modes = ['auto', 'nerd', 'unicode'] as const;
        const idx = modes.indexOf(config.iconMode);
        onConfigChange({ iconMode: modes[(idx + 1) % modes.length] });
      },
    },
    {
      id: 'exploreFilter',
      label: 'Explore default filter',
      value: () => config.exploreFilter === 'fits' ? 'Fits this machine' : 'All models',
      toggle: () => onConfigChange({
        exploreFilter: config.exploreFilter === 'all' ? 'fits' : 'all',
      }),
    },
    {
      id: 'endpoint',
      label: 'LM Studio endpoint',
      value: () => config.lmStudioEndpoint,
      toggle: () => { /* would need text input for editing */ },
    },
  ];

  useInput((input, key) => {
    if (input === 'q') {
      exit();
      return;
    }
    if (input === 'j' || key.downArrow) {
      setSelectedIndex(i => Math.min(i + 1, items.length - 1));
    } else if (input === 'k' || key.upArrow) {
      setSelectedIndex(i => Math.max(i - 1, 0));
    } else if (key.return || input === ' ') {
      items[selectedIndex]?.toggle();
    }
  });

  return (
    <Box flexDirection="column" paddingX={1}>
      <Box marginBottom={1}>
        <Text bold>Settings</Text>
      </Box>

      {items.map((item, i) => {
        const isSelected = i === selectedIndex;
        const val = item.value();
        const isOn = val === 'ON';
        const isOff = val === 'OFF';

        return (
          <Box key={item.id} flexDirection="row">
            <Text color={isSelected ? 'cyan' : undefined}>
              {isSelected ? '❯ ' : '  '}
            </Text>
            <Box width={25}>
              <Text bold={isSelected}>{item.label}</Text>
            </Box>
            <Text
              color={isOn ? 'green' : isOff ? 'red' : undefined}
              bold={isSelected}
            >
              {val}
            </Text>
          </Box>
        );
      })}

      <Box marginTop={2}>
        <Text dimColor>Enter/Space to toggle  •  j/k to navigate  •  Restart for icon changes</Text>
      </Box>
    </Box>
  );
};
