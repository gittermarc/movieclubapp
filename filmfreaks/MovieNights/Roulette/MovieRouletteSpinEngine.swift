//
//  MovieRouletteSpinEngine.swift
//  filmfreaks
//
//  Created by Marc Fechner on 15.04.26.
//

import Foundation

/// Pure spin planning logic for Filmroulette.
enum MovieRouletteSpinEngine {
    static let animationDuration: Double = 3.6
    static let animationDurationNanoseconds: UInt64 = 3_600_000_000

    struct SpinPlan: Equatable {
        let displayCandidates: [MovieRouletteCandidate]
        let initialIndex: Int
        let targetIndex: Int
        let winningCandidate: MovieRouletteCandidate
    }

    static func idleStrip(for candidates: [MovieRouletteCandidate]) -> [MovieRouletteCandidate] {
        guard !candidates.isEmpty else { return [] }
        return repeated(candidates: candidates, repetitions: idleRepetitionCount(for: candidates.count))
    }

    static func idleIndex(for candidates: [MovieRouletteCandidate]) -> Int {
        guard !candidates.isEmpty else { return 0 }
        return candidates.count
    }

    static func makePlan(from candidates: [MovieRouletteCandidate]) -> SpinPlan? {
        var generator = SystemRandomNumberGenerator()
        return makePlan(from: candidates, using: &generator)
    }

    static func makePlan<RNG: RandomNumberGenerator>(
        from candidates: [MovieRouletteCandidate],
        using generator: inout RNG
    ) -> SpinPlan? {
        guard !candidates.isEmpty else { return nil }

        let startBaseIndex = Int.random(in: 0..<candidates.count, using: &generator)
        let winnerBaseIndex = Int.random(in: 0..<candidates.count, using: &generator)

        let initialLoopOffset = candidates.count
        let targetLoopOffset = candidates.count * targetLoopCount(for: candidates.count)
        let repetitions = targetLoopCount(for: candidates.count) + 2
        let displayCandidates = repeated(candidates: candidates, repetitions: repetitions)

        let initialIndex = initialLoopOffset + startBaseIndex
        let targetIndex = targetLoopOffset + winnerBaseIndex

        guard displayCandidates.indices.contains(initialIndex), displayCandidates.indices.contains(targetIndex) else {
            return nil
        }

        return SpinPlan(
            displayCandidates: displayCandidates,
            initialIndex: initialIndex,
            targetIndex: targetIndex,
            winningCandidate: candidates[winnerBaseIndex]
        )
    }

    private static func targetLoopCount(for candidateCount: Int) -> Int {
        switch candidateCount {
        case 0...2:
            return 7
        case 3...5:
            return 6
        default:
            return 5
        }
    }

    private static func idleRepetitionCount(for candidateCount: Int) -> Int {
        switch candidateCount {
        case 0:
            return 0
        case 1:
            return 5
        case 2:
            return 4
        default:
            return 3
        }
    }

    private static func repeated(candidates: [MovieRouletteCandidate], repetitions: Int) -> [MovieRouletteCandidate] {
        guard repetitions > 0 else { return [] }

        var result: [MovieRouletteCandidate] = []
        result.reserveCapacity(candidates.count * repetitions)

        for _ in 0..<repetitions {
            result.append(contentsOf: candidates)
        }

        return result
    }
}
