//
//  ModelScanner.swift
//  modelhub
//

import Foundation

/// Discovers locally-available models by walking the LM Studio and
/// HuggingFace cache directories.
///
/// Scans are intentionally synchronous and cheap — they enumerate two
/// shallow directories (publisher/repo or `models--…` slugs) without
/// recursing into the model contents. Heavy work (size + date + LM Studio
/// liveness) happens in ``MenuController`` via ``SizeUtil`` and
/// ``LiveLoadedChecker``.
///
/// Both functions return entries sorted by ``ParsedModel/sortKey`` so
/// callers get a deterministic baseline ordering regardless of how the OS
/// returns directory contents.
enum ModelScanner {
    /// Walks `~/.lmstudio/models/<publisher>/<repo>/` and returns every
    /// model directory found.
    ///
    /// - Returns: Models in name-sorted order. Empty if the LM Studio root
    ///   doesn't exist or is unreadable.
    static func scanLMStudio() -> [ParsedModel] {
        let root = ModelPaths.lmStudioRoot
        let fm = FileManager.default
        guard let publishers = try? fm.contentsOfDirectory(atPath: root) else { return [] }

        var out: [ParsedModel] = []
        for pub in publishers where !pub.hasPrefix(".") {
            let pubPath = (root as NSString).appendingPathComponent(pub)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: pubPath, isDirectory: &isDir), isDir.boolValue else { continue }
            guard let repos = try? fm.contentsOfDirectory(atPath: pubPath) else { continue }

            for repo in repos where !repo.hasPrefix(".") {
                let repoPath = (pubPath as NSString).appendingPathComponent(repo)
                var rd: ObjCBool = false
                guard fm.fileExists(atPath: repoPath, isDirectory: &rd), rd.boolValue else { continue }
                out.append(ModelParser.parse(publisher: pub, repo: repo, path: repoPath, source: .lmStudio))
            }
        }
        return out.sorted { $0.sortKey < $1.sortKey }
    }

    /// Walks `~/.cache/huggingface/hub/` and returns every `models--…`
    /// directory parsed back into publisher/repo form.
    ///
    /// HuggingFace stores repos with `--` as a separator (e.g.
    /// `models--Qwen--Qwen3.5-35B-A3B`). The first segment is fixed
    /// (`models`), the second is the publisher, and any remaining segments
    /// rejoin to form the repo name.
    ///
    /// - Returns: Models in name-sorted order. Empty if the cache root
    ///   doesn't exist or is unreadable.
    static func scanHuggingFace() -> [ParsedModel] {
        let root = ModelPaths.huggingFaceRoot
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: root) else { return [] }

        var out: [ParsedModel] = []
        for entry in entries where entry.hasPrefix("models--") {
            let repoPath = (root as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: repoPath, isDirectory: &isDir), isDir.boolValue else { continue }

            let parts = entry.components(separatedBy: "--")
            guard parts.count >= 3 else { continue }
            let publisher = parts[1]
            let repo = parts[2...].joined(separator: "--")
            out.append(ModelParser.parse(publisher: publisher, repo: repo, path: repoPath, source: .huggingFace))
        }
        return out.sorted { $0.sortKey < $1.sortKey }
    }
    
    /// Walks the Ollama manifests directory to discover local models.
    ///
    /// Ollama models are configured as layers in JSON manifests. The path structure walks
    /// `~/.ollama/models/manifests/registry.ollama.ai/library/<model>/<tag>`.
    /// Each tag configuration file is parsed into a single model entry.
    ///
    /// - Returns: Model entries in name-sorted order. Empty if Ollama directories are missing or unreadable.
    static func scanOllama() -> [ParsedModel] {
        let root = ModelPaths.ollamaRoot
        let manifestsRoot = (root as NSString)
            .appendingPathComponent("manifests/registry.ollama.ai/library")
        let fm = FileManager.default
        guard let models = try? fm.contentsOfDirectory(atPath: manifestsRoot) else { return [] }

        var out: [ParsedModel] = []
        for modelDir in models where !modelDir.hasPrefix(".") {
            let modelPath = (manifestsRoot as NSString).appendingPathComponent(modelDir)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: modelPath, isDirectory: &isDir), isDir.boolValue else { continue }
            guard let tags = try? fm.contentsOfDirectory(atPath: modelPath) else { continue }

            for tag in tags where !tag.hasPrefix(".") {
                let tagPath = (modelPath as NSString).appendingPathComponent(tag)
                out.append(ModelParser.parse(
                    publisher: "ollama",
                    repo: "\(modelDir):\(tag)",
                    path: tagPath,
                    source: .ollama
                ))
            }
        }
        return out.sorted { $0.sortKey < $1.sortKey }
    }

    /// Scans AnythingLLM's local storage directory for GGUF model files.
    ///
    /// AnythingLLM stores downloaded files directly under the path
    /// `~/Library/Application Support/anythingllm-desktop/storage/models/`.
    /// It filters for files with `.gguf` extension, omitting hidden files.
    ///
    /// - Returns: Model entries in name-sorted order. Empty if the folder is missing or empty.
    static func scanAnythingLLM() -> [ParsedModel] {
        let root = ModelPaths.anythingLLMRoot
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: root) else { return [] }

        var out: [ParsedModel] = []
        for entry in entries where !entry.hasPrefix(".") && entry.lowercased().hasSuffix(".gguf") {
            let filePath = (root as NSString).appendingPathComponent(entry)
            out.append(ModelParser.parse(
                publisher: "anythingllm",
                repo: entry,
                path: filePath,
                source: .anythingLLM
            ))
        }
        return out.sorted { $0.sortKey < $1.sortKey }
    }

    /// Scans the Jan.ai models directory to discover local models.
    ///
    /// Jan downloads and extracts models into individual subfolders under `~/jan/models/`.
    /// This walks the first level of subfolders (excluding hidden ones) and registers
    /// each subdirectory as a distinct model configuration.
    ///
    /// - Returns: Model entries in name-sorted order. Empty if the directory is missing.
    static func scanJan() -> [ParsedModel] {
        let root = ModelPaths.janRoot
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: root) else { return [] }

        var out: [ParsedModel] = []
        for entry in entries where !entry.hasPrefix(".") {
            let dirPath = (root as NSString).appendingPathComponent(entry)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: dirPath, isDirectory: &isDir), isDir.boolValue else { continue }
            out.append(ModelParser.parse(
                publisher: "jan",
                repo: entry,
                path: dirPath,
                source: .jan
            ))
        }
        return out.sorted { $0.sortKey < $1.sortKey }
    }

    /// Scans GPT4All's local storage directory for GGUF model files.
    ///
    /// GPT4All stores model binaries directly under the path
    /// `~/Library/Application Support/nomic.ai/GPT4All/`.
    /// The scanner filters for regular files carrying the `.gguf` extension.
    ///
    /// - Returns: Model entries in name-sorted order. Empty if the directory is unreadable.
    static func scanGPT4All() -> [ParsedModel] {
        let root = ModelPaths.gpt4AllRoot
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: root) else { return [] }

        var out: [ParsedModel] = []
        for entry in entries where !entry.hasPrefix(".") && entry.lowercased().hasSuffix(".gguf") {
            let filePath = (root as NSString).appendingPathComponent(entry)
            out.append(ModelParser.parse(
                publisher: "gpt4all",
                repo: entry,
                path: filePath,
                source: .gpt4All
            ))
        }
        return out.sorted { $0.sortKey < $1.sortKey }
    }

    /// Dispatches the scan command to the appropriate helper based on the source enum.
    ///
    /// - Parameter source: The ``ParsedModel/Source`` directory configuration to scan.
    /// - Returns: An array of ``ParsedModel`` entries in name-sorted order.
    static func scan(source: ParsedModel.Source) -> [ParsedModel] {
        switch source {
        case .lmStudio: return scanLMStudio()
        case .huggingFace: return scanHuggingFace()
        case .ollama: return scanOllama()
        case .anythingLLM: return scanAnythingLLM()
        case .jan: return scanJan()
        case .gpt4All: return scanGPT4All()
        }
    }
}
