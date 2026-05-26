//
//  UpdateManager.swift
//  modelhub
//

import AppKit
import Sparkle

/// Notifications posted as Sparkle's background check progresses.
///
/// The menu controller observes these to decide whether to show the
/// "Update available" row at the top of the menu and to refresh the
/// Settings tab's update block.
extension Notification.Name {
    /// A valid update has been found. `userInfo["version"]` carries the
    /// new short version string (e.g. `"1.2.0"`).
    static let modelhubUpdateAvailable = Notification.Name("modelhub.updateAvailable")
    /// A background check completed and the app is already on the latest
    /// version. Used to clear any stale "update available" UI.
    static let modelhubUpdateNotFound = Notification.Name("modelhub.updateNotFound")
}

/// Thin wrapper around Sparkle that owns the updater lifecycle and
/// surfaces a couple of notifications the menu can react to.
///
/// ## Why a wrapper
///
/// `SPUStandardUpdaterController` works fine on its own, but the menu
/// bar app wants two extra things:
/// 1. A *passive* "update available" surface that lives inside the menu
///    itself — not Sparkle's default modal dialog. We get this by acting
///    as ``SPUUpdaterDelegate`` and posting notifications when a
///    background check resolves.
/// 2. A short throttle on background checks so opening the menu rapidly
///    doesn't hammer the appcast endpoint.
///
/// Sparkle still drives the active install flow (download + EdDSA
/// signature verification + relaunch). Re-implementing that surface
/// would mean reinventing every edge case Sparkle already handles.
final class UpdateManager: NSObject {
    /// Shared instance — initialized once in ``AppDelegate``.
    static let shared = UpdateManager()

    /// Minimum interval between two background appcast fetches. Keeps
    /// rapid menu-bar clicks from hammering the studio site.
    private static let checkThrottle: TimeInterval = 30

    /// Implicitly unwrapped because `SPUStandardUpdaterController` needs
    /// `self` as its `updaterDelegate`, and Swift's two-phase init forbids
    /// referencing `self` until `super.init` has run. We assign it on
    /// the line right after `super.init` — it's effectively `let`.
    private var controller: SPUStandardUpdaterController!
    private var lastCheck: Date?

    /// The most recent valid update Sparkle has surfaced, if any.
    /// Cleared once the user installs it or a subsequent background
    /// check confirms there's no update.
    private(set) var pendingUpdate: SUAppcastItem?

    /// `CFBundleShortVersionString`, surfaced in the Settings tab.
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    /// Build metadata (`CFBundleVersion`), shown next to the short
    /// version in Settings.
    var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    // MARK: - Init

    override init() {
        super.init()
        // `SPUStandardUpdaterController` is the supported way to wire a
        // delegate in Sparkle 2.x — `SPUUpdater.delegate` is read-only.
        // `startingUpdater: true` boots the updater immediately so it
        // picks up the launch-time check Sparkle schedules.
        //
        // We also register as the userDriverDelegate so we can opt into
        // Sparkle's "gentle scheduled update reminders" pattern — see
        // the SPUStandardUserDriverDelegate conformance below for why.
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: self
        )
    }

    // MARK: - Public API

    /// Run a background appcast fetch if we haven't checked recently.
    /// Called from ``MenuController/menuDidOpen`` so every menu open is
    /// effectively an update check — invisible until something's found.
    func checkInBackground() {
        if let last = lastCheck, Date().timeIntervalSince(last) < Self.checkThrottle {
            return
        }
        lastCheck = Date()
        controller.updater.checkForUpdatesInBackground()
    }

    /// User-initiated check from the Settings tab. Drives Sparkle's
    /// standard UI so we get the "you're up to date" / "couldn't reach
    /// server" affordances for free.
    func checkNow() {
        lastCheck = Date()
        controller.checkForUpdates(nil)
    }

    /// User tapped the "Update" button on the in-menu banner. Hands
    /// control to Sparkle's standard flow — it downloads the DMG,
    /// verifies the EdDSA signature, prompts for install, and relaunches.
    func installPending() {
        controller.checkForUpdates(nil)
    }

    // MARK: - Internals

    /// Capture an appcast item and announce it to the menu. Called from
    /// both delegate paths (the standard updater delegate for
    /// user-initiated checks, and the user-driver delegate for
    /// gentle-reminder background checks).
    private func surfacePendingUpdate(_ item: SUAppcastItem) {
        pendingUpdate = item
        NotificationCenter.default.post(
            name: .modelhubUpdateAvailable,
            object: nil,
            userInfo: ["version": item.displayVersionString]
        )
    }
}

// MARK: - SPUUpdaterDelegate

extension UpdateManager: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        surfacePendingUpdate(item)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        pendingUpdate = nil
        NotificationCenter.default.post(name: .modelhubUpdateNotFound, object: nil)
    }
}

// MARK: - SPUStandardUserDriverDelegate

/// Opt into Sparkle's "gentle scheduled update reminders" so background
/// appcast fetches don't pop a modal — instead they call us back, and
/// we surface the banner row at the top of the menu.
///
/// Without this, `checkForUpdatesInBackground()` decides on its own
/// whether to interrupt the user, and `updater(_:didFindValidUpdate:)`
/// is not reliably called for background paths. With it, every
/// background check that finds an update flows through
/// ``standardUserDriverWillHandleShowingUpdate(_:forUpdate:state:)``.
///
/// User-initiated checks via ``checkNow`` are unaffected — Sparkle's
/// standard modal UI still drives those (so we keep its built-in
/// "you're up to date" / "couldn't reach server" affordances).
extension UpdateManager: SPUStandardUserDriverDelegate {
    /// Tell Sparkle we can show our own UI for scheduled updates.
    /// Without this it falls back to its built-in modal.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    /// Returning `false` tells Sparkle's standard driver: "don't show
    /// your modal for this scheduled update — I'll handle the UI myself."
    /// `immediateFocus` is whether the app is currently frontmost; we
    /// defer to our banner in both cases for a consistent look.
    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        false
    }

    /// Called whenever Sparkle is about to show an update originated by
    /// a scheduled check. When we've returned `false` above,
    /// `handleShowingUpdate` is `false` too — meaning Sparkle's modal is
    /// suppressed and our banner is now the user's only signal that an
    /// update exists.
    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard !handleShowingUpdate else { return }
        surfacePendingUpdate(update)
    }
}
