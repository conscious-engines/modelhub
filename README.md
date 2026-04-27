# Model Hub

A macOS menu-bar app for managing every local LLM you've got — and pulling
new ones from HuggingFace right from the menu bar. Lives alongside
**LM Studio** and the **HuggingFace** CLI cache without breaking either.

<img width="1049" height="889" alt="Screenshot 2026-04-27 at 7 37 39 PM" src="https://github.com/user-attachments/assets/fc72a451-5bd0-4bf2-95e9-d5b19ed06e7e" />

---

## Features

### Browse + download from HuggingFace ⭐ *new*

- **Two tabs at the top**: **Local** (everything on your disk) and
  **Explore** (browse + download from HuggingFace).
- **Top text-generation models on Explore** by default, freshly fetched
  from `huggingface.co/api/models`. Type in the search bar to query
  HuggingFace directly with a 350 ms debounce.
- **Author avatars** load asynchronously after each result lands. Hover
  shows the author's display name. Initial-circle placeholder while the
  image fetches; deterministic palette so the same publisher always gets
  the same color.
- **Model size up front** — the per-model `usedStorage` is fetched in
  parallel with the avatar so you know what you're committing to before
  hitting download.
- **Download with progress, pause, resume** — single-button state machine:
  - **`arrow.down.circle.fill`** → tap to start
  - **`arrow.down.circle.dotted`** → fetching model details
  - **`arrow.down.circle`** → in progress, with the SF Symbol's variable
    ring filling proportionally to the byte count. Hover for live
    `XX.X MB / Y.Y GB · NN% · Z.Z MB/s` tooltip.
  - **`arrow.down.circle.badge.pause`** → paused; tap to resume from
    where it stopped (URLSession resume data, opaque blob)
  - **`checkmark.circle.fill`** (green) → done; click is a no-op
- **Bit-perfect HuggingFace cache layout** — downloads land in the same
  `~/.cache/huggingface/hub/models--{publisher}--{repo}/blobs · refs ·
  snapshots` structure that `huggingface-cli download` produces. So
  anything that reads from that cache (`transformers`, `mlx-lm`,
  `llama.cpp`, `ollama`, your own scripts) finds the model
  interchangeably. Symlinks are relative `../../blobs/{etag}` and `refs/main`
  holds the bare commit SHA — same convention.
- **LFS handling** — `X-Linked-Etag` from the pre-redirect response is
  captured before the S3 redirect proceeds, so multi-GB safetensors
  blobs are content-addressed by SHA-256 (just like the CLI), and small
  config files by their git SHA-1.
- **Already-downloaded models are auto-detected** in Explore — they show
  the green checkmark immediately, no re-download.

### Local browse

- **Walks `~/.lmstudio/models/` and `~/.cache/huggingface/hub/`** on
  every menu open. What you see is what's on disk right now.
- **Pretty names.** `Qwen3.5-35B-A3B-MLX-4bit/` becomes
  `[qwen] Qwen 3.5 35B A3B  ·  MLX 4bit` — family tag, prettified
  version string, format + quantization rendered in their own column.
  No more parsing hyphens by eye.
- **Live "loaded" indicator.** A pulsing green dot marks any model
  currently loaded in LM Studio. Queried via its local REST API; silently
  no-ops if the server isn't running.
- **Click to copy.** Clicking a row copies its canonical
  `publisher/repo` ID (lowercase) — paste straight into `lms get …` or
  `huggingface-cli download …`. The row briefly shows
  "Copied to clipboard!" and the menu stays open.
- **Hover to reveal trash.** Hover a row, the trash icon slides in from
  the trailing edge. Click → confirm → moved to the Trash. Models are
  big; permanent delete is a footgun, so this uses `NSWorkspace.recycle`
  deliberately.
- **Marquee on hover** — long names truncate with ellipsis and scroll on
  hover to reveal the full text.

### Common to both tabs

- **Search bar at the top** — meaning shifts with the active tab.
  - Local: live filter across publisher, repo, display name, family
    tag, type label, and copyable ID. Multi-word queries are AND-ed.
  - Explore: 350 ms debounced HuggingFace search; "Loading…" placeholder
    while the request is in flight.
- **Sort.** Per-section sort by size (asc/desc) or date added
  (oldest/newest). State persists across menu opens. The clock button
  carries a tiny chevron overlay so direction is visible at a glance.
- **Reveal in Finder.** Every section header has a folder button that
  opens the section's root directory.
