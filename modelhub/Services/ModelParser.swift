//
//  ModelParser.swift
//  modelhub
//

import Foundation

/// Turns raw on-disk repo names into a tidy ``ParsedModel`` for display.
///
/// Real-world repo names are messy — `Qwen3.5-35B-A3B-MLX-4bit`,
/// `gemma-4-E4B-it-MLX-6bit`, `whisper.cpp` — and the goal here is to
/// produce something a human can scan in a menu without parsing
/// hyphens in their head.
///
/// The pipeline:
/// 1. Detect format (`MLX`/`GGUF`) from the publisher + repo name.
/// 2. Tokenize the repo on `-`, peeling format/quant tokens off into
///    side-channels.
/// 3. Fall back to filesystem inspection if the name didn't reveal a format.
/// 4. Split letter-then-digit tokens (`Qwen3.5` → `Qwen` + `3.5`) so the
///    family name and version display as separate words.
/// 5. Title-case each token, with allow-lists for abbreviations that should
///    stay uppercase (`IT`, `VL`, `MoE`, …) and guards that preserve
///    intentional CamelCase (`DFlash`).
enum ModelParser {
    /// Parses a single model directory.
    ///
    /// - Parameters:
    ///   - publisher: Publisher segment as it appears on disk (preserves case).
    ///   - repo: Repo segment as it appears on disk.
    ///   - path: Absolute path to the model directory.
    ///   - source: Which scan produced this entry.
    /// - Returns: A populated ``ParsedModel``.
    static func parse(
        publisher: String,
        repo: String,
        path: String,
        source: ParsedModel.Source
    ) -> ParsedModel {
        var format = detectFormatFromName(publisher: publisher, repo: repo)

        let rawTokens = repo.split(separator: "-", omittingEmptySubsequences: true).map(String.init)

        var keptTokens: [String] = []
        var quant: String?
        for tok in rawTokens {
            let l = tok.lowercased()
            if l == "mlx" { format = format ?? "MLX"; continue }
            if l == "gguf" { format = format ?? "GGUF"; continue }
            if let q = parseQuant(tok) {
                if quant == nil { quant = q }
                continue
            }
            keptTokens.append(tok)
        }

        if format == nil {
            format = detectFormatFromFiles(at: path)
        }

        let expanded = keptTokens.flatMap { splitLetterDigit($0) }
        let prettyTokens = expanded.map { prettyToken($0) }
        let displayName = prettyTokens.joined(separator: " ")

        let familyTag = extractFamilyTag(from: expanded.first ?? repo)

        let typeLabel = composeTypeLabel(format: format, quant: quant)

        return ParsedModel(
            publisher: publisher,
            repo: repo,
            familyTag: familyTag,
            displayName: displayName,
            typeLabel: typeLabel,
            fullPath: path,
            source: source
        )
    }

    // MARK: - Family

    /// Pulls the leading run of letters off a token (after stripping a
    /// trailing `.cpp` suffix). Returns `"model"` as a fallback so menu
    /// rows always have a tag to render.
    private static func extractFamilyTag(from token: String) -> String {
        var t = token
        if t.lowercased().hasSuffix(".cpp") { t = String(t.dropLast(4)) }

        var letters = ""
        for ch in t {
            if ch.isLetter { letters.append(ch) } else { break }
        }
        let tag = letters.lowercased()
        return tag.isEmpty ? "model" : tag
    }

    // MARK: - Format

    private static func detectFormatFromName(publisher: String, repo: String) -> String? {
        let combined = (publisher + " " + repo).lowercased()
        if combined.contains("gguf") { return "GGUF" }
        if combined.contains("mlx")  { return "MLX" }
        return nil
    }

    /// Falls back to scanning the model directory when the name doesn't
    /// reveal the format. Capped at 400 entries so very large HF repos
    /// don't stall the menu rebuild.
    private static func detectFormatFromFiles(at path: String) -> String? {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return nil }

