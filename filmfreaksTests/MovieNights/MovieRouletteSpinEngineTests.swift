import Foundation
import Testing
@testable import filmfreaks

struct MovieRouletteSpinEngineTests {

    @Test func idleStripRepeatsCandidatesToCreateStageDepth() {
        let candidates = makeCandidates(count: 2)

        let strip = MovieRouletteSpinEngine.idleStrip(for: candidates)

        #expect(strip.count == 8)
        #expect(MovieRouletteSpinEngine.idleIndex(for: candidates) == 2)
    }

    @Test func makePlanReturnsWinnerAtTargetIndexAndMovesForward() throws {
        var generator = FixedRandomNumberGenerator(values: [1, 2])
        let candidates = makeCandidates(count: 4)

        let plan = MovieRouletteSpinEngine.makePlan(from: candidates, using: &generator)

        let unwrappedPlan = try #require(plan)
        #expect(unwrappedPlan.targetIndex > unwrappedPlan.initialIndex)
        #expect(unwrappedPlan.displayCandidates[unwrappedPlan.targetIndex] == unwrappedPlan.winningCandidate)
    }

    @Test func makePlanReturnsNilForEmptyCandidates() {
        let plan = MovieRouletteSpinEngine.makePlan(from: [])
        #expect(plan == nil)
    }

    private func makeCandidates(count: Int) -> [MovieRouletteCandidate] {
        (0..<count).map { index in
            MovieRouletteCandidate(
                movieRef: MovieNightMovieRef(
                    movieId: UUID(),
                    title: "Film \(index)",
                    year: "20\(index)",
                    posterPath: nil,
                    tmdbId: nil
                ),
                addedAt: nil
            )
        }
    }
}

private struct FixedRandomNumberGenerator: RandomNumberGenerator {
    private var values: [UInt64]
    private var index: Int = 0

    init(values: [UInt64]) {
        self.values = values
    }

    mutating func next() -> UInt64 {
        guard values.isEmpty == false else { return 0 }
        let value = values[index % values.count]
        index += 1
        return value
    }
}
