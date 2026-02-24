//
//  CustomGoalEditorSections.Basic.swift
//  filmfreaks
//

internal import SwiftUI

struct CustomGoalTargetSection: View {

    @Binding var target: Int

    var body: some View {
        Section("Ziel") {
            Stepper(value: $target, in: 1...500) {
                Text("\(target) Filme")
            }
        }
    }
}

struct CustomGoalValiditySection: View {

    @Binding var startYear: Int
    @Binding var durationYears: Int
    let availableYears: [Int]
    let validityLabel: String

    var body: some View {
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
    }
}

struct CustomGoalDecadeSection: View {

    @Binding var decadeStart: Int
    let availableDecades: [Int]

    var body: some View {
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
}

struct CustomGoalGenreSection: View {

    @Binding var selectedGenreId: Int
    @Binding var selectedGenreName: String
    let availableGenres: [TMDbGenre]

    var body: some View {
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
}
