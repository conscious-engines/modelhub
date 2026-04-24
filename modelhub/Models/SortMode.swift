//
//  SortMode.swift
//  modelhub
//

import Foundation

/// Per-section sort order applied to ``ModelEntry`` lists.
///
/// A section starts in ``name`` order. Tapping the size button cycles between
/// ``sizeAsc`` and ``sizeDesc``; tapping the date button cycles between
/// ``dateOldest`` and ``dateNewest``. Each tap commits to that family's
/// initial direction (asc) when switching from the other family.
enum SortMode {
    /// Alphabetical via ``ParsedModel/sortKey``. Default state.
    case name

    /// Smallest size first.
    case sizeAsc

    /// Largest size first.
    case sizeDesc

    /// Oldest creation date first.
    case dateOldest

    /// Newest creation date first.
    case dateNewest

    /// Maps the current mode onto the size button's visual state.
    var sizeButtonState: SortIconButton.SortState {
        switch self {
        case .sizeAsc:  return .asc
        case .sizeDesc: return .desc
        default:        return .inactive
        }
    }

    /// Maps the current mode onto the date button's visual state.
    var dateButtonState: DateSortButton.SortState {
        switch self {
        case .dateOldest: return .asc
        case .dateNewest: return .desc
        default:          return .inactive
        }
    }
}
