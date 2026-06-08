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
    @Published private(set) var availablePresets: [MovieRoulettePreset] = []
    @Published private(set) var selectedPresetId: UUID?
    @Published var selectedSource: MovieRouletteSource = .backlog

    private var activeGroupId: String = ""
    private var backlogCandidates: [MovieRouletteCandidate] = []
    private var excludedCandidateIds: Set<UUID> = []
    private var lastCandidateIds: [UUID] = []
    private var lastSourceCandidateIds: [UUID] = []
    private var lastPresetIds: [UUID] = []
    private var spinKickoffTask: Task<Void, Never>?
    private var spinCompletionTask: Task<Void, Never>?

    init() {
        groupName = MovieRouletteViewModel.defaultGroupName
    }

    var selectedPreset: MovieRoulettePreset? {
        guard let selectedPresetId else { return nil }
        return availablePresets.first(where: { $0.id == selectedPresetId })
    }

    var resultSourceTitle: String {
        switch selectedSource {
        case .backlog:
            return "Backlog"
        case .preset:
            return selectedPreset?.displayName ?? "Auswahl"
        }
    }

    var resultMessage: String {
        switch selectedSource {
        case .backlog:
            return "Das Roulette hat für \(groupName) einen Film aus eurem Backlog ausgewählt."
        case .preset:
            if let preset = selectedPreset {
                return "Das Roulette hat für \(groupName) einen Film aus der Auswahl „\(preset.displayName)“ ausgewählt."
            }
            return "Das Roulette hat für \(groupName) einen Film aus eurer Auswahl ausgewählt."
        }
    }

    var stageDescription: String {
        if isSpinning {
            return "Das Roulette läuft gerade aus. Sobald der Strip stoppt, steht der Gewinner fest."
        }
        if winningCandidate != nil {
            return "Der Gewinner steht fest. Du kannst ihn direkt als Filmabend übernehmen oder noch einmal drehen."
        }
        return "Der leuchtende Marker zeigt am Ende den Gewinnerfilm an."
    }

    var canSuggestMovieNight: Bool {
        winningCandidate != nil && activeGroupId.isEmpty == false
    }

    var canRemoveWinnerAndSpinAgain: Bool {
        winningCandidate != nil && candidates.count > 1 && isSpinning == false
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

    var sourceBadgeText: String {
        switch selectedSource {
        case .backlog:
            return "Backlog"
        case .preset:
            return selectedPreset?.displayName ?? "Auswahl"
        }
    }

    var sourceDescription: String {
        switch selectedSource {
        case .backlog:
            return "Ein Spin aus dem Backlog von \(groupName). Ideal, wenn ihr euch gerade nicht entscheiden könnt."
        case .preset:
            if let preset = selectedPreset {
                return "Ein Spin aus der Auswahl „\(preset.displayName)“ für \(groupName)."
            }
            return "Wähle oder erstelle eine Auswahl für \(groupName), um daraus zu drehen."
        }
    }

    var selectedPresetSummary: String {
        guard let selectedPreset else { return "" }
        let countText = selectedPreset.movieCount == 1 ? "1 Film" : "\(selectedPreset.movieCount) Filme"
        return "\(selectedPreset.displayName) · \(countText)"
    }

    var emptyStateTitle: String {
        if activeGroupId.isEmpty {
            return "Keine Gruppe aktiv"
        }

        switch selectedSource {
        case .backlog:
            return "Backlog ist leer"
        case .preset:
            if availablePresets.isEmpty {
                return "Noch keine Auswahlen"
            }
            return "Auswahl ist leer"
        }
    }

    var emptyStateMessage: String {
        if activeGroupId.isEmpty {
            return "Wähle zuerst eine Gruppe aus. Dann kann Filmroulette deren Backlog oder eure Auswahlen verwenden."
        }

        switch selectedSource {
        case .backlog:
            return "Für \(groupName) gibt es aktuell noch keine Backlog-Filme, aus denen das Roulette ziehen kann."
        case .preset:
            if availablePresets.isEmpty {
                return "Lege eine erste vordefinierte Auswahl für \(groupName) an. Danach kannst du direkt daraus drehen."
            }
            return "Die aktuell gewählte Auswahl enthält keine Filme. Bearbeite sie oder wähle eine andere Auswahl."
        }
    }

    var canManagePresets: Bool {
        activeGroupId.isEmpty == false
    }

    func update(
        backlogMovies: [Movie],
        currentGroupId: String?,
        currentGroupName: String?,
        presets: [MovieRoulettePreset]
    ) {
        let normalizedGroupId = Self.normalizedValue(currentGroupId)
        let resolvedGroupName = Self.resolvedName(currentGroupName)
        let normalizedPresets = MovieRoulettePreset.normalized(presets, groupId: normalizedGroupId)
        let nextPresetIds = normalizedPresets.map(\.id)
        let previousGroupId = activeGroupId
        let previousSelectedPresetId = selectedPresetId

        let backlogIndex = MovieRouletteBacklogIndex(backlogMovies: backlogMovies, activeGroupId: normalizedGroupId)
        backlogCandidates = backlogIndex.candidates

        if normalizedGroupId != activeGroupId {
            selectedSource = .backlog
            selectedPresetId = nil
        }

        if normalizedPresets.contains(where: { $0.id == selectedPresetId }) == false {
            selectedPresetId = normalizedPresets.first?.id
        }

        activeGroupId = normalizedGroupId
        groupName = resolvedGroupName
        availablePresets = normalizedPresets

        let sourceCandidates = currentSourceCandidates()
        let sourceCandidateIds = sourceCandidates.map(\.id)
        let shouldResetSession = normalizedGroupId != previousGroupId || sourceCandidateIds != lastSourceCandidateIds || nextPresetIds != lastPresetIds || previousSelectedPresetId != selectedPresetId

        if shouldResetSession {
            excludedCandidateIds.removeAll()
        }

        let nextCandidates = applyExclusions(to: sourceCandidates)
        let nextCandidateIds = nextCandidates.map(\.id)

        candidates = nextCandidates
        lastCandidateIds = nextCandidateIds
        lastSourceCandidateIds = sourceCandidateIds
        lastPresetIds = nextPresetIds

        if shouldResetSession {
            resetState(clearWinner: true)
        } else if displayCandidates.isEmpty && nextCandidates.isEmpty == false {
            resetStrip(with: nextCandidates)
        }
    }

    func selectSource(_ source: MovieRouletteSource) {
        guard selectedSource != source else { return }
        selectedSource = source
        excludedCandidateIds.removeAll()
        recalculateCandidates(clearWinner: true)
    }

    func selectPreset(_ presetId: UUID) {
        guard selectedPresetId != presetId else { return }
        selectedPresetId = presetId
        excludedCandidateIds.removeAll()
        recalculateCandidates(clearWinner: true)
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
            guard Task.isCancelled == false else { return }
            await MainActor.run {
                self?.winningCandidate = plan.winningCandidate
                self?.isSpinning = false
            }
        }
    }

    func removeWinningCandidateAndSpinAgain() {
        guard let winningCandidate, canRemoveWinnerAndSpinAgain else { return }
        guard removeCandidateFromCurrentSession(candidateId: winningCandidate.id) else { return }
        if candidates.isEmpty == false {
            spin()
        }
    }

    @discardableResult
    func removeCandidateFromCurrentSession(candidateId: UUID) -> Bool {
        let sourceCandidateIds = currentSourceCandidates().map(\.id)
        guard sourceCandidateIds.contains(candidateId) else { return false }

        excludedCandidateIds.insert(candidateId)
        let nextCandidates = applyExclusions(to: currentSourceCandidates())
        candidates = nextCandidates
        lastCandidateIds = nextCandidates.map(\.id)
        lastSourceCandidateIds = sourceCandidateIds
        resetState(clearWinner: true)
        return true
    }

    private func recalculateCandidates(clearWinner: Bool) {
        let sourceCandidates = currentSourceCandidates()
        candidates = applyExclusions(to: sourceCandidates)
        lastCandidateIds = candidates.map(\.id)
        lastSourceCandidateIds = sourceCandidates.map(\.id)
        resetState(clearWinner: clearWinner)
    }

    private func currentSourceCandidates() -> [MovieRouletteCandidate] {
        switch selectedSource {
        case .backlog:
            return backlogCandidates
        case .preset:
            return MovieRouletteCandidate.buildPresetCandidates(from: selectedPreset)
        }
    }

    private func applyExclusions(to sourceCandidates: [MovieRouletteCandidate]) -> [MovieRouletteCandidate] {
        guard excludedCandidateIds.isEmpty == false else { return sourceCandidates }
        return sourceCandidates.filter { excludedCandidateIds.contains($0.id) == false }
    }

    private func resetState(clearWinner: Bool) {
        spinKickoffTask?.cancel()
        spinCompletionTask?.cancel()
        spinKickoffTask = nil
        spinCompletionTask = nil
        isSpinning = false
        if clearWinner {
            winningCandidate = nil
        }
        resetStrip(with: candidates)
    }

    private func resetStrip(with candidates: [MovieRouletteCandidate]) {
        displayCandidates = MovieRouletteSpinEngine.idleStrip(for: candidates)
        activeDisplayIndex = MovieRouletteSpinEngine.idleIndex(for: candidates)
    }

    private static let defaultGroupName = "deiner Gruppe"

    private static func resolvedName(_ value: String?) -> String {
        let trimmed = normalizedValue(value)
        return trimmed.isEmpty ? defaultGroupName : trimmed
    }

    private static func normalizedValue(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
