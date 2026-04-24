//
//  MenuController.swift
//  modelhub
//

import AppKit

/// Owns the status-bar menu and orchestrates everything inside it:
/// scanning, sizing, sort state, search filtering, and per-section row
/// reordering.
///
/// ## Lifecycle
///
/// 1. ``AppDelegate`` creates one `MenuController` and assigns its
///    ``menu`` to the `NSStatusItem`.
/// 2. `NSMenuDelegate` callbacks drive everything else:
///    - `menuNeedsUpdate(_:)` → ``rebuild()`` re-scans both directories,
///      rebuilds all rows, re-applies the persisted sort modes.
///    - `menuDidOpen(_:)` → makes the search field first responder so the
///      user can type immediately.
/// 3. While the menu is open, the search field's `onChange` calls
///    ``applyFilter(query:)`` to hide/show rows in place, and tapping
///    a sort button calls ``setSort(_:mode:)`` which removes that
///    section's rows and re-inserts them in the new order without
///    closing the menu.
final class MenuController: NSObject, NSMenuDelegate, NSSearchFieldDelegate {
    /// The status-bar menu owned by this controller.
    let menu: NSMenu

    // MARK: - Tracking structures

    /// Pairing of a menu item with its model, used to drive search
    /// filtering and per-source removal during sort reorder.
    private struct RowEntry {
        let item: NSMenuItem
        let model: ParsedModel
    }

    private var rows: [RowEntry] = []
    private var lmHeaderItem: NSMenuItem?
    private var hfHeaderItem: NSMenuItem?
    private var middleSeparator: NSMenuItem?
    private var lmEmptyItem: NSMenuItem?
    private var hfEmptyItem: NSMenuItem?
    private var searchFieldView: SearchFieldView?

    // MARK: - Persistent state

    /// Sort state — persists across menu opens.
    private var lmSortMode: SortMode = .name
    /// Sort state — persists across menu opens.
    private var hfSortMode: SortMode = .name

    /// Cached entries so per-section sort can reorder rows without
    /// re-reading the filesystem.
    private var lmEntries: [ModelEntry] = []
    private var hfEntries: [ModelEntry] = []

    /// Cached row width so reorder uses the same layout as the
    /// initial build.
    private var currentRowWidth: CGFloat = 320

    // MARK: - Init

    override init() {
        menu = NSMenu()
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild()
    }

    func menuDidOpen(_ menu: NSMenu) {
        // Focus the search field so typing filters immediately.
        DispatchQueue.main.async { [weak self] in
            guard let sf = self?.searchFieldView?.searchField else { return }
            sf.window?.makeFirstResponder(sf)
        }
    }

    // MARK: - Build

