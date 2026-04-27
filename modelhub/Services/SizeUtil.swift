//
//  SizeUtil.swift
//  modelhub
//

import Foundation

/// Filesystem helpers for sizing and dating model directories, plus a
/// shared `ByteCountFormatter` for display.
///
/// Kept as a stateless namespace rather than an instance type — callers
/// don't need lifecycle, and the shared formatter is safe to reuse.
enum SizeUtil {
    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        // Without .useTB, multi-terabyte models render as e.g. "1,506.6 GB"
        // which doesn't fit a sensible size column.
        f.allowedUnits = [.useTB, .useGB, .useMB, .useKB, .useBytes]
        f.countStyle = .file
        f.isAdaptive = true
        return f
    }()

    /// Formats a byte count for display.
    /// - Returns: A localized string like `"4.28 GB"`. Returns `"—"` for
    ///   non-positive byte counts.
    static func format(_ bytes: Int64) -> String {
        if bytes <= 0 { return "—" }
        return formatter.string(fromByteCount: bytes)
    }

    /// Best-effort "date added" for a directory.
    ///
    /// Reads the URL's creation date first, falling back to its content
    /// modification date, finally defaulting to ``Date/distantPast`` so
    /// callers can sort safely without optionals.
    static func dateAdded(at path: String) -> Date {
        let url = URL(fileURLWithPath: path)
        if let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey]) {
            if let d = values.creationDate { return d }
            if let d = values.contentModificationDate { return d }
        }
        return .distantPast
    }

    /// Recursive on-disk size in bytes.
    ///
    /// Skips symlinks so HuggingFace's `snapshots/<rev>/` symlinks back
    /// into `blobs/` don't double-count the same data. Returns `0` for
    /// unreadable paths.
    static func directorySize(at path: String) -> Int64 {
        let url = URL(fileURLWithPath: path)
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(
                forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey]
            )
            if values?.isSymbolicLink == true { continue }
            if values?.isRegularFile == true, let size = values?.fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}
