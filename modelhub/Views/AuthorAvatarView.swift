//
//  AuthorAvatarView.swift
//  modelhub
//

import AppKit

/// Small circular avatar shown at the leading edge of an Explore row.
///
/// Renders a deterministic colored circle with the publisher's initial
/// while the real avatar fetches. When ``apply(image:fullName:)`` is
/// called with a non-nil image, the placeholder is hidden and the real
/// image takes over. Hovering anywhere on the avatar shows the
/// publisher's display name as a tooltip.
final class AuthorAvatarView: NSView {
    /// Edge length of the circle.
    static let size: CGFloat = 18

    private let imageView = NSImageView()
    private let initialLabel = NSTextField(labelWithString: "")
    private let publisher: String

    init(publisher: String) {
        self.publisher = publisher
        super.init(frame: NSRect(x: 0, y: 0, width: Self.size, height: Self.size))

        wantsLayer = true
        layer?.cornerRadius = Self.size / 2
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.backgroundColor = Self.colorForName(publisher).cgColor

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.isHidden = true
        addSubview(imageView)

        initialLabel.alignment = .center
        initialLabel.isBezeled = false
        initialLabel.isEditable = false
        initialLabel.drawsBackground = false
        initialLabel.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        initialLabel.textColor = .white
        initialLabel.stringValue = String(publisher.first ?? "?").uppercased()
        addSubview(initialLabel)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        initialLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            initialLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            initialLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        toolTip = publisher
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    /// Apply enrichment from ``HuggingFaceAPI/fetchOwner(name:)``.
    /// - Parameters:
    ///   - image: Decoded avatar image, or `nil` to keep the placeholder.
    ///   - fullName: Display name to use as the hover tooltip. Falls back
    ///     to the publisher slug when nil/empty.
    func apply(image: NSImage?, fullName: String?) {
        if let trimmed = fullName?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
            toolTip = trimmed
        } else {
            toolTip = publisher
        }

        if let image {
            imageView.image = image
            imageView.isHidden = false
            initialLabel.isHidden = true
            // Drop the placeholder fill so any image transparency reads cleanly.
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }

    // MARK: - Placeholder color

    /// Deterministic palette pick by hashing the publisher slug.
    /// Same input ⇒ same color across runs, so users build mental
    /// associations.
    static func colorForName(_ name: String) -> NSColor {
        let palette: [NSColor] = [
            NSColor(red: 0.40, green: 0.55, blue: 0.85, alpha: 1.0),
            NSColor(red: 0.86, green: 0.50, blue: 0.50, alpha: 1.0),
            NSColor(red: 0.55, green: 0.75, blue: 0.50, alpha: 1.0),
            NSColor(red: 0.92, green: 0.65, blue: 0.40, alpha: 1.0),
            NSColor(red: 0.65, green: 0.50, blue: 0.85, alpha: 1.0),
            NSColor(red: 0.40, green: 0.75, blue: 0.80, alpha: 1.0),
            NSColor(red: 0.85, green: 0.55, blue: 0.70, alpha: 1.0),
            NSColor(red: 0.50, green: 0.65, blue: 0.55, alpha: 1.0),
        ]
        let hash = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return palette[abs(hash) % palette.count]
    }
}
