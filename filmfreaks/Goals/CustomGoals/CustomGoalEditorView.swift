//
//  CustomGoalEditorView.swift
//  filmfreaks
//

internal import SwiftUI

// MARK: - Editor

struct CustomGoalEditorView: View {

    let initialGoal: ViewingCustomGoal
    let contextYear: Int
    let availableYears: [Int]
    let availableDecades: [Int]
    let actorSuggestions: [PersonSuggestion]
    let directorSuggestions: [PersonSuggestion]
    let availableGenres: [TMDbGenre]

    let onCancel: () -> Void
    let onSave: (ViewingCustomGoal) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var target: Int = 10

    // validity
    @State private var startYear: Int = Calendar.current.component(.year, from: Date())
    @State private var durationYears: Int = 1

    // decade
    @State private var decadeStart: Int = 2000

    // person/director
    @State private var personQuery: String = ""
    @State private var isSearchingPerson = false
    @State private var personResults: [TMDbPersonSummary] = []
    @State private var selectedPersonId: Int = 0
    @State private var selectedPersonName: String = ""
    @State private var selectedProfilePath: String? = nil

    // genre
    @State private var selectedGenreId: Int = 0
    @State private var selectedGenreName: String = ""

    // keyword
    @State private var keywordQuery: String = ""
    @State private var isSearchingKeyword = false
    @State private var keywordResults: [TMDbKeywordSummary] = []
    @State private var selectedKeywordId: Int = 0
    @State private var selectedKeywordName: String = ""

    init(
        initialGoal: ViewingCustomGoal,
        contextYear: Int,
        availableYears: [Int],
        availableDecades: [Int],
        actorSuggestions: [PersonSuggestion],
        directorSuggestions: [PersonSuggestion],
        availableGenres: [TMDbGenre],
        onCancel: @escaping () -> Void,
        onSave: @escaping (ViewingCustomGoal) -> Void
    ) {
        self.initialGoal = initialGoal
        self.contextYear = contextYear
        self.availableYears = availableYears
        self.availableDecades = availableDecades
        self.actorSuggestions = actorSuggestions
        self.directorSuggestions = directorSuggestions
        self.availableGenres = availableGenres
        self.onCancel = onCancel
        self.onSave = onSave

        _target = State(initialValue: initialGoal.target)
        _startYear = State(initialValue: initialGoal.startYear)
        _durationYears = State(initialValue: max(1, initialGoal.durationYears))

        switch initialGoal.rule {
        case .releaseDecade(let d):
            _decadeStart = State(initialValue: d)

        case .person(let id, let name, let profilePath):
            _selectedPersonId = State(initialValue: id)
            _selectedPersonName = State(initialValue: name)
            _selectedProfilePath = State(initialValue: profilePath)

        case .director(let id, let name, let profilePath):
            _selectedPersonId = State(initialValue: id)
            _selectedPersonName = State(initialValue: name)
            _selectedProfilePath = State(initialValue: profilePath)

        case .genre(let id, let name):
            _selectedGenreId = State(initialValue: id)
            _selectedGenreName = State(initialValue: name)

        case .keyword(let id, let name):
            _selectedKeywordId = State(initialValue: id)
            _selectedKeywordName = State(initialValue: name)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                CustomGoalTargetSection(target: $target)
                CustomGoalValiditySection(
                    startYear: $startYear,
                    durationYears: $durationYears,
                    availableYears: availableYears,
                    validityLabel: validityLabel
                )

                switch initialGoal.type {
                case .decade:
                    CustomGoalDecadeSection(
                        decadeStart: $decadeStart,
                        availableDecades: availableDecades
                    )

                case .person:
                    CustomGoalPersonSection(
                        title: "Darsteller",
                        placeholder: "Name suchen …",
                        suggestions: actorSuggestions,
                        preferDepartment: nil,
                        personQuery: $personQuery,
                        isSearchingPerson: $isSearchingPerson,
                        personResults: $personResults,
                        selectedPersonId: $selectedPersonId,
                        selectedPersonName: $selectedPersonName,
                        selectedProfilePath: $selectedProfilePath,
                        onQueryChanged: { newValue in
                            Task { await searchPersonIfNeeded(query: newValue, preferDepartment: nil) }
                        }
                    )

                case .director:
                    CustomGoalPersonSection(
                        title: "Regie",
                        placeholder: "Regisseur suchen …",
                        suggestions: directorSuggestions,
                        preferDepartment: "Directing",
                        personQuery: $personQuery,
                        isSearchingPerson: $isSearchingPerson,
                        personResults: $personResults,
                        selectedPersonId: $selectedPersonId,
                        selectedPersonName: $selectedPersonName,
                        selectedProfilePath: $selectedProfilePath,
                        onQueryChanged: { newValue in
                            Task { await searchPersonIfNeeded(query: newValue, preferDepartment: "Directing") }
                        }
                    )

                case .genre:
                    CustomGoalGenreSection(
                        selectedGenreId: $selectedGenreId,
                        selectedGenreName: $selectedGenreName,
                        availableGenres: availableGenres
                    )

                case .keyword:
                    CustomGoalKeywordSection(
                        keywordQuery: $keywordQuery,
                        isSearchingKeyword: $isSearchingKeyword,
                        keywordResults: $keywordResults,
                        selectedKeywordId: $selectedKeywordId,
                        selectedKeywordName: $selectedKeywordName,
                        onQueryChanged: { newValue in
                            Task { await searchKeywordIfNeeded(query: newValue) }
                        }
                    )
                }
            }
            .navigationTitle("Ziel bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        onSave(buildUpdatedGoal())
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var validityLabel: String {
        let endYear = startYear + max(1, durationYears) - 1
        if durationYears <= 1 {
            return "Dieses Ziel wird nur im Jahr \(startYear) getrackt."
        }
        return "Dieses Ziel wird von \(startYear) bis \(endYear) getrackt."
    }

    // MARK: - Networking

    private func searchPersonIfNeeded(query: String, preferDepartment: String?) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            await MainActor.run { personResults = [] }
            return
        }

        await MainActor.run { isSearchingPerson = true }
        defer { Task { @MainActor in isSearchingPerson = false } }

        do {
            let results = try await TMDbAPI.shared.searchPerson(name: trimmed)
            await MainActor.run {
                // Für Directors gerne Directing zuerst – aber alles anzeigen
                personResults = results
            }
        } catch {
            await MainActor.run { personResults = [] }
        }
    }

