//
//  SourcePreferences.swift
//  modelhub
//

import Foundation

/// User preferences controlling which model sources the Local tab
/// surfaces. HuggingFace is enabled by default; LM Studio is opt-in.
struct SourcePreferences {
    private var enabledStates: [ParsedModel.Source: Bool]

    var lmStudioEnabled: Bool {
        get { isEnabled(.lmStudio) }
        set { setEnabled(.lmStudio, enabled: newValue) }
    }

    var huggingFaceEnabled: Bool {
        get { isEnabled(.huggingFace) }
        set { setEnabled(.huggingFace, enabled: newValue) }
    }

    static func load() -> SourcePreferences {
        let defaults = UserDefaults.standard
        var states: [ParsedModel.Source: Bool] = [:]
        for source in ParsedModel.Source.allCases {
            let key = "modelhub.sources.\(source.rawValue)Enabled"
            // Defaults: huggingFace is true by default, others false
            let defaultValue = (source == .huggingFace)
            states[source] = defaults.object(forKey: key) as? Bool ?? defaultValue
        }
        return SourcePreferences(enabledStates: states)
    }

    func isEnabled(_ source: ParsedModel.Source) -> Bool {
        return enabledStates[source] ?? false
    }

    mutating func setEnabled(_ source: ParsedModel.Source, enabled: Bool) {
        enabledStates[source] = enabled
        let defaults = UserDefaults.standard
        defaults.set(enabled, forKey: "modelhub.sources.\(source.rawValue)Enabled")
    }

    func save() {
        let defaults = UserDefaults.standard
        for source in ParsedModel.Source.allCases {
            let key = "modelhub.sources.\(source.rawValue)Enabled"
            defaults.set(isEnabled(source), forKey: key)
        }
    }
}
