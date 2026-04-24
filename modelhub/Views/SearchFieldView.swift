//
//  SearchFieldView.swift
//  modelhub
//

import AppKit

/// Standard `NSSearchField` wrapped in a fixed-width row for use as an
/// `NSMenuItem.view`.
///
/// Forwards every text change through ``onChange`` — wired up via both
/// the search field's target/action and `NSControl.textDidChangeNotification`
/// so single-character typing fires immediately (action alone misses
/// keystrokes when `sendsSearchStringImmediately` is set in some
/// AppKit versions).
final class SearchFieldView: NSView {
    /// Total row height. Used by ``MenuController`` for layout math.
    static let rowHeight: CGFloat = 34

    /// The underlying field. Exposed so ``MenuController`` can make it
    /// first-responder when the menu opens.
    let searchField: NSSearchField

    /// Invoked with the current text every time the user types or clears.
    var onChange: ((String) -> Void)?

    init(width: CGFloat) {
        searchField = NSSearchField()
        searchField.placeholderString = "Search models…"
        searchField.sendsWholeSearchString = false
        searchField.sendsSearchStringImmediately = true
        searchField.focusRingType = .none
        searchField.bezelStyle = .roundedBezel
        searchField.font = NSFont.systemFont(ofSize: 12)
        searchField.controlSize = .regular

        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.rowHeight))

        addSubview(searchField)
        searchField.target = self
        searchField.action = #selector(searchChanged(_:))
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textChanged(_:)),
            name: NSControl.textDidChangeNotification,
            object: searchField
        )

        searchField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            searchField.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchField.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Forwarding

    @objc private func searchChanged(_ sender: Any?) {
        onChange?(searchField.stringValue)
    }

    @objc private func textChanged(_ note: Notification) {
        onChange?(searchField.stringValue)
    }
}
