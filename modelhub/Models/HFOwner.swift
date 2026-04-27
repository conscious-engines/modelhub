//
//  HFOwner.swift
//  modelhub
//

import Foundation

/// Decoded shape for HuggingFace's `/api/users/{name}/overview` and
/// `/api/organizations/{name}/overview` endpoints.
///
/// Both endpoints return the same two fields we care about — `avatarUrl`
/// and `fullname` — so a single `Decodable` works for either case.
/// ``HuggingFaceAPI`` tries the organization endpoint first and falls
/// back to the user endpoint if it 404s.
struct HFOwner: Decodable {
    /// Absolute URL to the owner's avatar image. `nil` for owners who
    /// haven't uploaded one (HF doesn't always supply a fallback).
    let avatarUrl: String?

    /// Human-readable display name (e.g. `"Andrej K"`). Used as the
    /// avatar's hover tooltip in lieu of the slug.
    let fullname: String?
}
