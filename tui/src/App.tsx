import React, { useState, useCallback } from 'react';
import { Box, Text, useInput } from 'ink';
import { Tab } from './models/types.js';
import { TabBar } from './components/TabBar.js';
import { StatusBar } from './components/StatusBar.js';
import { LocalTab } from './components/LocalTab.js';
import { ExploreTab } from './components/ExploreTab.js';
import { SettingsPanel } from './components/SettingsPanel.js';
import { HelpScreen } from './components/HelpScreen.js';
import { useModels } from './hooks/useModels.js';
import { useConfig } from './hooks/useConfig.js';

export const App: React.FC = () => {
  const [activeTab, setActiveTab] = useState<Tab>('local');
  const [searchMode, setSearchMode] = useState(false);
  const [showHelp, setShowHelp] = useState(false);
  const { config, updateConfig } = useConfig();
  const { models, lmStudioConnected, refresh } = useModels(config);

  useInput((input, key) => {
    if (showHelp) {
      if (input === '?' || key.escape) setShowHelp(false);
      return;
    }
    if (searchMode) return;

    if (input === '?') {
      setShowHelp(true);
      return;
    }
    if (input === '1') setActiveTab('local');
    else if (input === '2') setActiveTab('explore');
    else if (input === '3') setActiveTab('settings');
    else if (key.tab) {
      setActiveTab(prev => {
        if (prev === 'local') return 'explore';
        if (prev === 'explore') return 'settings';
        return 'local';
      });
    }
  });

  const handleSearchFocus = useCallback((focused: boolean) => {
    setSearchMode(focused);
  }, []);

  if (showHelp) {
    return (
      <Box flexDirection="column" height={process.stdout.rows || 24}>
        <HelpScreen onClose={() => setShowHelp(false)} />
      </Box>
    );
  }

  return (
    <Box flexDirection="column" height={process.stdout.rows || 24}>
      <Box marginBottom={0}>
        <Text bold color="cyan">{'  Model Hub '}</Text>
        <Text dimColor>v1.0.0</Text>
        <Text dimColor>{'  ?:help'}</Text>
      </Box>

      <TabBar activeTab={activeTab} onTabChange={setActiveTab} />

      <Box flexGrow={1} flexDirection="column">
        {activeTab === 'local' && (
          <LocalTab
            models={models}
            config={config}
            onSearchFocus={handleSearchFocus}
            onRefresh={refresh}
          />
        )}
        {activeTab === 'explore' && (
          <ExploreTab
            config={config}
            onSearchFocus={handleSearchFocus}
          />
        )}
        {activeTab === 'settings' && (
          <SettingsPanel config={config} onConfigChange={updateConfig} />
        )}
      </Box>

      <StatusBar
        activeTab={activeTab}
        lmStudioConnected={lmStudioConnected}
        modelCount={models.length}
      />
    </Box>
  );
};
