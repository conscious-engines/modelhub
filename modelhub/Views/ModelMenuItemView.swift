//
//  ModelMenuItemView.swift
//  modelhub
//

import AppKit
import QuartzCore

/// One row in the menu — renders a single ``ParsedModel`` with its
/// family tag, display name, type/quant label, optional loaded-indicator
/// dot, on-disk size, and a hover-revealed trash button.
///
/// ## Layout
///
/// ```
/// [tag]  Display Name  ·  TYPE LABEL  ●        12.4 GB
/// ```
///
/// On hover (after a 1s dwell) the trash icon slides in from off-screen
/// at the trailing edge while the size text shifts left to make room.
///
/// ## Interaction
///
/// - **Click row body**: copies ``ParsedModel/copyableID`` to the
///   pasteboard and shows a 2-second "Copied to clipboard!" fade.
/// - **Click trash**: dismisses the menu, presents a confirmation alert,
///   and on confirm moves the model directory to the Trash.
final class ModelMenuItemView: NSView {

    // MARK: - Layout constants

    /// Outer horizontal padding on both sides.
    static let horizontalPadding: CGFloat = 14
    /// Diameter of the live-loaded indicator dot.
    static let dotSize: CGFloat = 8
    /// Gap between the title and the loaded dot.
    static let dotGap: CGFloat = 8
    /// Minimum gap between the dot and the size field.
    static let sizeGap: CGFloat = 14
    /// Total row height.
    static let rowHeight: CGFloat = 26

    /// Edge length of the trash icon button.
    static let trashSize: CGFloat = 14
    /// Gap between the size field and the trash button when revealed.
    static let trashGap: CGFloat = 6
    /// Trailing-anchor constant when the trash is hidden (off-screen).
    static let trashHiddenOffset: CGFloat = 18
    /// Trailing-anchor constant when the trash is revealed.
    static let trashVisibleOffset: CGFloat = -horizontalPadding
    /// Maximum width the title (`[tag] Name`) is allowed to take before
    /// truncating and unlocking marquee on hover. Generous enough that
    /// almost all real local titles fit without needing the marquee;
    /// only stupendously long names from Explore search results actually
    /// hit the cap.
    static let maxTitleWidth: CGFloat = 280
    /// Gap between the loaded-dot and the type column.
    static let typeGap: CGFloat = 10

    // MARK: - Public

    /// The model rendered by this row.
    let model: ParsedModel

    /// Whether this model was reported loaded by ``LiveLoadedChecker``.
    let loaded: Bool

    // MARK: - Subviews

    private let titleLabel: MarqueeLabel
    private let dotView: PulsingDotView
    private let typeField: NSTextField
    private let sizeField: NSTextField
    private let trashButton: NSButton

    // MARK: - Animatable constraints

    private var trashTrailingConstraint: NSLayoutConstraint!
    private var sizeTrailingConstraint: NSLayoutConstraint!

    // MARK: - State

    private let bytes: Int64
    private var trackingArea: NSTrackingArea?
    private var isRowHovered = false
    private var isShowingCopyFeedback = false
    private var copyFeedbackToken = 0
    private var isTrashRevealed = false

    // MARK: - Init

    /// - Parameters:
    ///   - model: Model to render.
    ///   - bytes: On-disk size in bytes (rendered on the trailing edge).
    ///   - loaded: Whether to show the pulsing-green "loaded" dot.
    ///   - width: Row width. Should match the menu's overall row width.
    init(model: ParsedModel, bytes: Int64, loaded: Bool, width: CGFloat) {
        self.model = model
        self.loaded = loaded
        self.bytes = bytes

        titleLabel = MarqueeLabel(maxWidth: Self.maxTitleWidth)
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)

        dotView = PulsingDotView()
        dotView.isHidden = !loaded

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
        // between the type column and the size text. Compression
        // resistance is required so layout pressure can't squeeze the
        // size text below its natural width (which is what was causing
        // the " GB" suffix to clip in earlier versions).
        sizeField.setContentHuggingPriority(.required, for: .horizontal)
        sizeField.setContentCompressionResistancePriority(.required, for: .horizontal)

