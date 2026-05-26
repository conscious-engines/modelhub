//
//  SourcePreferences.swift
//  modelhub
//

import Foundation

/// User preferences controlling which model sources the Local tab
/// surfaces. HuggingFace is enabled by default; LM Studio is opt-in.
struct SourcePreferences {
    var lmStudioEnabled: Bool
    var huggingFaceEnabled: Bool

    private static let lmStudioKey = "modelhub.sources.lmStudioEnabled"
    private static let huggingFaceKey = "modelhub.sources.huggingFaceEnabled"

    static func load() -> SourcePreferences {
        let defaults = UserDefaults.standard
        let lm = defaults.object(forKey: lmStudioKey) as? Bool ?? false
        let hf = defaults.object(forKey: huggingFaceKey) as? Bool ?? true
        return SourcePreferences(lmStudioEnabled: lm, huggingFaceEnabled: hf)
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(lmStudioEnabled, forKey: Self.lmStudioKey)
        defaults.set(huggingFaceEnabled, forKey: Self.huggingFaceKey)
    }
}
