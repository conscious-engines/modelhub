# Model Hub

[![Platform](https://img.shields.io/badge/platform-macOS%2015.0%2B-blue.svg)](https://developer.apple.com/macos/)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg?logo=swift)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/conscious-engines/modelhub?color=success)](https://github.com/conscious-engines/modelhub/releases)

Managing local LLMs is messy. You've got models scattered across LM Studio,
the HuggingFace CLI cache, maybe a few random folders — and finding,
downloading, or removing one means juggling a browser, two terminals, and
hopping between tools that don't talk to each other.

> Model Hub brings it all into one place.

A macOS menu-bar app that surfaces every local model you have, lets you
browse and download from HuggingFace, and gives you the basic management
tools you need — all from the menu bar.

![Demo](./demo.gif)

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
- **Source Status & Actions** — see which developer tools (LM Studio, Ollama, Hugging Face, AnythingLLM, Jan.ai, GPT4All) are installed on your Mac. Click the folder icon to open their model storage directories in Finder (automatically created if not present) or the globe icon to open their website.

---

## Install

**Download the latest release** →
[github.com/conscious-engines/modelhub/releases](https://github.com/conscious-engines/modelhub/releases)

Drop the app into `/Applications` and launch. It runs as a menu-bar agent
(no Dock icon).

**Or build from source** (requires Xcode 16+ and macOS 15+):

```bash
open modelhub.xcodeproj
# Build & Run (⌘R)
```

---

## Community & Contributing

Contributions are welcome! Please check out the following documents for our standards and guides:
- **[Contributing Guide](CONTRIBUTING.md)**: Project architecture constraints (SwiftUI-free AppKit, thread-safe downloads).
- **[Code of Conduct](CODE_OF_CONDUCT.md)**: Standards of behavior for our community.
- **[Security Policy](SECURITY.md)**: How to report vulnerabilities securely.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
