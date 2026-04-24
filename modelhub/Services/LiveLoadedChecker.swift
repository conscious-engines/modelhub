//
//  LiveLoadedChecker.swift
//  modelhub
//

import Foundation

/// Asks LM Studio's local REST server which models are currently loaded
/// in memory, returning their canonical lowercased identifiers.
///
/// ## Why only LM Studio?
///
/// LM Studio exposes an OpenAI-compatible `GET /v1/models` endpoint on
/// `localhost:1234` (when its "Local Server" is enabled) that lists the
/// currently-resident models. The IDs match Model Hub's
/// ``ParsedModel/copyableID`` format (`publisher/repo`, lowercased), so
/// matching is a clean set membership check.
///
/// HuggingFace-cached models have no equivalent — they're consumed by
/// arbitrary tools (transformers, mlx-lm, llama.cpp, ollama, custom
/// scripts), and there's no daemon to ask. Detecting "loaded" via
/// `lsof`-style mmap inspection works in principle but is too slow to
/// run on every menu open. The trade-off here: no indicator beats a
/// laggy or unreliable one.
///
/// ## Failure mode
///
/// If LM Studio isn't running or its server is disabled, the request
/// fails fast (connection refused on localhost) and the function
/// returns an empty set. The 0.4s timeout is a hard ceiling; in
/// practice loopback requests resolve in under 10ms.
enum LiveLoadedChecker {
    /// Returns the lowercased `publisher/repo` IDs of models currently
    /// loaded by LM Studio. Empty if the server isn't reachable.
    ///
    /// Synchronous on purpose — called from ``MenuController/menuNeedsUpdate(_:)``,
    /// which AppKit invokes just before the menu opens. Blocking briefly is
    /// fine; spawning an async task and missing the menu-open window is not.
    static func loadedCopyableIDs() -> Set<String> {
        guard let url = URL(string: "http://127.0.0.1:1234/v1/models") else { return [] }
        var req = URLRequest(url: url, timeoutInterval: 0.4)
        req.httpMethod = "GET"

        let semaphore = DispatchSemaphore(value: 0)
        var received: Data?
        URLSession.shared.dataTask(with: req) { data, _, _ in
            received = data
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + 0.5)

        guard let data = received,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["data"] as? [[String: Any]]
        else { return [] }

        var ids: Set<String> = []
        for item in items {
            if let id = item["id"] as? String {
                ids.insert(id.lowercased())
            }
        }
        return ids
    }
}
