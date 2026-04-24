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
}
