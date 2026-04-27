//
//  TabSwitcherView.swift
//  modelhub
//

import AppKit

/// Two-segment "Local | Explore" control rendered as a row at the top
/// of the menu.
///
/// Embeds a standard `NSSegmentedControl` so we get native styling and
/// keyboard behavior. Selection changes are forwarded through
/// ``onSelection`` so the controller can swap menu content.
final class TabSwitcherView: NSView {
    /// Total row height. Used by ``MenuController`` for layout math.
    static let rowHeight: CGFloat = 36

    /// Underlying control. Exposed in case the controller needs to read
    /// or update the selection externally (e.g. on rebuild).
    let segmented: NSSegmentedControl

    /// Invoked when the user picks a different segment.
    var onSelection: ((Tab) -> Void)?

    init(width: CGFloat, current: Tab) {
        segmented = NSSegmentedControl(
            labels: ["Local", "Explore"],
            trackingMode: .selectOne,
            target: nil,
            action: nil
        )
        segmented.segmentStyle = .capsule
        segmented.selectedSegment = (current == .local) ? 0 : 1

        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.rowHeight))

        addSubview(segmented)
        segmented.target = self
        segmented.action = #selector(segmentChanged(_:))

        segmented.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            segmented.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            segmented.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            segmented.centerYAnchor.constraint(equalTo: centerYAnchor),
            segmented.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    @objc private func segmentChanged(_ sender: NSSegmentedControl) {
        let tab: Tab = sender.selectedSegment == 0 ? .local : .explore
        onSelection?(tab)
    }
}
