//
//  HFCacheWriter.swift
//  modelhub
//

import Foundation

/// Writes downloaded model files into HuggingFace's standard cache
/// layout so the same models are usable by anything that reads from
/// `~/.cache/huggingface/hub` — `transformers`, `mlx-lm`, `llama.cpp`,
/// `ollama`, the HF CLI itself, etc.
///
/// ## Layout written (matches `huggingface_hub` exactly)
///
/// ```
/// models--{publisher}--{repo}/
/// ├── blobs/
/// │   └── {etag}                # actual file content (one per unique blob)
/// ├── refs/
/// │   └── main                  # contains the commit sha
/// └── snapshots/
///     └── {commit_sha}/
///         └── {filename}        # symlink → ../../blobs/{etag}
/// ```
///
/// All snapshot symlinks are RELATIVE (`../../blobs/{etag}`) — same as
/// the CLI — so the cache directory can be moved without breaking.
enum HFCacheWriter {
    /// Resolves the cache directory for a repo without creating anything.
    static func modelDirectory(repoID: String) -> URL {
        let parts = repoID.split(separator: "/").map(String.init)
        let dirName = "models--\(parts.joined(separator: "--"))"
        return URL(fileURLWithPath: ModelPaths.huggingFaceRoot)
            .appendingPathComponent(dirName)
    }

    /// `true` if the repo appears fully downloaded (i.e. has `refs/main`).
    /// Mirrors the CLI's "is this model in the cache?" check.
    static func isDownloaded(repoID: String) -> Bool {
        let path = modelDirectory(repoID: repoID)
            .appendingPathComponent("refs")
            .appendingPathComponent("main")
            .path
        return FileManager.default.fileExists(atPath: path)
    }

    /// Create the `blobs/`, `refs/`, and `snapshots/{sha}/` directories.
    /// Idempotent — safe to call on a partially-existing cache.
    @discardableResult
    static func prepareDirectories(repoID: String, sha: String) throws -> URL {
        let root = modelDirectory(repoID: repoID)
        let fm = FileManager.default
        try fm.createDirectory(at: root.appendingPathComponent("blobs"),
                               withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("refs"),
                               withIntermediateDirectories: true)
        try fm.createDirectory(
            at: root.appendingPathComponent("snapshots").appendingPathComponent(sha),
            withIntermediateDirectories: true
        )
        return root
    }

    /// Move a freshly-downloaded temp file into `blobs/{blobHash}`.
    /// If a blob with this hash already exists (cross-model dedup, or
    /// retry-after-failure), the temp file is discarded and the existing
    /// blob is reused.
    @discardableResult
    static func placeBlob(at tempLocation: URL, repoID: String, blobHash: String) throws -> URL {
        let blobURL = modelDirectory(repoID: repoID)
            .appendingPathComponent("blobs")
            .appendingPathComponent(blobHash)
        let fm = FileManager.default
        if fm.fileExists(atPath: blobURL.path) {
            try? fm.removeItem(at: tempLocation)
            return blobURL
        }
        try fm.moveItem(at: tempLocation, to: blobURL)
        return blobURL
    }

    /// Create a relative symlink at `snapshots/{sha}/{filename}` pointing
    /// to `../../blobs/{blobHash}` (with extra `../` levels added when
    /// the filename has nested directories).
    static func createSnapshotSymlink(
        repoID: String,
        sha: String,
        filename: String,
        blobHash: String
    ) throws {
        let linkURL = modelDirectory(repoID: repoID)
            .appendingPathComponent("snapshots")
            .appendingPathComponent(sha)
            .appendingPathComponent(filename)

        let fm = FileManager.default
        let parent = linkURL.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)

        // For nested filenames like "subdir/foo.json", the symlink needs
        // an extra `../` per directory level to climb back to the model
        // root before descending into `blobs/`.
        let depth = filename.split(separator: "/").count - 1
        let upLevels = String(repeating: "../", count: depth + 2)
        let target = "\(upLevels)blobs/\(blobHash)"

        // Replace any existing entry at this path.
        if fm.fileExists(atPath: linkURL.path) {
            try? fm.removeItem(at: linkURL)
        }
        try fm.createSymbolicLink(atPath: linkURL.path, withDestinationPath: target)
    }

    /// Write `refs/main` containing just the commit SHA (no trailing newline,
    /// matching the CLI).
    static func writeRef(repoID: String, sha: String) throws {
        let refURL = modelDirectory(repoID: repoID)
            .appendingPathComponent("refs")
            .appendingPathComponent("main")
        try sha.write(to: refURL, atomically: true, encoding: .utf8)
    }
}
