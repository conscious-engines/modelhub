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
    enum Source: String, CaseIterable, Codable {
        /// HuggingFace Hub cache (`~/.cache/huggingface/hub`).
        case huggingFace = "huggingFace"
        /// Ollama's local model cache (`~/.ollama/models`).
        case ollama = "ollama"
        /// LM Studio's local model directory (`~/.lmstudio/models`).
        case lmStudio = "lmStudio"
        /// AnythingLLM model storage
        case anythingLLM = "anythingLLM"
        /// Jan.ai model storage
        case jan = "jan"
        /// GPT4All model storage
        case gpt4All = "gpt4All"

        var displayName: String {
            switch self {
            case .lmStudio: return "LM Studio"
            case .huggingFace: return "Hugging Face"
            case .ollama: return "Ollama"
            case .anythingLLM: return "AnythingLLM"
            case .jan: return "Jan.ai"
            case .gpt4All: return "GPT4All"
            }
        }

        var iconName: String {
            switch self {
            case .lmStudio: return "lmstudio"
            case .huggingFace: return "huggingface"
            case .ollama: return "ollama"
            case .anythingLLM: return "anythingllm"
            case .jan: return "janai"
            case .gpt4All: return "gpt4all"
            }
        }

        var isInstalled: Bool {
            let fm = FileManager.default
            switch self {
            case .huggingFace:
                return fm.fileExists(atPath: "/opt/homebrew/bin/huggingface-cli") ||
                       fm.fileExists(atPath: "/usr/local/bin/huggingface-cli") ||
                       fm.fileExists(atPath: ModelPaths.huggingFaceRoot)
            case .ollama:
                return fm.fileExists(atPath: "/Applications/Ollama.app") ||
                       fm.fileExists(atPath: "\(NSHomeDirectory())/Applications/Ollama.app") ||
                       fm.fileExists(atPath: "/usr/local/bin/ollama") ||
                       fm.fileExists(atPath: "/opt/homebrew/bin/ollama")
            case .lmStudio:
                return fm.fileExists(atPath: "/Applications/LM Studio.app") ||
                       fm.fileExists(atPath: "\(NSHomeDirectory())/Applications/LM Studio.app") ||
                       fm.fileExists(atPath: "/Applications/LMStudio.app") ||
                       fm.fileExists(atPath: "\(NSHomeDirectory())/Applications/LMStudio.app")
            case .anythingLLM:
                return fm.fileExists(atPath: "/Applications/AnythingLLM.app") ||
                       fm.fileExists(atPath: "\(NSHomeDirectory())/Applications/AnythingLLM.app")
            case .jan:
                return fm.fileExists(atPath: "/Applications/Jan.app") ||
                       fm.fileExists(atPath: "\(NSHomeDirectory())/Applications/Jan.app") ||
                       fm.fileExists(atPath: "/Applications/Jan.ai.app") ||
                       fm.fileExists(atPath: "\(NSHomeDirectory())/Applications/Jan.ai.app")
            case .gpt4All:
                return fm.fileExists(atPath: "/Applications/GPT4All.app") ||
                       fm.fileExists(atPath: "\(NSHomeDirectory())/Applications/GPT4All.app")
            }
        }

        var homepageURL: URL {
            switch self {
            case .lmStudio:
                return URL(string: "https://lmstudio.ai")!
            case .huggingFace:
                return URL(string: "https://huggingface.co")!
            case .ollama:
                return URL(string: "https://ollama.com")!
            case .anythingLLM:
                return URL(string: "https://anythingllm.com")!
            case .jan:
                return URL(string: "https://jan.ai")!
            case .gpt4All:
                return URL(string: "https://gpt4all.io")!
            }
        }
    }

    /// Lowercased `publisher/repo` identifier — matches the format that
    /// LM Studio's REST API and the HuggingFace CLI use to refer to a model.
    /// Suitable for placing on the pasteboard.
    var copyableID: String { "\(publisher.lowercased())/\(repo.lowercased())" }

    /// Original-case `publisher/repo` identifier — matches what the
    /// HuggingFace REST API returns and what the on-disk cache uses
    /// (`models--{publisher}--{repo}/`). Used for download routing.
    var canonicalID: String { "\(publisher)/\(repo)" }

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
