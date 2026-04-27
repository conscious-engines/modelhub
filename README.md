# Model Hub

A macOS menu-bar app for managing every local LLM you've got — and pulling
new ones from HuggingFace right from the menu bar. Lives alongside
**LM Studio** and the **HuggingFace** CLI cache without breaking either.

<img width="1049" height="889" alt="Screenshot" src="https://github.com/user-attachments/assets/fc72a451-5bd0-4bf2-95e9-d5b19ed06e7e" />

---

## What it is

A single menu-bar surface for everything you do with local LLMs:

- **See every model on your disk** across LM Studio and the HuggingFace
  cache, in one tidy list with pretty names, sizes, formats, and a live
  total.
- **Browse and search HuggingFace** without leaving the menu bar — top
  text-generation models by default, full HF search as you type.
- **Download new models with one click**, with live progress, pause,
  resume, and exact compatibility with whatever you use to run them
  next (`transformers`, `mlx-lm`, `llama.cpp`, `ollama`, the HF CLI…).
- **Manage what you've got** — copy a model's canonical ID for use in a
  CLI, reveal it in Finder, see which one is currently loaded in
  LM Studio, sort by size or date, trash any model you no longer need.

The moat is **seamless local model management** — the same list and the
same downloads that the rest of your toolchain already uses, surfaced as
fast menu-bar actions instead of three terminals and a browser tab.

---

## Explore + download ⭐

- **Two tabs**: **Local** for what's on disk, **Explore** for HuggingFace.
- **Top text-generation models** load on Explore by default. Type to
  search HuggingFace live (debounced).
- **See size and author** before you download. Author avatar with a
  hover tooltip for the display name; per-model size pulled from
  HuggingFace so you know what you're committing to.
- **Click to download** — the cloud icon turns into a progress ring that
  fills as bytes arrive. Hover for live `XX MB / Y GB · NN% · Z MB/s`.
- **Pause + resume** — same icon morphs into a pause indicator on click,
  resumes from exactly where you left off.
- **Bit-perfect HuggingFace cache layout** — downloads land in the same
  `~/.cache/huggingface/hub/models--{publisher}--{repo}/blobs/refs/snapshots`
  structure that `huggingface-cli download` produces. Anything that reads
  from that cache (`transformers`, `mlx-lm`, `llama.cpp`, `ollama`, your
  own scripts) finds the model interchangeably.
- **No re-downloads** — already-cached models show as completed in
  Explore the moment you open it.

---

## Manage your local models

- **Two sources, one list.** Walks `~/.lmstudio/models/` and
  `~/.cache/huggingface/hub/` every time you open the menu — what you
  see is what's on disk right now.
- **Pretty names.** `Qwen3.5-35B-A3B-MLX-4bit/` becomes
  `[qwen] Qwen 3.5 35B A3B  ·  MLX 4bit`. Family tag, prettified
  version string, format + quantization in their own column.
- **Live "loaded" indicator.** A pulsing green dot marks any model
  currently loaded in LM Studio. Silently no-ops if LM Studio's local
  server isn't running.
- **Click to copy.** Clicking a row copies its canonical
  `publisher/repo` ID to the clipboard — paste straight into
  `lms get …`, `huggingface-cli download …`, or your model loader of
  choice.
- **Hover to delete.** The trash icon slides in from the trailing edge.
  Click → confirm → moved to the Trash. (Models are big — permanent
  delete is a footgun, so this uses macOS's standard "Move to Trash".)
- **Search, sort, total.** Live filter as you type. Per-section sort by
  size or date added. Bottom row sums on-disk bytes across both
  sources, skipping symlinks so HuggingFace's snapshots don't
  double-count.
- **Reveal in Finder.** Folder icons in each section header open the
  source's root directory.

---

## Install

**Download the latest release** →
[github.com/conscious-engines/modelhub/releases](https://github.com/conscious-engines/modelhub/releases)

Drop the app into `/Applications` and launch.

**Or build from source** (requires Xcode 26+ and macOS 26+):

```bash
open modelhub.xcodeproj
# Build & Run (⌘R)
```

The app runs as a menu-bar agent — no Dock icon. Look for it in the
right side of your menu bar.

---

## License

MIT.
