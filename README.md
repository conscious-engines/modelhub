# Model Hub

A tiny macOS menu-bar app that lists every local LLM you have stored from
**LM Studio** and the **HuggingFace** CLI cache, with live size, sort, search,
copy-as-ID, and reveal-in-Finder.

<img width="501" height="367" alt="Screenshot 2026-04-24 at 4 30 14 PM" src="https://github.com/user-attachments/assets/5d1cf7d9-ebde-4f15-8f9c-dcff0c7b0b8a"/>

---

## Features

- **Two sources, one list.** Walks `~/.lmstudio/models/` and
  `~/.cache/huggingface/hub/` on every menu open — what you see is what's
  on disk right now.
- **Pretty names.** `Qwen3.5-35B-A3B-MLX-4bit/` becomes
  `[qwen] Qwen 3.5 35B A3B  ·  MLX 4bit` — family tag, prettified version
  string, format + quantization in a muted suffix. No more parsing
  hyphens by eye.
- **Loaded indicator.** A pulsing green dot marks any model currently
  loaded in LM Studio (queried via its local REST API; silently no-ops
  if the server isn't running).
- **Click to copy.** Clicking a row copies its canonical
  `publisher/repo` ID (lowercase) — paste straight into `lms get …` or
  `huggingface-cli download …`. The row briefly shows
  "Copied to clipboard!" and the menu stays open.
- **Hover to delete.** Dwell on a row for one second; a trash icon
  slides in from the trailing edge. Click → confirm → moved to the
  Trash. Models are large; permanent delete is a footgun, so this uses
  `NSWorkspace.recycle` deliberately.
- **Search.** A search field at the top filters live across publisher,
  repo, display name, family tag, type label, and copyable ID.
  Multi-word queries are AND-ed.
- **Sort.** Per-section sort by size (asc/desc) or date added
  (oldest/newest). State persists across menu opens. The clock button
  carries a tiny chevron overlay so you can see direction at a glance.
- **Reveal in Finder.** Every section header has a folder button that
  opens the section's root directory.
- **Total size.** Bottom row sums on-disk bytes across both sources,
  skipping symlinks so HuggingFace's snapshot links don't double-count
  the real blobs.

---

## Build

Requires Xcode 16+ and macOS 14+ (deployment target is set higher in the
project — adjust if needed).

```bash
open modelhub.xcodeproj
# Build & Run (⌘R)
```

The app is configured as a menu-bar agent (`LSUIElement = YES`), so no
Dock icon appears. Look for the cube icon in the right side of your menu
bar.

> **Sandbox is intentionally off.** The whole point of this app is to
> read `~/.lmstudio` and `~/.cache/huggingface`, both of which are
> outside any sandbox container. Keep `ENABLE_APP_SANDBOX = NO` in the
> project settings.

---

## Architecture

One target, no third-party dependencies. The Xcode project uses
`PBXFileSystemSynchronizedRootGroup`, so any `.swift` file inside
`modelhub/` is auto-discovered and compiled — no fiddling with the
project file when you add a new view.

```
modelhub/
├── App/
│   ├── ModelHubApp.swift          @main, hosts NSApplicationDelegateAdaptor
│   └── AppDelegate.swift          NSStatusItem setup, hands off to MenuController
├── Models/
│   ├── ParsedModel.swift          Pretty-fied row data + matches() for search
│   ├── ModelEntry.swift           ParsedModel + bytes/dateAdded/loaded
│   ├── SortMode.swift             Sort enum + button state mapping
│   └── ModelPaths.swift           ~/.lmstudio + ~/.cache/huggingface roots
├── Services/
│   ├── ModelScanner.swift         Walks both directories, returns ParsedModels
│   ├── ModelParser.swift          Tokenizes/prettifies repo names
│   ├── SizeUtil.swift             Recursive size + creation date + formatting
│   └── LiveLoadedChecker.swift    GET localhost:1234/v1/models
└── Controllers/
    └── MenuController.swift       NSMenuDelegate; build, sort, filter, reorder
└── Views/
    ├── SearchFieldView.swift      NSSearchField wrapped for use as menu item
    ├── SectionHeaderView.swift    Title + sort buttons + folder button
    ├── ModelMenuItemView.swift    The row — title/dot/size/trash, hover anim
    ├── TotalRowView.swift         Bottom "Total ………… N GB"
    ├── PulsingDotView.swift       Live-loaded indicator
    ├── SortIconButton.swift       Three-state size sort button
    └── DateSortButton.swift       Clock + chevron overlay date sort button
```

### Why AppKit and not SwiftUI?

This app needs:

- A status-bar menu that **rebuilds itself on every open** with fresh
  filesystem state.
- Custom row views with hover-tracked animations that shift one row's
  layout independently of others.
- A search field embedded in the menu that takes first responder when
  the menu opens.

`MenuBarExtra` plus SwiftUI menus get you a beautiful start but fight
you the moment you need any of the above. AppKit's `NSStatusItem` +
`NSMenu` + `NSMenuDelegate` makes all of this simple and predictable.

### Why a controller per menu, not a singleton?

`MenuController` owns its `NSMenu` and all the per-session state
(cached entries, sort modes, row references). One controller per
status item means cleaning up is "release the controller" — no
global state to reset.

### Sort reorder without rebuilding the menu

When you tap a sort button, the controller doesn't tear down the menu.
It finds that section's row range between the section header and the
following separator, removes those rows, sorts the cached entries, and
inserts new row views at the original starting index. Search bar focus,
the other section, the total, and Quit all stay intact. The current
search query is re-applied so newly-inserted rows respect any active
filter.

---

## License

MIT
