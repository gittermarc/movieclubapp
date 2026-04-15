import Foundation
import Testing
@testable import filmfreaks

@MainActor
struct MovieNightStoreRoulettePresetTests {

    @Test func saveRoulettePresetStoresPresetPerGroup() async throws {
        let store = MovieNightStore(useCloud: false)
        if let task = store.initialLoadTask {
            await task.value
        }

        let groupId = "group-preset-save-\(UUID().uuidString)"

        let saved = store.saveRoulettePreset(
            groupId: groupId,
            name: "Sci-Fi",
            movieRefs: [MovieNightMovieRef(movieId: UUID(), title: "Arrival", year: "2016", posterPath: nil, tmdbId: nil)]
        )

        let preset = try #require(saved)
        #expect(preset.displayName == "Sci-Fi")
        #expect(store.roulettePresets(for: groupId).count == 1)
    }

    @Test func deleteRoulettePresetRemovesPresetAndReindexesRemainingOnes() async throws {
        let store = MovieNightStore(useCloud: false)
        if let task = store.initialLoadTask {
            await task.value
        }

        let groupId = "group-preset-delete-\(UUID().uuidString)"

        let first = store.saveRoulettePreset(
            groupId: groupId,
            name: "Erste",
            movieRefs: [MovieNightMovieRef(movieId: UUID(), title: "Heat", year: "1995", posterPath: nil, tmdbId: nil)]
        )
        let second = store.saveRoulettePreset(
            groupId: groupId,
            name: "Zweite",
            movieRefs: [MovieNightMovieRef(movieId: UUID(), title: "Alien", year: "1979", posterPath: nil, tmdbId: nil)]
        )

        let firstPreset = try #require(first)
        let secondPreset = try #require(second)
        store.deleteRoulettePreset(groupId: groupId, presetId: firstPreset.id)

        let remaining = store.roulettePresets(for: groupId)
        #expect(remaining.count == 1)
        #expect(remaining.first?.id == secondPreset.id)
        #expect(remaining.first?.sortIndex == 0)
    }
}
