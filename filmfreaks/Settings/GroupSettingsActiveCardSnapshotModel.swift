import Combine
import Foundation

final class GroupSettingsActiveCardSnapshotModel: ObservableObject {
    @Published private(set) var snapshot: GroupSettingsActiveCardSnapshot

    private var lastSignature: GroupSettingsActiveCardSnapshotInputSignature?
    private let builder: any GroupSettingsActiveCardSnapshotBuilding

    init(
        snapshot: GroupSettingsActiveCardSnapshot = .empty,
        builder: any GroupSettingsActiveCardSnapshotBuilding = GroupSettingsActiveCardSnapshotBuilderAdapter()
    ) {
        self.snapshot = snapshot
        self.builder = builder
    }

    @discardableResult
    func update(input: GroupSettingsActiveCardSnapshotInput, now: Date = .now) -> Bool {
        let signature = GroupSettingsActiveCardSnapshotInputSignature(input: input)
        guard signature != lastSignature else {
            return false
        }

        lastSignature = signature
        snapshot = builder.build(input: input, now: now)
        return true
    }
}

protocol GroupSettingsActiveCardSnapshotBuilding {
    func build(input: GroupSettingsActiveCardSnapshotInput, now: Date) -> GroupSettingsActiveCardSnapshot
}

struct GroupSettingsActiveCardSnapshotBuilderAdapter: GroupSettingsActiveCardSnapshotBuilding {
    func build(input: GroupSettingsActiveCardSnapshotInput, now: Date) -> GroupSettingsActiveCardSnapshot {
        GroupSettingsActiveCardSnapshotBuilder.build(
            users: input.users,
            movieEvents: input.movieEvents,
            movieNightEvents: input.movieNightEvents,
            movies: input.movies,
            backlogMovies: input.backlogMovies,
            now: now
        )
    }
}

struct GroupSettingsActiveCardSnapshotInput {
    let users: [User]
    let movieEvents: [GroupActivityEvent]
    let movieNightEvents: [MovieNightActivityEvent]
    let movies: [Movie]
    let backlogMovies: [Movie]
}

struct GroupSettingsActiveCardSnapshotInputSignature: Equatable {
    private let users: [UserSignature]
    private let movieEvents: [MovieEventSignature]
    private let movieNightEvents: [MovieNightEventSignature]
    private let moviePosters: [MoviePosterSignature]
    private let backlogPosters: [MoviePosterSignature]

    init(input: GroupSettingsActiveCardSnapshotInput) {
        self.users = input.users.map(UserSignature.init)
        self.movieEvents = input.movieEvents.map(MovieEventSignature.init)
        self.movieNightEvents = input.movieNightEvents.map(MovieNightEventSignature.init)
        self.moviePosters = input.movies.map(MoviePosterSignature.init)
        self.backlogPosters = input.backlogMovies.map(MoviePosterSignature.init)
    }
}

private struct UserSignature: Equatable {
    let id: UUID
    let name: String

    init(_ user: User) {
        self.id = user.id
        self.name = user.name
    }
}

private struct MovieEventSignature: Equatable {
    let id: String
    let date: Date
    let actorName: String?
    let movieTitle: String
    let movieYear: String?
    let posterPath: String?
    let ratingValue: Double?

    init(_ event: GroupActivityEvent) {
        self.id = event.id
        self.date = event.date
        self.actorName = event.actorName
        self.movieTitle = event.movieTitle
        self.movieYear = event.movieYear
        self.posterPath = event.posterPath
        self.ratingValue = event.ratingValue
    }
}

private struct MovieNightEventSignature: Equatable {
    let id: UUID
    let groupId: String
    let kind: MovieNightActivityEvent.Kind
    let createdAt: Date
    let actorName: String
    let decision: MovieNightResponse.Decision?
    let newStatus: MovieNightEvent.Status?

    init(_ event: MovieNightActivityEvent) {
        self.id = event.id
        self.groupId = event.groupId
        self.kind = event.kind
        self.createdAt = event.createdAt
        self.actorName = event.actorName
        self.decision = event.decision
        self.newStatus = event.newStatus
    }
}

private struct MoviePosterSignature: Equatable {
    let id: UUID
    let posterPath: String?

    init(_ movie: Movie) {
        self.id = movie.id
        self.posterPath = movie.posterPath
    }
}

extension GroupSettingsActiveCardSnapshot {
    static var empty: GroupSettingsActiveCardSnapshot {
        GroupSettingsActiveCardSnapshot(
            members: [],
            hiddenMemberCount: 0,
            memberSummaryText: nil,
            recentActivityText: nil,
            backgroundPosterURL: nil,
            backgroundSystemImage: "film"
        )
    }
}
