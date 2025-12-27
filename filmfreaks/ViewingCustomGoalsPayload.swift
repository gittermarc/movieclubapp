//
//  ViewingCustomGoalsPayload.swift
//  filmfreaks
//
//  Versioniertes Payload für Custom Goals (skalierbar).
//  Step 3+4: ein Array `goals` statt mehrere Arrays pro Typ.
//

import Foundation

struct ViewingCustomGoalsPayload: Codable, Equatable {

    /// Falls wir später Felder umbauen, können wir sauber migrieren.
    /// - 2: legacy (decadeGoals + actorGoals)
    /// - 3: current (goals: [ViewingCustomGoal])
    var version: Int = 3

    var goals: [ViewingCustomGoal] = []

    init(version: Int = 3, goals: [ViewingCustomGoal] = []) {
        self.version = version
        self.goals = goals
    }

    // MARK: - Codable Migration

    private enum CodingKeys: String, CodingKey {
        case version
        case goals

        // legacy v2
        case decadeGoals
        case actorGoals
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let version = (try? c.decode(Int.self, forKey: .version)) ?? 2

        if version >= 3, let goals = try? c.decode([ViewingCustomGoal].self, forKey: .goals) {
            self.version = version
            self.goals = goals
            return
        }

        // v2 legacy: decadeGoals + actorGoals
        let decadeGoals = (try? c.decode([DecadeGoal].self, forKey: .decadeGoals)) ?? []
        let actorGoals = (try? c.decode([ActorGoal].self, forKey: .actorGoals)) ?? []

        var merged: [ViewingCustomGoal] = []
        merged.reserveCapacity(decadeGoals.count + actorGoals.count)

        merged.append(contentsOf: decadeGoals.map { ViewingCustomGoal(from: $0) })
        merged.append(contentsOf: actorGoals.map { ViewingCustomGoal(from: $0) })

        self.version = 3
        self.goals = merged
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(3, forKey: .version)
        try c.encode(goals, forKey: .goals)
    }
}
