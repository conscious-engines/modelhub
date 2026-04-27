//
//  TotalRowView.swift
//  modelhub
//

import AppKit

/// Compact summary row showing the combined on-disk size of every model
/// across both sources (or, while a search is active, the combined size
/// of the matching subset).
///
/// Layout: `Total .................. <bytes>`. Non-interactive.
/// Mutable via ``update(bytes:)`` so the controller can reflect a
/// filtered total without reconstructing the menu item.
final class TotalRowView: NSView {
    /// Total row height. Used by ``MenuController`` for layout math.
    static let rowHeight: CGFloat = 26

    private let rightField: NSTextField

    /// - Parameters:
    ///   - bytes: Combined on-disk size for the menu's "Total" line.
    ///   - width: Row width. Should match the menu's overall row width.
    init(bytes: Int64, width: CGFloat) {
        rightField = NSTextField(labelWithString: "")
        rightField.isBezeled = false
        rightField.isEditable = false
        rightField.drawsBackground = false
        rightField.alignment = .right

        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.rowHeight))

        let left = NSTextField(labelWithString: "")
        left.isBezeled = false
        left.isEditable = false
        left.drawsBackground = false
        left.attributedStringValue = NSAttributedString(string: "Total", attributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
            .kern: 0.3
        ])

        addSubview(left)
        addSubview(rightField)
        left.translatesAutoresizingMaskIntoConstraints = false
        rightField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            left.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            left.centerYAnchor.constraint(equalTo: centerYAnchor),
            rightField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            rightField.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        update(bytes: bytes)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    /// Replace the displayed byte count without rebuilding the row —
    /// used by ``MenuController`` to reflect a filtered total when the
    /// user types in the search bar.
    func update(bytes: Int64) {
        rightField.attributedStringValue = NSAttributedString(string: SizeUtil.format(bytes), attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor
        ])
    }
}
