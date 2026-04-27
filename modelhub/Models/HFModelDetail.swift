//
//  HFModelDetail.swift
//  modelhub
//

import Foundation

/// Decoded shape for HuggingFace's `/api/models/{repo_id}` endpoint.
///
/// The endpoint returns far more than this — model index, widget data,
/// transformers info, etc. — but for now we only need:
/// - ``usedStorage`` so the Explore row can show the model's on-disk size.
/// - ``sha`` and ``siblings`` for Phase 2 downloads (the cache layout
///   needs the commit hash, and downloads need the file list).
struct HFModelDetail: Decodable {
    /// Commit SHA of the current revision. Becomes the snapshot
    /// directory name in the HuggingFace cache layout.
    let sha: String?

    /// Total bytes the model occupies in HuggingFace's storage.
    /// Maps directly to what the size column should show.
    let usedStorage: Int64?

    /// File listing for the current revision.
    let siblings: [Sibling]?

    /// One file in the model repo.
    struct Sibling: Decodable {
        /// Path of the file relative to the repo root.
        let rfilename: String
    }
}
