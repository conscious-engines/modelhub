//
//  ExploreCompatibility.swift
//  modelhub
//

import Foundation

enum ExploreCompatibility: Equatable {
    case compatible
    case maybeSlow
    case unknown
    case incompatibleMemory
    case incompatibleFormat

    var maybeSlowTooltip: String? {
        guard self == .maybeSlow else { return nil }
        return "May be slow on this Mac"
    }
}

enum ExploreFilterMode: String {
    case fitThisMac
    case allModels
}

/// Explore search result plus parsed display metadata so filtering and
/// row rebuilds don't need to re-parse model names every time.
struct ExploreModelCandidate {
    let summary: HFModelSummary
    let parsedModel: ParsedModel

    var id: String { summary.id }
}

enum ExploreCompatibilityEvaluator {
    private static let positiveSignals: [String] = [
        "apple-silicon", "mlx", "mlx-lm", "mlx-node", "gguf", "llama.cpp", "metal"
    ]

    private static let explicitNonAppleSignals: [String] = [
        "transformers", "vllm", "text-generation-inference", "tgi",
        "cuda", "nvidia", "tensorrt", "pytorch", "onnx", "jax", "tf", "tflite"
    ]

    static func evaluate(
        summary: HFModelSummary,
        parsedModel: ParsedModel,
        usedStorage: Int64?,
        machine: MachineProfile
    ) -> ExploreCompatibility {
        guard machine.isAppleSilicon else { return .unknown }

        let signals = normalizedSignals(summary: summary, parsedModel: parsedModel)

        if signals.contains(where: { containsPositiveSignal($0) }) {
            guard let usedStorage else { return .unknown }
            let memory = Double(machine.memoryBytes)
            let used = Double(usedStorage)

            if used <= memory * 0.75 { return .compatible }
            if used <= memory * 0.90 { return .maybeSlow }
            return .incompatibleMemory
        }

        if signals.isEmpty {
            return .unknown
        }

        if signals.contains(where: { containsExplicitNonAppleSignal($0) }) || parsedModel.typeLabel != nil {
            return .incompatibleFormat
        }

        return .unknown
    }

    private static func normalizedSignals(summary: HFModelSummary, parsedModel: ParsedModel) -> [String] {
        let fields = [
            summary.libraryName,
            parsedModel.typeLabel,
            parsedModel.repo,
            summary.id,
        ]

        var signals = fields.compactMap { $0?.lowercased() }
        signals.append(contentsOf: (summary.tags ?? []).map { $0.lowercased() })
        return signals
    }

    private static func containsPositiveSignal(_ value: String) -> Bool {
        positiveSignals.contains { value.contains($0) }
    }

    private static func containsExplicitNonAppleSignal(_ value: String) -> Bool {
        explicitNonAppleSignals.contains { value.contains($0) }
    }
}
