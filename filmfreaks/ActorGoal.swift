//
//  ActorGoal.swift
//  filmfreaks
//
//  Custom Goal (Step 2): Actor/Person Goals
//

import Foundation

struct ActorGoal: Identifiable, Codable, Hashable, Equatable {
    var id: UUID

    /// TMDb Person ID
    var personId: Int

    /// Display name (stabil, auch wenn TMDb später “umbenennt”)
    var personName: String

    /// Optional: Profile image path (TMDb)
    var profilePath: String?

    /// Ziel-Anzahl
    var target: Int

    var createdAt: Date

    init(
        id: UUID = UUID(),
        personId: Int,
        personName: String,
        profilePath: String? = nil,
        target: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.personId = personId
        self.personName = personName
        self.profilePath = profilePath
        self.target = target
        self.createdAt = createdAt
    }

    var title: String {
        "Filme mit \(personName)"
    }
}
