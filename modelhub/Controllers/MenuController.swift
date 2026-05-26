//
//  MenuController.swift
//  modelhub
//

import AppKit
import Sparkle

/// Owns the status-bar menu and orchestrates everything inside it:
/// scanning, sizing, sort state, search filtering, tab switching, and
/// HuggingFace search.
///
/// ## Lifecycle
///
/// 1. ``AppDelegate`` creates one `MenuController` and assigns its
///    ``menu`` to the `NSStatusItem`.
/// 2. `NSMenuDelegate` callbacks drive everything else:
///    - `menuNeedsUpdate(_:)` → ``rebuild()`` re-scans both directories,
///      rebuilds the full menu scaffold (tab switcher, search bar,
///      content for the active tab), and re-applies persisted sort modes.
///    - `menuDidOpen(_:)` → makes the search field first responder so the
///      user can type immediately.
/// 3. While the menu is open:
///    - The search field's `onChange` calls ``handleSearch(_:)`` which
///      either filters Local rows in place or kicks off a debounced
///      HuggingFace API search for the Explore tab.
///    - Tapping a sort button calls ``setSort(_:mode:)`` which removes
///      that section's rows and re-inserts them in the new order without
///      closing the menu.
///    - Tapping the tab switcher swaps the content section between
///      ``Tab/local`` and ``Tab/explore`` while leaving the tab switcher
///      and search bar in place (so search-field focus is preserved).
final class MenuController: NSObject, NSMenuDelegate, NSSearchFieldDelegate {
    private static let exploreFilterDefaultsKey = "modelhub.exploreFilterMode"

    /// The status-bar menu owned by this controller.
    let menu: NSMenu
    private let machineProfile = MachineProfile.current

    // MARK: - Tracking structures

    /// Pairing of a menu item with its model, used to drive search
    /// filtering and per-source removal during sort reorder.
    private struct RowEntry {
        let item: NSMenuItem
        let model: ParsedModel
        /// Bytes for this row's model — cached on the entry so
        /// ``applyFilter(query:)`` can sum the matched subset for the
        /// Total row without re-querying ``lmEntries``/``hfEntries``.
        let bytes: Int64
    }

    private var rows: [RowEntry] = []
    private var lmHeaderItem: NSMenuItem?
    private var hfHeaderItem: NSMenuItem?
    private var middleSeparator: NSMenuItem?
    private var lmEmptyItem: NSMenuItem?
    private var hfEmptyItem: NSMenuItem?
    private var searchFieldView: SearchFieldView?
    private var searchItem: NSMenuItem?

    /// Items in the Local content's footer area, tracked so search-state
    /// changes can update / hide them without rebuilding the menu.
    private var totalRowItem: NSMenuItem?
    private var totalSeparator: NSMenuItem?
    private var noResultsItem: NSMenuItem?

    /// Markers wrapping the per-tab content. Items between (exclusive)
    /// these two separators are owned by the active tab and get
    /// replaced together on tab switch or explore-state change.
    private var contentTopSeparator: NSMenuItem?
    private var contentBottomSeparator: NSMenuItem?

    /// Top-of-menu "Update available" banner. `nil` while there is no
    /// pending update; set by ``updateAvailable(_:)`` and ``rebuild()``
    /// when ``UpdateManager/pendingUpdate`` is non-nil.
    private var updateRowItem: NSMenuItem?
    private var updateRowSeparator: NSMenuItem?

    // MARK: - Persistent state

    /// Sort state — persists across menu opens.
    private var lmSortMode: SortMode = .name
    /// Sort state — persists across menu opens.
    private var hfSortMode: SortMode = .name

    /// Cached entries so per-section sort can reorder rows without
    /// re-reading the filesystem.
    private var lmEntries: [ModelEntry] = []
    private var hfEntries: [ModelEntry] = []
    private var totalBytesCached: Int64 = 0

    /// Total bytes for sources the user has enabled in Settings.
    private var visibleTotalBytes: Int64 {
        var sum: Int64 = 0
        if sourcePrefs.lmStudioEnabled { sum += lmEntries.map(\.bytes).reduce(0, +) }
        if sourcePrefs.huggingFaceEnabled { sum += hfEntries.map(\.bytes).reduce(0, +) }
        return sum
    }

    /// Cached row width so reorder uses the same layout as the
    /// initial build.
    private var currentRowWidth: CGFloat = 360
    private var currentSizeColumnWidth: CGFloat = 0

    // MARK: - Tab + Explore state

    /// Active tab. Persists across menu opens.
    private var currentTab: Tab = .local

    /// Last typed search query. Persists across tabs and menu opens so
    /// switching tabs preserves user intent.
    private var searchQuery: String = ""
    private var exploreFilterMode: ExploreFilterMode = .fitThisMac
    private var sourcePrefs: SourcePreferences = .load()

    /// State of the Explore tab's content area.
    private enum ExploreState {
        /// Hasn't been fetched yet.
        case idle
        /// API request in flight.
        case loading
        /// Decoded results from HuggingFace plus parsed metadata used
        /// for compatibility checks and row rendering.
        case results([ExploreModelCandidate])
        /// Human-readable error message to surface in place of results.
        case error(String)
    }
    private var exploreState: ExploreState = .idle
    private var exploreSearchTask: Task<Void, Never>?

    /// `true` while NSMenu is currently displaying the menu. Used to
    /// gate ``menuNeedsUpdate(_:)`` — see that method for why.
    private var menuIsOpen = false

