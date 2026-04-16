import Foundation

struct GroupSettingsActiveCardSnapshot: Equatable {
    struct MemberPreview: Identifiable, Equatable {
        let id: UUID
        let name: String
    }

    let members: [MemberPreview]
    let hiddenMemberCount: Int
    let memberSummaryText: String?
    let recentActivityText: String?
    let backgroundPosterURL: URL?
    let backgroundSystemImage: String
}

enum GroupSettingsActiveCardSnapshotBuilder {
    private static let maxVisibleMembers = 4

    static func build(
        users: [User],
        movieEvents: [GroupActivityEvent],
        movieNightEvents: [MovieNightActivityEvent],
        movies: [Movie],
        backlogMovies: [Movie],
        now: Date = .now
    ) -> GroupSettingsActiveCardSnapshot {
        let visibleMembers = Array(users.prefix(maxVisibleMembers)).map {
            GroupSettingsActiveCardSnapshot.MemberPreview(id: $0.id, name: $0.name)
        }
        let hiddenMemberCount = max(0, users.count - visibleMembers.count)

        let latestActivity = ContentActivityPreviewSnapshotBuilder
            .build(
                input: .init(
                    movieEvents: movieEvents,
                    movieNightEvents: movieNightEvents,
                    perSourceLimit: 8,
                    totalLimit: 1
                )
            )
            .items
            .first

        let fallbackPosterURL = posterURL(from: movieEvents)
            ?? posterURL(from: movies + backlogMovies)

        return GroupSettingsActiveCardSnapshot(
            members: visibleMembers,
            hiddenMemberCount: hiddenMemberCount,
            memberSummaryText: users.isEmpty ? nil : GroupSettingsPresentation.memberCountText(users.count),
            recentActivityText: latestActivity.map { GroupSettingsPresentation.recentActivityText(for: $0, now: now) },
            backgroundPosterURL: posterURL(from: latestActivity) ?? fallbackPosterURL,
            backgroundSystemImage: "film"
        )
    }

    private static func posterURL(from event: UnifiedGroupActivityEvent?) -> URL? {
        guard let movieEvent = event?.movieEvent else { return nil }
        return movieEvent.posterURL
    }

    private static func posterURL(from movieEvents: [GroupActivityEvent]) -> URL? {
        movieEvents.first(where: { $0.posterURL != nil })?.posterURL
    }

    private static func posterURL(from movies: [Movie]) -> URL? {
        movies.first(where: { normalizedPosterPath($0.posterPath) != nil }).flatMap { movie in
            guard let posterPath = normalizedPosterPath(movie.posterPath) else { return nil }
            return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
        }
    }

    private static func normalizedPosterPath(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
