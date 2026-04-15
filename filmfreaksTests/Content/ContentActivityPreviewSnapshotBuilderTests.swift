import Foundation
import Testing
@testable import filmfreaks

struct ContentActivityPreviewSnapshotBuilderTests {

    @Test func mergesMovieAndMovieNightActivitiesInDescendingDateOrder() {
        let snapshot = makeSnapshot(
            movieEvents: [
                makeMovieEvent(title: "Older Movie", day: 5, hour: 9),
                makeMovieEvent(title: "Newest Movie", day: 8, hour: 18)
            ],
            movieNightEvents: [
                makeNightEvent(day: 7, hour: 20, actorName: "Marc")
            ],
            perSourceLimit: 10,
            totalLimit: 10
        )

        let expectedKinds: [UnifiedGroupActivityEvent.Kind] = [.movieAdded, .movieNightProposed, .movieAdded]
        #expect(snapshot.items.map(\.kind) == expectedKinds)
        #expect(snapshot.items.compactMap { $0.movieEvent?.movieTitle } == ["Newest Movie", "Older Movie"])
        #expect(snapshot.items.compactMap { $0.movieNightEvent?.actorName } == ["Marc"])
    }

    @Test func keepsPerSourceAndOverallLimits() {
        let snapshot = makeSnapshot(
            movieEvents: [
                makeMovieEvent(title: "Movie 1", day: 9, hour: 20),
                makeMovieEvent(title: "Movie 2", day: 8, hour: 20),
                makeMovieEvent(title: "Movie 3", day: 7, hour: 20)
            ],
            movieNightEvents: [
                makeNightEvent(day: 9, hour: 19, actorName: "A"),
                makeNightEvent(day: 8, hour: 19, actorName: "B"),
                makeNightEvent(day: 7, hour: 19, actorName: "C")
            ],
            perSourceLimit: 2,
            totalLimit: 3
        )

        #expect(snapshot.items.count == 3)
        let expectedKinds: [UnifiedGroupActivityEvent.Kind] = [.movieAdded, .movieNightProposed, .movieAdded]
        #expect(snapshot.items.map(\.kind) == expectedKinds)
        #expect(snapshot.items.compactMap { $0.movieEvent?.movieTitle } == ["Movie 1", "Movie 2"])
        #expect(snapshot.items.compactMap { $0.movieNightEvent?.actorName } == ["A"])
        #expect(snapshot.allItems.count == 6)
    }

    @Test func equalDatesPreserveCombinedSourceOrder() {
        let date = makeDate(day: 10, hour: 12)
        let snapshot = makeSnapshot(
            movieEvents: [
                makeMovieEvent(title: "Movie First", date: date),
                makeMovieEvent(title: "Movie Second", date: date)
            ],
            movieNightEvents: [
                makeNightEvent(
                    date: date,
                    actorName: "Night",
                    actorUserId: UUID(uuidString: "44444444-4444-4444-4444-444444444444")
                )
            ],
            perSourceLimit: 10,
            totalLimit: 10
        )

        let expectedKinds: [UnifiedGroupActivityEvent.Kind] = [.movieAdded, .movieAdded, .movieNightProposed]
        #expect(snapshot.items.map(\.kind) == expectedKinds)
        #expect(snapshot.items.compactMap { $0.movieEvent?.movieTitle } == ["Movie First", "Movie Second"])
        #expect(snapshot.items.last?.movieNightEvent?.actorName == "Night")
    }

    @Test func emptyInputsProduceEmptySnapshot() {
        let snapshot = makeSnapshot()

        #expect(snapshot.items.isEmpty)
        #expect(snapshot.allItems.isEmpty)
    }

    @Test func newEventsCountIgnoresOwnEventsAndOldEntries() {
        let currentUserId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")
        let threshold = makeDate(day: 10, hour: 12)
        let snapshot = makeSnapshot(
            movieEvents: [
                makeMovieEvent(
                    title: "Own New Movie",
                    day: 10,
                    hour: 14,
                    actorName: "Marc",
                    actorId: currentUserId
                ),
                makeMovieEvent(
                    title: "Foreign Old Movie",
                    day: 10,
                    hour: 10,
                    actorName: "Michi",
                    actorId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")
                ),
                makeMovieEvent(
                    title: "Foreign New Movie",
                    day: 10,
                    hour: 15,
                    actorName: "Michi",
                    actorId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")
                )
            ],
            movieNightEvents: [
                makeNightEvent(
                    date: makeDate(day: 10, hour: 16),
                    actorName: "Marc",
                    actorUserId: currentUserId
                ),
                makeNightEvent(
                    date: makeDate(day: 10, hour: 17),
                    actorName: "Steffen",
                    actorUserId: UUID(uuidString: "33333333-3333-3333-3333-333333333333")
                )
            ],
            perSourceLimit: 10,
            totalLimit: 10
        )

        let newEventsCount = ContentActivityPreviewSnapshotBuilder.newEventsCount(
            in: snapshot.allItems,
            currentUserId: currentUserId,
            currentUserName: "Marc",
            unseenThreshold: threshold
        )

        #expect(newEventsCount == 2)
    }

    private func makeSnapshot(
        movieEvents: [GroupActivityEvent] = [],
        movieNightEvents: [MovieNightActivityEvent] = [],
        perSourceLimit: Int = 10,
        totalLimit: Int = 3
    ) -> ContentActivityPreviewSnapshot {
        ContentActivityPreviewSnapshotBuilder.build(
            input: .init(
                movieEvents: movieEvents,
                movieNightEvents: movieNightEvents,
                perSourceLimit: perSourceLimit,
                totalLimit: totalLimit
            )
        )
    }

    private func makeMovieEvent(
        title: String,
        day: Int? = nil,
        hour: Int? = nil,
        date: Date? = nil,
        actorName: String = "Marc",
        actorId: UUID? = UUID(uuidString: "11111111-1111-1111-1111-111111111111")
    ) -> GroupActivityEvent {
        GroupActivityEvent(
            kind: .movieAdded,
            date: date ?? makeDate(day: day ?? 1, hour: hour ?? 12),
            actorName: actorName,
            actorId: actorId,
            movieId: UUID(),
            movieTitle: title,
            movieYear: "2026",
            posterPath: nil,
            ratingValue: nil
        )
    }

    private func makeNightEvent(
        day: Int,
        hour: Int,
        actorName: String
    ) -> MovieNightActivityEvent {
        makeNightEvent(
            date: makeDate(day: day, hour: hour),
            actorName: actorName,
            actorUserId: UUID(uuidString: "44444444-4444-4444-4444-444444444444")
        )
    }

    private func makeNightEvent(
        date: Date,
        actorName: String,
        actorUserId: UUID? = UUID(uuidString: "44444444-4444-4444-4444-444444444444")
    ) -> MovieNightActivityEvent {
        MovieNightActivityEvent(
            id: UUID(),
            groupId: "group-1",
            kind: .proposed,
            createdAt: date,
            eventId: UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID(),
            eventStart: date,
            actorUserId: actorUserId ?? UUID(),
            actorName: actorName,
            decision: nil,
            newStatus: nil,
            note: nil
        )
    }

    private func makeDate(day: Int, hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 4,
            day: day,
            hour: hour,
            minute: 0,
            second: 0
        )
        return calendar.date(from: components) ?? .distantPast
    }
}
