//
//  DecadeGoal.swift
//  filmfreaks
//
//  Custom Goal (Step 1): Decade Goals
//

import Foundation

struct DecadeGoal: Identifiable, Codable, Hashable, Equatable {
    var id: UUID
    var decadeStart: Int     // z.B. 1950
    var target: Int          // z.B. 10
    var createdAt: Date

    init(id: UUID = UUID(), decadeStart: Int, target: Int, createdAt: Date = Date()) {
        self.id = id
        self.decadeStart = decadeStart
        self.target = target
        self.createdAt = createdAt
    }

    var decadeEnd: Int { decadeStart + 9 }

    var title: String {
        // "Filme aus den 50ern" / "Filme aus den 2000ern"
        let suffix: String
        if decadeStart >= 2000 {
            suffix = "\(decadeStart)ern"
        } else {
            suffix = "\(decadeStart % 100)ern"
        }
        return "Filme aus den \(suffix)"
    }
}
