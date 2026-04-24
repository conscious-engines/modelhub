//
//  SectionHeaderView.swift
//  modelhub
//

import AppKit

/// Header row that sits above a section's model rows.
///
/// Layout, left to right:
/// `[TITLE · count]   …   [size sort]  [date sort]  [folder]`
///
/// The size and date sort buttons are hidden when the section has fewer
/// than two models — there's nothing to sort. The folder button always
/// reveals the section's root in Finder, even for empty sections.
final class SectionHeaderView: NSView {
    /// Total row height. Used by ``MenuController`` for layout math.
    static let rowHeight: CGFloat = 26

    /// Absolute path opened when the folder icon is clicked.
    let rootPath: String

    /// Weak reference back to the host menu so the folder button can
    /// dismiss it cleanly when revealing the folder in Finder.
    weak var menuRef: NSMenu?

    /// Exposed so ``MenuController`` can update its visual state in place
    /// after a sort change without rebuilding the header.
    let sizeButton: SortIconButton

    /// Exposed for the same reason as ``sizeButton``.
    let dateButton: DateSortButton

    private let titleField: NSTextField
    private let folderButton: NSButton

    /// Invoked when the size sort button is clicked.
    var onSizeSortClicked: (() -> Void)?

    /// Invoked when the date sort button is clicked.
    var onDateSortClicked: (() -> Void)?

    /// - Parameters:
    ///   - title: Section title (e.g. `"LM Studio"`). Rendered upper-cased.
    ///   - count: Model count shown next to the title.
    ///   - rootPath: Absolute path opened by the folder button.
    ///   - width: Row width. Should match the menu's overall row width.
    ///   - menuRef: The host menu, captured weakly so the folder button
    ///     can dismiss it.
    ///   - sizeSortState: Initial state for the size sort button.
    ///   - dateSortState: Initial state for the date sort button.
    ///   - showSortControls: When `false`, both sort buttons are hidden
    ///     (used for sections with 0 or 1 models).
    init(
        title: String,
        count: Int,
        rootPath: String,
        width: CGFloat,
        menuRef: NSMenu?,
        sizeSortState: SortIconButton.SortState,
        dateSortState: DateSortButton.SortState,
        showSortControls: Bool
    ) {
        self.rootPath = rootPath
        self.menuRef = menuRef

        titleField = NSTextField(labelWithString: "")
        titleField.isBezeled = false
        titleField.isEditable = false
        titleField.drawsBackground = false

        let attr = NSMutableAttributedString()
        attr.append(NSAttributedString(string: title.uppercased(), attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
            .kern: 0.7
        ]))
        attr.append(NSAttributedString(string: "   ·   \(count)", attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]))
        titleField.attributedStringValue = attr

        folderButton = NSButton()
        folderButton.isBordered = false
        folderButton.bezelStyle = .shadowlessSquare
        let img = NSImage(systemSymbolName: "folder", accessibilityDescription: "Open folder")
        img?.isTemplate = true
        folderButton.image = img
        folderButton.imagePosition = .imageOnly
        folderButton.toolTip = "Open folder in Finder"
        folderButton.contentTintColor = .secondaryLabelColor

        sizeButton = SortIconButton()
        sizeButton.sortState = sizeSortState
        sizeButton.isHidden = !showSortControls

        dateButton = DateSortButton()
        dateButton.sortState = dateSortState
        dateButton.isHidden = !showSortControls

        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.rowHeight))

        addSubview(titleField)
        addSubview(sizeButton)
        addSubview(dateButton)
        addSubview(folderButton)

        folderButton.target = self
        folderButton.action = #selector(openFolder(_:))
        sizeButton.target = self
        sizeButton.action = #selector(sizeSortClicked(_:))
        dateButton.onClick = { [weak self] in self?.onDateSortClicked?() }

        titleField.translatesAutoresizingMaskIntoConstraints = false
        folderButton.translatesAutoresizingMaskIntoConstraints = false
        sizeButton.translatesAutoresizingMaskIntoConstraints = false
        dateButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),

            folderButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            folderButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            folderButton.widthAnchor.constraint(equalToConstant: 16),
            folderButton.heightAnchor.constraint(equalToConstant: 16),

            dateButton.trailingAnchor.constraint(equalTo: folderButton.leadingAnchor, constant: -10),
            dateButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            dateButton.widthAnchor.constraint(equalToConstant: 18),
            dateButton.heightAnchor.constraint(equalToConstant: 16),

            sizeButton.trailingAnchor.constraint(equalTo: dateButton.leadingAnchor, constant: -8),
            sizeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            sizeButton.widthAnchor.constraint(equalToConstant: 14),
            sizeButton.heightAnchor.constraint(equalToConstant: 14),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Actions

    @objc private func openFolder(_ sender: Any?) {
        NSWorkspace.shared.open(URL(fileURLWithPath: rootPath))
        menuRef?.cancelTracking()
    }

    @objc private func sizeSortClicked(_ sender: Any?) {
        onSizeSortClicked?()
    }
}
