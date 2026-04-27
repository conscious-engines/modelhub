//
//  HFModelSummary.swift
//  modelhub
//

import Foundation

/// One entry in a HuggingFace `/api/models` response.
///
/// Only the fields needed to render an Explore row and route a download
/// are decoded. The full HF response carries far more (siblings, config,
/// security info, etc.) — that lives behind ``HuggingFaceAPI``'s detail
/// endpoint and is fetched lazily during download.
///
/// Many fields are optional because HuggingFace omits them for new or
/// unindexed models.
struct HFModelSummary: Decodable {
    /// Repo identifier in `publisher/repo` form, e.g. `"Qwen/Qwen3.5-35B-A3B"`.
    let id: String

    /// All-time download count, when reported.
    let downloads: Int?

    /// Likes count, when reported.
    let likes: Int?

    /// HuggingFace library tag (e.g. `"transformers"`, `"mlx"`).
    let libraryName: String?

    /// Pipeline tag (e.g. `"text-generation"`).
    let pipelineTag: String?

    /// All repo tags.
    let tags: [String]?

    private enum CodingKeys: String, CodingKey {
        case id, downloads, likes, tags
        case libraryName = "library_name"
        case pipelineTag = "pipeline_tag"
    }

    /// Publisher segment of the id (text before the first `/`).
    /// Returns the whole id when there's no slash.
    var publisher: String {
        guard let slash = id.firstIndex(of: "/") else { return "" }
        return String(id[..<slash])
    }

    /// Repo segment of the id (text after the first `/`).
    /// Returns the whole id when there's no slash.
    var repo: String {
        guard let slash = id.firstIndex(of: "/") else { return id }
        return String(id[id.index(after: slash)...])
    }
}