    private func searchKeywordIfNeeded(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            await MainActor.run { keywordResults = [] }
            return
        }

        await MainActor.run { isSearchingKeyword = true }
        defer { Task { @MainActor in isSearchingKeyword = false } }

        do {
            let results = try await TMDbAPI.shared.searchKeywords(query: trimmed)
            await MainActor.run {
                keywordResults = Array(results.prefix(20))
            }
        } catch {
            await MainActor.run { keywordResults = [] }
        }
    }

    // MARK: - Build / Validation

    private var canSave: Bool {
        if target < 1 { return false }
        switch initialGoal.type {
        case .decade:
            return true
        case .person:
            return selectedPersonId > 0 && !selectedPersonName.isEmpty
        case .director:
            return selectedPersonId > 0 && !selectedPersonName.isEmpty
        case .genre:
            return selectedGenreId != 0 && !selectedGenreName.isEmpty
        case .keyword:
            return selectedKeywordId > 0 && !selectedKeywordName.isEmpty
        }
    }

    private func buildUpdatedGoal() -> ViewingCustomGoal {
        var updated = initialGoal
        updated.target = target
        updated.startYear = startYear
        updated.durationYears = max(1, durationYears)

        switch initialGoal.type {
        case .decade:
            updated.type = .decade
            updated.rule = .releaseDecade(decadeStart)

        case .person:
            updated.type = .person
            updated.rule = .person(id: selectedPersonId, name: selectedPersonName, profilePath: selectedProfilePath)

        case .director:
            updated.type = .director
            updated.rule = .director(id: selectedPersonId, name: selectedPersonName, profilePath: selectedProfilePath)

        case .genre:
            updated.type = .genre
            updated.rule = .genre(id: selectedGenreId, name: selectedGenreName)

        case .keyword:
            updated.type = .keyword
            updated.rule = .keyword(id: selectedKeywordId, name: selectedKeywordName)
        }

        return updated
    }
}
