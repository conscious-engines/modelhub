//
//  ExploreRowView.swift
//  modelhub
//

import AppKit

/// Row in the Explore tab — author avatar, pretty model name, model
/// size, and a download button.
///
/// Uses the same title styling as ``ModelMenuItemView`` so Local and
/// Explore rows feel like the same family. Differences:
/// - Leading author avatar (tooltip = author display name).
/// - No live-loaded dot — the model isn't on disk yet.
/// - Size is the model's HuggingFace `usedStorage`, fetched lazily.
/// - Download button at the trailing edge, always visible.
///
/// ## Enrichment lifecycle
///
/// The row is created with placeholders: an initial-circle avatar and a
/// `—` size. ``MenuController`` fires off async enrichment tasks after
/// the search returns, calling ``apply(avatarImage:fullName:)`` and
/// ``apply(sizeBytes:)`` on each row as the data lands.
final class ExploreRowView: NSView {
    /// Total row height. Slightly taller than ``ModelMenuItemView`` to
    /// fit the round avatar without clipping.
    static let rowHeight: CGFloat = 30
    static let horizontalPadding: CGFloat = 14
    static let avatarSize: CGFloat = AuthorAvatarView.size
    static let avatarGap: CGFloat = 8
    static let downloadButtonSize: CGFloat = 16
    /// Maximum width the title is allowed to take before truncating
    /// (and unlocking marquee on hover). Just `[tag] Name` — type and
    /// size live in their own dedicated columns so neither gets dragged
    /// into the marquee.
    static let maxTitleWidth: CGFloat = 280
    /// Gap between title and the type column.
    static let typeGap: CGFloat = 10
    /// Gap between the type column and the size column.
    static let sizeGap: CGFloat = 10

    /// The model rendered by this row.
    let model: ParsedModel

    /// Original-case `Publisher/Repo` — the canonical id used by
    /// ``DownloadManager`` and ``HFCacheWriter``.
    private var canonicalID: String { model.canonicalID }

    private let avatarView: AuthorAvatarView
    private let titleLabel: MarqueeLabel
    private let typeField: NSTextField
    private let sizeField: NSTextField
    private let downloadButton: DownloadStateButton
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var sizeBytes: Int64?

