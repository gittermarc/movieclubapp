import Foundation
import Testing
@testable import filmfreaks

struct MovieRoulettePresetTests {

    @Test func normalizedPresetsSortByIndexAndReassignContinuousOrder() {
        let groupId = "group-1"
        let presets = [
            MovieRoulettePreset(groupId: groupId, name: "B", sortIndex: 4, movieRefs: [], updatedAt: makeDate(day: 2)),
            MovieRoulettePreset(groupId: groupId, name: "A", sortIndex: 1, movieRefs: [], updatedAt: makeDate(day: 1))
        ]

        let normalized = MovieRoulettePreset.normalized(presets, groupId: groupId)

        #expect(normalized.map(\.displayName) == ["A", "B"])
        #expect(normalized.map(\.sortIndex) == [0, 1])
    }

    @Test func deduplicatedMovieRefsKeepsFirstOccurrencePerMovieId() {
        let movieId = UUID()
        let refs = [
            MovieNightMovieRef(movieId: movieId, title: "Heat", year: "1995", posterPath: nil, tmdbId: nil),
            MovieNightMovieRef(movieId: movieId, title: "Heat Duplicate", year: "1995", posterPath: nil, tmdbId: nil)
        ]

        let deduplicated = MovieRoulettePreset.deduplicatedMovieRefs(refs)

        #expect(deduplicated.count == 1)
        #expect(deduplicated.first?.title == "Heat")
    }

    private func makeDate(day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: 2026, month: 4, day: day, hour: 20)
        return calendar.date(from: components) ?? .distantPast
    }
}
