//
//  ViewingCustomGoalsPayload.swift
//  filmfreaks
//
//  Step 3: Versioniertes Payload für Custom Goals (skalierbar).
//

import Foundation

/// ✅ Aktuelles Payload (v3): eine Liste von „Custom Goals“ (heterogen via enum-rule).
struct ViewingCustomGoalsPayload: Codable, Equatable {
    var version: Int = 3
    var goals: [ViewingCustomGoal] = []

    init(version: Int = 3, goals: [ViewingCustomGoal] = []) {
        self.version = version
        self.goals = goals
    }
}

/// ⚠️ Legacy Payload (v2) aus Step 2 (Decade + Actor separat).
/// Bleibt nur zum Decoden/Migrieren erhalten.
struct ViewingCustomGoalsPayloadV2: Codable, Equatable {
    var version: Int = 2
    var decadeGoals: [DecadeGoal] = []
    var actorGoals: [ActorGoal] = []

    init(version: Int = 2, decadeGoals: [DecadeGoal] = [], actorGoals: [ActorGoal] = []) {
        self.version = version
        self.decadeGoals = decadeGoals
        self.actorGoals = actorGoals
    }

    func toV3() -> ViewingCustomGoalsPayload {
        var mapped: [ViewingCustomGoal] = []
        mapped.append(contentsOf: decadeGoals.map { ViewingCustomGoal(from: $0) })
        mapped.append(contentsOf: actorGoals.map { ViewingCustomGoal(from: $0) })
        return ViewingCustomGoalsPayload(version: 3, goals: mapped)
    }
}