    /// Tracks the active explore row views by `publisher/repo` so async
    /// avatar / size fetches can update them in place. Reset on each
    /// rebuild of the explore content.
    private var exploreRowsByID: [String: ExploreRowView] = [:]
    private var exploreCandidatesByID: [String: ExploreModelCandidate] = [:]

    /// In-flight enrichment work spawned after each successful search.
    /// Cancelled when a newer search starts.
    private var enrichmentTask: Task<Void, Never>?

    /// Per-publisher avatar cache. Survives across menu opens so popular
    /// publishers don't re-fetch every time.
    private struct AvatarEntry {
        let image: NSImage?
        let fullName: String?
    }
    private var avatarCache: [String: AvatarEntry] = [:]

    /// Per-repo size cache, keyed by `publisher/repo`.
    private var sizeCache: [String: Int64] = [:]
    /// Compatibility cache keyed by `publisher/repo`.
    private var compatibilityCache: [String: ExploreCompatibility] = [:]

    /// In-memory cache for landing (no-query) Explore fetches, keyed by
    /// the variant of the request (filter on/off). Lets us paint the
    /// last-seen result set instantly on menu open while we revalidate
    /// in the background.
    private var exploreLandingCache: [String: [HFModelSummary]] = [:]

    // MARK: - Init

    override init() {
        menu = NSMenu()
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        if let raw = UserDefaults.standard.string(forKey: Self.exploreFilterDefaultsKey),
           let mode = ExploreFilterMode(rawValue: raw) {
            exploreFilterMode = mode
        }

        // Listen for download completions so a freshly-downloaded model
        // can appear in Local without needing the user to close + reopen
        // the menu.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(downloadStateChanged(_:)),
            name: .downloadStateChanged,
            object: nil
        )

