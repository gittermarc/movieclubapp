//
//  ViewingCustomGoal.swift
//  filmfreaks
//
//  Step 3+4(+): Goal Types als enum + generisches Goal-Model (Decade, Actor, Director, Genre, Keyword)
//  Step 5 (Year Scope): Custom Goals gelten pro Jahr bzw. über eine definierte Dauer (in Jahren).
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
/// Director/Genre/Keyword sind zusätzliche cases (Step 4).
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

    /// Ab wann gilt das Ziel (Jahr).
    /// Standard: das Jahr, in dem es erstellt wurde.
    var startYear: Int

    /// Wie viele Jahre (ab startYear) das Ziel gilt.
    /// Standard: 1 (nur ein Jahr).
    var durationYears: Int

    init(
        id: UUID = UUID(),
        type: ViewingCustomGoalType,
        rule: ViewingCustomGoalRule,
        target: Int,
        createdAt: Date = Date(),
        startYear: Int? = nil,
        durationYears: Int = 1
    ) {
        self.id = id
        self.type = type
        self.rule = rule
        self.target = target
        self.createdAt = createdAt

        let inferredStart = startYear ?? Calendar.current.component(.year, from: createdAt)
        self.startYear = inferredStart
        self.durationYears = max(1, durationYears)
    }

    // MARK: - Codable (Migration-sicher)

    private enum CodingKeys: String, CodingKey {
        case id, type, rule, target, createdAt
        case startYear, durationYears
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id = try c.decode(UUID.self, forKey: .id)
        type = try c.decode(ViewingCustomGoalType.self, forKey: .type)
        rule = try c.decode(ViewingCustomGoalRule.self, forKey: .rule)
        target = try c.decode(Int.self, forKey: .target)
        createdAt = try c.decode(Date.self, forKey: .createdAt)

        // Backwards compatibility:
        // Older payloads may not contain startYear/durationYears.
        let fallbackStart = Calendar.current.component(.year, from: createdAt)
        startYear = try c.decodeIfPresent(Int.self, forKey: .startYear) ?? fallbackStart
        durationYears = max(1, (try c.decodeIfPresent(Int.self, forKey: .durationYears) ?? 1))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(type, forKey: .type)
        try c.encode(rule, forKey: .rule)
        try c.encode(target, forKey: .target)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(startYear, forKey: .startYear)
        try c.encode(durationYears, forKey: .durationYears)
    }

    // MARK: - Year Scope

    func isActive(in year: Int) -> Bool {
        let end = startYear + max(1, durationYears) - 1
        return year >= startYear && year <= end
    }

    var validityLabel: String {
        let end = startYear + max(1, durationYears) - 1
        if durationYears <= 1 { return "Gilt: \(startYear)" }
        return "Gilt: \(startYear)–\(end)"
    }

    /// Dedupe-Key pro „Semantik“ innerhalb eines Startjahres.
    /// (Damit du z.B. „Nolan 2025“ und „Nolan 2026“ gleichzeitig haben kannst.)
    var uniqueKey: String? {
        switch rule {
        case .releaseDecade(let decadeStart):
            return "decade:\(decadeStart):\(startYear)"

        case .person(let id, _, _):
            return id > 0 ? "person:\(id):\(startYear)" : nil

        case .director(let id, _, _):
            return id > 0 ? "director:\(id):\(startYear)" : nil

        case .genre(let id, _):
            return id > 0 ? "genre:\(id):\(startYear)" : nil

        case .keyword(let id, _):
            return id > 0 ? "keyword:\(id):\(startYear)" : nil
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
            createdAt: decadeGoal.createdAt,
            startYear: Calendar.current.component(.year, from: decadeGoal.createdAt),
            durationYears: 1
        )
    }

    init(from actorGoal: ActorGoal) {
        self.init(
            id: actorGoal.id,
            type: .person,
            rule: .person(id: actorGoal.personId, name: actorGoal.personName, profilePath: actorGoal.profilePath),
            target: actorGoal.target,
            createdAt: actorGoal.createdAt,
            startYear: Calendar.current.component(.year, from: actorGoal.createdAt),
            durationYears: 1
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
