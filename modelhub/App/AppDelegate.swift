//
//  AppDelegate.swift
//  modelhub
//

import AppKit

/// Owns the `NSStatusItem` and wires it up to the ``MenuController``.
///
/// The status-bar button hosts a template SF Symbol (so it adapts to the
/// system menu-bar tint), and the controller's menu is attached as the
/// status item's menu — clicking the button opens it, and `NSMenuDelegate`
/// callbacks on the controller drive the rebuild + filter behavior.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var controller: MenuController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let image = NSImage(
                systemSymbolName: "cube.transparent",
                accessibilityDescription: "Model Hub"
            )
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Model Hub"
        }

        controller = MenuController()
        statusItem.menu = controller.menu

        // Boot Sparkle. The shared instance owns the SPUUpdater and
        // schedules its own launch-time check; we additionally trigger
        // a background check on every menu open (see MenuController).
        _ = UpdateManager.shared

        // First-run only: point a popover at the menu bar icon so users
        // discover that the app lives up there.
        if let button = statusItem.button {
            WelcomePopover.showIfNeeded(anchor: button)
        }
    }
}
