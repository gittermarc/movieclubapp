//
//  StatsView+Drilldowns.swift
//  filmfreaks
//
//  Drilldown sheets (month/location/suggestedBy/critics) for StatsView.
//

internal import SwiftUI

extension StatsView {

    // MARK: - Drilldown Sheets

    @ViewBuilder
    func drilldownMoviesSheet(_ drilldown: StatsDrilldown) -> some View {
        switch drilldown {
        case .month(let date):
            drilldownMoviesSheetMonth(date)
        case .location(let loc):
            drilldownMoviesSheetLocation(loc)
        case .suggestedBy(let name):
            drilldownMoviesSheetSuggestedBy(name)
        case .critics(let kind):
            drilldownMoviesSheetCritics(kind)
        }
    }

    @ViewBuilder
    func drilldownMoviesSheetMonth(_ date: Date) -> some View {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: date)
        let year = comps.year ?? 0
        let month = comps.month ?? 0

        let movies = filteredMovies.filter { movie in
            guard let d = movie.watchedDate else { return false }
            let c = calendar.dateComponents([.year, .month], from: d)
            return (c.year == year && c.month == month)
        }

        NavigationStack {
            List {
                if movies.isEmpty {
                    Text("Keine Filme in diesem Monat.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(movies) { movie in
                        movieRow(movie)
                    }
                }
            }
            .navigationTitle(Self.monthFormatter.string(from: date))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { selectedDrilldown = nil }
                }
            }
        }
    }

    @ViewBuilder
    func drilldownMoviesSheetLocation(_ loc: String) -> some View {
        let movies = filteredMovies.filter { normalizedLocation(for: $0) == loc }

        NavigationStack {
            List {
                if movies.isEmpty {
                    Text("Keine Filme an diesem Ort.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(movies) { movie in
                        movieRow(movie)
                    }
                }
            }
            .navigationTitle(loc)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { selectedDrilldown = nil }
                }
            }
        }
    }

    @ViewBuilder
    func drilldownMoviesSheetSuggestedBy(_ name: String) -> some View {
        let movies = filteredMovies.filter { ($0.suggestedBy ?? "").lowercased() == name.lowercased() }

        NavigationStack {
            List {
                if movies.isEmpty {
                    Text("Keine Filme für diese Person.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(movies) { movie in
                        movieRow(movie)
                    }
                }
            }
            .navigationTitle("Vorgeschlagen von")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { selectedDrilldown = nil }
                }
            }
        }
    }

    @ViewBuilder
    func drilldownMoviesSheetCritics(_ kind: StatsCriticGapKind) -> some View {
        let entries: [CriticGapEntry] = {
            switch kind {
            case .groupHigher:
                return criticGapGroupHigher
            case .groupLower:
                return criticGapGroupLower
            }
        }()

        NavigationStack {
            List {
                Section {
                    if entries.isEmpty {
                        Text("Keine Filme im aktuellen Filter.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(entries) { entry in
                            criticGapRow(entry, kind: kind)
                        }
                    }
                } header: {
                    Text(kind.helpText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(kind.sheetTitle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { selectedDrilldown = nil }
                }
            }
        }
    }
}
