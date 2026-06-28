# User Interface and Experience Design

This document outlines the visual system, typography, layout rules, and interaction paradigms that define the **Model Hub** user experience. 

---

## 1. Design Philosophy

Model Hub is designed as a **macOS Menu-Bar Utility**. Because it resides directly in the system status bar, it follows specific design constraints:
- **System Cohesion:** Integration with native macOS Light and Dark modes, adapting automatically to system accent and selection highlight colors.
- **High Information Density:** Fitting complex model identifiers, file sizes, format/quantization tags, loaded state markers, and actions within a compact menu structure.
- **Zero-Friction Interactions:** Automatic keyboard focus on the search field, instant in-place filtering, and hover-triggered secondary actions (e.g., revealing trash or copying identifiers).

---

## 2. Typography & Core Colors

To ensure readability and clean visual alignments, Model Hub utilizes tailored typographic rules using native system fonts:

| Element | Font Type & Weight | Size | Default Tint | Highlight Tint |
| :--- | :--- | :--- | :--- | :--- |
| **Model Family Tag** | Monospaced System, Medium | 11pt | `secondaryLabelColor` | `selectedMenuItemTextColor` (75% alpha) |
| **Model Display Name** | Standard System, Medium | 13pt | `labelColor` | `selectedMenuItemTextColor` |
| **Format/Quant Label** | Monospaced System, Regular | 10pt | `tertiaryLabelColor` | `selectedMenuItemTextColor` (70% alpha) |
| **Model Size Text** | Monospaced Digit, Regular | 11pt | `tertiaryLabelColor` | `selectedMenuItemTextColor` (80% alpha) |
| **Compatibility Status** | Monospaced System, Semibold | 9pt | `systemOrange` (`SLOW`) | `selectedMenuItemTextColor` (78% alpha) |

### Accent and Interactive Colors
- **Active Selection:** Native `selectedContentBackgroundColor` and `selectedMenuItemTextColor` are drawn dynamically during mouse-hover events.
- **Loaded Status:** A vibrant, pulsing `systemGreen` indicates a model currently resident in LM Studio's memory.
- **Compatibility Alert:** `systemOrange` is reserved for the `SLOW` warning badge, indicating a model that might over-commit the Mac's physical RAM.

---

## 3. Structural Layouts & Menu Rows

The menu has a hardcoded layout width of **360px** (`currentRowWidth`), ensuring that items align neatly and stay legible within the status bar viewport.

### 3.1 Local Tab Item Layout (`ModelMenuItemView`)
Renders models already present on the local filesystem.

```
[tag]  Display Name  ·  TYPE LABEL  ●        12.4 GB
```

- **Pulsing Dot:** A small green dot (8px diameter) that pulses using Core Animation (`CABasicAnimation` on opacity from `0.35` to `1.0` over `1.1` seconds, ease-in-out) if the model is resident in memory.
- **Trash Button Interaction:** A trash button is normally hidden off-screen on the right. When the user hovers over a row, the trash button slides in from the trailing edge, and the size field slides slightly left to make room.
- **Copy Action:** Clicking anywhere on the row body copies the model's copyable ID (e.g. `qwen/qwen2.5-7b-instruct-mlx`) to the pasteboard and displays a temporary "Copied to clipboard!" overlay in place of the title.

### 3.2 Explore Tab Item Layout (`ExploreRowView`)
Renders search candidates fetched from the HuggingFace API.

```
[avatar]  [tag]  Display Name  ·  TYPE LABEL  [SLOW]  12.4 GB  [button]
```

- **Publisher Avatar:** A circular 20px avatar displays on the left, lazily fetched and cached using `AuthorAvatarView` based on the HF username.
- **Compatibility Warning:** If the model's size exceeds 75% of system RAM but is under 90%, it renders a custom orange `SLOW` badge. If it exceeds 90%, it gets filtered/flagged.
- **Download Action:** An interactive `DownloadStateButton` is pinned to the trailing edge, rendering inline download states (queued, progress bar, pause/resume, finished).

---

## 4. Control Panels and Navigation

### 4.1 Search Bar (`SearchFieldView`)
- Pinned to the top of the menu, wrapping a native `NSSearchField`.
- Focus is automatically captured on menu open via AppKit's first responder chain.
- Key inputs filter the local list in-place instantly or fire a debounced API query if the user is browsing the "Explore" tab.

### 4.2 Tab Switcher (`TabSwitcherView`)
- A segmented controller switching between **Local** and **Explore** views.
- Swapping tabs modifies the dynamic middle section of the menu while preserving search string and keyboard focus, preventing the menu from closing.

### 4.3 Headers and Inline Controls (`SectionHeaderView`)
- Visual headers (e.g. "LM STUDIO" or "HUGGING FACE") containing inline sorting controls (`DateSortButton` or `SortIconButton`).
- Clicking sort updates the dataset and redraws rows dynamically without closing the menu.
