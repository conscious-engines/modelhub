//
//  ModelPaths.swift
//  modelhub
//

import Foundation

/// Canonical on-disk locations Model Hub scans for models.
///
/// Both paths are computed from `NSHomeDirectory()` so they resolve to the
/// running user's actual home, not a hard-coded user.
enum ModelPaths {
    /// LM Studio's local model directory.
    /// Layout: `<root>/<publisher>/<repo>/`
    static let lmStudioRoot = (NSHomeDirectory() as NSString)
        .appendingPathComponent(".lmstudio/models")

    /// HuggingFace Hub cache.
    /// Layout: `<root>/models--<publisher>--<repo>/`
    /// (Inside each model dir: `blobs/` (real files) and `snapshots/<rev>/`
    /// (symlinks back into blobs). ``SizeUtil/directorySize(at:)`` skips
    /// symlinks so they don't double-count.)
    static let huggingFaceRoot = (NSHomeDirectory() as NSString)
        .appendingPathComponent(".cache/huggingface/hub")
}
