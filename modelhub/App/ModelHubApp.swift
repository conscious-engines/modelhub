//
//  ModelHubApp.swift
//  modelhub
//

import SwiftUI

/// Application entry point.
///
/// `ModelHubApp` exists only to host an `NSApplicationDelegateAdaptor` so the
/// AppKit-based ``AppDelegate`` can take ownership of the menu bar lifecycle.
///
/// The empty `Settings` scene is intentional — combined with `LSUIElement = YES`
/// in `Info.plist`, it gives a pure menu-bar app: no Dock icon, no main window,
/// no application menu. Cmd-, never resolves to anything because there's no
/// app-menu surface to expose it.
@main
struct ModelHubApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
