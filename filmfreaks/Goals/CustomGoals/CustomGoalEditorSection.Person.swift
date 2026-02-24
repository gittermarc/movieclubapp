//
//  CustomGoalEditorSection.Person.swift
//  filmfreaks
//

internal import SwiftUI

struct CustomGoalPersonSection: View {

    let title: String
    let placeholder: String
    let suggestions: [PersonSuggestion]
    let preferDepartment: String?

    @Binding var personQuery: String
    @Binding var isSearchingPerson: Bool
    @Binding var personResults: [TMDbPersonSummary]
    @Binding var selectedPersonId: Int
    @Binding var selectedPersonName: String
    @Binding var selectedProfilePath: String?

    let onQueryChanged: (String) -> Void

    var body: some View {
        Section(title) {
            VStack(alignment: .leading, spacing: 10) {
                TextField(placeholder, text: $personQuery)
                    .textInputAutocapitalization(.words)
                    .onChange(of: personQuery) { _, newValue in
                        onQueryChanged(newValue)
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
                        ForEach(filteredPersonResults()) { p in
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

    private func filteredPersonResults() -> [TMDbPersonSummary] {
        guard let preferDepartment, !preferDepartment.isEmpty else { return personResults }
        let preferred = personResults.filter { ($0.known_for_department ?? "").lowercased() == preferDepartment.lowercased() }
        let rest = personResults.filter { ($0.known_for_department ?? "").lowercased() != preferDepartment.lowercased() }
        return preferred + rest
    }
}
