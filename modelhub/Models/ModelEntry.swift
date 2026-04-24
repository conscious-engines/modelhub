//
//  ModelEntry.swift
//  modelhub
//

import Foundation

/// A ``ParsedModel`` enriched with measurements taken at scan time.
///
/// Caching `bytes`, `dateAdded`, and `loaded` on the entry lets the menu
/// reorder rows for sort changes without re-reading the filesystem or
/// re-pinging LM Studio's local server.
struct ModelEntry {
    /// The parsed model.
    let model: ParsedModel

    /// On-disk size in bytes, computed via ``SizeUtil/directorySize(at:)``.
    let bytes: Int64

    /// Best-effort "date added" for the model directory. Falls back to
    /// ``Date/distantPast`` when neither creation nor modification dates
    /// are available.
    let dateAdded: Date

    /// `true` if LM Studio currently has this model loaded in memory.
    /// Always `false` for HuggingFace-only models — see
    /// ``LiveLoadedChecker`` for details on why.
    let loaded: Bool
}
