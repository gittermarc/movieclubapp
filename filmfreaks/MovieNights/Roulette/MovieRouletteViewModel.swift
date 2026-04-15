//
//  MovieRouletteViewModel.swift
//  filmfreaks
//
//  Created by Marc Fechner on 15.04.26.
//

internal import SwiftUI
import Combine

@MainActor
final class MovieRouletteViewModel: ObservableObject {

    @Published private(set) var groupName: String
    @Published private(set) var candidates: [MovieRouletteCandidate] = []
    @Published private(set) var displayCandidates: [MovieRouletteCandidate] = []
    @Published private(set) var activeDisplayIndex: Int = 0
    @Published private(set) var winningCandidate: MovieRouletteCandidate?
    @Published private(set) var isSpinning: Bool = false

    private var activeGroupId: String = ""
    private var lastCandidateIds: [UUID] = []
    private var spinKickoffTask: Task<Void, Never>?
    private var spinCompletionTask: Task<Void, Never>?

    init() {
        groupName = MovieRouletteViewModel.defaultGroupName
    }


    var candidateCountText: String {
        switch candidates.count {
        case 0:
            return "Keine Filme"
        case 1:
            return "1 Film"
        default:
            return "\(candidates.count) Filme"
        }
    }

    var spinButtonTitle: String {
        if isSpinning {
            return "Roulette läuft"
        }
        return winningCandidate == nil ? "Roulette starten" : "Nochmal drehen"
    }

    var emptyStateTitle: String {
        if activeGroupId.isEmpty {
            return "Keine Gruppe aktiv"
        }
        return "Backlog ist leer"
    }

    var emptyStateMessage: String {
        if activeGroupId.isEmpty {
            return "Wähle zuerst eine Gruppe aus. Dann kann Filmroulette das Backlog dieser Runde verwenden."
        }
        return "Für \(groupName) gibt es aktuell noch keine Backlog-Filme, aus denen das Roulette ziehen kann."
    }

    func update(backlogMovies: [Movie], currentGroupId: String?, currentGroupName: String?) {
        let normalizedGroupId = Self.normalizedGroupId(currentGroupId)
        let resolvedGroupName = Self.resolvedGroupName(currentGroupName)
        let nextCandidates = MovieRouletteCandidate.buildBacklogCandidates(from: backlogMovies, activeGroupId: normalizedGroupId)
        let nextIds = nextCandidates.map(\.id)

        let shouldReset = normalizedGroupId != activeGroupId || nextIds != lastCandidateIds

        activeGroupId = normalizedGroupId
        groupName = resolvedGroupName
        candidates = nextCandidates
        lastCandidateIds = nextIds

        if shouldReset {
            resetState(preserveWinner: false)
        } else if displayCandidates.isEmpty && !nextCandidates.isEmpty {
            resetStrip(with: nextCandidates)
        }
    }

    func spin() {
        guard !candidates.isEmpty, !isSpinning else { return }
        guard let plan = MovieRouletteSpinEngine.makePlan(from: candidates) else { return }

        spinKickoffTask?.cancel()
        spinCompletionTask?.cancel()
        isSpinning = true
        winningCandidate = nil
        displayCandidates = plan.displayCandidates
        activeDisplayIndex = plan.initialIndex

        spinKickoffTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard Task.isCancelled == false else { return }
            self?.activeDisplayIndex = plan.targetIndex
        }

        spinCompletionTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: MovieRouletteSpinEngine.animationDurationNanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.winningCandidate = plan.winningCandidate
                self?.isSpinning = false
            }
        }
    }

    private func resetState(preserveWinner: Bool) {
        spinKickoffTask?.cancel()
        spinCompletionTask?.cancel()
        spinKickoffTask = nil
        spinCompletionTask = nil
        isSpinning = false
        if preserveWinner == false {
            winningCandidate = nil
        }
        resetStrip(with: candidates)
    }

    private func resetStrip(with candidates: [MovieRouletteCandidate]) {
        displayCandidates = MovieRouletteSpinEngine.idleStrip(for: candidates)
        activeDisplayIndex = MovieRouletteSpinEngine.idleIndex(for: candidates)
    }

    private static let defaultGroupName = "deiner Gruppe"

    private static func resolvedGroupName(_ value: String?) -> String {
        let trimmed = normalizedGroupId(value)
        return trimmed.isEmpty ? defaultGroupName : trimmed
    }

    private static func normalizedGroupId(_ value: String?) -> String {
        (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
