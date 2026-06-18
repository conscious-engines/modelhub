//
//  MarqueeLabel.swift
//  modelhub
//

import AppKit
import QuartzCore

/// Single-line text view with width capping + ellipsis truncation by
/// default, plus a hover-triggered marquee that scrolls the full text
/// horizontally to reveal anything that's hidden.
///
/// ## Behavior
///
/// - The text is laid out in an internal `NSTextField`. The label's
///   width resolves to `min(intrinsicTextWidth, maxWidth)` so it
///   integrates with sibling Auto Layout constraints naturally.
/// - When the text fits, hover does nothing.
/// - When the text overflows, calling ``beginHover()`` arms a 1-second
///   timer; on fire, truncation switches off and the text scrolls
///   leftward at a constant speed to reveal the tail. After a brief
///   pause it scrolls back, and loops until ``endHover()`` is called,
///   at which point everything resets instantly.
///
/// Drop-in compatible with `NSTextField` for the common pattern:
/// ```swift
/// label.attributedStringValue = makeAttributedTitle(...)
/// ```
/// `alphaValue` is inherited from `NSView`, so existing fade animations
/// (e.g. the "Copied to clipboard!" feedback) keep working unchanged.
final class MarqueeLabel: NSView {
    /// Pixels per second when scrolling toward the end of the text.
    private static let scrollSpeed: CGFloat = 30
    /// Multiplier on the return phase (faster snap back).
    private static let returnSpeedMultiplier: CGFloat = 2.0
    /// Pause at the start and end of each scroll cycle.
    private static let pauseDuration: TimeInterval = 1.0

    /// Maximum width the text is allowed to occupy. Text wider than
    /// this gets truncated with an ellipsis until hover-marquee
    /// reveals it.
    let maxWidth: CGFloat

    /// Currently-rendered attributed text. Setting cancels any running
    /// marquee animation and re-resolves the label width.
    var attributedStringValue: NSAttributedString {
        get { textField.attributedStringValue }
        set { setAttributedString(newValue) }
    }

    private let textField: NSTextField
    private var leadingConstraint: NSLayoutConstraint!
    private var widthConstraint: NSLayoutConstraint!

    private var marqueeTask: Task<Void, Never>?
    private var isMarqueeing = false

    init(maxWidth: CGFloat) {
        self.maxWidth = maxWidth

        textField = NSTextField(labelWithString: "")
        textField.isBezeled = false
        textField.isEditable = false
        textField.drawsBackground = false
        textField.usesSingleLineMode = true
        textField.cell?.usesSingleLineMode = true
        textField.cell?.lineBreakMode = .byTruncatingTail
        textField.cell?.wraps = false

        super.init(frame: NSRect(x: 0, y: 0, width: maxWidth, height: 18))
        // Layer-backed + clipped so the inner field can extend beyond
        // our bounds during marquee without painting outside.
        wantsLayer = true
        layer?.masksToBounds = true

        addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        leadingConstraint = textField.leadingAnchor.constraint(equalTo: leadingAnchor)
        widthConstraint = textField.widthAnchor.constraint(equalToConstant: maxWidth)
        NSLayoutConstraint.activate([
            leadingConstraint,
            widthConstraint,
            textField.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    /// Resolved label width feeds sibling Auto Layout constraints.
    /// Reflects the inner text field's actual width (capped at `maxWidth`).
    override var intrinsicContentSize: NSSize {
        NSSize(width: widthConstraint.constant, height: textField.intrinsicContentSize.height)
    }

    // MARK: - Public hover hooks

    /// Start the marquee immediately if the text actually overflows.
    /// (Animation itself runs at `scrollSpeed` — no dwell delay.)
    func beginHover() {
        guard isTextOverflowing else { return }
        startMarquee()
    }

    /// Stop the marquee immediately and reset to the truncated state.
    func endHover() {
        if isMarqueeing { stopMarquee() }
    }

    // MARK: - Implementation

    private var fullTextWidth: CGFloat {
        ceil(attributedStringValue.size().width)
    }

    /// The label's currently-laid-out width. Use this for overflow
    /// decisions instead of `maxWidth` — outer constraints (e.g. a
    /// `lessThanOrEqualTo` from a sibling column) can compress the
    /// label below `maxWidth`, and we still need marquee in that case.
    private var visibleWidth: CGFloat {
        bounds.width > 0 ? min(bounds.width, maxWidth) : maxWidth
    }

    private var isTextOverflowing: Bool {
        fullTextWidth > visibleWidth + 0.5
    }

    private func setAttributedString(_ value: NSAttributedString) {
        textField.attributedStringValue = value
        if isMarqueeing { stopMarquee() }
        widthConstraint.constant = min(ceil(value.size().width), maxWidth)
        textField.cell?.lineBreakMode = .byTruncatingTail
        invalidateIntrinsicContentSize()
    }

    private func startMarquee() {
        guard !isMarqueeing else { return }
        // Scroll relative to the visible (laid-out) width, not the
        // hard maxWidth — handles compression by outer constraints.
        let overflow = fullTextWidth - visibleWidth
        guard overflow > 0 else { return }

        isMarqueeing = true
        // Disable truncation and let the field grow to its full width;
        // our clipping container hides whatever sticks out.
        textField.cell?.lineBreakMode = .byClipping
        widthConstraint.constant = fullTextWidth
        layoutSubtreeIfNeeded()

        let scrollDuration = Double(overflow) / Double(Self.scrollSpeed)
        let returnDuration = scrollDuration / Double(Self.returnSpeedMultiplier)

        marqueeTask = Task { @MainActor [weak self] in
            // First scroll fires immediately on hover (no leading
            // pause). Subsequent cycles keep the inter-cycle pauses so
            // the loop has rhythm.
            while true {
                guard let s = self, s.isMarqueeing, !Task.isCancelled else { return }
                s.animateLeading(to: -overflow, duration: scrollDuration, timing: .linear)
                try? await Task.sleep(nanoseconds: UInt64(scrollDuration * 1_000_000_000))

                guard let s = self, s.isMarqueeing, !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: UInt64(Self.pauseDuration * 1_000_000_000))

                guard let s = self, s.isMarqueeing, !Task.isCancelled else { return }
                s.animateLeading(to: 0, duration: returnDuration, timing: .easeOut)
                try? await Task.sleep(nanoseconds: UInt64(returnDuration * 1_000_000_000))

                guard let s = self, s.isMarqueeing, !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: UInt64(Self.pauseDuration * 1_000_000_000))
            }
        }
    }

    private func animateLeading(to constant: CGFloat, duration: TimeInterval, timing: CAMediaTimingFunctionName) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: timing)
            ctx.allowsImplicitAnimation = true
            self.leadingConstraint.animator().constant = constant
            self.layoutSubtreeIfNeeded()
        }
    }

    private func stopMarquee() {
        isMarqueeing = false
        marqueeTask?.cancel()
        marqueeTask = nil

        // Snap back without animation so an interrupted scroll doesn't
        // animate out the long way.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        leadingConstraint.constant = 0
        widthConstraint.constant = min(fullTextWidth, maxWidth)
        textField.cell?.lineBreakMode = .byTruncatingTail
        textField.layer?.removeAllAnimations()
        layer?.removeAllAnimations()
        layoutSubtreeIfNeeded()
        CATransaction.commit()
    }
}
