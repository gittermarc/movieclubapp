import Foundation
import Testing
@testable import filmfreaks

struct GroupSettingsActiveCardSnapshotTests {

    @Test func activitySummaryUsesMovieCopy() {
        let event = UnifiedGroupActivityEvent(
            movieEvent: GroupActivityEvent(
                kind: .movieRated,
                date: Date(timeIntervalSince1970: 1_000),
                actorName: "Michi",
                actorId: UUID(),
                movieId: UUID(),
                movieTitle: "Heat",
                movieYear: "1995",
                posterPath: "/heat.jpg",
                ratingValue: 8.5
            )
        )

        #expect(GroupSettingsPresentation.activitySummaryText(for: event) == "Michi hat Heat bewertet")
    }

    @Test func activitySummaryUsesMovieNightCopy() {
        let event = UnifiedGroupActivityEvent(
            movieNightActivity: MovieNightActivityEvent(
                groupId: "group-1",
                kind: .statusChanged,
                createdAt: Date(timeIntervalSince1970: 1_500),
                eventId: UUID(),
                eventStart: Date(timeIntervalSince1970: 2_000),
                actorUserId: UUID(),
                actorName: "Steffen",
                decision: nil,
                newStatus: .scheduled,
                note: nil
            )
        )

        #expect(GroupSettingsPresentation.activitySummaryText(for: event) == "Steffen hat den Filmabend geplant")
    }

    @Test func snapshotBuildsVisibleMembersAndHiddenCount() {
        let snapshot = GroupSettingsActiveCardSnapshotBuilder.build(
            users: [
                User(name: "Marc"),
                User(name: "Michi"),
                User(name: "Steffen"),
                User(name: "Thomas"),
                User(name: "Sarah")
            ],
            movieEvents: [],
            movieNightEvents: [],
            movies: [],
            backlogMovies: [],
            now: Date(timeIntervalSince1970: 3_000)
        )

        #expect(snapshot.members.map(\.name) == ["Marc", "Michi", "Steffen", "Thomas"])
        #expect(snapshot.hiddenMemberCount == 1)
        #expect(snapshot.memberSummaryText == "5 Mitglieder")
    }

    @Test func snapshotPrefersLatestUnifiedActivityAndMoviePoster() {
        let now = Date(timeIntervalSince1970: 10_000)
        let olderMovieEvent = GroupActivityEvent(
            kind: .movieAdded,
            date: Date(timeIntervalSince1970: 8_000),
            actorName: "Marc",
            actorId: UUID(),
            movieId: UUID(),
            movieTitle: "Arrival",
            movieYear: "2016",
            posterPath: "/arrival.jpg",
            ratingValue: nil
        )
        let newerMovieNightEvent = MovieNightActivityEvent(
            groupId: "group-1",
            kind: .responded,
            createdAt: Date(timeIntervalSince1970: 9_000),
            eventId: UUID(),
            eventStart: Date(timeIntervalSince1970: 12_000),
            actorUserId: UUID(),
            actorName: "Michi",
            decision: .accepted,
            newStatus: nil,
            note: nil
        )
        let fallbackMovie = Movie(
            title: "Heat",
            year: "1995",
            posterPath: "/heat.jpg"
        )

        let snapshot = GroupSettingsActiveCardSnapshotBuilder.build(
            users: [User(name: "Marc")],
            movieEvents: [olderMovieEvent],
            movieNightEvents: [newerMovieNightEvent],
            movies: [fallbackMovie],
            backlogMovies: [],
            now: now
        )

        #expect(snapshot.recentActivityText?.contains("Michi hat für den Filmabend zugesagt") == true)
        #expect(snapshot.backgroundPosterURL?.absoluteString == "https://image.tmdb.org/t/p/w500/arrival.jpg")
    }
}
