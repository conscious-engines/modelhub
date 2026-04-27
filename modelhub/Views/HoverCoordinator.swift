//
//  HoverCoordinator.swift
//  modelhub
//

import Foundation

/// Implemented by menu rows that participate in the single-row hover
/// invariant.
///
/// `clearHoverState()` is called when *another* row claims hover focus.
/// Implementations should reset their highlight and any hover-driven
/// affordances (e.g. revealed buttons).
protocol HoverableMenuRow: AnyObject {
    /// Called when another row claims hover focus.
    func clearHoverState()
}

/// Enforces a single-row hover state across the entire menu.
///
/// ## Why this exists
///
/// `NSTrackingArea` reports `mouseEntered` / `mouseExited` based on the
/// cursor crossing a tracking rect. NSMenu's auto-scroll moves rows
/// under a *stationary* cursor — and those events aren't always paired
/// the way you'd expect. New rows scroll into the cursor and report
/// `mouseEntered`, but the previously-hovered row may never get its
/// `mouseExited`. Result: two rows light up at once.
///
/// The coordinator works around this by holding a weak reference to
/// whichever row last claimed focus. When a new row reports `enter`,
/// the previous one is forced to clear.
///
/// The reference is `weak`, so menu views aren't kept alive across menu
/// closes.
enum HoverCoordinator {
    /// Currently-hovered row, weakly held.
    static weak var currentlyHovered: HoverableMenuRow?

    /// A row reports it just became hovered. Clears the previously
    /// hovered row, if any.
    static func enter(_ row: HoverableMenuRow) {
        if let prev = currentlyHovered, prev !== row {
            prev.clearHoverState()
        }
        currentlyHovered = row
    }

    /// A row reports it's no longer hovered.
    static func exit(_ row: HoverableMenuRow) {
        if currentlyHovered === row {
            currentlyHovered = nil
        }
    }
}
