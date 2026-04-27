//
//  WelcomePopover.swift
//  modelhub
//

import AppKit

/// First-run popover that points at the menu-bar icon and tells the
/// user the app lives there.
///
/// Triggered once via a `UserDefaults` flag — wiped only by clearing
/// the app's defaults (e.g. for testing). Anchors to the
/// `NSStatusItem.button` so AppKit handles the menu-bar coordinate
/// math; we never have to compute screen positions ourselves.
enum WelcomePopover {
    private static let seenKey = "modelhub.hasSeenWelcomePopover"
    private static let initialDelay: TimeInterval = 0.2
    private static let autoDismissAfter: TimeInterval = 8.0

    /// One-shot reference to the active popover so the auto-dismiss
    /// timer doesn't fire after a manual dismissal.
    private static var active: NSPopover?

    /// Show the popover the first time the app launches. No-op on
    /// subsequent launches.
    static func showIfNeeded(anchor button: NSStatusBarButton) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: seenKey) else { return }
        defaults.set(true, forKey: seenKey)

        // Brief delay so the menu-bar item has settled into place by
        // the time the popover anchors to it.
        DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay) { [weak button] in
            guard let button else { return }
            present(anchor: button)
        }
    }

    private static func present(anchor button: NSStatusBarButton) {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = WelcomeViewController()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        active = popover

        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissAfter) { [weak popover] in
            guard let popover, popover === active else { return }
            popover.performClose(nil)
            active = nil
        }
    }
}

private final class WelcomeViewController: NSViewController {
    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 92))

        let icon = NSImageView()
        let symbol = NSImage(systemSymbolName: "arrow.up", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 16, weight: .semibold))
        icon.image = symbol
        icon.contentTintColor = .controlAccentColor

        let title = NSTextField(labelWithString: "Model Hub lives here!")
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        title.alignment = .center
        title.textColor = .labelColor
        title.isBezeled = false
        title.isEditable = false
        title.drawsBackground = false

        let subtitle = NSTextField(labelWithString:
            "Click the cube in the menu bar to browse and manage your models."
        )
        subtitle.font = NSFont.systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        subtitle.alignment = .center
        subtitle.maximumNumberOfLines = 0
        subtitle.usesSingleLineMode = false
        subtitle.cell?.wraps = true
        subtitle.cell?.lineBreakMode = .byWordWrapping
        subtitle.isBezeled = false
        subtitle.isEditable = false
        subtitle.drawsBackground = false

        container.addSubview(icon)
        container.addSubview(title)
        container.addSubview(subtitle)

        icon.translatesAutoresizingMaskIntoConstraints = false
        title.translatesAutoresizingMaskIntoConstraints = false
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            icon.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),

            title.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 6),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            title.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            subtitle.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            subtitle.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            subtitle.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -12),
        ])

        view = container
    }
}
