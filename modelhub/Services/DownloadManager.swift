//
//  DownloadManager.swift
//  modelhub
//

import AppKit
import Foundation

/// Notification posted by ``DownloadManager`` whenever a download's
/// state changes. `userInfo`:
/// - `"repoID"`: original-case `Publisher/Repo` string
/// - `"state"`: the new ``DownloadState``
extension Notification.Name {
    static let downloadStateChanged = Notification.Name("modelhub.downloadStateChanged")
}

/// Single owner of the URLSession used to fetch model files from
/// HuggingFace. Replicates the CLI's cache layout via ``HFCacheWriter``,
/// so downloads from Model Hub are interchangeable with downloads from
/// `huggingface-cli` for any tool that reads `~/.cache/huggingface/hub`.
///
/// ## Threading
///
/// Singleton. The URLSession is configured with `delegateQueue: .main`,
/// so all delegate callbacks fire on the main thread and the rest of
/// the manager's mutable state (`downloads`, per-`Download` fields) is
/// only ever touched from main. No locking required.
///
/// ## Lifecycle of a download
///
/// 1. `start(repoID:estimatedTotalBytes:)` — creates ``Download``,
///    state = `.queued`, kicks off async details fetch.
/// 2. Details land → directory structure created → state = `.downloading`.
/// 3. Each file: `URLSessionDownloadTask` opened, redirect handler
///    captures `X-Linked-Etag` (LFS files lose it after the S3 redirect),
///    progress published on every `didWriteData`.
/// 4. On `didFinishDownloadingTo`: blob moved to `blobs/{etag}`,
///    snapshot symlink created, advance to next file.
/// 5. After last file: `refs/main` written, state = `.completed`,
///    download removed from the in-memory map.
final class DownloadManager: NSObject, URLSessionDownloadDelegate {
    /// Process-wide instance. AppDelegate doesn't need to wire it up;
    /// first access initializes everything lazily.
    static let shared = DownloadManager()

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        // Multi-GB safetensors can take a while; default 7-day max stays.
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 60 * 60 * 24
        config.urlCache = nil
        config.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    /// Active downloads keyed by `Publisher/Repo`.
    private var downloads: [String: Download] = [:]

    private override init() { super.init() }

    // MARK: - Public API

    /// Resolve the current state for a repo. Falls back to `.completed`
    /// if the cache already has the model on disk, otherwise `.notStarted`.
    func state(for repoID: String) -> DownloadState {
        if let download = downloads[repoID] { return download.state }
        if HFCacheWriter.isDownloaded(repoID: repoID) { return .completed }
        return .notStarted
    }

    /// Begin a download. No-op if one is already tracked for this repo
    /// or if the model is already in the cache.
    func start(repoID: String, estimatedTotalBytes: Int64) {
        if HFCacheWriter.isDownloaded(repoID: repoID) {
            notify(repoID: repoID, state: .completed)
            return
        }
        guard downloads[repoID] == nil else { return }

        let download = Download(repoID: repoID, totalBytes: max(0, estimatedTotalBytes))
        download.state = .queued
        downloads[repoID] = download
        notify(repoID: repoID, state: .queued)

        Task { await prepareAndStart(download: download) }
    }

    /// Pause an in-flight download. Captures resume data for a later
    /// `resume(repoID:)` call.
    func pause(repoID: String) {
        guard let download = downloads[repoID], let task = download.task else { return }
        task.cancel(byProducingResumeData: { [weak self] data in
            // Already on main (delegateQueue), but be defensive.
            DispatchQueue.main.async {
                guard let self else { return }
                download.resumeData = data
                download.task = nil
                let state = DownloadState.paused(
                    progress: download.progress,
                    bytesDownloaded: download.bytesDownloaded,
                    totalBytes: download.totalBytes
                )
                download.state = state
                self.notify(repoID: download.repoID, state: state)
            }
        })
    }

    /// Resume a paused download.
    func resume(repoID: String) {
        guard let download = downloads[repoID], let resumeData = download.resumeData else { return }

        let task = session.downloadTask(withResumeData: resumeData)
        download.task = task
        download.resumeData = nil
        let state = DownloadState.downloading(
            progress: download.progress,
            bytesDownloaded: download.bytesDownloaded,
            totalBytes: download.totalBytes,
            bytesPerSecond: download.bytesPerSecond
        )
        download.state = state
        notify(repoID: download.repoID, state: state)
        task.resume()
    }

    // MARK: - Orchestration

    /// Fetch the file list + commit sha, prepare the cache directories,
    /// then kick off the first file transfer.
    private func prepareAndStart(download: Download) async {
        do {
            let detail = try await HuggingFaceAPI.modelDetail(repoID: download.repoID)
            guard let sha = detail.sha, let siblings = detail.siblings, !siblings.isEmpty else {
                throw HuggingFaceAPI.APIError.badResponse
            }
            // Filter out hidden housekeeping files (.gitattributes etc are kept;
            // huggingface_hub downloads them too — they're real repo files).
            download.sha = sha
            download.files = siblings.map {
                DownloadFile(filename: $0.rfilename, transferredBytes: 0, blobHash: nil)
            }
            // Refine the total estimate if HF gave us usedStorage at search time,
            // otherwise keep what was passed in.
            try HFCacheWriter.prepareDirectories(repoID: download.repoID, sha: sha)

            await MainActor.run {
                let state = DownloadState.downloading(
                    progress: 0,
                    bytesDownloaded: 0,
                    totalBytes: download.totalBytes,
                    bytesPerSecond: 0
                )
                download.state = state
                self.notify(repoID: download.repoID, state: state)
                self.startCurrentFile(download: download)
            }
        } catch {
            await MainActor.run {
                self.fail(download: download, message: error.localizedDescription)
            }
        }
    }

