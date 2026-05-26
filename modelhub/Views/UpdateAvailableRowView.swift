//
//  UpdateAvailableRowView.swift
//  modelhub
//

import AppKit

/// Top-of-menu banner shown when ``UpdateManager`` has a pending update.
///
/// ## Layout
///
/// `[ ↓ icon ]  Update available · 1.2.0   ────────────   [ Update ]`
///
/// Subtle accent tint draws the eye without making the banner shout.
/// Tapping the Update button hands control back to Sparkle via
/// ``UpdateManager/installPending``.
///
/// ## Animation
///
/// When `animated: true`, the row's content fades in and slides down
/// 8pt to settle into place over ~220ms. The animation is purely
/// internal to the row — NSMenu doesn't animate item insertion itself,
/// but animating the row's content is enough to feel "graceful" when
/// the banner appears while the menu is already open.
final class UpdateAvailableRowView: NSView {
    /// Row height. Slightly taller than the search / tab rows so the
    /// banner reads as a distinct band rather than another menu row.
    static let rowHeight: CGFloat = 36
    static let horizontalPadding: CGFloat = 14

    /// Invoked when the user clicks the Update button.
    var onUpdate: (() -> Void)?

    private let contentView: NSView
    private let backgroundLayer: CALayer

    init(version: String, width: CGFloat, animated: Bool) {
        contentView = NSView()
        backgroundLayer = CALayer()

        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.rowHeight))

        // The outer NSView is transparent. The accent tint and content
        // live on contentView so animating its alpha + transform
        // doesn't drag the menu's own background with it.
        //
        // The top corners are rounded to echo the menu's own rounded
        // top edge — the banner reads as a contained shape that "caps"
        // the menu rather than a rectangular row glued on top. NSMenu's
        // ~5pt internal item inset means the banner can't physically
        // bleed into the menu's corner pixels, but the matched corner
        // radius makes the relationship visually intentional.
        //
        // CACornerMask uses layer-space corner names. With NSView's
        // default non-flipped geometry the layer's Y axis points up, so
        // the visual top-left/top-right are MinXMaxY and MaxXMaxY.
        wantsLayer = true
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.controlAccentColor
            .withAlphaComponent(0.10).cgColor
        contentView.layer?.cornerRadius = 10
        contentView.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]

        addSubview(contentView)
        contentView.frame = bounds
        contentView.autoresizingMask = [.width, .height]

        // Icon
        let icon = NSImageView(image: NSImage(
            systemSymbolName: "arrow.down.circle.fill",
            accessibilityDescription: nil
        ) ?? NSImage())
        icon.contentTintColor = .controlAccentColor
        icon.imageScaling = .scaleProportionallyUpOrDown

        // Label
        let label = NSTextField(labelWithString: "Update available · \(version)")
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail

        // Button
        let button = NSButton(title: "Update", target: self, action: #selector(updateTapped))
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = NSFont.systemFont(ofSize: 11, weight: .medium)

        contentView.addSubview(icon)
        contentView.addSubview(label)
        contentView.addSubview(button)

        icon.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Self.horizontalPadding),
            icon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),

            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Self.horizontalPadding),
            button.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            label.trailingAnchor.constraint(lessThanOrEqualTo: button.leadingAnchor, constant: -10),
        ])

        if animated {
            playIntroAnimation()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Animation

    /// Fades the content in while sliding it 8pt down into its final
    /// position. Plays once on insert.
    private func playIntroAnimation() {
        contentView.alphaValue = 0
        contentView.layer?.setAffineTransform(CGAffineTransform(translationX: 0, y: -8))
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            contentView.animator().alphaValue = 1
            contentView.layer?.setAffineTransform(.identity)
        }
    }

    @objc private func updateTapped() {
        onUpdate?()
    }
}
