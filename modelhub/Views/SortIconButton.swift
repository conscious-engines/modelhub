//
//  SortIconButton.swift
//  modelhub
//

import AppKit

/// Three-state icon button used for size sorting in section headers.
///
/// Visual states:
/// - ``SortState/inactive``: `arrow.up.arrow.down`, secondary tint.
/// - ``SortState/asc``: `arrow.up`, accent tint.
/// - ``SortState/desc``: `arrow.down`, accent tint.
///
/// Setting ``sortState`` automatically swaps the SF Symbol and tint.
final class SortIconButton: NSButton {
    /// Direction the parent section is currently sorted in.
    enum SortState {
        case inactive, asc, desc
    }

    /// Current state; assigning refreshes the icon.
    var sortState: SortState = .inactive {
        didSet { refreshIcon() }
    }

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 14, height: 14))
        isBordered = false
        bezelStyle = .shadowlessSquare
        imagePosition = .imageOnly
        toolTip = "Sort by size"
        refreshIcon()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func refreshIcon() {
        let symbolName: String
        switch sortState {
        case .inactive: symbolName = "arrow.up.arrow.down"
        case .asc:      symbolName = "arrow.up"
        case .desc:     symbolName = "arrow.down"
        }
        let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Sort by size")
        img?.isTemplate = true
        image = img
        contentTintColor = (sortState == .inactive) ? .secondaryLabelColor : .controlAccentColor
    }
}
