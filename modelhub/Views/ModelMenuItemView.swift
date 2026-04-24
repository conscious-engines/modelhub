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
    static let trashGap: CGFloat = 10
    /// Trailing-anchor constant when the trash is hidden (off-screen).
    static let trashHiddenOffset: CGFloat = 18
    /// Trailing-anchor constant when the trash is revealed.
    static let trashVisibleOffset: CGFloat = -horizontalPadding
    /// Hover dwell time before the trash icon slides in.
    static let hoverDelay: TimeInterval = 1.0

    // MARK: - Public

    /// The model rendered by this row.
    let model: ParsedModel

    /// Whether this model was reported loaded by ``LiveLoadedChecker``.
    let loaded: Bool

    // MARK: - Subviews

    private let titleField: NSTextField
    private let dotView: PulsingDotView
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
    private var hoverWorkItem: DispatchWorkItem?
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

        titleField = NSTextField(labelWithString: "")
        titleField.isBezeled = false
        titleField.isEditable = false
        titleField.drawsBackground = false
        titleField.usesSingleLineMode = true
        titleField.cell?.lineBreakMode = .byTruncatingTail
        titleField.setContentHuggingPriority(.required, for: .horizontal)

        dotView = PulsingDotView()
        dotView.isHidden = !loaded

        sizeField = NSTextField(labelWithString: "")
        sizeField.isBezeled = false
        sizeField.isEditable = false
        sizeField.drawsBackground = false
        sizeField.alignment = .right
        sizeField.setContentHuggingPriority(.required, for: .horizontal)

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

        addSubview(titleField)
        addSubview(dotView)
        addSubview(sizeField)
        addSubview(trashButton)

        trashButton.target = self
        trashButton.action = #selector(trashButtonClicked(_:))

        titleField.translatesAutoresizingMaskIntoConstraints = false
        dotView.translatesAutoresizingMaskIntoConstraints = false
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
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalPadding),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),

            dotView.leadingAnchor.constraint(equalTo: titleField.trailingAnchor, constant: Self.dotGap),
            dotView.centerYAnchor.constraint(equalTo: centerYAnchor),
            dotView.widthAnchor.constraint(equalToConstant: Self.dotSize),
            dotView.heightAnchor.constraint(equalToConstant: Self.dotSize),

            sizeTrailingConstraint,
            sizeField.centerYAnchor.constraint(equalTo: centerYAnchor),
            sizeField.leadingAnchor.constraint(greaterThanOrEqualTo: dotView.trailingAnchor, constant: Self.sizeGap),

            trashTrailingConstraint,
            trashButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            trashButton.widthAnchor.constraint(equalToConstant: Self.trashSize),
            trashButton.heightAnchor.constraint(equalToConstant: Self.trashSize),
        ])

        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Attributed content

    /// Builds the row's primary attributed title (`[tag] Name · TYPE`).
    /// Highlighted variants substitute the selected-menu-item text color
    /// so the row stays legible when hovered.
    static func makeAttributedTitle(_ m: ParsedModel, highlighted: Bool) -> NSAttributedString {
        let s = NSMutableAttributedString()

        let tagColor: NSColor = highlighted
            ? NSColor.selectedMenuItemTextColor.withAlphaComponent(0.75)
            : .secondaryLabelColor
        let nameColor: NSColor = highlighted ? .selectedMenuItemTextColor : .labelColor
        let sepColor: NSColor = highlighted
            ? NSColor.selectedMenuItemTextColor.withAlphaComponent(0.5)
            : .quaternaryLabelColor
        let typeColor: NSColor = highlighted
            ? NSColor.selectedMenuItemTextColor.withAlphaComponent(0.7)
            : .tertiaryLabelColor

        s.append(NSAttributedString(string: "[\(m.familyTag)]", attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: tagColor
        ]))
        s.append(NSAttributedString(string: "  "))
        s.append(NSAttributedString(string: m.displayName, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: nameColor
        ]))
        if let t = m.typeLabel {
            s.append(NSAttributedString(string: "   ·  ", attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: sepColor
            ]))
            s.append(NSAttributedString(string: t, attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: typeColor
            ]))
        }
        return s
    }

    /// Intrinsic pixel width of the title for the given model.
    /// Used by ``MenuController`` to size the menu to the widest row.
    static func titleIntrinsicWidth(for model: ParsedModel) -> CGFloat {
        ceil(makeAttributedTitle(model, highlighted: false).size().width)
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
            titleField.attributedStringValue = Self.makeCopiedAttributedString(highlighted: isRowHovered)
        } else {
            titleField.attributedStringValue = Self.makeAttributedTitle(model, highlighted: isRowHovered)
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
        scheduleTrashReveal()
    }

    override func mouseExited(with event: NSEvent) {
        isRowHovered = false
        updateAppearance()
        cancelTrashReveal()
    }

    // MARK: - Trash slide-in

    private func scheduleTrashReveal() {
        cancelHoverWorkItem()
        let work = DispatchWorkItem { [weak self] in self?.revealTrash() }
        hoverWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.hoverDelay, execute: work)
    }

    private func cancelTrashReveal() {
        cancelHoverWorkItem()
        if isTrashRevealed { hideTrash() }
    }

    private func cancelHoverWorkItem() {
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
    }

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
        titleField.wantsLayer = true
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.14
            ctx.allowsImplicitAnimation = true
            titleField.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self else { return }
            self.titleField.attributedStringValue = newValue
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.14
                ctx.allowsImplicitAnimation = true
                self.titleField.animator().alphaValue = 1
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
