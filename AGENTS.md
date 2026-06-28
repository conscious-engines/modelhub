# Developer and AI Agent Guide

Welcome to the **Model Hub** codebase. This guide serves as a technical walkthrough and reference for AI coding agents and human developers who want to understand, extend, or maintain this repository.

---

## 1. Project Overview

**Model Hub** is a macOS menu-bar utility application designed to scan, manage, and download local Large Language Models (LLMs). It acts as a unified dashboard for models stored in **LM Studio** and the **HuggingFace CLI cache**, allowing users to search, download new models, and delete/manage existing ones from their menu bar.

### Tech Stack
- **Language:** Swift (Modern Swift with Swift Concurrency)
- **UI Framework:** AppKit (NSMenu, NSMenuItem, custom NSView subclasses)
- **Deployment Targets:** macOS 15.0+
- **Build System:** Xcode 16.0+ (`modelhub.xcodeproj`)
- **Key Dependencies:**
  - **Sparkle 2.x** (integrated via Swift Package Manager) for background app updates.

---

## 2. Directory and Architecture Directory Structure

The project code is modularized under the `modelhub` directory:

```
modelhub/
├── App/
│   ├── ModelHubApp.swift               # SwiftUI App entry point hosting the AppDelegate adaptor
│   └── AppDelegate.swift               # AppKit AppDelegate managing the NSStatusItem lifecycle
├── Controllers/
│   └── MenuController.swift            # Core orchestrator. Manages NSMenu construction, sorting, and tabs
├── Models/
│   ├── Download.swift                  # Represents an active download item
│   ├── DownloadState.swift             # Enumeration representing queued, downloading, paused, and completed states
│   ├── ExploreCompatibility.swift      # Compatibility logic matching hardware profiles to models
│   ├── HFModelDetail.swift             # HuggingFace API JSON mapping for repository details
│   ├── HFModelSummary.swift            # HuggingFace API JSON mapping for search summaries
│   ├── MachineProfile.swift            # Device-specific hardware profiling (RAM, CPU cores, GPU info)
│   ├── ModelEntry.swift                # Wrapper mapping a model, its disk size, and modification date
│   ├── ModelPaths.swift                # Local constants for default scanning paths
│   ├── ParsedModel.swift               # The parsed model data structure (immutable representation)
│   ├── SortMode.swift                  # Sort options (Alphabetical, Size, Date)
│   ├── SourcePreferences.swift         # Persistent user preferences for active scan directories
│   └── Tab.swift                       # Enumeration for menu views (Local vs. Explore)
├── Services/
│   ├── DownloadManager.swift           # Core downloading engine (URLSessionDownloadDelegate, MainActor-bound)
│   ├── HFCacheWriter.swift             # Replicates HuggingFace Hub directory & symlink structure
│   ├── HuggingFaceAPI.swift            # Network requests to HF endpoints (Search, Metadata)
│   ├── LiveLoadedChecker.swift         # Queries local LM Studio server for resident memory models
│   ├── ModelParser.swift               # Tokenizes and prettifies model naming strings
│   ├── ModelScanner.swift              # Non-recursive directory scanner for local models
│   ├── SizeUtil.swift                  # Directory size calculation utility
│   └── UpdateManager.swift             # Sparkle 2.x wrapper driving updates inside the menu
└── Views/
    ├── AuthorAvatarView.swift          # Publisher avatar image downloader/renderer
    ├── DateSortButton.swift            # AppKit custom view for date sorting toggles
    ├── DownloadStateButton.swift       # Action button for pausing/resuming/canceling downloads
    ├── ExploreFilterToggleView.swift   # Filters models based on hardware compatibility
    ├── ExploreRowView.swift            # Menu item view representing a model candidate on HF
    ├── HoverCoordinator.swift          # Coordinates mouse-hover tracking across items
    ├── MarqueeLabel.swift              # Custom text drawing view that scrolls on text overflow
    ├── ModelMenuItemView.swift         # Row rendering local models with trash interaction
    ├── PulsingDotView.swift            # Renders pulsing green indicator for loaded models
    ├── SearchFieldView.swift           # Wrapper for NSSearchField within the menu
    ├── SectionHeaderView.swift         # Visual header titles with custom sort action integrations
    ├── SortIconButton.swift            # Mini sort indicators
    ├── SourceToggleRowView.swift       # Checkbox buttons toggling HuggingFace vs LM Studio scan
    ├── TabSwitcherView.swift           # Tab button controls
    ├── TotalRowView.swift              # Sum of disk footprint of visible models
    ├── UpdateAvailableRowView.swift    # Top-level update banner
    └── WelcomePopover.swift            # Onboarding visual indicator for first launch
```