    /// Start the next file in the queue, or finalize if we're done.
    private func startCurrentFile(download: Download) {
        guard download.currentIndex < download.files.count else {
            finalize(download: download)
            return
        }
        guard let sha = download.sha else { return }

        let file = download.files[download.currentIndex]
        guard let url = HuggingFaceAPI.resolveURL(
            repoID: download.repoID,
            revision: sha,
            filename: file.filename
        ) else {
            fail(download: download, message: "Couldn't build download URL.")
            return
        }

        download.currentFileBytes = 0
        download.preRedirectEtag = nil
        let task = session.downloadTask(with: url)
        download.task = task
        task.resume()
    }

    /// All files done — write the ref and mark complete.
    private func finalize(download: Download) {
        guard let sha = download.sha else { return }
        do {
            try HFCacheWriter.writeRef(repoID: download.repoID, sha: sha)
            download.state = .completed
            notify(repoID: download.repoID, state: .completed)
            downloads.removeValue(forKey: download.repoID)
        } catch {
            fail(download: download, message: error.localizedDescription)
        }
    }

    private func fail(download: Download, message: String) {
        download.state = .failed(message)
        notify(repoID: download.repoID, state: .failed(message))
        downloads.removeValue(forKey: download.repoID)
    }

    private func notify(repoID: String, state: DownloadState) {
        NotificationCenter.default.post(
            name: .downloadStateChanged,
            object: self,
            userInfo: ["repoID": repoID, "state": state]
        )
    }

    private func findDownload(for task: URLSessionTask) -> Download? {
        downloads.values.first { $0.task?.taskIdentifier == task.taskIdentifier }
    }

    /// Strip surrounding quotes (and a possible `W/` weak-validator prefix)
    /// from an ETag header value.
    private func stripQuotes(_ s: String) -> String {
        var out = s
        if out.hasPrefix("W/") { out.removeFirst(2) }
        if out.hasPrefix("\"") { out.removeFirst() }
        if out.hasSuffix("\"") { out.removeLast() }
        return out
    }

    // MARK: - URLSessionTaskDelegate

    /// Captures `X-Linked-Etag` from the **pre-redirect** response so we
    /// can name LFS blobs by their content SHA-256 (the redirect target,
    /// e.g. S3, doesn't carry the linked-etag header).
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        if let download = findDownload(for: task) {
            let xLinked = response.value(forHTTPHeaderField: "X-Linked-Etag")
                ?? response.value(forHTTPHeaderField: "x-linked-etag")
            let etag = response.value(forHTTPHeaderField: "ETag")
                ?? response.value(forHTTPHeaderField: "etag")
            if let raw = xLinked ?? etag {
                download.preRedirectEtag = stripQuotes(raw)
            }
        }
        completionHandler(request)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        let nsError = error as NSError
        // Cancellation is part of the pause flow — state is already set there.
        if nsError.code == NSURLErrorCancelled { return }
        guard let download = findDownload(for: task) else { return }
        fail(download: download, message: error.localizedDescription)
    }

    // MARK: - URLSessionDownloadDelegate

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let download = findDownload(for: downloadTask) else { return }
        download.currentFileBytes = totalBytesWritten
        download.recordSample()

        let state = DownloadState.downloading(
            progress: download.progress,
            bytesDownloaded: download.bytesDownloaded,
            totalBytes: download.totalBytes,
            bytesPerSecond: download.bytesPerSecond
        )
        download.state = state
        notify(repoID: download.repoID, state: state)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let download = findDownload(for: downloadTask) else {
            try? FileManager.default.removeItem(at: location)
            return
        }
        guard let response = downloadTask.response as? HTTPURLResponse else {
            fail(download: download, message: "Bad response.")
            return
        }
        // HuggingFace returns a body even on 4xx/5xx — must check the status.
        if !(200..<300).contains(response.statusCode) {
            try? FileManager.default.removeItem(at: location)
            let msg: String
            switch response.statusCode {
            case 401, 403: msg = "Model requires HuggingFace authentication."
            case 404:      msg = "Model file not found."
            default:       msg = "HTTP \(response.statusCode)"
            }
            fail(download: download, message: msg)
            return
        }

        // Determine blob hash. For LFS files the captured pre-redirect
        // X-Linked-Etag wins; for non-LFS files there was no redirect
        // and we read the post-response ETag directly.
        let postEtag = response.value(forHTTPHeaderField: "ETag")
            ?? response.value(forHTTPHeaderField: "etag")
        let rawHash = download.preRedirectEtag
            ?? postEtag.map(stripQuotes)
            ?? UUID().uuidString
        let blobHash = stripQuotes(rawHash)

        guard let sha = download.sha else {
            fail(download: download, message: "Missing commit sha.")
            return
        }
        let file = download.files[download.currentIndex]

        do {
            try HFCacheWriter.placeBlob(at: location, repoID: download.repoID, blobHash: blobHash)
            try HFCacheWriter.createSnapshotSymlink(
                repoID: download.repoID,
                sha: sha,
                filename: file.filename,
                blobHash: blobHash
            )
        } catch {
            fail(download: download, message: error.localizedDescription)
            return
        }

        // Advance.
        let bytesForFile = downloadTask.countOfBytesReceived
        download.completedFileBytes += bytesForFile
        download.currentFileBytes = 0
        download.files[download.currentIndex].transferredBytes = bytesForFile
        download.files[download.currentIndex].blobHash = blobHash
        download.currentIndex += 1
        download.task = nil

        // Refine total estimate if it under-reported.
        if download.completedFileBytes > download.totalBytes {
            download.totalBytes = download.completedFileBytes
        }

        startCurrentFile(download: download)
    }
}
