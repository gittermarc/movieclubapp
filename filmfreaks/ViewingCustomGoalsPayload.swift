//
//  ViewingCustomGoalsPayload.swift
//  filmfreaks
//
//  Versioniertes Payload für Custom Goals (skalierbar).
//

import Foundation

struct ViewingCustomGoalsPayload: Codable, Equatable {
    /// Falls wir später Felder umbauen, können wir sauber migrieren.
    var version: Int = 2

    var decadeGoals: [DecadeGoal] = []
    var actorGoals: [ActorGoal] = []

    init(version: Int = 2, decadeGoals: [DecadeGoal] = [], actorGoals: [ActorGoal] = []) {
        self.version = version
        self.decadeGoals = decadeGoals
        self.actorGoals = actorGoals
    }
}
