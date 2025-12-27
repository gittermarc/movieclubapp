//
//  ViewingCustomGoal.swift
//  filmfreaks
//
//  Step 3+4: Goal Types als enum + generisches Goal-Model (Decade, Actor, Director, Genre, Keyword)
//

import Foundation

enum ViewingCustomGoalType: String, Codable, CaseIterable, Hashable {
    case decade
    case person        // Actor / cast
    case director
    case genre
    case keyword

    var displayName: String {
        switch self {
        case .decade: return "Decade-Ziel"
        case .person: return "Darsteller-Ziel"
        case .director: return "Regie-Ziel"
        case .genre: return "Genre-Ziel"
        case .keyword: return "Keyword-Ziel"
        }
    }

    var systemImage: String {
        switch self {
        case .decade: return "calendar"
        case .person: return "person.fill"
        case .director: return "megaphone.fill"
        case .genre: return "square.grid.2x2.fill"
        case .keyword: return "tag.fill"
        }
    }
}

/// Regel/„Matcher“ für Custom Goals.
/// Für Step 4 kommen Director/Genre/Keyword als neue cases hinzu.
enum ViewingCustomGoalRule: Hashable {
    case releaseDecade(Int) // decadeStart
    case person(id: Int, name: String, profilePath: String?)
    case director(id: Int, name: String, profilePath: String?)
    case genre(id: Int, name: String)
    case keyword(id: Int, name: String)
}

extension ViewingCustomGoalRule: Codable {

    private enum CodingKeys: String, CodingKey {
        case kind
        case decadeStart

        case personId
        case personName
        case profilePath

        case genreId
        case genreName

        case keywordId
        case keywordName
    }

    private enum Kind: String, Codable {
        case releaseDecade
        case person
        case director
        case genre
        case keyword
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

        case .director:
            let id = try c.decode(Int.self, forKey: .personId)
            let name = try c.decode(String.self, forKey: .personName)
            let profilePath = try c.decodeIfPresent(String.self, forKey: .profilePath)
            self = .director(id: id, name: name, profilePath: profilePath)

        case .genre:
            let id = try c.decode(Int.self, forKey: .genreId)
            let name = try c.decode(String.self, forKey: .genreName)
            self = .genre(id: id, name: name)

        case .keyword:
            let id = try c.decode(Int.self, forKey: .keywordId)
            let name = try c.decode(String.self, forKey: .keywordName)
            self = .keyword(id: id, name: name)
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

        case .director(let id, let name, let profilePath):
            try c.encode(Kind.director, forKey: .kind)
            try c.encode(id, forKey: .personId)
            try c.encode(name, forKey: .personName)
            try c.encodeIfPresent(profilePath, forKey: .profilePath)

        case .genre(let id, let name):
            try c.encode(Kind.genre, forKey: .kind)
            try c.encode(id, forKey: .genreId)
            try c.encode(name, forKey: .genreName)

        case .keyword(let id, let name):
            try c.encode(Kind.keyword, forKey: .kind)
            try c.encode(id, forKey: .keywordId)
            try c.encode(name, forKey: .keywordName)
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

    /// Dedupe-Key pro „Semantik“ (damit nicht 2× dasselbe Ziel existiert).
    var uniqueKey: String? {
        switch rule {
        case .releaseDecade(let decadeStart):
            return "decade:\(decadeStart)"

        case .person(let id, _, _):
            return id > 0 ? "person:\(id)" : nil

        case .director(let id, _, _):
            return id > 0 ? "director:\(id)" : nil

        case .genre(let id, _):
            return id > 0 ? "genre:\(id)" : nil

        case .keyword(let id, _):
            return id > 0 ? "keyword:\(id)" : nil
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

        case .director(_, let name, _):
            return "Filme von \(name)"

        case .genre(_, let name):
            return "Genre: \(name)"

        case .keyword(_, let name):
            return "Keyword: \(name)"
        }
    }

    // Convenience Accessors (für UI)
    var decadeStart: Int? {
        if case .releaseDecade(let d) = rule { return d }
        return nil
    }

    var personId: Int? {
        switch rule {
        case .person(let id, _, _): return id
        default: return nil
        }
    }

    var personName: String? {
        switch rule {
        case .person(_, let name, _): return name
        default: return nil
        }
    }

    var directorId: Int? {
        switch rule {
        case .director(let id, _, _): return id
        default: return nil
        }
    }

    var directorName: String? {
        switch rule {
        case .director(_, let name, _): return name
        default: return nil
        }
    }

    var profilePath: String? {
        switch rule {
        case .person(_, _, let p): return p
        case .director(_, _, let p): return p
        default: return nil
        }
    }

    var genreId: Int? {
        if case .genre(let id, _) = rule { return id }
        return nil
    }

    var genreName: String? {
        if case .genre(_, let name) = rule { return name }
        return nil
    }

    var keywordId: Int? {
        if case .keyword(let id, _) = rule { return id }
        return nil
    }

    var keywordName: String? {
        if case .keyword(_, let name) = rule { return name }
        return nil
    }
}

// MARK: - Migration Helpers (Step 1/2 → v3+)

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