    /// Wipes the menu and rebuilds it from a fresh disk scan, while
    /// preserving the per-section sort modes from the previous open.
    private func rebuild() {
        menu.removeAllItems()
        rows.removeAll()

        let lm = ModelScanner.scanLMStudio()
        let hf = ModelScanner.scanHuggingFace()
        let loaded = LiveLoadedChecker.loadedCopyableIDs()

        lmEntries = lm.map { m in
            ModelEntry(
                model: m,
                bytes: SizeUtil.directorySize(at: m.fullPath),
                dateAdded: SizeUtil.dateAdded(at: m.fullPath),
                loaded: loaded.contains(m.copyableID)
            )
        }
        hfEntries = hf.map { m in
            ModelEntry(
                model: m,
                bytes: SizeUtil.directorySize(at: m.fullPath),
                dateAdded: SizeUtil.dateAdded(at: m.fullPath),
                loaded: false
            )
        }
        let totalBytes: Int64 = (lmEntries + hfEntries).map(\.bytes).reduce(0, +)

        // Figure out a row width that fits the widest title+size.
        let maxTitle = (lm + hf).map { ModelMenuItemView.titleIntrinsicWidth(for: $0) }.max() ?? 200
        let maxSize = (lmEntries + hfEntries)
            .map { ModelMenuItemView.sizeIntrinsicWidth(for: $0.bytes) }
            .max() ?? 50
        let computed = ModelMenuItemView.horizontalPadding
            + maxTitle
            + ModelMenuItemView.dotGap + ModelMenuItemView.dotSize
            + ModelMenuItemView.sizeGap + maxSize
            + ModelMenuItemView.trashGap + ModelMenuItemView.trashSize
            + ModelMenuItemView.horizontalPadding
        currentRowWidth = ceil(max(360, min(600, computed)))
        let rowWidth = currentRowWidth

        // Search bar
        let sfView = SearchFieldView(width: rowWidth)
        sfView.onChange = { [weak self] query in self?.applyFilter(query: query) }
        let searchItem = NSMenuItem()
        searchItem.view = sfView
        menu.addItem(searchItem)
        searchFieldView = sfView

        menu.addItem(.separator())

        // LM Studio section
        let lmH = NSMenuItem()
        let lmHeader = SectionHeaderView(
            title: "LM Studio",
            count: lm.count,
            rootPath: ModelPaths.lmStudioRoot,
            width: rowWidth,
            menuRef: menu,
            sizeSortState: lmSortMode.sizeButtonState,
            dateSortState: lmSortMode.dateButtonState,
            showSortControls: lmEntries.count >= 2
        )
        lmHeader.onSizeSortClicked = { [weak self] in self?.toggleSizeSort(.lmStudio) }
        lmHeader.onDateSortClicked = { [weak self] in self?.toggleDateSort(.lmStudio) }
        lmH.view = lmHeader
        menu.addItem(lmH)
        lmHeaderItem = lmH

        if lmEntries.isEmpty {
            let empty = disabledTextItem("No models")
            lmEmptyItem = empty
            menu.addItem(empty)
        } else {
            let sorted = sortEntries(lmEntries, mode: lmSortMode)
            for entry in sorted {
                let item = makeModelItem(model: entry.model, bytes: entry.bytes, loaded: entry.loaded, width: rowWidth)
                rows.append(RowEntry(item: item, model: entry.model))
                menu.addItem(item)
            }
        }

        let sep = NSMenuItem.separator()
        middleSeparator = sep
        menu.addItem(sep)

        // Hugging Face section
        let hfH = NSMenuItem()
        let hfHeader = SectionHeaderView(
            title: "Hugging Face",
            count: hf.count,
            rootPath: ModelPaths.huggingFaceRoot,
            width: rowWidth,
            menuRef: menu,
            sizeSortState: hfSortMode.sizeButtonState,
            dateSortState: hfSortMode.dateButtonState,
            showSortControls: hfEntries.count >= 2
        )
        hfHeader.onSizeSortClicked = { [weak self] in self?.toggleSizeSort(.huggingFace) }
        hfHeader.onDateSortClicked = { [weak self] in self?.toggleDateSort(.huggingFace) }
        hfH.view = hfHeader
        menu.addItem(hfH)
        hfHeaderItem = hfH

        if hfEntries.isEmpty {
            let empty = disabledTextItem("No models")
            hfEmptyItem = empty
            menu.addItem(empty)
        } else {
            let sorted = sortEntries(hfEntries, mode: hfSortMode)
            for entry in sorted {
                let item = makeModelItem(model: entry.model, bytes: entry.bytes, loaded: entry.loaded, width: rowWidth)
                rows.append(RowEntry(item: item, model: entry.model))
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        // Total row
        let totalItem = NSMenuItem()
        totalItem.view = TotalRowView(bytes: totalBytes, width: rowWidth)
        menu.addItem(totalItem)

        menu.addItem(.separator())

        // Quit
        let quit = NSMenuItem(
            title: "Quit Model Hub",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.target = NSApp
        menu.addItem(quit)
    }

    // MARK: - Item factories

    private func disabledTextItem(_ text: String) -> NSMenuItem {
        let item = NSMenuItem()
        item.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.tertiaryLabelColor
        ])
        item.isEnabled = false
        return item
    }

    private func makeModelItem(model: ParsedModel, bytes: Int64, loaded: Bool, width: CGFloat) -> NSMenuItem {
        let item = NSMenuItem()
        let view = ModelMenuItemView(model: model, bytes: bytes, loaded: loaded, width: width)
        item.view = view
        return item
    }

    // MARK: - Sort

    private func sortEntries(_ entries: [ModelEntry], mode: SortMode) -> [ModelEntry] {
        switch mode {
        case .name:        return entries.sorted { $0.model.sortKey < $1.model.sortKey }
        case .sizeAsc:     return entries.sorted { $0.bytes < $1.bytes }
        case .sizeDesc:    return entries.sorted { $0.bytes > $1.bytes }
        case .dateOldest:  return entries.sorted { $0.dateAdded < $1.dateAdded }
        case .dateNewest:  return entries.sorted { $0.dateAdded > $1.dateAdded }
        }
    }

    private func toggleSizeSort(_ source: ParsedModel.Source) {
        let current = (source == .lmStudio) ? lmSortMode : hfSortMode
        let next: SortMode = (current == .sizeAsc) ? .sizeDesc : .sizeAsc
        setSort(source, mode: next)
    }

    private func toggleDateSort(_ source: ParsedModel.Source) {
        let current = (source == .lmStudio) ? lmSortMode : hfSortMode
        let next: SortMode = (current == .dateOldest) ? .dateNewest : .dateOldest
        setSort(source, mode: next)
    }

    private func setSort(_ source: ParsedModel.Source, mode: SortMode) {
        switch source {
        case .lmStudio:    lmSortMode = mode
        case .huggingFace: hfSortMode = mode
        }
        reorderSection(source: source)
        updateHeaderSortIndicators(for: source)
    }

    /// Removes existing model rows for a section, sorts the cached entries
    /// by the current mode, and inserts fresh row items in place. Keeps
    /// the search bar, headers, separators, total row, and Quit untouched
    /// so the open menu doesn't flicker or close.
    private func reorderSection(source: ParsedModel.Source) {
        guard let header = (source == .lmStudio) ? lmHeaderItem : hfHeaderItem else { return }
        let endItem: NSMenuItem? = (source == .lmStudio) ? middleSeparator : indexOfTrailingSeparator()
        let headerIdx = menu.index(of: header)
        guard headerIdx >= 0 else { return }

        // End boundary index (exclusive).
        let endIdx: Int
        if let e = endItem {
            let i = menu.index(of: e)
            endIdx = (i > headerIdx) ? i : (headerIdx + 1)
        } else {
            endIdx = menu.numberOfItems
        }

        // Remove existing rows in this section.
        if endIdx - 1 >= headerIdx + 1 {
            for i in stride(from: endIdx - 1, through: headerIdx + 1, by: -1) {
                menu.removeItem(at: i)
            }
        }

        // Drop tracked row entries for this source.
        rows.removeAll { $0.model.source == source }

        let entries = (source == .lmStudio) ? lmEntries : hfEntries
        let mode = (source == .lmStudio) ? lmSortMode : hfSortMode

        var insertIdx = headerIdx + 1
        if entries.isEmpty {
            let empty = disabledTextItem("No models")
            switch source {
            case .lmStudio:    lmEmptyItem = empty
            case .huggingFace: hfEmptyItem = empty
            }
            menu.insertItem(empty, at: insertIdx)
        } else {
            let sorted = sortEntries(entries, mode: mode)
            for entry in sorted {
                let item = makeModelItem(
                    model: entry.model,
                    bytes: entry.bytes,
                    loaded: entry.loaded,
                    width: currentRowWidth
                )
                menu.insertItem(item, at: insertIdx)
                rows.append(RowEntry(item: item, model: entry.model))
                insertIdx += 1
            }
        }

        // Reapply current search filter; new items default to visible.
        if let q = searchFieldView?.searchField.stringValue, !q.isEmpty {
            applyFilter(query: q)
        }
    }

    /// Finds the separator that sits between the HF section and the Total row.
    private func indexOfTrailingSeparator() -> NSMenuItem? {
        guard let hfHeader = hfHeaderItem else { return nil }
        let hfIdx = menu.index(of: hfHeader)
        guard hfIdx >= 0 else { return nil }
        var i = hfIdx + 1
        while i < menu.numberOfItems {
            if menu.item(at: i)?.isSeparatorItem == true { return menu.item(at: i) }
            i += 1
        }
        return nil
    }

    private func updateHeaderSortIndicators(for source: ParsedModel.Source) {
        let headerItem = (source == .lmStudio) ? lmHeaderItem : hfHeaderItem
        guard let view = headerItem?.view as? SectionHeaderView else { return }
        let mode = (source == .lmStudio) ? lmSortMode : hfSortMode
        view.sizeButton.sortState = mode.sizeButtonState
        view.dateButton.sortState = mode.dateButtonState
    }

    // MARK: - Filter

    /// Applies a whitespace-tokenized AND filter to every row, hiding
    /// section headers / separators when their section has no matches.
    private func applyFilter(query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = q.lowercased().split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let empty = tokens.isEmpty

        var lmVisible = 0
        var hfVisible = 0

        for row in rows {
            let match = empty || tokens.allSatisfy { row.model.matches($0) }
            row.item.isHidden = !match
            if match {
                switch row.model.source {
                case .lmStudio:    lmVisible += 1
                case .huggingFace: hfVisible += 1
                }
            }
        }

        if empty {
            lmHeaderItem?.isHidden = false
            hfHeaderItem?.isHidden = false
            middleSeparator?.isHidden = false
            lmEmptyItem?.isHidden = false
            hfEmptyItem?.isHidden = false
        } else {
            lmHeaderItem?.isHidden = (lmVisible == 0)
            hfHeaderItem?.isHidden = (hfVisible == 0)
            // Middle separator only useful if both sides visible.
            middleSeparator?.isHidden = (lmVisible == 0 || hfVisible == 0)
            lmEmptyItem?.isHidden = true
            hfEmptyItem?.isHidden = true
        }
    }
}
