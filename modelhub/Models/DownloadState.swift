//
//  DownloadState.swift
//  modelhub
//

import Foundation

/// Lifecycle state of one in-flight or completed model download.
///
/// Carries everything the row's download button needs to render itself
/// (icon + tooltip + tap behavior) so the button doesn't need to know
/// about ``DownloadManager`` directly.
enum DownloadState {
    /// Never started, or finished with a failure (allow retry).
    case notStarted

    /// User tapped — fetching model details before any byte transfers begin.
    case queued

    /// Files are transferring.
    /// - Parameters:
    ///   - progress: 0...1 — used as the SF symbol's `variableValue`
    ///     so the ring around `arrow.down.circle` fills with progress.
    ///   - bytesDownloaded: cumulative across all files in the model.
    ///   - totalBytes: best estimate (HF's `usedStorage`, refined as
    ///     individual file Content-Length headers come in).
    ///   - bytesPerSecond: short-term rolling-window speed.
    case downloading(progress: Double, bytesDownloaded: Int64, totalBytes: Int64, bytesPerSecond: Double)

    /// Currently paused; tap to resume from where it left off.
    case paused(progress: Double, bytesDownloaded: Int64, totalBytes: Int64)

    /// All files finished and the cache layout is fully written. The
    /// model will appear in the Local section the next time the menu opens.
    case completed

    /// Last attempt failed. Tooltip carries the message; tap retries.
    case failed(String)
}
