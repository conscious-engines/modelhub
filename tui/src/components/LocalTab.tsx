import React, { useState, useRef, useEffect } from 'react';
import { Box, Text, useInput, useApp } from 'ink';
import TextInput from 'ink-text-input';
import { ModelEntry, AppConfig, SortMode, ModelSource } from '../models/types.js';
import { ModelRow } from './ModelRow.js';
import { sortModels } from '../hooks/useModels.js';
import { icons } from '../utils/icons.js';
import { formatSize } from '../services/sizeUtil.js';
import clipboard from 'clipboardy';
import open from 'open';
import { rmSync } from 'node:fs';
import { dirname } from 'node:path';

interface LocalTabProps {
  models: ModelEntry[];
  config: AppConfig;
  onSearchFocus: (focused: boolean) => void;
  onRefresh: () => void;
}

interface FlatItem {
  type: 'header' | 'model' | 'empty';
  source?: ModelSource;
  model?: ModelEntry;
  count?: number;
}

export const LocalTab: React.FC<LocalTabProps> = ({ models, config, onSearchFocus, onRefresh }) => {
  const { exit } = useApp();
  const [selectedIndex, setSelectedIndex] = useState(0);
  const [copiedName, setCopiedName] = useState<string | null>(null);
  const copiedTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchFocused, setSearchFocused] = useState(false);
  const [sortMode, setSortMode] = useState<SortMode>(config.sortMode);
  const [filterSource, setFilterSource] = useState<ModelSource | null>(null);
  const [confirmDelete, setConfirmDelete] = useState<string | null>(null);

  const filtered = models.filter(m => {
    if (filterSource && m.source !== filterSource) return false;
    if (searchQuery) {
      const q = searchQuery.toLowerCase();
      return (
        m.name.toLowerCase().includes(q) ||
        m.publisher.toLowerCase().includes(q)
      );
    }
    return true;
  });

  const lmsModels = sortModels(filtered.filter(m => m.source === 'lmstudio'), sortMode);
  const hfModels = sortModels(filtered.filter(m => m.source === 'huggingface'), sortMode);

  // Build flat list for navigation (only model items are selectable)
  const flatItems: FlatItem[] = [];
  if (!filterSource || filterSource === 'lmstudio') {
    flatItems.push({ type: 'header', source: 'lmstudio', count: lmsModels.length });
    if (lmsModels.length === 0) {
      flatItems.push({ type: 'empty', source: 'lmstudio' });
    } else {
      for (const m of lmsModels) flatItems.push({ type: 'model', model: m });
    }
  }
  if (!filterSource || filterSource === 'huggingface') {
    flatItems.push({ type: 'header', source: 'huggingface', count: hfModels.length });
    if (hfModels.length === 0) {
      flatItems.push({ type: 'empty', source: 'huggingface' });
    } else {
      for (const m of hfModels) flatItems.push({ type: 'model', model: m });
    }
  }

  const selectableIndices = flatItems
    .map((item, i) => item.type === 'model' ? i : -1)
    .filter(i => i >= 0);

  const totalSize = filtered.reduce((sum, m) => sum + m.size, 0);

  const currentSelectablePos = Math.min(selectedIndex, selectableIndices.length - 1);
  const currentFlatIndex = selectableIndices[currentSelectablePos] ?? -1;

  useInput((input, key) => {
    if (confirmDelete) {
      if (input === 'y' || input === 'Y') {
        const flatIdx = selectableIndices[selectedIndex];
        const item = flatIdx !== undefined ? flatItems[flatIdx] : undefined;
        if (item?.model) {
          try {
            rmSync(item.model.path, { recursive: true, force: true });
            onRefresh();
          } catch { /* ignore */ }
        }
        setConfirmDelete(null);
      } else {
        setConfirmDelete(null);
      }
      return;
    }

    if (searchFocused) {
      if (key.escape) {
        setSearchFocused(false);
        setSearchQuery('');
        onSearchFocus(false);
      }
      return;
    }

    if (input === '/') {
      setSearchFocused(true);
      onSearchFocus(true);
      return;
    }
    if (input === 'q') {
      exit();
      return;
    }
    if (input === 'j' || key.downArrow) {
      setSelectedIndex(i => Math.min(i + 1, selectableIndices.length - 1));
    } else if (input === 'k' || key.upArrow) {
      setSelectedIndex(i => Math.max(i - 1, 0));
    } else if (input === 's') {
      setSortMode(prev => {
        if (prev === 'name') return 'size';
        if (prev === 'size') return 'date';
        return 'name';
      });
    } else if (input === 'f') {
      setFilterSource(prev => {
        if (prev === null) return 'lmstudio';
        if (prev === 'lmstudio') return 'huggingface';
        return null;
      });
      setSelectedIndex(0);
    } else if (input === 'c' || key.return) {
      const flatIdx = selectableIndices[selectedIndex];
      const item = flatIdx !== undefined ? flatItems[flatIdx] : undefined;
      if (item?.model) {
        const name = `${item.model.publisher}/${item.model.name}`;
        clipboard.writeSync(name);
        setCopiedName(name);
        if (copiedTimer.current) clearTimeout(copiedTimer.current);
        copiedTimer.current = setTimeout(() => setCopiedName(null), 2000);
      }
    } else if (input === 'o') {
      const flatIdx = selectableIndices[selectedIndex];
      const item = flatIdx !== undefined ? flatItems[flatIdx] : undefined;
      if (item?.model) open(dirname(item.model.path));
    } else if (input === 'd' || key.delete) {
      const flatIdx = selectableIndices[selectedIndex];
      const item = flatIdx !== undefined ? flatItems[flatIdx] : undefined;
      if (item?.model) setConfirmDelete(item.model.id);
    }
  });

  return (
    <Box flexDirection="column" paddingX={1}>
      {/* Copied feedback */}
      {copiedName && (
        <Box marginBottom={1}>
          <Text color="green" bold>✓ Copied "{copiedName}" to clipboard</Text>
        </Box>
      )}

      {/* Search bar */}
      {!copiedName && (
      <Box marginBottom={1}>
        {searchFocused ? (
          <Box>
            <Text color="cyan">{icons.search} </Text>
            <TextInput
              value={searchQuery}
              onChange={setSearchQuery}
              placeholder="Search models..."
            />
          </Box>
        ) : (
          <Box flexDirection="row" justifyContent="space-between">
            <Text dimColor>
              {searchQuery ? `Filter: ${searchQuery}` : '/ to search'}
            </Text>
            <Box>
              <Text dimColor>
                Sort: {sortMode} {sortMode === 'size' ? icons.sortDesc : sortMode === 'date' ? icons.sortDesc : icons.sortAsc}
              </Text>
              {filterSource && (
                <Text color="yellow">
                  {'  '}Filter: {filterSource === 'lmstudio' ? 'LMS' : 'HF'}
                </Text>
              )}
            </Box>
          </Box>
        )}
      </Box>
      )}

      {/* Delete confirmation */}
      {confirmDelete && (
        <Box marginBottom={1}>
          <Text color="red" bold>Delete this model permanently? (y/N)</Text>
        </Box>
      )}

      {/* Grouped model list */}
      {flatItems.map((item, i) => {
        if (item.type === 'header') {
          const isLms = item.source === 'lmstudio';
          const icon = isLms ? icons.lmStudio : icons.huggingFace;
          const label = isLms ? 'LM STUDIO' : 'HUGGING FACE';
          return (
            <Box key={`header-${item.source}`} marginTop={i > 0 ? 1 : 0} marginBottom={0}>
              <Text>
                <Text color={isLms ? 'blue' : 'yellow'}>{icon}</Text>
                {'  '}
                <Text bold dimColor>{label}</Text>
                <Text dimColor>{`  · ${item.count}`}</Text>
              </Text>
            </Box>
          );
        }
        if (item.type === 'empty') {
          return (
            <Box key={`empty-${item.source}`}>
              <Text dimColor>{'    No models'}</Text>
            </Box>
          );
        }
        if (item.type === 'model' && item.model) {
          const isSelected = currentFlatIndex === i;
          return (
            <ModelRow
              key={item.model.id}
              model={item.model}
              isSelected={isSelected}
            />
          );
        }
        return null;
      })}

      {/* Total */}
      <Box marginTop={1}>
        <Text bold>{'Total'.padEnd(63)}</Text>
        <Text bold>{formatSize(totalSize).padStart(8)}</Text>
      </Box>
    </Box>
  );
};
