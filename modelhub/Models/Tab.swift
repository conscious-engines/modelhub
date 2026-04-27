//
//  Tab.swift
//  modelhub
//

import Foundation

/// Top-level mode for what the menu shows.
///
/// Switching between modes preserves the search query but rebuilds the
/// content section (rows, headers, separators) — the search bar and tab
/// switcher themselves stay put so typing focus isn't lost.
enum Tab {
    /// Models discovered on disk in LM Studio + HuggingFace caches.
    case local
    /// Browse + download from HuggingFace.
    case explore
}
