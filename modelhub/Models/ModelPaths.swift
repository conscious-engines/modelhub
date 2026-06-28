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

    /// Ollama local models root directory.
    static let ollamaRoot = (NSHomeDirectory() as NSString)
        .appendingPathComponent(".ollama/models")

    /// AnythingLLM local model storage directory.
    static let anythingLLMRoot = (NSHomeDirectory() as NSString)
        .appendingPathComponent("Library/Application Support/anythingllm-desktop/storage/models")

    /// Jan.ai local model storage directory.
    static let janRoot = (NSHomeDirectory() as NSString)
        .appendingPathComponent("jan/models")

    /// GPT4All local model storage directory.
    static let gpt4AllRoot = (NSHomeDirectory() as NSString)
        .appendingPathComponent("Library/Application Support/nomic.ai/GPT4All")

    /// Returns the root path for a given model source.
    static func rootPath(for source: ParsedModel.Source) -> String {
        switch source {
        case .lmStudio: return lmStudioRoot
        case .huggingFace: return huggingFaceRoot
        case .ollama: return ollamaRoot
        case .anythingLLM: return anythingLLMRoot
        case .jan: return janRoot
        case .gpt4All: return gpt4AllRoot
        }
    }
}
