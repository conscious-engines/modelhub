# Contributing to Model Hub

Thank you for your interest in contributing to Model Hub! We welcome contributions to make this macOS menu-bar utility even better.

Please review the following guidelines before you start contributing.

---

## Technical Stack & Requirements

- **Language:** Swift (Modern Swift with Swift Concurrency)
- **UI Framework:** AppKit (`NSMenu`, `NSMenuItem`, custom `NSView` subclasses)
- **Deployment Target:** macOS 15.0+
- **Build System:** Xcode 16.0+ (`modelhub.xcodeproj`)
- **Key Dependencies:**
  - **Sparkle 2.x** (integrated via SPM) for updates.

---

## Design and Architecture Constraints

Before making UI changes, please keep the following design constraints in mind:

1. **Custom SwiftUI-Free AppKit Menu Views:**
   Model Hub uses custom `NSView` subclasses assigned to `NSMenuItem.view` rather than SwiftUI `NSHostingView`. This prevents rendering lags, layout glitches, and target interaction delays in the macOS status menu bar. Avoid using SwiftUI inside the menu view hierarchy.
2. **Main Thread Safety:**
   Heavy computations (like scanning folder sizes or querying servers) must either be cached or offloaded to background queues. LM Studio memory model updates are handled synchronously with a strict `0.4-second` timeout to ensure the menu renders immediately.
3. **Data Safety (Deletions):**
   When moving a model to the Trash, the application must move the parent directory to the system Trash rather than performing an unrecoverable hard delete.

---

## How to Contribute

### 1. Reporting Bugs / Feature Requests
If you encounter a bug or have a suggestion, please open an Issue using the appropriate issue template in this repository. Be sure to include:
- A clear, descriptive title.
- Steps to reproduce the issue.
- Your macOS version and device profile.

### 2. Making Changes
1. Fork the repository and create your branch from `main`.
2. Ensure the code compiles without warnings in Xcode 16+.
3. Maintain documentation integrity. Keep comments and docstrings up to date.
4. Verify your UI changes look premium (consistent with dark/light themes, proper padding, and hover highlights).

### 3. Submitting Pull Requests
- Keep PRs focused on a single change.
- Use a clear title and fill out the provided Pull Request template.
- Ensure your changes do not break existing scan directories or model deletion safeguards.

Thank you for helping build a better Model Hub!
