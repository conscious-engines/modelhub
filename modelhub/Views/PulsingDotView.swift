//
//  PulsingDotView.swift
//  modelhub
//

import AppKit
import QuartzCore

/// Small green dot that pulses to indicate a model is currently loaded.
///
/// Renders entirely via Core Animation: a single layer with a circular
/// fill plus an autoreversing opacity animation. The animation runs only
/// while the menu is open (the view is removed when the menu closes), so
/// there's no idle CPU cost.
final class PulsingDotView: NSView {
    init() {
        super.init(frame: NSRect(
            x: 0, y: 0,
            width: ModelMenuItemView.dotSize,
            height: ModelMenuItemView.dotSize
        ))
        wantsLayer = true
        layer?.backgroundColor = NSColor.systemGreen.cgColor
        layer?.cornerRadius = ModelMenuItemView.dotSize / 2
        layer?.masksToBounds = true

        let glow = CABasicAnimation(keyPath: "opacity")
        glow.fromValue = 0.35
        glow.toValue = 1.0
        glow.duration = 1.1
        glow.autoreverses = true
        glow.repeatCount = .infinity
        glow.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer?.add(glow, forKey: "pulse")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    /// Keeps the corner radius perfectly circular if the frame ever changes.
    override func layout() {
        super.layout()
        layer?.cornerRadius = min(bounds.width, bounds.height) / 2
    }
}