        var sawSafetensors = false
        var count = 0
        for case let url as URL in enumerator {
            count += 1
            if count > 400 { break }
            let ext = url.pathExtension.lowercased()
            if ext == "gguf" { return "GGUF" }
            if ext == "safetensors" { sawSafetensors = true }
        }
        return sawSafetensors ? "safetensors" : nil
    }

    // MARK: - Tokens

    /// Splits letter-prefix-then-digit tokens like `Qwen3.5` into
    /// `["Qwen", "3.5"]`. Preserves "tight" tags like `A3B`/`E4B`/`35B` by
    /// only splitting when the leading letter run is at least 3 characters.
    private static func splitLetterDigit(_ tok: String) -> [String] {
        guard let first = tok.first, first.isLetter else { return [tok] }

        var firstDigit: String.Index?
        for idx in tok.indices where tok[idx].isNumber {
            firstDigit = idx
            break
        }
        guard let si = firstDigit else { return [tok] }

        let prefix = String(tok[..<si])
        let suffix = String(tok[si...])
        guard prefix.count >= 3 else { return [tok] }
        return [prefix, suffix]
    }

    /// Recognises common quantization markers and returns a normalized,
    /// display-ready version. Returns `nil` if the token isn't a quant.
    private static func parseQuant(_ tok: String) -> String? {
        let l = tok.lowercased()
        if l.range(of: #"^\d{1,2}bit$"#, options: .regularExpression) != nil { return l }
        if l.range(of: #"^q\d+(_[a-z0-9]+)*$"#, options: .regularExpression) != nil { return tok.uppercased() }
        if ["bf16", "fp16", "f16", "f32", "b16"].contains(l) { return l.uppercased() }
        if l.range(of: #"^int\d+$"#, options: .regularExpression) != nil { return l.uppercased() }
        return nil
    }

    /// Title-cases a token, with carve-outs for abbreviations that should
    /// stay uppercase, numeric/alphanumeric tags that read better in caps,
    /// and tokens with intentional inner uppercase that should be preserved.
    private static func prettyToken(_ tok: String) -> String {
        let lower = tok.lowercased()

        let upperCaseAbbrevs: Set<String> = [
            "it", "vl", "moe", "sft", "dpo", "rm", "rlhf", "ft", "gguf", "mlx", "vlm"
        ]
        if upperCaseAbbrevs.contains(lower) { return lower.uppercased() }

        // Pure numbers / decimals: leave as-is.
        if tok.range(of: #"^[0-9]+(\.[0-9]+)?$"#, options: .regularExpression) != nil { return tok }

        // "35B", "30B", "4B" — uppercase.
        if tok.range(of: #"^[0-9]+[a-zA-Z]+$"#, options: .regularExpression) != nil {
            return tok.uppercased()
        }
        // "A3B", "E4B" — uppercase.
        if tok.range(of: #"^[a-zA-Z]\d+[a-zA-Z]+$"#, options: .regularExpression) != nil {
            return tok.uppercased()
        }

        var t = tok
        if t.lowercased().hasSuffix(".cpp") { t = String(t.dropLast(4)) }

        // Preserve intentional inner-capital casing (e.g. "DFlash", "MoE").
        if t.count > 1, t.dropFirst().contains(where: { $0.isUppercase }) {
            return t
        }

        guard let firstCh = t.first else { return "" }
        return String(firstCh).uppercased() + t.dropFirst().lowercased()
    }

    /// Builds the trailing `"FORMAT QUANT"` / `"FORMAT"` / `"QUANT"` label,
    /// or `nil` when neither is known.
    private static func composeTypeLabel(format: String?, quant: String?) -> String? {
        switch (format, quant) {
        case let (f?, q?): return "\(f) \(q)"
        case let (f?, nil): return f
        case let (nil, q?): return q
        default: return nil
        }
    }
}
