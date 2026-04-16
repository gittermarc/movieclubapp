import Foundation
import Testing
@testable import filmfreaks

@MainActor
struct ContentActivityPreviewModelTests {

    @Test func latestUpdateWinsWhenInputsChangeQuickly() async {
        let oldSnapshot = ContentActivityPreviewSnapshot(
            items: [UnifiedGroupActivityEvent(movieEvent: makeMovieEvent(title: "Old"))],
            allItems: [UnifiedGroupActivityEvent(movieEvent: makeMovieEvent(title: "Old"))]
        )
        let newSnapshot = ContentActivityPreviewSnapshot(
            items: [UnifiedGroupActivityEvent(movieEvent: makeMovieEvent(title: "New"))],
            allItems: [UnifiedGroupActivityEvent(movieEvent: makeMovieEvent(title: "New"))]
        )

        let model = ContentActivityPreviewModel(
            snapshotBuilder: { inputs in
                if inputs.ratingDisplayMode.rawValue == RatingDisplayMode.ratingAverage.rawValue {
                    Thread.sleep(forTimeInterval: 0.15)
                    return oldSnapshot
                }

                return newSnapshot
            }
        )

        model.update(
            watchedMovies: [makeMovie(title: "Old Source")],
            backlogMovies: [],
            movieNightEvents: [],
            ratingDisplayMode: .ratingAverage
        )

        model.update(
            watchedMovies: [makeMovie(title: "New Source")],
            backlogMovies: [],
            movieNightEvents: [],
            ratingDisplayMode: .fazitAverage
        )

        await waitForUpdates(count: 6)

        #expect(model.items.compactMap { $0.movieEvent?.movieTitle } == ["New"])
        #expect(model.allItems.compactMap { $0.movieEvent?.movieTitle } == ["New"])
    }

    @Test func updatePublishesBuiltSnapshot() async {
        let model = ContentActivityPreviewModel()
        let newerDate = makeDate(day: 10, hour: 18)
        let olderDate = makeDate(day: 10, hour: 8)

        model.update(
            watchedMovies: [
                makeMovie(title: "Newer Movie", addedAt: newerDate, addedByName: "Marc"),
                makeMovie(title: "Older Movie", addedAt: olderDate, addedByName: "Michi")
            ],
            backlogMovies: [],
            movieNightEvents: [
                makeNightEvent(day: 10, hour: 12, actorName: "Steffen")
            ],
            ratingDisplayMode: .ratingAverage
        )

        await waitForUpdates(count: 4)

        #expect(model.items.count == 3)
        #expect(model.items.map(\.kind) == [.movieAdded, .movieNightProposed, .movieAdded])
        #expect(model.allItems.map(\.kind) == [.movieAdded, .movieNightProposed, .movieAdded])
    }

    private func makeMovie(
        title: String,
        addedAt: Date? = nil,
        addedByName: String? = nil
    ) -> Movie {
        Movie(
            title: title,
            year: "2026",
            addedAt: addedAt,
            addedByName: addedByName
        )
    }

    private func makeMovieEvent(title: String) -> GroupActivityEvent {
        GroupActivityEvent(
            kind: .movieAdded,
            date: makeDate(day: 10, hour: 12),
            actorName: "Marc",
            actorId: UUID(uuidString: "11111111-1111-1111-1111-111111111111"),
            movieId: UUID(),
            movieTitle: title,
            movieYear: "2026",
            posterPath: nil,
            ratingValue: nil
        )
    }

    private func makeNightEvent(day: Int, hour: Int, actorName: String) -> MovieNightActivityEvent {
        MovieNightActivityEvent(
            id: UUID(),
            groupId: "group-1",
            kind: .proposed,
            createdAt: makeDate(day: day, hour: hour),
            eventId: UUID(),
            eventStart: makeDate(day: day, hour: hour),
            actorUserId: UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID(),
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

    private func waitForUpdates(count: Int = 3) async {
        for _ in 0..<count {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}