- **Total size.** Bottom row sums on-disk bytes across both sources,
  skipping symlinks so HuggingFace's snapshot links don't double-count
  the real blobs.
- **Single-row hover invariant.** A coordinator forces only one row to
  show as hovered at a time, even when NSMenu's auto-scroll moves rows
  under a stationary cursor (a `mouseExited` event sometimes goes missing
  in that scenario; the coordinator fills the gap).

---

## Build

Requires Xcode 26+ and macOS 26+ (the project deployment target is set
to `26.4` and uses Icon Composer's `.icon` format and SF Symbol variable
rendering).

```bash
open modelhub.xcodeproj
# Build & Run (⌘R)
```

The app is configured as a menu-bar agent (`LSUIElement = YES`), so no
Dock icon appears. Look for the cube icon in the right side of your menu
bar.

> **Sandbox is intentionally off.** The app reads/writes
> `~/.lmstudio` and `~/.cache/huggingface`, both outside any sandbox
> container. Keep `ENABLE_APP_SANDBOX = NO` in the project settings.
> The hardened runtime stays on.

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
│   ├── ModelPaths.swift           ~/.lmstudio + ~/.cache/huggingface roots
│   ├── SortMode.swift             Sort enum + button state mapping
│   ├── Tab.swift                  Local | Explore
│   ├── HFModelSummary.swift       /api/models response (search results)
│   ├── HFModelDetail.swift        /api/models/{id} (sha + siblings + usedStorage)
│   ├── HFOwner.swift              user/org overview (avatarUrl + fullname)
│   ├── DownloadState.swift        Lifecycle enum the button + tooltip read
│   └── Download.swift             Per-download record (sha, files, speed samples)
├── Services/
│   ├── ModelScanner.swift         Walks both directories, returns ParsedModels
│   ├── ModelParser.swift          Tokenizes/prettifies repo names
│   ├── SizeUtil.swift             Recursive size + creation date + formatting
│   ├── LiveLoadedChecker.swift    GET localhost:1234/v1/models
│   ├── HuggingFaceAPI.swift       search + modelDetail + fetchOwner + fetchImage + resolveURL
│   ├── HFCacheWriter.swift        Writes blobs/refs/snapshots — exact CLI layout
│   └── DownloadManager.swift      Singleton URLSession owner; pause/resume/redirect
├── Controllers/
│   └── MenuController.swift       NSMenuDelegate; tab switch, build, sort, filter, reorder
└── Views/
    ├── SearchFieldView.swift      NSSearchField wrapped for use as menu item
    ├── TabSwitcherView.swift      "Local | Explore" segmented control row
    ├── SectionHeaderView.swift    Title + sort buttons + folder button
    ├── ModelMenuItemView.swift    Local row — title/dot/type/size/trash, hover anim
    ├── ExploreRowView.swift       Explore row — avatar/title/type/size/download
    ├── DownloadStateButton.swift  State-aware SF symbol button (the one that morphs)
    ├── AuthorAvatarView.swift     Round avatar with initial-circle fallback
    ├── MarqueeLabel.swift         Width-capped label with hover-marquee
    ├── HoverCoordinator.swift     Single-row hover invariant
    ├── PulsingDotView.swift       Live-loaded indicator
    ├── TotalRowView.swift         Bottom "Total ………… N GB"
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
  the menu opens, with custom debounce + state per active tab.
- A download UI that keeps progress + pause/resume state alive across
  menu opens.

`MenuBarExtra` plus SwiftUI menus get you a beautiful start but fight
you the moment you need any of the above. AppKit's `NSStatusItem` +
`NSMenu` + `NSMenuDelegate` makes all of this simple and predictable.

### Tab switching without rebuilding the menu

`MenuController` tracks two `NSMenuItem` markers — `contentTopSeparator`
and `contentBottomSeparator` — that bracket the active tab's content.
Tab switches only swap the items between those markers; the tab
switcher and search field above stay put so typing focus is preserved.

### Sort reorder without rebuilding the menu

When you tap a sort button, the controller doesn't tear down the menu.
It finds that section's row range between the section header and the
following separator, removes those rows, sorts the cached entries, and
inserts new row views at the original starting index. The current
search query is re-applied so newly-inserted rows respect any active
filter.

### Download lifecycle

`DownloadManager` is a singleton owning one `URLSession` (delegate queue:
`.main`, so every callback lands on the main thread — no locks needed).

1. `start(repoID:estimatedTotalBytes:)` creates a `Download`, marks it
   `.queued`, posts a `.downloadStateChanged` notification.
