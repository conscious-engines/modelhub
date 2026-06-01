import React, { useState } from 'react';
import { Box, Text, useInput, useApp } from 'ink';
import TextInput from 'ink-text-input';
import Spinner from 'ink-spinner';
import { AppConfig, HFModelSummary, ExploreCompatibility } from '../models/types.js';
import { ExploreRow } from './ExploreRow.js';
import { DownloadBar } from './DownloadBar.js';
import { useExplore } from '../hooks/useExplore.js';
import { useDownloads } from '../hooks/useDownloads.js';
import { estimateModelSize } from '../services/huggingFaceApi.js';
import { icons } from '../utils/icons.js';
import { formatSize } from '../services/sizeUtil.js';
import { totalmem, cpus } from 'node:os';

interface ExploreTabProps {
  config: AppConfig;
  onSearchFocus: (focused: boolean) => void;
}

function getCompatibility(model: HFModelSummary): ExploreCompatibility {
  const size = estimateModelSize(model);
  if (size === 0) return 'unknown';
  const ram = totalmem();
  if (size <= ram * 0.7) return 'fits';
  if (size <= ram) return 'partial';
  return 'too_large';
}

function getMachineInfo(): string {
  const ram = formatSize(totalmem());
  const cpu = cpus()[0]?.model?.replace(/\s+/g, ' ').trim() ?? 'Unknown CPU';
  const shortCpu = cpu.includes('Apple') ? cpu.split(' ').slice(0, 3).join(' ') : cpu.split(' ').slice(0, 4).join(' ');
  return `${shortCpu} · ${ram}`;
}

export const ExploreTab: React.FC<ExploreTabProps> = ({ config, onSearchFocus }) => {
  const { exit } = useApp();
  const { query, results, loading, error, search } = useExplore();
  const { downloads, startDownload, pause, resume, cancel } = useDownloads();
  const [selectedIndex, setSelectedIndex] = useState(0);
  const [searchFocused, setSearchFocused] = useState(true);
  const [filterFits, setFilterFits] = useState(config.exploreFilter === 'fits');

  const filtered = filterFits
    ? results.filter(m => getCompatibility(m) !== 'too_large')
    : results;

  const maxVisible = Math.max(1, (process.stdout.rows || 24) - 14);
  const scrollOffset = Math.max(0, selectedIndex - maxVisible + 1);
  const visible = filtered.slice(scrollOffset, scrollOffset + maxVisible);

  const machineInfo = getMachineInfo();

  useInput((input, key) => {
    if (searchFocused) {
      if (key.escape) {
        setSearchFocused(false);
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
      setSelectedIndex(i => Math.min(i + 1, filtered.length - 1));
    } else if (input === 'k' || key.upArrow) {
      setSelectedIndex(i => Math.max(i - 1, 0));
    } else if (input === 'f') {
      setFilterFits(prev => !prev);
    } else if (key.return) {
      const model = filtered[selectedIndex];
      if (model) {
        const alreadyDownloading = downloads.some(d => d.modelId === model.modelId && (d.state === 'downloading' || d.state === 'paused' || d.state === 'completed'));
        if (!alreadyDownloading && model.siblings && model.siblings.length > 0) {
          const mainFile = model.siblings.find(s =>
            s.rfilename.endsWith('.gguf') ||
            s.rfilename.endsWith('.safetensors') ||
            s.rfilename.endsWith('.bin')
          ) ?? model.siblings[0]!;
          const url = `https://huggingface.co/${model.modelId}/resolve/main/${mainFile.rfilename}`;
          startDownload(model.modelId, mainFile.rfilename, url);
        }
      }
    } else if (input === 'p') {
      const activeDownloads = downloads.filter(d => d.state === 'downloading');
      if (activeDownloads.length > 0) pause(activeDownloads[0]!.id);
    } else if (input === 'r') {
      const pausedDownloads = downloads.filter(d => d.state === 'paused');
      if (pausedDownloads.length > 0) resume(pausedDownloads[0]!.id);
    } else if (key.escape) {
      const activeDownloads = downloads.filter(d => d.state === 'downloading' || d.state === 'paused');
      if (activeDownloads.length > 0) cancel(activeDownloads[0]!.id);
    }
  });

  return (
    <Box flexDirection="column" paddingX={1}>
      {/* Search */}
      <Box marginBottom={1}>
        <Text color="cyan">{icons.search} </Text>
        {searchFocused ? (
          <TextInput
            value={query}
            onChange={search}
            placeholder="Search models..."
          />
        ) : (
          <Text>{query || 'Press / to search'}</Text>
        )}
      </Box>

      {/* Machine info + filter toggle */}
      <Box marginBottom={1}>
        <Text dimColor>{filterFits ? '●' : '○'} Runs on this machine</Text>
        <Text dimColor>{'  '}{machineInfo}</Text>
      </Box>

      {/* Downloads in progress */}
      {downloads.filter(d => d.state !== 'completed').map(d => (
        <DownloadBar key={d.id} download={d} />
      ))}

      {/* Loading */}
      {loading && (
        <Box>
          <Text color="cyan"><Spinner type="dots" /></Text>
          <Text> Searching...</Text>
        </Box>
      )}

      {/* Error */}
      {error && (
        <Box><Text color="red">Error: {error}</Text></Box>
      )}

      {/* Section header */}
      {!loading && !error && filtered.length > 0 && (
        <Box marginBottom={0}>
          <Text dimColor bold>HUGGINGFACE ·</Text>
        </Box>
      )}

      {/* Results */}
      {!loading && !error && filtered.length === 0 && query && (
        <Text dimColor>No results found for "{query}"</Text>
      )}

      {!loading && visible.map((model, i) => {
        const dlForModel = downloads.find(d => d.modelId === model.modelId);
        return (
          <ExploreRow
            key={model.id}
            model={model}
            compatibility={getCompatibility(model)}
            isSelected={i + scrollOffset === selectedIndex}
            isDownloading={dlForModel?.state === 'downloading' || dlForModel?.state === 'paused'}
            isDownloaded={dlForModel?.state === 'completed'}
          />
        );
      })}

      {filtered.length > maxVisible && (
        <Text dimColor>
          {scrollOffset + 1}-{Math.min(scrollOffset + maxVisible, filtered.length)} of {filtered.length}
        </Text>
      )}
    </Box>
  );
};
