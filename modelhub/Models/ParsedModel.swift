//
//  ParsedModel.swift
//  modelhub
//

import Foundation

/// A locally-stored language model, parsed into something nice to display.
///
/// `ParsedModel` is the immutable result of running a raw on-disk repository
/// (e.g. `Qwen/Qwen3.5-35B-A3B-MLX-4bit`) through ``ModelParser``. It carries
/// both the original `publisher`/`repo` strings (for reconstructing canonical
/// IDs) and pre-prettified fields used by the menu rows.
///
/// ## Discussion
///
/// The struct intentionally holds **derived display fields** alongside the
/// raw inputs. This avoids re-running the parser every time a row is built,
/// which matters because ``MenuController`` rebuilds rows on every menu open
/// and on every sort toggle.
///
/// - Note: Equality and hashability are intentionally **not** synthesized;
///   identity isn't meaningful for this type — `fullPath` is effectively the
///   primary key, but no consumer needs that today.
struct ParsedModel {
    /// Original publisher segment as it appears on disk.
    /// Examples: `"Qwen"`, `"mlx-community"`, `"lmstudio-community"`.
    let publisher: String

    /// Original repo segment as it appears on disk.
    /// Example: `"Qwen3.5-35B-A3B-MLX-4bit"`.
    let repo: String

    /// Short lowercased family identifier extracted from the repo name.
    /// Examples: `"qwen"`, `"llama"`, `"gemma"`.
    let familyTag: String

    /// Human-friendly model name suitable for the menu row.
    /// Example: `"Qwen 3.5 35B A3B"`.
    let displayName: String

    /// Optional format + quantization label.
    /// Examples: `"MLX 4bit"`, `"GGUF Q6_K"`, `"safetensors"`.
    let typeLabel: String?

    /// Absolute path to the on-disk model directory.
    let fullPath: String

    /// Where the model was discovered.
    let source: Source

    /// Disk source the model was discovered in.
    enum Source {
        /// LM Studio's local model directory (`~/.lmstudio/models`).
        case lmStudio
        /// HuggingFace Hub cache (`~/.cache/huggingface/hub`).
        case huggingFace
    }

    /// Lowercased `publisher/repo` identifier — matches the format that
    /// LM Studio's REST API and the HuggingFace CLI use to refer to a model.
    /// Suitable for placing on the pasteboard.
    var copyableID: String { "\(publisher.lowercased())/\(repo.lowercased())" }

    /// Stable key for alphabetical ordering. Family-first so models from the
    /// same family cluster together regardless of version-string ordering.
    var sortKey: String { "\(familyTag) \(displayName.lowercased())" }

    /// Returns `true` if the given lowercased token matches anywhere in the
    /// model's text fields. Empty queries match everything.
    ///
    /// - Parameter query: A single search token. Callers split user input on
    ///   whitespace and AND the results together.
    func matches(_ query: String) -> Bool {
        let q = query.lowercased()
        if q.isEmpty { return true }
        if publisher.lowercased().contains(q) { return true }
        if repo.lowercased().contains(q) { return true }
        if displayName.lowercased().contains(q) { return true }
        if familyTag.contains(q) { return true }
        if (typeLabel ?? "").lowercased().contains(q) { return true }
        if copyableID.contains(q) { return true }
        return false
    }
}
