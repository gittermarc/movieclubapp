import Foundation
import Testing
@testable import filmfreaks

struct MovieRouletteCandidateTests {

    @Test func buildBacklogCandidatesFiltersToActiveGroupAndKeepsLegacyEntries() {
        let activeGroupId = "group-1"
        let candidates = MovieRouletteCandidate.buildBacklogCandidates(
            from: [
                makeMovie(title: "Heat", year: "1995", groupId: activeGroupId, addedAt: makeDate(day: 2, hour: 20)),
                makeMovie(title: "Arrival", year: "2016", groupId: "group-2", addedAt: makeDate(day: 3, hour: 20)),
                makeMovie(title: "Alien", year: "1979", groupId: nil, addedAt: makeDate(day: 1, hour: 20))
            ],
            activeGroupId: activeGroupId
        )

        #expect(candidates.map(\.title) == ["Heat", "Alien"])
    }

    @Test func buildBacklogCandidatesSortsNewestFirstThenAlphabetically() {
        let activeGroupId = "group-1"
        let candidates = MovieRouletteCandidate.buildBacklogCandidates(
            from: [
                makeMovie(title: "Zodiac", year: "2007", groupId: activeGroupId, addedAt: makeDate(day: 1, hour: 20)),
                makeMovie(title: "Arrival", year: "2016", groupId: activeGroupId, addedAt: makeDate(day: 3, hour: 20)),
                makeMovie(title: "Alien", year: "1979", groupId: activeGroupId, addedAt: makeDate(day: 3, hour: 20))
            ],
            activeGroupId: activeGroupId
        )

        #expect(candidates.map(\.title) == ["Alien", "Arrival", "Zodiac"])
    }

    private func makeMovie(title: String, year: String, groupId: String?, addedAt: Date?) -> Movie {
        var movie = Movie(title: title, year: year, addedAt: addedAt)
        movie.groupId = groupId
        return movie
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