        trashButton = NSButton()
        trashButton.isBordered = false
        trashButton.bezelStyle = .shadowlessSquare
        trashButton.imagePosition = .imageOnly
        let trashImg = NSImage(systemSymbolName: "trash", accessibilityDescription: "Move to Trash")
        trashImg?.isTemplate = true
        trashButton.image = trashImg
        trashButton.contentTintColor = .white
        trashButton.toolTip = "Move to Trash"
        trashButton.wantsLayer = true
        trashButton.alphaValue = 0

        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.rowHeight))

        addSubview(titleLabel)
        addSubview(dotView)
        addSubview(typeField)
        addSubview(sizeField)
        addSubview(trashButton)

        trashButton.target = self
        trashButton.action = #selector(trashButtonClicked(_:))

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        dotView.translatesAutoresizingMaskIntoConstraints = false
        typeField.translatesAutoresizingMaskIntoConstraints = false
        sizeField.translatesAutoresizingMaskIntoConstraints = false
        trashButton.translatesAutoresizingMaskIntoConstraints = false

        // Size sits flush at the trailing edge when trash is hidden;
        // it animates leftward to make room for the trash on hover.
        sizeTrailingConstraint = sizeField.trailingAnchor.constraint(
            equalTo: trailingAnchor,
            constant: -Self.horizontalPadding
        )
        trashTrailingConstraint = trashButton.trailingAnchor.constraint(
            equalTo: trailingAnchor,
            constant: Self.trashHiddenOffset
        )

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalPadding),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            dotView.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: Self.dotGap),
            dotView.centerYAnchor.constraint(equalTo: centerYAnchor),
            dotView.widthAnchor.constraint(equalToConstant: Self.dotSize),
            dotView.heightAnchor.constraint(equalToConstant: Self.dotSize),

            // Type column has intrinsic width; pinned to size's left edge.
            typeField.trailingAnchor.constraint(equalTo: sizeField.leadingAnchor, constant: -Self.sizeGap),
            typeField.centerYAnchor.constraint(equalTo: centerYAnchor),
            typeField.leadingAnchor.constraint(greaterThanOrEqualTo: dotView.trailingAnchor, constant: Self.typeGap),

            // Size sizes to its intrinsic content (with required hugging
            // + compression resistance so it can't be squeezed). Trailing
            // is pinned and animates leftward when trash slides in.
            sizeTrailingConstraint,
            sizeField.centerYAnchor.constraint(equalTo: centerYAnchor),

            trashTrailingConstraint,
            trashButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            trashButton.widthAnchor.constraint(equalToConstant: Self.trashSize),
            trashButton.heightAnchor.constraint(equalToConstant: Self.trashSize),
        ])

        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Attributed content

    /// Builds the row's title — `[tag] Name`. The type/format label is
    /// rendered in its own dedicated column (``makeTypeAttributed``) so
    /// neither the type nor the size gets dragged into the title's
    /// marquee animation.
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
    /// Returns an empty attributed string when the model has no type info.
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

    /// Intrinsic pixel width of the title for the given model.
    /// Used by ``MenuController`` to size the menu to the widest row.
    static func titleIntrinsicWidth(for model: ParsedModel) -> CGFloat {
        ceil(makeAttributedTitle(model, highlighted: false).size().width)
    }

    /// Intrinsic width of the type column for the given model.
    /// `0` if the model has no type info.
    static func typeIntrinsicWidth(for model: ParsedModel) -> CGFloat {
        ceil(makeTypeAttributed(model, highlighted: false).size().width)
    }

    /// Builds the trailing size label.
    static func makeSizeAttributed(bytes: Int64, highlighted: Bool) -> NSAttributedString {
        let color: NSColor = highlighted
            ? NSColor.selectedMenuItemTextColor.withAlphaComponent(0.8)
            : .tertiaryLabelColor
        return NSAttributedString(string: SizeUtil.format(bytes), attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: color
        ])
    }

    /// Intrinsic pixel width of the size label for the given byte count.
    static func sizeIntrinsicWidth(for bytes: Int64) -> CGFloat {
        ceil(makeSizeAttributed(bytes: bytes, highlighted: false).size().width)
    }

    /// "Copied to clipboard!" text shown briefly after a successful copy.
    static func makeCopiedAttributedString(highlighted: Bool) -> NSAttributedString {
        let color: NSColor = highlighted ? .selectedMenuItemTextColor : .systemGreen
        return NSAttributedString(string: "Copied to clipboard!", attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: color
        ])
    }

    // MARK: - Appearance

    private func updateAppearance() {
        if isShowingCopyFeedback {
            titleLabel.attributedStringValue = Self.makeCopiedAttributedString(highlighted: isRowHovered)
            // Hide the type column during the feedback flash to keep
            // attention on the message.
            typeField.attributedStringValue = NSAttributedString()
        } else {
            titleLabel.attributedStringValue = Self.makeAttributedTitle(model, highlighted: isRowHovered)
            typeField.attributedStringValue = Self.makeTypeAttributed(model, highlighted: isRowHovered)
        }
        sizeField.attributedStringValue = Self.makeSizeAttributed(bytes: bytes, highlighted: isRowHovered)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if isRowHovered {
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
        isRowHovered = true
        updateAppearance()
        revealTrash()
        titleLabel.beginHover()
        HoverCoordinator.enter(self)
    }

    override func mouseExited(with event: NSEvent) {
        isRowHovered = false
        updateAppearance()
        if isTrashRevealed { hideTrash() }
        titleLabel.endHover()
        HoverCoordinator.exit(self)
    }

    // MARK: - Trash slide-in

    private func revealTrash() {
        guard !isTrashRevealed else { return }
        isTrashRevealed = true
        let sizeShifted = -(Self.horizontalPadding + Self.trashSize + Self.trashGap)
        layoutSubtreeIfNeeded()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.allowsImplicitAnimation = true
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.sizeTrailingConstraint.animator().constant = sizeShifted
            self.trashTrailingConstraint.animator().constant = Self.trashVisibleOffset
            self.trashButton.animator().alphaValue = 1
            self.layoutSubtreeIfNeeded()
        }
    }

    private func hideTrash() {
        isTrashRevealed = false
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.allowsImplicitAnimation = true
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.sizeTrailingConstraint.animator().constant = -Self.horizontalPadding
            self.trashTrailingConstraint.animator().constant = Self.trashHiddenOffset
            self.trashButton.animator().alphaValue = 0
            self.layoutSubtreeIfNeeded()
        }
    }

    // MARK: - Click → copy

    override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        guard bounds.contains(loc) else {
            super.mouseUp(with: event)
            return
        }
        copyIdentifier()
    }

    private func copyIdentifier() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(model.copyableID, forType: .string)
        showCopiedFeedback()
    }

    private func showCopiedFeedback() {
        copyFeedbackToken &+= 1
        let token = copyFeedbackToken
        isShowingCopyFeedback = true

        fadeTitle(to: Self.makeCopiedAttributedString(highlighted: isRowHovered))

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self, self.copyFeedbackToken == token else { return }
            self.isShowingCopyFeedback = false
            self.fadeTitle(to: Self.makeAttributedTitle(self.model, highlighted: self.isRowHovered))
        }
    }

    private func fadeTitle(to newValue: NSAttributedString) {
        titleLabel.wantsLayer = true
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.14
            ctx.allowsImplicitAnimation = true
            titleLabel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.titleLabel.attributedStringValue = newValue
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.14
                ctx.allowsImplicitAnimation = true
                self.titleLabel.animator().alphaValue = 1
            }
        })
    }

    // MARK: - Click → trash

    @objc private func trashButtonClicked(_ sender: Any?) {
        // Capture by value before the menu closes and the row view is released.
        let path = model.fullPath
        let displayName = model.displayName
        let bytesNow = bytes
        enclosingMenuItem?.menu?.cancelTracking()
        DispatchQueue.main.async {
            ModelMenuItemView.confirmAndTrash(path: path, displayName: displayName, bytes: bytesNow)
        }
    }

    /// Presents a confirmation alert and, on approval, moves the model
    /// directory to the Trash via `NSWorkspace`.
    ///
    /// The alert is presented after `NSApp.activate(ignoringOtherApps:)`
    /// since `LSUIElement` apps aren't activated by default — without it
    /// the alert would appear behind the active app.
    private static func confirmAndTrash(path: String, displayName: String, bytes: Int64) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Delete “\(displayName)”?"
        alert.informativeText = "\(SizeUtil.format(bytes)) will be moved to the Trash.\n\n\(path)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        NSWorkspace.shared.recycle([URL(fileURLWithPath: path)]) { _, error in
            guard let error = error else { return }
            DispatchQueue.main.async {
                let err = NSAlert()
                err.messageText = "Couldn't delete “\(displayName)”"
                err.informativeText = error.localizedDescription
                err.alertStyle = .critical
                err.addButton(withTitle: "OK")
                err.runModal()
            }
        }
    }
}

// MARK: - Hover coordination

extension ModelMenuItemView: HoverableMenuRow {
    /// Called by ``HoverCoordinator`` when another row claims focus.
    /// Clears highlight + tucks the trash icon back away if it's out.
    func clearHoverState() {
        guard isRowHovered else { return }
        isRowHovered = false
        updateAppearance()
        if isTrashRevealed { hideTrash() }
        titleLabel.endHover()
    }
}
