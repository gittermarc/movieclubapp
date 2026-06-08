import Foundation
import Testing
@testable import filmfreaks

struct MovieRouletteBacklogIndexTests {

    @Test func indexResolvesPresetManagementMoviesInCandidateOrder() {
        let activeGroupId = "group-1"
        let heat = makeMovie(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Heat",
            year: "1995",
            groupId: activeGroupId,
            addedAt: makeDate(day: 2)
        )
        let arrival = makeMovie(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "Arrival",
            year: "2016",
            groupId: activeGroupId,
            addedAt: makeDate(day: 3)
        )
        let legacy = makeMovie(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            title: "Alien",
            year: "1979",
            groupId: nil,
            addedAt: makeDate(day: 1)
        )
        let otherGroup = makeMovie(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            title: "Zodiac",
            year: "2007",
            groupId: "group-2",
            addedAt: makeDate(day: 4)
        )

        let index = MovieRouletteBacklogIndex(
            backlogMovies: [otherGroup, legacy, heat, arrival],
            activeGroupId: activeGroupId
        )

        #expect(index.candidates.map(\.id) == [arrival.id, heat.id, legacy.id])
        #expect(index.presetManagementMovies.map(\.id) == [arrival.id, heat.id, legacy.id])
    }

    @Test func indexKeepsStableCandidateOrderWhenBacklogInputOrderChanges() {
        let activeGroupId = "group-1"
        let older = makeMovie(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            title: "Older",
            year: "1990",
            groupId: activeGroupId,
            addedAt: makeDate(day: 1)
        )
        let newer = makeMovie(
            id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            title: "Newer",
            year: "2020",
            groupId: activeGroupId,
            addedAt: makeDate(day: 2)
        )

        let firstIndex = MovieRouletteBacklogIndex(
            backlogMovies: [older, newer],
            activeGroupId: activeGroupId
        )
        let reorderedIndex = MovieRouletteBacklogIndex(
            backlogMovies: [newer, older],
            activeGroupId: activeGroupId
        )

        #expect(firstIndex.candidates.map(\.id) == [newer.id, older.id])
        #expect(reorderedIndex.candidates.map(\.id) == [newer.id, older.id])
        #expect(reorderedIndex.presetManagementMovies.map(\.id) == [newer.id, older.id])
    }

    @Test func indexReturnsEmptySnapshotWithoutActiveGroup() {
        let index = MovieRouletteBacklogIndex(
            backlogMovies: [makeMovie(title: "Heat", groupId: "group-1")],
            activeGroupId: "  "
        )

        #expect(index.candidates.isEmpty)
        #expect(index.presetManagementMovies.isEmpty)
    }

    private func makeMovie(
        id: UUID = UUID(),
        title: String,
        year: String = "1995",
        groupId: String?,
        addedAt: Date? = nil
    ) -> Movie {
        var movie = Movie(id: id, title: title, year: year, addedAt: addedAt)
        movie.groupId = groupId
        return movie
    }

    private func makeDate(day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 4,
            day: day,
            hour: 20,
            minute: 0,
            second: 0
        )
        return calendar.date(from: components) ?? .distantPast
    }
}
