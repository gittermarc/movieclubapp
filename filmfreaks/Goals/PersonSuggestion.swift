//
//  PersonSuggestion.swift
//  filmfreaks
//
//  Shared UI helper used by GoalsView + CustomGoalEditorView.
//

import Foundation

/// Vorschläge aus den vorhandenen Filmen (offline), damit man ein Ziel schnell klicken kann.
struct PersonSuggestion: Identifiable, Hashable {
    let personId: Int
    let name: String
    let count: Int
    let profilePath: String?

    var id: Int { personId }
}
