//
//  DateSortButton.swift
//  modelhub
//

import AppKit

/// Clock icon with a tiny chevron overlay indicating date-sort direction.
///
/// Built as a custom `NSView` rather than `NSButton` because it needs
/// two stacked `NSImageView`s — the clock body and the corner chevron —
/// plus its own hover tracking for tint behavior.
///
/// Visual states:
/// - ``SortState/inactive``: clock only, secondary tint.
/// - ``SortState/asc``: clock + `chevron.up`, both accent tinted.
/// - ``SortState/desc``: clock + `chevron.down`, both accent tinted.
final class DateSortButton: NSView {
    /// Direction the parent section is currently sorted in.
    enum SortState {
        case inactive, asc, desc
    }

    /// Current state; assigning refreshes the appearance.
    var sortState: SortState = .inactive {
        didSet { refreshAppearance() }
    }

    /// Invoked when the user clicks anywhere inside the button bounds.
    var onClick: (() -> Void)?

    private let clockView = NSImageView()
    private let arrowView = NSImageView()
    private var trackingArea: NSTrackingArea?
    private var isHovered = false

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 18, height: 16))
        wantsLayer = true
        toolTip = "Sort by date added"

        let clockImg = NSImage(systemSymbolName: "clock", accessibilityDescription: "Sort by date")
        clockImg?.isTemplate = true
        clockView.image = clockImg
        clockView.imageScaling = .scaleProportionallyUpOrDown

        arrowView.imageScaling = .scaleProportionallyUpOrDown
        arrowView.isHidden = true

        addSubview(clockView)
        addSubview(arrowView)

        clockView.translatesAutoresizingMaskIntoConstraints = false
        arrowView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            clockView.leadingAnchor.constraint(equalTo: leadingAnchor),
            clockView.centerYAnchor.constraint(equalTo: centerYAnchor),
            clockView.widthAnchor.constraint(equalToConstant: 13),
            clockView.heightAnchor.constraint(equalToConstant: 13),

            arrowView.trailingAnchor.constraint(equalTo: trailingAnchor),
            arrowView.topAnchor.constraint(equalTo: topAnchor),
            arrowView.widthAnchor.constraint(equalToConstant: 8),
            arrowView.heightAnchor.constraint(equalToConstant: 8),
        ])

        refreshAppearance()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Tracking

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = trackingArea { removeTrackingArea(ta) }
        let ta = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(ta)
        trackingArea = ta
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        refreshAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        refreshAppearance()
    }

    override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        guard bounds.contains(loc) else { return }
        onClick?()
    }

    // MARK: - Appearance

    private func refreshAppearance() {
        let active = sortState != .inactive
        let baseColor: NSColor = active ? .controlAccentColor : .secondaryLabelColor
        clockView.contentTintColor = isHovered
            ? (active ? .controlAccentColor : .labelColor)
            : baseColor

        switch sortState {
        case .inactive:
            arrowView.isHidden = true
        case .asc:
            let img = NSImage(systemSymbolName: "chevron.up", accessibilityDescription: nil)
            img?.isTemplate = true
            arrowView.image = img
            arrowView.contentTintColor = .controlAccentColor
            arrowView.isHidden = false
        case .desc:
            let img = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)
            img?.isTemplate = true
            arrowView.image = img
            arrowView.contentTintColor = .controlAccentColor
            arrowView.isHidden = false
        }
    }
}