    init(model: ParsedModel, sizeBytes: Int64?, width: CGFloat) {
        self.model = model
        self.sizeBytes = sizeBytes

        avatarView = AuthorAvatarView(publisher: model.publisher)

        titleLabel = MarqueeLabel(maxWidth: Self.maxTitleWidth)

        typeField = NSTextField(labelWithString: "")
        typeField.isBezeled = false
        typeField.isEditable = false
        typeField.drawsBackground = false
        typeField.usesSingleLineMode = true
        typeField.cell?.lineBreakMode = .byClipping
        typeField.setContentHuggingPriority(.required, for: .horizontal)

        sizeField = NSTextField(labelWithString: "")
        sizeField.isBezeled = false
        sizeField.isEditable = false
        sizeField.drawsBackground = false
        sizeField.alignment = .right
        sizeField.usesSingleLineMode = true
        sizeField.cell?.lineBreakMode = .byClipping
        // Hug intrinsic content tightly so there's no empty padding
        // between the type column and the size text.
        sizeField.setContentHuggingPriority(.required, for: .horizontal)
        sizeField.setContentCompressionResistancePriority(.required, for: .horizontal)

        downloadButton = DownloadStateButton()

        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.rowHeight))

        addSubview(avatarView)
        addSubview(titleLabel)
        addSubview(typeField)
        addSubview(sizeField)
        addSubview(downloadButton)

        downloadButton.onTap = { [weak self] state in self?.handleDownloadTap(state: state) }
        // Reflect any in-flight or already-completed download immediately.
        downloadButton.update(state: DownloadManager.shared.state(for: canonicalID))

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(downloadStateChanged(_:)),
            name: .downloadStateChanged,
            object: nil
        )

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        typeField.translatesAutoresizingMaskIntoConstraints = false
        sizeField.translatesAutoresizingMaskIntoConstraints = false
        downloadButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalPadding),
            avatarView.centerYAnchor.constraint(equalTo: centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarView.heightAnchor.constraint(equalToConstant: Self.avatarSize),

            titleLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: Self.avatarGap),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            downloadButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontalPadding),
            downloadButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            downloadButton.widthAnchor.constraint(equalToConstant: Self.downloadButtonSize),
            downloadButton.heightAnchor.constraint(equalToConstant: Self.downloadButtonSize),

            // Size sizes to its intrinsic content (with required hugging
            // + compression resistance set above so it can't be squeezed).
            sizeField.trailingAnchor.constraint(equalTo: downloadButton.leadingAnchor, constant: -10),
            sizeField.centerYAnchor.constraint(equalTo: centerYAnchor),

            // Type sits between the title and the size column with intrinsic width.
            typeField.trailingAnchor.constraint(equalTo: sizeField.leadingAnchor, constant: -Self.sizeGap),
            typeField.centerYAnchor.constraint(equalTo: centerYAnchor),

            // Title compresses (and marquees on hover) before the type column moves.
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: typeField.leadingAnchor, constant: -Self.typeGap),
        ])

        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Enrichment

    /// Apply the author's avatar + display name once the API returns.
    func apply(avatarImage: NSImage?, fullName: String?) {
        avatarView.apply(image: avatarImage, fullName: fullName)
    }

    /// Apply the model's `usedStorage` byte count once the API returns.
    func apply(sizeBytes: Int64) {
        self.sizeBytes = sizeBytes
        updateAppearance()
    }

    // MARK: - Attributed content

    /// Builds the row's title — `[tag] Name`. The type/format label is
    /// rendered in its own dedicated column (``makeTypeAttributed``) so
    /// it doesn't get dragged into the title's marquee animation.
    static func makeAttributedTitle(_ m: ParsedModel, highlighted: Bool) -> NSAttributedString {
        let s = NSMutableAttributedString()

        let tagColor: NSColor = highlighted
            ? NSColor.selectedMenuItemTextColor.withAlphaComponent(0.75)
            : .secondaryLabelColor
        let nameColor: NSColor = highlighted ? .selectedMenuItemTextColor : .labelColor

        s.append(NSAttributedString(string: "[\(m.familyTag)]", attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: tagColor
        ]))
        s.append(NSAttributedString(string: "  "))
        s.append(NSAttributedString(string: m.displayName, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: nameColor
        ]))
        return s
    }

    /// Builds the standalone type/format label (e.g. `MLX 4bit`).
    /// Returns an empty attributed string when the model has no type
    /// info — keeping the field present (with zero intrinsic width)
    /// avoids reshuffling layout constraints.
    static func makeTypeAttributed(_ m: ParsedModel, highlighted: Bool) -> NSAttributedString {
        guard let t = m.typeLabel else { return NSAttributedString() }
        let typeColor: NSColor = highlighted
            ? NSColor.selectedMenuItemTextColor.withAlphaComponent(0.7)
            : .tertiaryLabelColor
        return NSAttributedString(string: t, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: typeColor
        ])
    }

    static func makeSizeAttributed(bytes: Int64?, highlighted: Bool) -> NSAttributedString {
        let color: NSColor = highlighted
            ? NSColor.selectedMenuItemTextColor.withAlphaComponent(0.8)
            : .tertiaryLabelColor
        let text: String = bytes.map { SizeUtil.format($0) } ?? "—"
        return NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: color
        ])
    }

    // MARK: - Appearance

    private func updateAppearance() {
        titleLabel.attributedStringValue = Self.makeAttributedTitle(model, highlighted: isHovered)
        typeField.attributedStringValue = Self.makeTypeAttributed(model, highlighted: isHovered)
        sizeField.attributedStringValue = Self.makeSizeAttributed(bytes: sizeBytes, highlighted: isHovered)
        // Tint is owned by DownloadStateButton itself — it resolves the
        // right color for the active state + hover. Just propagate hover.
        downloadButton.rowIsHovered = isHovered
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHovered {
            NSColor.selectedContentBackgroundColor.setFill()
            bounds.fill()
        }
    }

    // MARK: - Hover tracking

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
        updateAppearance()
        titleLabel.beginHover()
        HoverCoordinator.enter(self)
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateAppearance()
        titleLabel.endHover()
        HoverCoordinator.exit(self)
    }

    // MARK: - Download wiring

    private func handleDownloadTap(state: DownloadState) {
        switch state {
        case .notStarted, .failed:
            DownloadManager.shared.start(
                repoID: canonicalID,
                estimatedTotalBytes: sizeBytes ?? 0
            )
        case .downloading:
            DownloadManager.shared.pause(repoID: canonicalID)
        case .paused:
            DownloadManager.shared.resume(repoID: canonicalID)
        case .queued, .completed:
            break
        }
    }

    @objc private func downloadStateChanged(_ note: Notification) {
        guard let id = note.userInfo?["repoID"] as? String, id == canonicalID else { return }
        guard let state = note.userInfo?["state"] as? DownloadState else { return }
        downloadButton.update(state: state)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Hover coordination

extension ExploreRowView: HoverableMenuRow {
    /// Called by ``HoverCoordinator`` when another row claims focus.
    func clearHoverState() {
        guard isHovered else { return }
        isHovered = false
        updateAppearance()
        titleLabel.endHover()
    }
}
