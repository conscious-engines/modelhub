//
//  DownloadStateButton.swift
//  modelhub
//

import AppKit

/// Single button that renders the right SF symbol + tint + tooltip for
/// any ``DownloadState``, and forwards taps with the current state so
/// the caller can decide whether to start, pause, or resume.
///
/// ## Symbol map
///
/// | State          | Symbol                              | Tint           |
/// |----------------|-------------------------------------|----------------|
/// | `notStarted`   | `arrow.down.circle.fill`            | secondaryLabel |
/// | `queued`       | `arrow.down.circle.dotted`          | accent         |
/// | `downloading`  | `arrow.down.circle` (variableValue=p)| accent        |
/// | `paused`       | `arrow.down.circle.badge.pause`     | accent         |
/// | `completed`    | `checkmark.circle.fill`             | systemGreen    |
/// | `failed`       | `arrow.down.circle.fill`            | systemOrange   |
///
/// `arrow.down.circle` exposes the ring around the arrow as a variable
/// layer, so passing the download progress as `variableValue` paints
/// the ring as a progress indicator natively.
final class DownloadStateButton: NSButton {
    /// Most recent state passed to ``update(state:)``. Forwarded back
    /// to the tap handler so the caller has the matching context.
    private(set) var currentState: DownloadState = .notStarted

    /// Whether the parent row is currently hovered. Owners (e.g.
    /// ``ExploreRowView``) should toggle this from their hover handlers
    /// so the icon's tint matches the row's highlight without fighting
    /// the per-state color.
    var rowIsHovered: Bool = false {
        didSet { applyTint() }
    }

    /// Tap callback. Receives the state that was active at click time.
    var onTap: ((DownloadState) -> Void)?

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 18, height: 18))
        isBordered = false
        bezelStyle = .shadowlessSquare
        imagePosition = .imageOnly
        target = self
        action = #selector(tapped(_:))
        update(state: .notStarted)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    /// Update icon and tooltip to match the given state. Tint is
    /// applied separately by ``applyTint()`` so it can also re-resolve
    /// when ``rowIsHovered`` flips.
    func update(state: DownloadState) {
        self.currentState = state
        let symbolName: String
        var variableValue: Double = 1.0

        switch state {
        case .notStarted:
            symbolName = "arrow.down.circle.fill"
        case .queued:
            // arrow.down.circle.dotted exists in SF Symbols 5+ (macOS 14.4+).
            // Falls back to nil if unavailable — acceptable for the brief
            // pre-download window.
            symbolName = "arrow.down.circle.dotted"
        case .downloading(let progress, _, _, _):
            symbolName = "arrow.down.circle"
            variableValue = max(0.001, min(1.0, progress))
        case .paused:
            symbolName = "arrow.down.circle.badge.pause"
        case .completed:
            symbolName = "checkmark.circle.fill"
        case .failed:
            symbolName = "arrow.down.circle.fill"
        }

        let image = NSImage(
            systemSymbolName: symbolName,
            variableValue: variableValue,
            accessibilityDescription: nil
        )
        image?.isTemplate = true
        self.image = image
        self.toolTip = makeTooltip(for: state)
        applyTint()

        // Completed is terminal — disable so taps do nothing visually.
        // (The tap handler also no-ops, but disabling kills the highlight.)
        if case .completed = state {
            self.isEnabled = false
        } else {
            self.isEnabled = true
        }
    }

    /// Pick the right tint for the current state + hover combination:
    /// - Completed stays systemGreen regardless of hover.
    /// - Failed stays systemOrange.
    /// - Everything else mirrors the row's hover-aware label colors
    ///   (white on hover, secondary off hover).
    private func applyTint() {
        switch currentState {
        case .completed:
            self.contentTintColor = .systemGreen
        case .failed:
            self.contentTintColor = .systemOrange
        case .notStarted, .queued, .downloading, .paused:
            self.contentTintColor = rowIsHovered
                ? .selectedMenuItemTextColor
                : .secondaryLabelColor
        }
    }

    // MARK: - Tooltip

    private func makeTooltip(for state: DownloadState) -> String {
        switch state {
        case .notStarted:
            return "Download from HuggingFace"
        case .queued:
            return "Preparing…"
        case .downloading(let progress, let downloaded, let total, let speed):
            let pct = Int(progress * 100)
            let dl = SizeUtil.format(downloaded)
            let tot = total > 0 ? SizeUtil.format(total) : "—"
            let spd = formatSpeed(speed)
            return "\(dl) / \(tot)  ·  \(pct)%  ·  \(spd)\nClick to pause"
        case .paused(let progress, let downloaded, let total):
            let pct = Int(progress * 100)
            let dl = SizeUtil.format(downloaded)
            let tot = total > 0 ? SizeUtil.format(total) : "—"
            return "Paused  ·  \(dl) / \(tot)  ·  \(pct)%\nClick to resume"
        case .completed:
            return "Downloaded — appears in Local on next open"
        case .failed(let msg):
            return "Failed: \(msg)\nClick to retry"
        }
    }

    private func formatSpeed(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_000_000 {
            return String(format: "%.1f MB/s", bytesPerSec / 1_000_000)
        }
        if bytesPerSec >= 1_000 {
            return String(format: "%.0f KB/s", bytesPerSec / 1_000)
        }
        return "\(Int(bytesPerSec)) B/s"
    }

    @objc private func tapped(_ sender: Any?) {
        onTap?(currentState)
    }
}
