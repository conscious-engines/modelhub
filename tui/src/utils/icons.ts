import { loadConfig } from '../services/configStore.js';

interface IconSet {
  lmStudio: string;
  huggingFace: string;
  loaded: string;
  folder: string;
  fileSize: string;
  sortAsc: string;
  sortDesc: string;
  fits: string;
  partial: string;
  tooLarge: string;
  tabActive: string;
  tabInactive: string;
  search: string;
  download: string;
  pause: string;
  spinner: string[];
}

const NERD_ICONS: IconSet = {
  lmStudio: '\uf085',
  huggingFace: '🤗',
  loaded: '●',
  folder: '',
  fileSize: '󰋊',
  sortAsc: '󰁝',
  sortDesc: '󰁅',
  fits: '󰄬',
  partial: '󰀦',
  tooLarge: '󰅖',
  tabActive: '●',
  tabInactive: '○',
  search: '',
  download: '',
  pause: '',
  spinner: ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'],
};

const UNICODE_ICONS: IconSet = {
  lmStudio: '[LMS]',
  huggingFace: '🤗',
  loaded: '●',
  folder: '📁',
  fileSize: '💾',
  sortAsc: '↑',
  sortDesc: '↓',
  fits: '✓',
  partial: '△',
  tooLarge: '✗',
  tabActive: '●',
  tabInactive: '○',
  search: '/',
  download: '↓',
  pause: '⏸',
  spinner: ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'],
};

function detectNerdFonts(): boolean {
  if (process.env['NERD_FONTS'] === '1' || process.env['NERD_FONTS'] === 'true') {
    return true;
  }
  const term = process.env['TERM_PROGRAM'] ?? '';
  const nerdTerms = ['WezTerm', 'Alacritty', 'kitty', 'iTerm.app'];
  if (nerdTerms.some(t => term.includes(t))) {
    return true;
  }
  return false;
}

function resolveIconMode(): boolean {
  const config = loadConfig();
  if (config.iconMode === 'nerd') return true;
  if (config.iconMode === 'unicode') return false;
  return detectNerdFonts();
}

export const icons: IconSet = resolveIconMode() ? NERD_ICONS : UNICODE_ICONS;
