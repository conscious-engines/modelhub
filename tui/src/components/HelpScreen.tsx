import React from 'react';
import { Box, Text } from 'ink';

const HELP_TEXT = [
  ['Navigation', ''],
  ['1 / 2 / 3', 'Switch to Local / Explore / Settings'],
  ['Tab', 'Cycle through tabs'],
  ['j / ↓', 'Move down'],
  ['k / ↑', 'Move up'],
  ['/', 'Focus search'],
  ['Esc', 'Clear search / cancel'],
  ['q', 'Quit'],
  ['', ''],
  ['Local Tab', ''],
  ['s', 'Cycle sort mode (name → size → date)'],
  ['f', 'Filter by source (all → LMS → HF)'],
  ['c', 'Copy model path to clipboard'],
  ['o', 'Open folder in file manager'],
  ['d', 'Delete model (with confirmation)'],
  ['', ''],
  ['Explore Tab', ''],
  ['Enter', 'Download selected model'],
  ['f', 'Toggle "fits this machine" filter'],
  ['p', 'Pause active download'],
  ['r', 'Resume paused download'],
  ['Esc', 'Cancel download'],
  ['', ''],
  ['Settings', ''],
  ['Enter / Space', 'Toggle selected option'],
];

export const HelpScreen: React.FC<{ onClose: () => void }> = () => {
  return (
    <Box flexDirection="column" paddingX={2} paddingY={1}>
      <Box marginBottom={1}>
        <Text bold color="cyan">Keyboard Shortcuts</Text>
        <Text dimColor>  (press ? or Esc to close)</Text>
      </Box>

      {HELP_TEXT.map(([key, desc], i) => {
        if (!key && !desc) return <Text key={i}> </Text>;
        if (!desc) {
          return (
            <Box key={i} marginTop={1}>
              <Text bold underline>{key}</Text>
            </Box>
          );
        }
        return (
          <Box key={i} flexDirection="row">
            <Box width={16}>
              <Text color="yellow">{key}</Text>
            </Box>
            <Text>{desc}</Text>
          </Box>
        );
      })}
    </Box>
  );
};
