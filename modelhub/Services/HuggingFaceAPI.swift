//
//  HuggingFaceAPI.swift
//  modelhub
//

import AppKit
import Foundation

/// Async client for HuggingFace's public REST API.
///
/// All endpoints used here are unauthenticated and work for public
/// models / users / organizations. Gated repos (Llama family, etc.)
/// require a bearer token — that's a future addition, planned to live
/// behind a Keychain-backed settings surface.
///
/// ## Endpoints used
///
/// - `GET /api/models?search=…&pipeline_tag=text-generation` — search.
/// - `GET /api/models/{repo_id}` — per-model details, including
///   `usedStorage` (bytes) and `sha` + `siblings` for downloads.
/// - `GET /api/organizations/{name}/overview` and
///   `/api/users/{name}/overview` — author avatar + full name.
/// - Any URL — generic image fetch for avatars.
enum HuggingFaceAPI {
    private static let base = URL(string: "https://huggingface.co/api")!

    /// Errors thrown by the API client.
    enum APIError: Error, LocalizedError {
        /// Response wasn't an HTTP response or had a malformed body.
        case badResponse
        /// HTTP error code (4xx / 5xx).
        case http(Int)
        /// JSON decoding failure.
        case decoding(Error)
        /// Underlying transport / connectivity failure.
        case network(Error)

        var errorDescription: String? {
            switch self {
            case .badResponse:    return "Couldn't reach HuggingFace."
            case .http(let code): return "HuggingFace returned HTTP \(code)."
            case .decoding:       return "Couldn't read HuggingFace's response."
            case .network:        return "Couldn't reach HuggingFace."
            }
        }
    }

    // MARK: - Search

    /// Search public text-generation models.
    ///
    /// - Parameters:
    ///   - query: Optional search string. `nil` or empty returns the
    ///     top-by-downloads list (good as a default Explore landing page).
    ///   - limit: Max results to return. HuggingFace caps at 100.
    /// - Returns: Decoded model summaries. Empty array on no matches.
    /// - Throws: ``APIError`` for transport, HTTP, or decoding failures.
    static func searchModels(query: String?, limit: Int = 30) async throws -> [HFModelSummary] {
        var components = URLComponents(
            url: base.appendingPathComponent("models"),
            resolvingAgainstBaseURL: false
        )!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "pipeline_tag", value: "text-generation"),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let q = query?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty {
            items.append(URLQueryItem(name: "search", value: q))
        } else {
            items.append(URLQueryItem(name: "sort", value: "downloads"))
            items.append(URLQueryItem(name: "direction", value: "-1"))
        }
        components.queryItems = items
        guard let url = components.url else { throw APIError.badResponse }

        let data = try await getJSON(url, timeout: 8)
        do {
            return try JSONDecoder().decode([HFModelSummary].self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    // MARK: - Model details (size, files, sha)

    /// Fetch the per-model details endpoint.
    ///
    /// - Parameter repoID: Full `publisher/repo` identifier.
    /// - Returns: Detail payload — currently used for `usedStorage`.
    static func modelDetail(repoID: String) async throws -> HFModelDetail {
        // `appendingPathComponent("a/b")` keeps embedded slashes as path
        // separators rather than encoding them, which is exactly what HF
        // wants here.
        let url = base
            .appendingPathComponent("models")
            .appendingPathComponent(repoID)
        let data = try await getJSON(url, timeout: 8)
        do {
            return try JSONDecoder().decode(HFModelDetail.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    // MARK: - Owner (org or user) avatar + name

    /// Fetch a publisher's overview, trying the organization endpoint
    /// first and falling back to the user endpoint on 404.
    ///
    /// HuggingFace publishers can be either type and the slug doesn't
    /// disambiguate, so we just try in the order most repos use.
    static func fetchOwner(name: String) async throws -> HFOwner {
        let orgURL = base
            .appendingPathComponent("organizations")
            .appendingPathComponent(name)
            .appendingPathComponent("overview")
        if let owner = try? await fetchOwnerOverview(url: orgURL) { return owner }

        let userURL = base
            .appendingPathComponent("users")
            .appendingPathComponent(name)
            .appendingPathComponent("overview")
        return try await fetchOwnerOverview(url: userURL)
    }

    private static func fetchOwnerOverview(url: URL) async throws -> HFOwner {
        let data = try await getJSON(url, timeout: 6)
        do {
            return try JSONDecoder().decode(HFOwner.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    // MARK: - File download URL

    /// Build the URL to fetch a single file from a model at a given
    /// revision: `https://huggingface.co/{repoID}/resolve/{revision}/{filename}`.
    ///
    /// HuggingFace serves these directly for non-LFS files and 302s to
    /// the LFS storage backend (S3) for large weights. ``DownloadManager``
    /// handles both flows; the only thing it needs from us is the URL.
    static func resolveURL(repoID: String, revision: String, filename: String) -> URL? {
        let base = URL(string: "https://huggingface.co")!
        return base
            .appendingPathComponent(repoID)
            .appendingPathComponent("resolve")
            .appendingPathComponent(revision)
            .appendingPathComponent(filename)
    }

    // MARK: - Image fetch

    /// Best-effort image download. Returns `nil` on any failure — avatar
    /// loading is non-critical and never surfaces an error to the user.
    static func fetchImage(url: URL) async -> NSImage? {
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("image/*", forHTTPHeaderField: "Accept")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            return NSImage(data: data)
        } catch {
            return nil
        }
    }

    // MARK: - Internals

    /// Performs a `GET` returning raw `Data`, mapping transport / HTTP
    /// errors into ``APIError``.
    private static func getJSON(_ url: URL, timeout: TimeInterval) async throws -> Data {
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw APIError.badResponse }
            guard (200..<300).contains(http.statusCode) else { throw APIError.http(http.statusCode) }
            return data
        } catch let e as APIError {
            throw e
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw APIError.network(error)
        }
    }
}
