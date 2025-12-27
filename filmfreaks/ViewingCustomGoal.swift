//
//  ViewingCustomGoal.swift
//  filmfreaks
//
//  Step 3: Goal Types als enum + generisches Goal-Model
//

import Foundation

enum ViewingCustomGoalType: String, Codable, CaseIterable, Hashable {
    case decade
    case person

    var displayName: String {
        switch self {
        case .decade: return "Decade-Ziel"
        case .person: return "Darsteller-Ziel"
        }
    }

    var systemImage: String {
        switch self {
        case .decade: return "calendar"
        case .person: return "person.fill"
        }
    }
}

/// Regel/„Matcher“ für Custom Goals.
/// Für Step 3 halten wir’s bewusst eng, aber skalierbar (Director/Genre/Keyword sind später nur neue cases).
enum ViewingCustomGoalRule: Hashable {
    case releaseDecade(Int) // decadeStart
    case person(id: Int, name: String, profilePath: String?)
}

extension ViewingCustomGoalRule: Codable {

    private enum CodingKeys: String, CodingKey {
        case kind
        case decadeStart
        case personId
        case personName
        case profilePath
    }

    private enum Kind: String, Codable {
        case releaseDecade
        case person
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)

        switch kind {
        case .releaseDecade:
            let d = try c.decode(Int.self, forKey: .decadeStart)
            self = .releaseDecade(d)
        case .person:
            let id = try c.decode(Int.self, forKey: .personId)
            let name = try c.decode(String.self, forKey: .personName)
            let profilePath = try c.decodeIfPresent(String.self, forKey: .profilePath)
            self = .person(id: id, name: name, profilePath: profilePath)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .releaseDecade(let decadeStart):
            try c.encode(Kind.releaseDecade, forKey: .kind)
            try c.encode(decadeStart, forKey: .decadeStart)

        case .person(let id, let name, let profilePath):
            try c.encode(Kind.person, forKey: .kind)
            try c.encode(id, forKey: .personId)
            try c.encode(name, forKey: .personName)
            try c.encodeIfPresent(profilePath, forKey: .profilePath)
        }
    }
}

struct ViewingCustomGoal: Identifiable, Codable, Hashable, Equatable {

    var id: UUID
    var type: ViewingCustomGoalType
    var rule: ViewingCustomGoalRule
    var target: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        type: ViewingCustomGoalType,
        rule: ViewingCustomGoalRule,
        target: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.rule = rule
        self.target = target
        self.createdAt = createdAt
    }

    /// Dedupe-Key pro „Semantik“ (damit nicht 2× dieselbe Decade / derselbe Actor existiert).
    /// Wenn wir später komplexere Regeln haben, erweitern wir das hier.
    var uniqueKey: String? {
        switch rule {
        case .releaseDecade(let decadeStart):
            return "decade:\(decadeStart)"
        case .person(let id, _, _):
            // Achtung: 0 = nicht gewählt → nicht dedupen, Editor lässt Speichern sowieso nicht zu
            return id > 0 ? "person:\(id)" : nil
        }
    }

    var title: String {
        switch rule {
        case .releaseDecade(let decadeStart):
            let suffix: String
            if decadeStart >= 2000 {
                suffix = "\(decadeStart)ern"
            } else {
                suffix = "\(decadeStart % 100)ern"
            }
            return "Filme aus den \(suffix)"
        case .person(_, let name, _):
            return "Filme mit \(name)"
        }
    }

    // Convenience Accessors (für UI)
    var decadeStart: Int? {
        if case .releaseDecade(let d) = rule { return d }
        return nil
    }

    var personId: Int? {
        if case .person(let id, _, _) = rule { return id }
        return nil
    }

    var personName: String? {
        if case .person(_, let name, _) = rule { return name }
        return nil
    }

    var profilePath: String? {
        if case .person(_, _, let p) = rule { return p }
        return nil
    }
}

// MARK: - Migration Helpers (v2 → v3)

extension ViewingCustomGoal {

    init(from decadeGoal: DecadeGoal) {
        self.init(
            id: decadeGoal.id,
            type: .decade,
            rule: .releaseDecade(decadeGoal.decadeStart),
            target: decadeGoal.target,
            createdAt: decadeGoal.createdAt
        )
    }

    init(from actorGoal: ActorGoal) {
        self.init(
            id: actorGoal.id,
            type: .person,
            rule: .person(id: actorGoal.personId, name: actorGoal.personName, profilePath: actorGoal.profilePath),
            target: actorGoal.target,
            createdAt: actorGoal.createdAt
        )
    }

    func toDecadeGoal() -> DecadeGoal? {
        guard case .releaseDecade(let d) = rule else { return nil }
        return DecadeGoal(id: id, decadeStart: d, target: target, createdAt: createdAt)
    }

    func toActorGoal() -> ActorGoal? {
        guard case .person(let pid, let name, let profilePath) = rule else { return nil }
        return ActorGoal(id: id, personId: pid, personName: name, profilePath: profilePath, target: target, createdAt: createdAt)
    }
}
