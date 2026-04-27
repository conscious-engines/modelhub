//
//  Download.swift
//  modelhub
//

import Foundation

/// One file in a model's download queue.
struct DownloadFile {
    /// Path of the file relative to the repo root.
    let filename: String
    /// Bytes transferred for this file (populated after completion).
    var transferredBytes: Int64
    /// Blob hash used as the file's name under `blobs/`. For non-LFS
    /// files this is the git SHA-1 from the `ETag` header; for LFS
    /// files it's the SHA-256 from `X-Linked-Etag` on the pre-redirect
    /// response.
    var blobHash: String?
}

/// Internal record of one in-flight or paused model download.
///
/// Owned by ``DownloadManager``. Mutated only on the main thread.
final class Download {
    /// `Publisher/Repo` — original case, matching HF's API and cache layout.
    let repoID: String

    /// Commit SHA. Populated after the initial details fetch and used
    /// as the snapshot directory name.
    var sha: String?

    /// File queue. Populated after the initial details fetch.
    var files: [DownloadFile] = []

    /// Index into ``files`` of the currently-active transfer.
    var currentIndex: Int = 0

    /// Sum of bytes from already-completed files.
    var completedFileBytes: Int64 = 0

    /// Bytes downloaded for the currently-active file (resets on file completion).
    var currentFileBytes: Int64 = 0

    /// Estimated total (from HF's `usedStorage`).
    var totalBytes: Int64

    /// Active task for the currently-downloading file. Nil briefly
    /// between files or while paused.
    var task: URLSessionDownloadTask?

    /// Resume data captured at pause time; non-nil while paused.
    var resumeData: Data?

    /// Etag captured from the pre-redirect response so LFS blob hashes
    /// (in `X-Linked-Etag`) survive the S3 redirect.
    var preRedirectEtag: String?

    /// Recent (time, totalBytesDownloaded) samples for speed calculation.
    var speedSamples: [(time: Date, bytes: Int64)] = []

    /// Public state — what the UI renders.
    var state: DownloadState = .queued

    init(repoID: String, totalBytes: Int64) {
        self.repoID = repoID
        self.totalBytes = totalBytes
    }

    /// Cumulative bytes across the whole model.
    var bytesDownloaded: Int64 {
        completedFileBytes + currentFileBytes
    }

    /// Fraction `0...1` of total bytes, clamped.
    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1.0, Double(bytesDownloaded) / Double(totalBytes))
    }

    /// Speed averaged over the most recent ~3 seconds.
    var bytesPerSecond: Double {
        let now = Date()
        let cutoff = now.addingTimeInterval(-3)
        let recent = speedSamples.filter { $0.time >= cutoff }
        guard recent.count >= 2,
              let first = recent.first, let last = recent.last,
              last.time > first.time
        else { return 0 }
        let bytes = Double(last.bytes - first.bytes)
        let seconds = last.time.timeIntervalSince(first.time)
        return bytes / seconds
    }

    /// Record a fresh sample. Trims samples older than 5 seconds.
    func recordSample() {
        let now = Date()
        speedSamples.append((time: now, bytes: bytesDownloaded))
        let cutoff = now.addingTimeInterval(-5)
        speedSamples.removeAll { $0.time < cutoff }
    }
}
