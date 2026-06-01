import React from 'react';
import { render } from 'ink';
import { App } from './App.js';
import { loadConfig, saveConfig } from './services/configStore.js';

const args = process.argv.slice(2);

if (args.includes('--help') || args.includes('-h')) {
  console.log(`
  Model Hub - Terminal UI for managing local LLMs

  Usage: modelhub [options]

  Options:
    --icons=nerd     Force Nerd Font icons
    --icons=unicode  Force Unicode/emoji icons
    --help, -h       Show this help
    --version, -v    Show version
`);
  process.exit(0);
}

if (args.includes('--version') || args.includes('-v')) {
  console.log('modelhub v1.0.0');
  process.exit(0);
}

const iconsArg = args.find(a => a.startsWith('--icons='));
if (iconsArg) {
  const mode = iconsArg.split('=')[1] as 'nerd' | 'unicode';
  if (mode === 'nerd' || mode === 'unicode') {
    const config = loadConfig();
    config.iconMode = mode;
    saveConfig(config);
  }
}

const instance = render(React.createElement(App));

instance.waitUntilExit().then(() => {
  process.stdout.write('\x1B[2J\x1B[H');
});
