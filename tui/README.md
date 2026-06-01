# Model Hub TUI

A cross-platform terminal UI for managing local LLMs from LM Studio and HuggingFace.

```
  Model Hub v1.0.0  ?:help
● 1 Local  ○ 2 Explore  ○ 3 Settings

❯ ● [LMS]  TheBloke/Mistral-7B-v0.1-GGUF       4.1 GB   2024-01-15
    🤗     meta-llama/Llama-2-7b-hf             13.5 GB  2024-02-10
    [LMS]  NousResearch/Hermes-2-Pro-Mistral    4.4 GB   2024-03-01
```

## Install & Run

```bash
npx modelhub
```

Or install globally:

```bash
npm install -g modelhub
modelhub
```

## Features

### Local Tab
- Scans `~/.lmstudio/models/` and `~/.cache/huggingface/hub/`
- Shows model name, publisher, size, date, and source
- Green dot indicator for models currently loaded in LM Studio
- Sort by name, size, or date
- Filter by source (LM Studio / HuggingFace)
- Copy path, open folder, delete models

### Explore Tab
- Search HuggingFace models in real-time
- RAM compatibility badges (fits / partial / too large)
- Download with progress bar, pause/resume support
- Downloads write standard HF cache layout (compatible with transformers, mlx-lm, llama.cpp)

### Settings
- Toggle LM Studio / HuggingFace sources
- Default sort mode
- Icon style (auto / nerd fonts / unicode)
- Explore filter preference
- LM Studio API endpoint

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `1` / `2` / `3` | Switch tabs |
| `Tab` | Cycle tabs |
| `j` / `k` | Navigate up/down |
| `/` | Focus search |
| `Esc` | Clear / back |
| `q` | Quit |
| `?` | Help screen |
| `s` | Cycle sort (Local) |
| `f` | Toggle filter |
| `c` | Copy path (Local) |
| `o` | Open folder (Local) |
| `d` | Delete model (Local) |
| `Enter` | Download (Explore) / Toggle (Settings) |
| `p` / `r` | Pause / Resume download |

## Icons

The app auto-detects Nerd Font support. Override with:

```bash
modelhub --icons=nerd    # Force Nerd Font icons
modelhub --icons=unicode # Force Unicode/emoji fallback
```

Or set the `NERD_FONTS=1` environment variable.

## Configuration

Settings are stored at `~/.config/modelhub/config.json`.

## Requirements

- Node.js >= 18
- macOS or Linux
- LM Studio (optional, for loaded model detection)

## License

MIT
