//
//  TotalRowView.swift
//  modelhub
//

import AppKit

/// Compact summary row showing the combined on-disk size of every model
/// across both sources.
///
/// Layout: `Total .................. <bytes>`. Non-interactive.
final class TotalRowView: NSView {
    /// Total row height. Used by ``MenuController`` for layout math.
    static let rowHeight: CGFloat = 26

    /// - Parameters:
    ///   - bytes: Combined on-disk size for the menu's "Total" line.
    ///   - width: Row width. Should match the menu's overall row width.
    init(bytes: Int64, width: CGFloat) {
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

        let right = NSTextField(labelWithString: "")
        right.isBezeled = false
        right.isEditable = false
        right.drawsBackground = false
        right.alignment = .right
        right.attributedStringValue = NSAttributedString(string: SizeUtil.format(bytes), attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor
        ])

        addSubview(left)
        addSubview(right)
        left.translatesAutoresizingMaskIntoConstraints = false
        right.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            left.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            left.centerYAnchor.constraint(equalTo: centerYAnchor),
            right.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            right.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }
}
