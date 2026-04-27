# Model Hub

Managing local LLMs is messy. You've got models scattered across LM Studio,
the HuggingFace CLI cache, maybe a few random folders — and finding,
downloading, or removing one means juggling a browser, two terminals, and
hopping between tools that don't talk to each other.

Model Hub brings it all into one place.

A macOS menu-bar app that surfaces every local model you have, lets you
browse and download from HuggingFace, and gives you the basic management
tools you need — all from the menu bar.

<img width="1049" height="889" alt="Screenshot" src="https://github.com/user-attachments/assets/fc72a451-5bd0-4bf2-95e9-d5b19ed06e7e" />

---

## What it does

- **See every local model in one list** — scans LM Studio
  (`~/.lmstudio/models/`) and the HuggingFace cache
  (`~/.cache/huggingface/hub/`) every time you open the menu.
- **Browse and search HuggingFace** — top text-generation models load by
  default; type to search live.
- **Download with one click** — progress, pause, and resume from the menu
  bar. Models land in the standard HuggingFace cache layout so they're
  immediately usable by `transformers`, `mlx-lm`, `llama.cpp`, `ollama`,
  and other tools.
- **Manage your models** — copy a model's ID to the clipboard, reveal in
  Finder, move to Trash, sort by size or date, and filter as you type.
  A pulsing green dot shows which model is currently loaded in LM Studio.

---

## Install

**Download the latest release** →
[github.com/conscious-engines/modelhub/releases](https://github.com/conscious-engines/modelhub/releases)

Drop the app into `/Applications` and launch. It runs as a menu-bar agent
(no Dock icon).

**Or build from source** (requires Xcode 26+ and macOS 26+):

```bash
open modelhub.xcodeproj
# Build & Run (⌘R)
```

---

## License

MIT.
