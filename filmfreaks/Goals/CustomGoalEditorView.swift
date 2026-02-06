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

                Section("Ziel") {
                    Stepper(value: $target, in: 1...500) {
                        Text("\(target) Filme")
                    }
                }

                Section("Gültigkeit") {
                    Picker("Startjahr", selection: $startYear) {
                        ForEach(availableYears, id: \.self) { y in
                            Text(verbatim: "\(y)").tag(y)
                        }
                    }

                    Stepper(value: $durationYears, in: 1...20) {
                        let endYear = startYear + durationYears - 1
                        if durationYears <= 1 {
                            Text(verbatim: "Dauer: 1 Jahr (\(startYear))")
                        } else {
                            Text(verbatim: "Dauer: \(durationYears) Jahre (\(startYear)–\(endYear))")
                        }
                    }

                    Text(validityLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                switch initialGoal.type {
                case .decade:
                    decadeEditor

                case .person:
                    personEditor(
                        title: "Darsteller",
                        placeholder: "Name suchen …",
                        suggestions: actorSuggestions,
                        preferDepartment: nil
                    )

                case .director:
                    personEditor(
                        title: "Regie",
                        placeholder: "Regisseur suchen …",
                        suggestions: directorSuggestions,
                        preferDepartment: "Directing"
                    )

                case .genre:
                    genreEditor

                case .keyword:
                    keywordEditor
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

    // MARK: - Editor Sections

    private var decadeEditor: some View {
        Section("Decade") {
            Picker("Jahrzehnt", selection: $decadeStart) {
                ForEach(availableDecades, id: \.self) { d in
                        // `Text("\(d)")` inside SwiftUI can localize numbers (e.g. "1.950").
                        // We want plain digits for years.
                        Text(verbatim: "\(d)–\(d + 9)").tag(d)
                }
            }
        }
    }

    private func personEditor(
        title: String,
        placeholder: String,
        suggestions: [PersonSuggestion],
        preferDepartment: String?
    ) -> some View {
        Section(title) {
            VStack(alignment: .leading, spacing: 10) {
                TextField(placeholder, text: $personQuery)
                    .textInputAutocapitalization(.words)
                    .onChange(of: personQuery) { _, newValue in
                        Task { await searchPersonIfNeeded(query: newValue, preferDepartment: preferDepartment) }
                    }

                if selectedPersonId > 0 {
                    HStack(spacing: 10) {
                        if let p = selectedProfilePath, let url = URL(string: "https://image.tmdb.org/t/p/w185\(p)") {
                            CachedAsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    RoundedRectangle(cornerRadius: 8).foregroundStyle(.gray.opacity(0.15))
                                        .overlay { ProgressView() }
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                case .failure:
                                    RoundedRectangle(cornerRadius: 8).foregroundStyle(.gray.opacity(0.15))
                                        .overlay { Image(systemName: "person.fill").foregroundStyle(.secondary) }
                                @unknown default:
                                    RoundedRectangle(cornerRadius: 8).foregroundStyle(.gray.opacity(0.15))
                                }
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .foregroundStyle(.gray.opacity(0.15))
                                .frame(width: 40, height: 40)
                                .overlay { Image(systemName: "person.fill").foregroundStyle(.secondary) }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedPersonName)
                                .font(.subheadline.weight(.semibold))
                            Text("Ausgewählt")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button(role: .destructive) {
                            selectedPersonId = 0
                            selectedPersonName = ""
                            selectedProfilePath = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }

                if isSearchingPerson {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Suche …").font(.caption).foregroundStyle(.secondary)
                    }
                }

                if personQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, selectedPersonId == 0 {
                    if !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(verbatim: "Vorschläge aus \(Calendar.current.component(.year, from: Date())) / deiner Auswahl:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                // Use `enumerated()` as the identity so taps stay correct even if
                                // we accidentally have duplicate personIds in suggestions.
                                ForEach(Array(suggestions.enumerated()), id: \.offset) { _, s in
                                    Button {
                                        selectedPersonId = s.personId
                                        selectedPersonName = s.name
                                        selectedProfilePath = s.profilePath
                                    } label: {
                                        HStack {
                                            Text(s.name)
                                            Spacer()
                                            Text("\(s.count)x")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                        }
                    } else {
                        Text("Tipp: Such oben nach einem Namen oder öffne ein paar Filmdetails, damit Cast/Regie lokal gespeichert wird.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    if !personResults.isEmpty {
                            ForEach(filteredPersonResults(preferDepartment: preferDepartment)) { p in
                                Button {
                                    selectedPersonId = p.id
                                    selectedPersonName = p.name
                                    selectedProfilePath = p.profile_path
                                    personQuery = ""
                                    personResults = []
                                } label: {
                                    HStack(spacing: 10) {
                                    if let path = p.profile_path, let url = URL(string: "https://image.tmdb.org/t/p/w185\(path)") {
                                        CachedAsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                RoundedRectangle(cornerRadius: 8).foregroundStyle(.gray.opacity(0.15))
                                                    .overlay { ProgressView() }
                                            case .success(let image):
                                                image.resizable().scaledToFill()
                                            case .failure:
                                                RoundedRectangle(cornerRadius: 8).foregroundStyle(.gray.opacity(0.15))
                                                    .overlay { Image(systemName: "person.fill").foregroundStyle(.secondary) }
                                            @unknown default:
                                                RoundedRectangle(cornerRadius: 8).foregroundStyle(.gray.opacity(0.15))
                                            }
                                        }
                                        .frame(width: 34, height: 34)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .foregroundStyle(.gray.opacity(0.15))
                                            .frame(width: 34, height: 34)
                                            .overlay { Image(systemName: "person.fill").foregroundStyle(.secondary) }
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(p.name)
                                        if let dep = p.known_for_department, !dep.isEmpty {
                                            Text(dep)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                        }
                    } else if !personQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isSearchingPerson {
                        Text("Keine Treffer.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var genreEditor: some View {
        Section("Genre") {
            if availableGenres.isEmpty {
                Text("Keine Genres verfügbar. (TMDb konnte nicht geladen werden)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Genre", selection: Binding(
                    get: { selectedGenreId },
                    set: { newValue in
                        selectedGenreId = newValue
                        selectedGenreName = availableGenres.first(where: { $0.id == newValue })?.name ?? ""
                    }
                )) {
                    ForEach(availableGenres) { g in
                        Text(g.name).tag(g.id)
                    }
                }
                .onAppear {
                    if selectedGenreId == 0 {
                        selectedGenreId = availableGenres.first?.id ?? 0
                        selectedGenreName = availableGenres.first?.name ?? ""
                    }
                }
            }
        }
    }

    private var keywordEditor: some View {
        Section("Keyword") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Keyword suchen …", text: $keywordQuery)
                    .textInputAutocapitalization(.never)
                    .onChange(of: keywordQuery) { _, newValue in
                        Task { await searchKeywordIfNeeded(query: newValue) }
                    }

                if selectedKeywordId > 0 {
                    HStack {
                        Text(selectedKeywordName)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Button(role: .destructive) {
                            selectedKeywordId = 0
                            selectedKeywordName = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }

                if isSearchingKeyword {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Suche …").font(.caption).foregroundStyle(.secondary)
                    }
                }

                    if !keywordResults.isEmpty {
                        // Use `enumerated()` as identity to avoid any weirdness if TMDb ever returns duplicates.
                        ForEach(Array(keywordResults.enumerated()), id: \.offset) { _, k in
                            Button {
                                selectedKeywordId = k.id
                                selectedKeywordName = k.name
                                keywordQuery = ""
                                keywordResults = []
                            } label: {
                                HStack {
                                    Text(k.name)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } else if !keywordQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isSearchingKeyword {
                    Text("Keine Treffer.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    private func filteredPersonResults(preferDepartment: String?) -> [TMDbPersonSummary] {
        guard let preferDepartment, !preferDepartment.isEmpty else { return personResults }
        let preferred = personResults.filter { ($0.known_for_department ?? "").lowercased() == preferDepartment.lowercased() }
        let rest = personResults.filter { ($0.known_for_department ?? "").lowercased() != preferDepartment.lowercased() }
        return preferred + rest
    }

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