2. Async: hits `/api/models/{id}` for `sha` + `siblings`. Creates the
   `blobs/refs/snapshots/{sha}` directory tree.
3. State flips to `.downloading`, files transfer **sequentially**.
   Per file:
   - `URLSessionDownloadTask` opened.
   - `willPerformHTTPRedirection` captures `X-Linked-Etag` from the
     pre-redirect response (LFS files only carry it there — the S3
     redirect target doesn't).
   - `didWriteData` publishes progress on every chunk; speed averaged
     over a 3-second rolling window.
   - `didFinishDownloadingTo` moves the temp file into `blobs/{etag}`
     and creates the relative symlink `snapshots/{sha}/{filename} →
     ../../blobs/{etag}` (with extra `../` levels for nested filenames).
4. After all files: `refs/main` written with the commit SHA, state goes
   `.completed`, the download is removed from the in-memory map.

Pause uses `task.cancel(byProducingResumeData:)`; resume re-issues
`session.downloadTask(withResumeData:)`. The opaque resume blob handles
mid-file restart automatically. Multiple downloads can run in parallel
(URLSession queues them per-host, capped at 4 connections).

`ExploreRowView` observes `.downloadStateChanged` notifications and
calls `DownloadStateButton.update(state:)` to morph the icon + tooltip.
On row creation, `DownloadManager.state(for:)` short-circuits to
`.completed` if `HFCacheWriter.isDownloaded(repoID:)` says the model is
already on disk — so re-opens of Explore correctly show the green
checkmark for past downloads.

### HuggingFace API surface

`HuggingFaceAPI` is async + `Codable` over `URLSession.shared`:

| Endpoint                                                  | Used for                                |
|-----------------------------------------------------------|-----------------------------------------|
| `GET /api/models?pipeline_tag=text-generation&search=…`   | Explore search + top-models default     |
| `GET /api/models/{id}`                                    | `usedStorage` for size column, `sha` + `siblings` for download |
| `GET /api/organizations/{name}/overview`                  | Author avatar (org-first)               |
| `GET /api/users/{name}/overview`                          | Author avatar (fallback when not org)   |
| `GET huggingface.co/{id}/resolve/{rev}/{file}`            | Actual file bytes during download       |

All endpoints are unauthenticated. Gated repos (Llama family, etc.)
return 401 → the row's button shows orange and the tooltip explains.
Keychain-backed HF token support is on the roadmap but not yet wired up.

---

## Design notes

### Why is there no permanent-delete option?

Models are big. Trashing them via `NSWorkspace.recycle` makes a misclick
recoverable. If you want them gone for real, empty the Trash. (If you'd
rather wire up a hard delete, swap `recycle(_:completionHandler:)` for
`FileManager.default.removeItem(atPath:)` in
`ModelMenuItemView.confirmAndTrash`.)

### Why no HuggingFace "loaded" indicator?

LM Studio runs a known REST API on a known port — easy to ping, easy to
match to a `publisher/repo` ID. HuggingFace-cached models are consumed
by whatever tool happens to open them (transformers, mlx-lm,
llama.cpp, ollama, custom scripts), and there's no daemon to ask.
Detecting open file handles via `lsof` works in principle but is too
slow to run on every menu open and would need to be debounced + cached.
Worth doing later; not worth doing badly.

### Why does the trash slide in instantly now (was 1 second)?

Earlier iterations dwelled for 1s before revealing the trash so cursor
flyovers wouldn't trigger the animation. In practice that felt sluggish
once you knew what to look for. The dwell was removed and the icon
slides in immediately on `mouseEntered`. The animation itself stays
(180ms ease-out) — only the wait is gone. Same change applies to the
marquee animation on long titles.

### Why doesn't the search bar get a custom background?

`NSSearchField` paints its own rounded bezel via `NSSearchFieldCell`,
on top of any background you set on the field or its layer. The clean
fix is to disable the bezel and add a layer-backed pill subview behind
the field — but the system bezel matches macOS's native search
controls, so the default is what's checked in.

### Why does the row width auto-size instead of being fixed?

Local rows are sized to fit your widest title + widest type + widest
size text exactly. Add a long-named model and the menu grows; remove
it and the menu shrinks back. This avoids the "tons of empty trailing
space when titles are short" problem that fixed-width columns produce.
The title column is capped at 280pt for sanity (Explore search results
can have absurdly long names) — anything beyond that marquees on hover.

---

## License

MIT