---

## 3. Key Design Patterns and Constraints

### 3.1 Custom SwiftUI-Free AppKit Menu Views
Because Model Hub runs strictly as a macOS menu-bar application, it uses AppKit (`NSMenu`, `NSMenuItem`) rather than a SwiftUI scene. However, rather than standard menu text items, **almost every row utilizes custom `NSView` subclasses assigned to `NSMenuItem.view`** (e.g., `ModelMenuItemView`, `SearchFieldView`, `TabSwitcherView`).
- If you build new interactive components, subclass `NSView` directly.
- Avoid using SwiftUI's `NSHostingView` inside the menu items as it can cause rendering lag, layout glitches, and target interaction delays in highly dynamic menu contexts.

### 3.2 Thread-Safe Async Downloading (`DownloadManager`)
- The `DownloadManager` runs strictly on `@MainActor` and configures its underlying `URLSession` to use `delegateQueue: .main`.
- All mutability (tracking arrays, file progresses, current downloads) is touched only from the main thread. No custom lock synchronization is required.
- Do not move delegate callbacks to custom concurrent queues.

### 3.3 Replicating the HuggingFace CLI Cache Layout (`HFCacheWriter`)
Model Hub is fully compatible with HuggingFace CLI. When downloading, `HFCacheWriter` creates standard layouts to ensure that downloaded files can be resolved by tools like `transformers`, `mlx-lm`, and `llama.cpp`.
The structure created:
```
~/.cache/huggingface/hub/
└── models--{publisher}--{repo}/
    ├── blobs/
    │   └── {blobHash}          # Actual file content
    ├── refs/
    │   └── main                # File containing the latest commit SHA
    └── snapshots/
        └── {commit_sha}/
            └── {filename}      # Relative symlink -> ../../blobs/{blobHash}
```
> [!IMPORTANT]
> Symlinks created in `snapshots/{commit_sha}` MUST be relative symlinks (`../../blobs/...`). This matches HuggingFace behavior and allows users to safely move their cache directory.

### 3.4 LM Studio Memory Check (`LiveLoadedChecker`)
To detect which model is loaded in memory:
- LM Studio runs an OpenAI-compatible REST server.
- `LiveLoadedChecker` queries `http://127.0.0.1:1234/v1/models`.
- This is run **synchronously** in the menu's lifecycle callback (`menuNeedsUpdate(_:)`) using a `DispatchSemaphore` with a **strict 0.4-second timeout**.
- Running it synchronously ensures the green dot renders immediately on menu open without flickering. The strict timeout ensures the UI never hangs if LM Studio is closed or unresponsive.

---

## 4. Development Guidelines

1. **Target Requirements:** Ensure you compile using Xcode 16+ on macOS 15+.
2. **Main Thread Safety:** Never run blocking synchronous I/O or directory scans outside of short-circuited checks. Heavy calculations like folder size summation (`SizeUtil`) are cached to prevent lag when the menu opens.
3. **Menu Rebuilding Lifecycle:** The `MenuController` updates dynamic rows on `menuNeedsUpdate(_:)`. Keep this step as lightweight as possible. Avoid redundant disk scanning by utilizing caches (`lmEntries`, `hfEntries`).
4. **Symlinks & Deletions:** When a user moves a model to the Trash (via `ModelMenuItemView`), the app moves the parent `models--...` folder to the Trash rather than doing an un-recoverable hard delete. Keep this behavior intact for user data safety.
5. **Coding Style & Documentation:** Keep the code expressive, comment complex layout math constraints, and preserve existing API boundaries.