        // Sparkle-driven update notifications. The first surfaces the
        // top-of-menu banner; the second clears any stale banner.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateAvailable(_:)),
            name: .modelhubUpdateAvailable,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateNotFound(_:)),
            name: .modelhubUpdateNotFound,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func downloadStateChanged(_ note: Notification) {
        guard let state = note.userInfo?["state"] as? DownloadState else { return }
        guard case .completed = state else { return }
        // Re-scan the local cache so the new model is in our entries map.
        refreshLocalEntries()
        // If the user is currently looking at Local, replace its content
        // in place; if they're on Explore the cache is already up-to-date
        // and the next tab switch will pick it up.
        if currentTab == .local {
            rebuildContent()
            applyFilter(query: searchQuery)
        }
    }

    /// Rescan ``ModelScanner`` outputs and rebuild ``lmEntries`` /
    /// ``hfEntries`` / ``totalBytesCached``. Mirrors the equivalent
    /// section of ``rebuild()`` — kept separate so a download-completion
    /// refresh doesn't have to teardown the whole menu.
    private func refreshLocalEntries() {
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
        totalBytesCached = (lmEntries + hfEntries).map(\.bytes).reduce(0, +)
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        // NSMenu can re-fire menuNeedsUpdate during an open tracking
        // session (auto-validation, scroll-driven re-layout, etc.).
        // Re-running rebuild() while open would tear down the search
        // field, restart the explore fetch, and drop sort/filter state.
        guard !menuIsOpen else { return }
        rebuild()
    }

    func menuDidOpen(_ menu: NSMenu) {
        menuIsOpen = true
        // Every menu open kicks off a throttled appcast fetch. If a new
        // version is found, the SPU delegate posts
        // `.modelhubUpdateAvailable` and `updateAvailable(_:)` slides the
        // banner in. Throttling lives inside UpdateManager so rapid menu
        // opens don't hammer the studio site.
        UpdateManager.shared.checkInBackground()
        DispatchQueue.main.async { [weak self] in
            guard let sf = self?.searchFieldView?.searchField else { return }
            sf.window?.makeFirstResponder(sf)
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        menuIsOpen = false
    }

    private var effectiveExploreFilterMode: ExploreFilterMode {
        machineProfile.isAppleSilicon ? exploreFilterMode : .allModels
    }

    private func setExploreFilter(enabled: Bool) {
        exploreFilterMode = enabled ? .fitThisMac : .allModels
        UserDefaults.standard.set(exploreFilterMode.rawValue, forKey: Self.exploreFilterDefaultsKey)

        guard currentTab == .explore else { return }
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            triggerExploreFetch(query: searchQuery)
        } else {
            updateExploreContentInPlace()
        }
    }

    // MARK: - Build

    /// Wipes the menu and rebuilds it from a fresh disk scan, while
    /// preserving the per-section sort modes, current tab, and search
    /// query from the previous session.
    private func rebuild() {
        menu.removeAllItems()
        rows.removeAll()

        // Always scan local — needed for Local tab content and the
        // Total row, which is part of the Local tab.
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
        totalBytesCached = (lmEntries + hfEntries).map(\.bytes).reduce(0, +)

        // Width sized to the widest local row, but the title column is
        // capped — anything wider truncates with an ellipsis and reveals
        // on hover via the marquee animation. Type and size are pinned to
        // their own columns (size has a fixed width so it never truncates).
        //
        // Note: we deliberately do NOT reserve space for the trash slot.
        // The trash slides in from off-screen on hover and the size +
        // type columns shift left to make room — so when no row is
        // hovered the right edge sits flush against the size column with
        // no empty trailing region.
        let maxTitleRaw = (lm + hf).map { ModelMenuItemView.titleIntrinsicWidth(for: $0) }.max() ?? 200
        let maxTitle = min(maxTitleRaw, ModelMenuItemView.maxTitleWidth)
        let maxType = (lm + hf).map { ModelMenuItemView.typeIntrinsicWidth(for: $0) }.max() ?? 0
        // Tight column based on the actual widest size text in the data.
        let maxSize = (lmEntries + hfEntries)
            .map { ModelMenuItemView.sizeIntrinsicWidth(for: $0.bytes) }
            .max() ?? 30
        // Size column has a fixed width so size text right-edges
        // column-align across rows. The type field is intrinsic-width
        // with its trailing pinned to size's leading, so type
        // right-edges also column-align — but on rows with short types
        // the field shrinks and the title gets that space (no big
        // empty area between title and the type label).
        currentSizeColumnWidth = ceil(max(40, maxSize + 6))
        let computed = ModelMenuItemView.horizontalPadding
            + maxTitle
            + ModelMenuItemView.dotGap + ModelMenuItemView.dotSize
            + ModelMenuItemView.typeGap + maxType
            + ModelMenuItemView.sizeGap + currentSizeColumnWidth
            + ModelMenuItemView.horizontalPadding
        currentRowWidth = ceil(max(340, min(580, computed)))
        let rowWidth = currentRowWidth

        // Update banner — only present when Sparkle has surfaced a
        // pending update. Sits above everything so the user sees it
        // immediately on menu open. No intro animation here because the
        // menu itself is appearing fresh; the slide-in plays only when
        // a check resolves *while* the menu is already open
        // (see `updateAvailable(_:)`).
        updateRowItem = nil
        updateRowSeparator = nil
        if let pending = UpdateManager.shared.pendingUpdate {
            let updateItem = makeUpdateRowItem(
                version: pending.displayVersionString,
                width: rowWidth,
                animated: false
            )
            menu.addItem(updateItem)
            updateRowItem = updateItem

            let sep = NSMenuItem.separator()
            menu.addItem(sep)
            updateRowSeparator = sep
        }

        // Tab switcher — top of the menu, untouched on tab/state changes
        // so the user can switch back without the menu jumping.
        let tabItem = NSMenuItem()
        let tabSwitcher = TabSwitcherView(width: rowWidth, current: currentTab)
        tabSwitcher.onSelection = { [weak self] tab in self?.switchTab(tab) }
        tabItem.view = tabSwitcher
        menu.addItem(tabItem)

        // Search bar — single field whose meaning depends on the active tab.
        let sfView = SearchFieldView(width: rowWidth)
        sfView.onChange = { [weak self] query in self?.handleSearch(query) }
        sfView.searchField.stringValue = searchQuery
        let searchItem = NSMenuItem()
        searchItem.view = sfView
        menu.addItem(searchItem)
        searchFieldView = sfView
        self.searchItem = searchItem

        // Tab content sits between these two separators. Tab switches and
        // explore-state changes only touch this range; the search bar
        // stays put and never loses focus.
        let top = NSMenuItem.separator()
        contentTopSeparator = top
        menu.addItem(top)

        let bottom = NSMenuItem.separator()
        contentBottomSeparator = bottom
        menu.addItem(bottom)

        // Quit
        let quit = NSMenuItem(
            title: "Quit Model Hub",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.target = NSApp
        menu.addItem(quit)

        // Insert content for the active tab between the two separators.
        rebuildContent()

        switch currentTab {
        case .local:
            if !searchQuery.isEmpty { applyFilter(query: searchQuery) }
        case .explore:
            // Always (re-)trigger a fetch on full rebuild so the user sees
            // fresh data each time the menu opens on the Explore tab.
            triggerExploreFetch(query: searchQuery)
        case .settings:
            break
        }
    }

    // MARK: - Tab switching

    private func switchTab(_ tab: Tab) {
        guard tab != currentTab else { return }
        currentTab = tab
        rebuildContent()
        switch currentTab {
        case .local:
            applyFilter(query: searchQuery)
        case .explore:
            triggerExploreFetch(query: searchQuery)
        case .settings:
            break
        }
    }

    // MARK: - Per-tab content

    /// Builds the active tab's content items and swaps them in between
    /// the content separators.
    private func rebuildContent() {
        let items: [NSMenuItem]
        switch currentTab {
        case .local:    items = buildLocalContent(rowWidth: currentRowWidth)
        case .explore:  items = buildExploreContent(rowWidth: currentRowWidth)
        case .settings: items = buildSettingsContent(rowWidth: currentRowWidth)
        }
        // Search bar is only meaningful on Local + Explore.
        searchItem?.isHidden = (currentTab == .settings)
        replaceContent(with: items)
    }

    /// Removes everything currently between the content separators and
    /// inserts the given items in their place.
    private func replaceContent(with items: [NSMenuItem]) {
        guard let top = contentTopSeparator, let bottom = contentBottomSeparator else { return }
        let topIdx = menu.index(of: top)
        let bottomIdx = menu.index(of: bottom)
        guard topIdx >= 0, bottomIdx > topIdx else { return }

        if bottomIdx - 1 >= topIdx + 1 {
            for i in stride(from: bottomIdx - 1, through: topIdx + 1, by: -1) {
                menu.removeItem(at: i)
            }
        }

        var insertIdx = topIdx + 1
        for item in items {
            menu.insertItem(item, at: insertIdx)
            insertIdx += 1
        }
    }

    // MARK: - Local content

    private func buildLocalContent(rowWidth: CGFloat) -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        rows.removeAll()
        lmHeaderItem = nil
        hfHeaderItem = nil
        middleSeparator = nil
        lmEmptyItem = nil
        hfEmptyItem = nil

        if !sourcePrefs.lmStudioEnabled && !sourcePrefs.huggingFaceEnabled {
            items.append(disabledTextItem("No sources enabled — open Settings to pick one."))
            return items
        }

        // LM Studio
        if sourcePrefs.lmStudioEnabled {
        let lmH = NSMenuItem()
        let lmHeader = SectionHeaderView(
            title: "LM Studio",
            count: lmEntries.count,
            rootPath: ModelPaths.lmStudioRoot,
            width: rowWidth,
            menuRef: menu,
            sizeSortState: lmSortMode.sizeButtonState,
            dateSortState: lmSortMode.dateButtonState,
            showSortControls: lmEntries.count >= 2,
            iconName: "lmstudio"
        )
        lmHeader.onSizeSortClicked = { [weak self] in self?.toggleSizeSort(.lmStudio) }
        lmHeader.onDateSortClicked = { [weak self] in self?.toggleDateSort(.lmStudio) }
        lmH.view = lmHeader
        items.append(lmH)
        lmHeaderItem = lmH

        if lmEntries.isEmpty {
            let empty = disabledTextItem("No models")
            lmEmptyItem = empty
            items.append(empty)
        } else {
            let sorted = sortEntries(lmEntries, mode: lmSortMode)
            for entry in sorted {
                let item = makeModelItem(model: entry.model, bytes: entry.bytes, loaded: entry.loaded, width: rowWidth)
                rows.append(RowEntry(item: item, model: entry.model, bytes: entry.bytes))
                items.append(item)
            }
        }

        } // end LM Studio block

        if sourcePrefs.lmStudioEnabled && sourcePrefs.huggingFaceEnabled {
            let sep = NSMenuItem.separator()
            middleSeparator = sep
            items.append(sep)
        }

        // Hugging Face
        if sourcePrefs.huggingFaceEnabled {
        let hfH = NSMenuItem()
        let hfHeader = SectionHeaderView(
            title: "Hugging Face",
            count: hfEntries.count,
            rootPath: ModelPaths.huggingFaceRoot,
            width: rowWidth,
            menuRef: menu,
            sizeSortState: hfSortMode.sizeButtonState,
            dateSortState: hfSortMode.dateButtonState,
            showSortControls: hfEntries.count >= 2,
            iconName: "huggingface"
        )
        hfHeader.onSizeSortClicked = { [weak self] in self?.toggleSizeSort(.huggingFace) }
        hfHeader.onDateSortClicked = { [weak self] in self?.toggleDateSort(.huggingFace) }
        hfH.view = hfHeader
        items.append(hfH)
        hfHeaderItem = hfH

        if hfEntries.isEmpty {
            let empty = disabledTextItem("No models")
            hfEmptyItem = empty
            items.append(empty)
        } else {
            let sorted = sortEntries(hfEntries, mode: hfSortMode)
            for entry in sorted {
                let item = makeModelItem(model: entry.model, bytes: entry.bytes, loaded: entry.loaded, width: rowWidth)
                rows.append(RowEntry(item: item, model: entry.model, bytes: entry.bytes))
                items.append(item)
            }
        }

        } // end HuggingFace block

        let totalSep = NSMenuItem.separator()
        totalSeparator = totalSep
        items.append(totalSep)

        // Total — initial value is the unfiltered total. ``applyFilter``
        // mutates it to reflect the matching subset when a search is active.
        let totalItem = NSMenuItem()
        totalItem.view = TotalRowView(bytes: visibleTotalBytes, width: rowWidth)
        items.append(totalItem)
        totalRowItem = totalItem

        // "No results found" placeholder — hidden until ``applyFilter``
        // determines that the active search returns nothing. Sits at the
        // bottom of the local content so it lands in the same area the
        // total row used to occupy.
        let noResults = disabledTextItem("No results found")
        noResults.isHidden = true
        items.append(noResults)
        noResultsItem = noResults

        return items
    }

    // MARK: - Explore content

    private func buildExploreContent(rowWidth: CGFloat) -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        exploreRowsByID.removeAll()
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        if machineProfile.isAppleSilicon {
            let toggleItem = NSMenuItem()
            let toggleView = ExploreFilterToggleView(
                width: rowWidth,
                isOn: effectiveExploreFilterMode == .fitThisMac,
                machineProfile: machineProfile
            )
            toggleView.onToggle = { [weak self] isOn in self?.setExploreFilter(enabled: isOn) }
            toggleItem.view = toggleView
            items.append(toggleItem)
        }

        let headerText = makeExploreHeaderText(query: trimmedQuery)
        items.append(makeSectionHeaderItem(text: headerText))

        switch exploreState {
        case .idle, .loading:
            items.append(disabledTextItem(effectiveExploreFilterMode == .fitThisMac ? "Checking what runs on this Mac…" : "Loading…"))

        case .results(let candidates):
            let visibleCandidates = candidates.filter { shouldShow($0, query: trimmedQuery) }
            if visibleCandidates.isEmpty {
                if needsPendingFitMessage(candidates, query: trimmedQuery) {
                    items.append(disabledTextItem("Checking what runs on this Mac…"))
                } else {
                    items.append(disabledTextItem("No results"))
                }
            } else {
                for candidate in visibleCandidates {
                    let summary = candidate.summary
                    let view = ExploreRowView(
                        model: candidate.parsedModel,
                        sizeBytes: sizeCache[summary.id],
                        compatibility: compatibility(for: candidate),
                        width: rowWidth,
                        sizeColumnWidth: currentSizeColumnWidth
                    )
                    if let cached = avatarCache[summary.publisher] {
                        view.apply(avatarImage: cached.image, fullName: cached.fullName)
                    }
                    let item = NSMenuItem()
                    item.view = view
                    items.append(item)
                    exploreRowsByID[summary.id] = view
                }
            }

        case .error(let msg):
            items.append(disabledTextItem(msg))
        }

        return items
    }

    private func makeExploreHeaderText(query: String) -> String {
        guard machineProfile.isAppleSilicon else {
            return query.isEmpty ? "HuggingFace · Top Models" : "HuggingFace · Results"
        }

        if effectiveExploreFilterMode == .fitThisMac {
            return "HuggingFace · Runs on \(machineProfile.chipName) · \(machineProfile.memoryGB) GB"
        }

        return query.isEmpty
            ? "HuggingFace · All Models"
            : "HuggingFace · Results"
    }

    /// Lightweight section header for tabs that don't need the
    /// folder/sort buttons that ``SectionHeaderView`` carries.
    private func makeSectionHeaderItem(text: String) -> NSMenuItem {
        let item = NSMenuItem()
        let attr = NSMutableAttributedString()
        attr.append(NSAttributedString(string: text.uppercased(), attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
            .kern: 0.7
        ]))
        item.attributedTitle = attr
        item.isEnabled = false
        return item
    }

    // MARK: - Search dispatch

    /// Routes the search bar's text through the right handler for the
    /// active tab. Local mode filters in place; Explore mode debounces
    /// and hits the HuggingFace API.
    private func handleSearch(_ query: String) {
        // NSSearchField fires its action whenever focus shifts away from
        // the field, even when the value hasn't changed. Hovering custom
        // menu rows can shuffle first responder around, which would
        // otherwise re-trigger the debounced explore fetch and flash the
        // "Loading…" state every time the cursor moves.
        guard query != searchQuery else { return }
        searchQuery = query
        switch currentTab {
        case .local:
            applyFilter(query: query)
        case .explore:
            // Cancel any pending fetch; start a new debounced one. Don't
            // flip the UI to .loading until the debounce expires — that
            // way fast typing doesn't cause flicker.
            exploreSearchTask?.cancel()
            let task = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 350_000_000) // 350ms
                guard !Task.isCancelled, let self else { return }
                self.exploreCandidatesByID.removeAll()
                self.exploreState = .loading
                self.updateExploreContentInPlace()
                await self.fetchExplore(query: query)
            }
            exploreSearchTask = task
        case .settings:
            break
        }
    }

    /// Kick off a fetch immediately (no debounce). Used on tab entry
    /// and on full menu rebuild.
    ///
    /// For the empty-query "landing" view we paint cached results right
    /// away (if any) and revalidate in the background — the row list
    /// only re-renders if the API returns a different set of ids.
    private func triggerExploreFetch(query: String) {
        exploreSearchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let cacheKey = trimmed.isEmpty ? landingCacheKey() : nil

        if let cacheKey, let cached = exploreLandingCache[cacheKey] {
            // Paint from cache immediately.
            let candidates = cached.map(makeExploreCandidate(summary:))
            exploreCandidatesByID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
            for c in candidates { compatibilityCache[c.id] = compatibility(for: c) }
            exploreState = .results(candidates)
            updateExploreContentInPlace()
            enrichExploreResults(candidates)
        } else {
            exploreCandidatesByID.removeAll()
            exploreState = .loading
            updateExploreContentInPlace()
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.fetchExplore(query: query)
        }
        exploreSearchTask = task
    }

    /// Runs the API call and updates the explore section with results
    /// or an error. Bails if the user has switched tabs or typed a new
    /// query while the request was in flight. Also no-ops the UI update
    /// when the result matches what's already on screen (cache hit
    /// revalidation), so background refreshes don't flicker rows.
    private func fetchExplore(query: String) async {
        do {
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let results = try await HuggingFaceAPI.searchModels(options: makeExploreSearchOptions(query: q))
            // Drop the result if the user has moved on.
            guard currentTab == .explore, query == self.searchQuery else { return }

            // Cache landing results so the next open paints instantly.
            if q.isEmpty {
                exploreLandingCache[landingCacheKey()] = results
            }

            // If we're already showing the same ids in the same order,
            // skip the re-render — the visible rows are already correct
            // and their enrichment caches survive across opens.
            if case .results(let current) = exploreState,
               current.map(\.id) == results.map(\.id) {
                return
            }

            let candidates = results.map(makeExploreCandidate(summary:))
            exploreCandidatesByID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
            for candidate in candidates {
                compatibilityCache[candidate.id] = compatibility(for: candidate)
            }
            exploreState = .results(candidates)
            updateExploreContentInPlace()
            // Now that rows are rendered with placeholders, enrich them.
            enrichExploreResults(candidates)
        } catch is CancellationError {
            // Replaced by a newer task — nothing to do.
            return
        } catch {
            guard currentTab == .explore, query == self.searchQuery else { return }
            // Don't blow away cached results we're already showing just
            // because the revalidation hit a network blip.
            if case .results = exploreState { return }
            let msg = (error as? LocalizedError)?.errorDescription ?? "Couldn't reach HuggingFace."
            exploreState = .error(msg)
            updateExploreContentInPlace()
        }
    }

    /// Cache key for the landing fetch — varies with the only knob that
    /// changes the URL when query is empty (the Apple Silicon filter).
    private func landingCacheKey() -> String {
        let appleFilter = effectiveExploreFilterMode == .fitThisMac && machineProfile.isAppleSilicon
        return appleFilter ? "apple-silicon" : "all"
    }

    private func makeExploreSearchOptions(query: String) -> HuggingFaceAPI.SearchOptions {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let isEmpty = trimmed.isEmpty
        let useAppleLandingFilter = effectiveExploreFilterMode == .fitThisMac
            && machineProfile.isAppleSilicon
            && isEmpty

        return HuggingFaceAPI.SearchOptions(
            query: isEmpty ? nil : trimmed,
            limit: useAppleLandingFilter ? 60 : 30,
            filter: useAppleLandingFilter ? "apple-silicon" : nil
        )
    }

    private func makeExploreCandidate(summary: HFModelSummary) -> ExploreModelCandidate {
        ExploreModelCandidate(
            summary: summary,
            parsedModel: ModelParser.parse(
                publisher: summary.publisher,
                repo: summary.repo,
                path: "",
                source: .huggingFace,
                tags: summary.tags
            )
        )
    }

    private func compatibility(for candidate: ExploreModelCandidate) -> ExploreCompatibility {
        let result = ExploreCompatibilityEvaluator.evaluate(
            summary: candidate.summary,
            parsedModel: candidate.parsedModel,
            usedStorage: sizeCache[candidate.id],
            machine: machineProfile
        )
        compatibilityCache[candidate.id] = result
        return result
    }

    private func shouldShow(_ candidate: ExploreModelCandidate, query: String) -> Bool {
        guard effectiveExploreFilterMode == .fitThisMac else { return true }

        switch compatibility(for: candidate) {
        case .compatible, .maybeSlow:
            return true
        case .unknown:
            return !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .incompatibleMemory, .incompatibleFormat:
            return false
        }
    }

    private func needsPendingFitMessage(_ candidates: [ExploreModelCandidate], query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard effectiveExploreFilterMode == .fitThisMac, trimmed.isEmpty else { return false }

        return candidates.contains { candidate in
            compatibility(for: candidate) == .unknown && sizeCache[candidate.id] == nil
        }
    }

    // MARK: - Explore enrichment (avatars + sizes)

    /// After search results render with placeholders, fetch each unique
    /// publisher's avatar and each model's `usedStorage` in parallel.
    /// Updates the corresponding row views in place as data lands.
    /// Cancels any previously-running enrichment so rapid searches don't
    /// stack up dozens of background requests.
    private func enrichExploreResults(_ candidates: [ExploreModelCandidate]) {
        enrichmentTask?.cancel()

        // Apply already-cached values before going to the network.
        for candidate in candidates {
            let summary = candidate.summary
            if let cached = avatarCache[summary.publisher],
               let view = exploreRowsByID[summary.id] {
                view.apply(avatarImage: cached.image, fullName: cached.fullName)
            }
            if let cachedSize = sizeCache[summary.id],
               let view = exploreRowsByID[summary.id] {
                view.apply(sizeBytes: cachedSize)
            }
            if let view = exploreRowsByID[summary.id] {
                view.apply(compatibility: compatibility(for: candidate))
            }
        }

        let publishersToFetch = Set(candidates.map { $0.summary.publisher })
            .filter { !$0.isEmpty && avatarCache[$0] == nil }
        let idsToFetch = candidates.map(\.id).filter { sizeCache[$0] == nil }
        guard !publishersToFetch.isEmpty || !idsToFetch.isEmpty else { return }

        enrichmentTask = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                for publisher in publishersToFetch {
                    group.addTask { [weak self] in
                        await self?.fetchAvatar(publisher: publisher)
                    }
                }
                for id in idsToFetch {
                    group.addTask { [weak self] in
                        await self?.fetchSize(repoID: id)
                    }
                }
            }
        }
    }

    private func fetchAvatar(publisher: String) async {
        do {
            let owner = try await HuggingFaceAPI.fetchOwner(name: publisher)
            var image: NSImage?
            if let urlString = owner.avatarUrl, let url = URL(string: urlString) {
                image = await HuggingFaceAPI.fetchImage(url: url)
            }
            guard !Task.isCancelled else { return }
            let entry = AvatarEntry(image: image, fullName: owner.fullname)
            avatarCache[publisher] = entry
            // Update every currently-visible row that belongs to this publisher.
            for (id, view) in exploreRowsByID where id.hasPrefix("\(publisher)/") {
                view.apply(avatarImage: image, fullName: owner.fullname)
            }
        } catch {
            // Silent fail — row keeps its initial-circle placeholder.
        }
    }

    private func fetchSize(repoID: String) async {
        do {
            let detail = try await HuggingFaceAPI.modelDetail(repoID: repoID)
            guard !Task.isCancelled, let bytes = detail.usedStorage else { return }
            let previousCompatibility = compatibilityCache[repoID]
            sizeCache[repoID] = bytes
            let candidate = exploreCandidatesByID[repoID]
            let newCompatibility = candidate.map { compatibility(for: $0) } ?? .unknown
            if let view = exploreRowsByID[repoID] {
                view.apply(sizeBytes: bytes)
                view.apply(compatibility: newCompatibility)
            }

            guard currentTab == .explore,
                  candidate != nil else { return }

            let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            let becameVisible = previousCompatibility.map {
                visibility(for: $0, query: query) != visibility(for: newCompatibility, query: query)
            } ?? (visibility(for: .unknown, query: query) != visibility(for: newCompatibility, query: query))

            if becameVisible || (query.isEmpty && effectiveExploreFilterMode == .fitThisMac) {
                updateExploreContentInPlace()
            }
        } catch {
            // Silent fail — size stays "—".
        }
    }

    private func visibility(for compatibility: ExploreCompatibility, query: String) -> Bool {
        guard effectiveExploreFilterMode == .fitThisMac else { return true }
        switch compatibility {
        case .compatible, .maybeSlow:
            return true
        case .unknown:
            return !query.isEmpty
        case .incompatibleMemory, .incompatibleFormat:
            return false
        }
    }

    /// Re-renders the explore content section. No-op when not on the
    /// Explore tab.
    private func updateExploreContentInPlace() {
        guard currentTab == .explore else { return }
        let items = buildExploreContent(rowWidth: currentRowWidth)
        replaceContent(with: items)
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
        let view = ModelMenuItemView(
            model: model,
            bytes: bytes,
            loaded: loaded,
            width: width,
            sizeColumnWidth: currentSizeColumnWidth
        )
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
        // Sort buttons only live on Local headers — guard prevents
        // touching nil refs when the user happens to be on Explore.
        if currentTab == .local {
            reorderSection(source: source)
            updateHeaderSortIndicators(for: source)
        }
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

        let endIdx: Int
        if let e = endItem {
            let i = menu.index(of: e)
            endIdx = (i > headerIdx) ? i : (headerIdx + 1)
        } else {
            endIdx = menu.numberOfItems
        }

        if endIdx - 1 >= headerIdx + 1 {
            for i in stride(from: endIdx - 1, through: headerIdx + 1, by: -1) {
                menu.removeItem(at: i)
            }
        }

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
                rows.append(RowEntry(item: item, model: entry.model, bytes: entry.bytes))
                insertIdx += 1
            }
        }

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

    // MARK: - Settings content

    private var settingsHFToggleView: SourceToggleRowView?
    private var settingsLMToggleView: SourceToggleRowView?

    private func buildSettingsContent(rowWidth: CGFloat) -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        items.append(makeSectionHeaderItem(text: "Sources"))

        let hfRow = NSMenuItem()
        let hfView = SourceToggleRowView(
            width: rowWidth,
            title: "Hugging Face",
            isOn: sourcePrefs.huggingFaceEnabled,
            iconName: "huggingface"
        )
        hfView.onToggle = { [weak self] isOn in self?.setSourceEnabled(huggingFace: isOn) }
        hfRow.view = hfView
        items.append(hfRow)
        settingsHFToggleView = hfView

        let lmRow = NSMenuItem()
        let lmView = SourceToggleRowView(
            width: rowWidth,
            title: "LM Studio",
            isOn: sourcePrefs.lmStudioEnabled,
            iconName: "lmstudio"
        )
        lmView.onToggle = { [weak self] isOn in self?.setSourceEnabled(lmStudio: isOn) }
        lmRow.view = lmView
        items.append(lmRow)
        settingsLMToggleView = lmView

        updateSettingsToggleAvailability()

        // App section — version display + update controls.
        items.append(NSMenuItem.separator())
        items.append(makeSectionHeaderItem(text: "App"))

        let manager = UpdateManager.shared
        if let pending = manager.pendingUpdate {
            // Inline banner inside Settings mirrors the top-of-menu one.
            // Same affordance, same destination — we just place it where
            // the user is already looking when they're poking around in
            // Settings.
            items.append(makeUpdateRowItem(
                version: pending.displayVersionString,
                width: rowWidth,
                animated: false
            ))
        }

        items.append(makeVersionRowItem(
            version: manager.currentVersion,
            build: manager.currentBuild,
            width: rowWidth
        ))
        items.append(makeCheckForUpdatesRowItem(width: rowWidth))

        return items
    }

    /// Read-only "Version 1.0.0 (12)" row. Build number is shown in
    /// parentheses so power users can disambiguate between rebuilds of
    /// the same version during testing.
    private func makeVersionRowItem(version: String, build: String, width: CGFloat) -> NSMenuItem {
        let item = NSMenuItem()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 26))

        let label = NSTextField(labelWithString: "Version")
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .labelColor

        let value = NSTextField(labelWithString: "\(version) (\(build))")
        value.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        value.textColor = .secondaryLabelColor

        view.addSubview(label)
        view.addSubview(value)
        label.translatesAutoresizingMaskIntoConstraints = false
        value.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            value.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            value.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        item.view = view
        return item
    }

    /// "Check for Updates…" row — a label + trailing button that drives
    /// ``UpdateManager/checkNow`` (which surfaces Sparkle's standard
    /// "you're up to date" / "couldn't reach server" UI).
    private func makeCheckForUpdatesRowItem(width: CGFloat) -> NSMenuItem {
        let item = NSMenuItem()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 30))

        let label = NSTextField(labelWithString: "Check for Updates")
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .labelColor

        let button = NSButton(title: "Check", target: self, action: #selector(checkForUpdatesTapped))
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = NSFont.systemFont(ofSize: 11, weight: .medium)

        view.addSubview(label)
        view.addSubview(button)
        label.translatesAutoresizingMaskIntoConstraints = false
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        item.view = view
        return item
    }

    @objc private func checkForUpdatesTapped() {
        UpdateManager.shared.checkNow()
    }

    /// Disables the checkbox for whichever source is the only one
    /// currently enabled, so the user can't end up with zero sources.
    private func updateSettingsToggleAvailability() {
        let hfOnly = sourcePrefs.huggingFaceEnabled && !sourcePrefs.lmStudioEnabled
        let lmOnly = sourcePrefs.lmStudioEnabled && !sourcePrefs.huggingFaceEnabled
        settingsHFToggleView?.checkbox.isEnabled = !hfOnly
        settingsLMToggleView?.checkbox.isEnabled = !lmOnly
    }

    private func setSourceEnabled(huggingFace: Bool) {
        sourcePrefs.huggingFaceEnabled = huggingFace
        sourcePrefs.save()
        updateSettingsToggleAvailability()
    }

    private func setSourceEnabled(lmStudio: Bool) {
        sourcePrefs.lmStudioEnabled = lmStudio
        sourcePrefs.save()
        updateSettingsToggleAvailability()
    }

    // MARK: - Update banner

    /// Builds the "Update available" row with its tap handler wired
    /// through to ``UpdateManager/installPending``.
    private func makeUpdateRowItem(version: String, width: CGFloat, animated: Bool) -> NSMenuItem {
        let item = NSMenuItem()
        let view = UpdateAvailableRowView(version: version, width: width, animated: animated)
        view.onUpdate = { UpdateManager.shared.installPending() }
        item.view = view
        return item
    }

    /// Sparkle found a newer version. If the menu is already open we
    /// slide the banner in above the tab switcher; otherwise it'll be
    /// inserted at the top on the next ``rebuild()``.
    @objc private func updateAvailable(_ note: Notification) {
        guard menuIsOpen, updateRowItem == nil else { return }
        let version = (note.userInfo?["version"] as? String) ?? "new version"
        let item = makeUpdateRowItem(
            version: version,
            width: currentRowWidth,
            animated: true
        )
        menu.insertItem(item, at: 0)
        updateRowItem = item

        let sep = NSMenuItem.separator()
        menu.insertItem(sep, at: 1)
        updateRowSeparator = sep

        // Refresh the Settings tab inline block so the same news shows
        // up there too without waiting for a tab switch.
        if currentTab == .settings {
            rebuildContent()
        }
    }

    /// A background check confirmed we're on the latest. Drop any stale
    /// banner so we don't keep promising an update that no longer exists.
    @objc private func updateNotFound(_ note: Notification) {
        guard let item = updateRowItem else { return }
        let itemIdx = menu.index(of: item)
        if itemIdx >= 0 { menu.removeItem(at: itemIdx) }
        if let sep = updateRowSeparator {
            let sepIdx = menu.index(of: sep)
            if sepIdx >= 0 { menu.removeItem(at: sepIdx) }
        }
        updateRowItem = nil
        updateRowSeparator = nil
        if currentTab == .settings {
            rebuildContent()
        }
    }

    // MARK: - Filter (Local tab only)

    /// Applies a whitespace-tokenized AND filter to every Local row,
    /// hiding section headers / separators when their section has no
    /// matches. No-op on the Explore tab — its filtering happens via
    /// the HuggingFace API.
    private func applyFilter(query: String) {
        guard currentTab == .local else { return }

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = q.lowercased().split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let empty = tokens.isEmpty

        var lmVisible = 0
        var hfVisible = 0
        var visibleBytes: Int64 = 0

        for row in rows {
            let match = empty || tokens.allSatisfy { row.model.matches($0) }
            row.item.isHidden = !match
            if match {
                visibleBytes += row.bytes
                switch row.model.source {
                case .lmStudio:    lmVisible += 1
                case .huggingFace: hfVisible += 1
                }
            }
        }

        let totalView = totalRowItem?.view as? TotalRowView

        if empty {
            // No filter — restore the unfiltered Local view.
            lmHeaderItem?.isHidden = false
            hfHeaderItem?.isHidden = false
            middleSeparator?.isHidden = false
            lmEmptyItem?.isHidden = false
            hfEmptyItem?.isHidden = false
            totalSeparator?.isHidden = false
            totalRowItem?.isHidden = false
            noResultsItem?.isHidden = true
            totalView?.update(bytes: visibleTotalBytes)
        } else if lmVisible == 0 && hfVisible == 0 {
            // Search active, nothing matched — collapse the whole local
            // content area down to a single "No results found" line.
            lmHeaderItem?.isHidden = true
            hfHeaderItem?.isHidden = true
            middleSeparator?.isHidden = true
            lmEmptyItem?.isHidden = true
            hfEmptyItem?.isHidden = true
            totalSeparator?.isHidden = true
            totalRowItem?.isHidden = true
            noResultsItem?.isHidden = false
        } else {
            // Search active with matches — show only the sections that
            // have matches and a Total reflecting the matched subset.
            lmHeaderItem?.isHidden = (lmVisible == 0)
            hfHeaderItem?.isHidden = (hfVisible == 0)
            middleSeparator?.isHidden = (lmVisible == 0 || hfVisible == 0)
            lmEmptyItem?.isHidden = true
            hfEmptyItem?.isHidden = true
            totalSeparator?.isHidden = false
            totalRowItem?.isHidden = false
            noResultsItem?.isHidden = true
            totalView?.update(bytes: visibleBytes)
        }
    }
}
