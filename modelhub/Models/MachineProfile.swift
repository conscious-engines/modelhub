//
//  MachineProfile.swift
//  modelhub
//

import Darwin
import Foundation

/// Lightweight description of the local Mac used to tailor Explore
/// results toward models that are likely practical on this machine.
struct MachineProfile {
    let chipName: String
    let memoryBytes: UInt64
    let memoryGB: Int
    let isAppleSilicon: Bool
    let approxGpuTFLOPS: Double?

    static let current = detect()

    private static let appleSiliconTFLOPS: [String: Double] = [
        "Apple M1": 2.6,
        "Apple M1 Pro": 5.2,
        "Apple M1 Max": 10.4,
        "Apple M1 Ultra": 21.0,
        "Apple M2": 3.6,
        "Apple M2 Pro": 6.8,
        "Apple M2 Max": 13.49,
        "Apple M2 Ultra": 27.2,
        "Apple M3": 4.1,
        "Apple M3 Pro": 7.4,
        "Apple M3 Max": 14.2,
        "Apple M3 Ultra": 28.4,
        "Apple M4": 4.6,
        "Apple M4 Pro": 9.2,
        "Apple M4 Max": 18.4,
        "Apple M5": 5.7,
        "Apple M5 Pro": 11.4,
        "Apple M5 Max": 22.8,
    ]

    private static func detect() -> MachineProfile {
        let rawChip = sysctlString("machdep.cpu.brand_string")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let chipName = normalizedChipName(from: rawChip) ?? rawChip ?? "Unknown Mac"
        let memoryBytes = ProcessInfo.processInfo.physicalMemory
        let memoryGB = max(1, Int((Double(memoryBytes) / 1_073_741_824).rounded()))
        let isAppleSilicon = chipName.hasPrefix("Apple M")

        return MachineProfile(
            chipName: chipName,
            memoryBytes: memoryBytes,
            memoryGB: memoryGB,
            isAppleSilicon: isAppleSilicon,
            approxGpuTFLOPS: appleSiliconTFLOPS[chipName]
        )
    }

    private static func normalizedChipName(from raw: String?) -> String? {
        guard let raw else { return nil }
        let known = appleSiliconTFLOPS.keys.sorted { $0.count > $1.count }
        return known.first(where: { raw.localizedCaseInsensitiveContains($0) })
    }

    private static func sysctlString(_ name: String) -> String? {
        var size: size_t = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }

        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }
}
