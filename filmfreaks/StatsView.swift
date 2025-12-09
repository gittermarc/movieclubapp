//
//  StatsView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 29.11.25.
//

internal import SwiftUI

enum StatsTimeRange: String, CaseIterable, Identifiable {
    case last30 = "Letzte 30 Tage"
    case last90 = "Letzte 90 Tage"
    case thisYear = "Dieses Jahr"
    case all = "Gesamte Zeit"
    
    var id: Self { self }
}

struct StatsView: View {
    
    @EnvironmentObject var movieStore: MovieStore
    @EnvironmentObject var userStore: UserStore
    
    @State private var selectedRange: StatsTimeRange = .all
    @State private var selectedLocationFilter: String? = nil
    
    // Eigener Formatter für das "Zuletzt geschaut"-Feld
    private static let recentDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df
    }()
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                List {
                    // MARK: - Kontext & Filter
                    
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            
                            // Aktuelle Gruppe / Kontext
                            if let groupName = movieStore.currentGroupName {
                                Text("Statistiken für „\(groupName)“")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Statistiken für deine aktuelle Gruppe")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Filter-Panel
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Filter")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                // 👇 NEU: Zeitbereich als Chips
                                Text("Zeitraum")
                                    .font(.subheadline)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(StatsTimeRange.allCases) { range in
                                            let isSelected = (range == selectedRange)
                                            
                                            Button {
                                                selectedRange = range
                                            } label: {
                                                Text(range.rawValue)
                                                    .font(.caption)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 6)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 999)
                                                            .fill(
                                                                isSelected
                                                                ? Color.accentColor.opacity(0.18)
                                                                : Color.gray.opacity(0.12)
                                                            )
                                                    )
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 999)
                                                            .strokeBorder(
                                                                isSelected
                                                                ? Color.accentColor
                                                                : Color.clear,
                                                                lineWidth: 1
                                                            )
                                                    )
                                                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                                            }
                                        }
                                    }
                                }
                                
                                HStack {
                                    Text("Ort")
                                        .font(.subheadline)
                                    
                                    Menu {
                                        Button("Alle") {
                                            selectedLocationFilter = nil
                                        }
                                        
                                        if availableLocations.isEmpty {
                                            Text("Keine Orte im Zeitraum")
                                        } else {
                                            ForEach(availableLocations, id: \.self) { loc in
                                                Button(loc) {
                                                    selectedLocationFilter = loc
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(selectedLocationFilter ?? "Alle")
                                            Image(systemName: "chevron.down")
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.gray.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    
                                    Spacer()
                                }
                                
                                Text("Diese Filter wirken auf alle Statistiken unten.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // MARK: - Dashboard-Überblick
                    
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Überblick")
                                .font(.headline)
                            
                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible())],
                                spacing: 12
                            ) {
                                // Gesehene Filme
                                statsCard(
                                    title: "Gesehene Filme",
                                    subtitle: "mit Datum im Zeitraum",
                                    value: "\(filteredMovies.count)",
                                    icon: "film"
                                )
                                
                                // Backlog
                                statsCard(
                                    title: "Backlog",
                                    subtitle: "offene Filme",
                                    value: "\(movieStore.backlogMovies.count)",
                                    icon: "tray.full"
                                )
                                
                                // Durchschnitt
                                statsCard(
                                    title: "Ø Bewertung",
                                    subtitle: "aller Ratings",
                                    value: overallAverageRating.map { String(format: "%.1f", $0) } ?? "–",
                                    icon: "star.leadinghalf.filled"
                                )
                                
                                // Zuletzt geschaut
                                statsCard(
                                    title: "Zuletzt geschaut",
                                    subtitle: "mit Datum",
                                    value: mostRecentWatchedDate.map { Self.recentDateFormatter.string(from: $0) } ?? "–",
                                    icon: "clock.arrow.circlepath"
                                )
                            }
                            
                            if let loc = selectedLocationFilter {
                                Text("Gefiltert nach Ort: \(loc)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // MARK: - Filme pro Monat
                    
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Filme pro Monat")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "calendar")
                                    .foregroundStyle(.secondary)
                            }
                            
                            if moviesPerMonth.isEmpty {
                                Text("Keine Filme im ausgewählten Zeitraum/Ort.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(moviesPerMonth, id: \.date) { entry in
                                    HStack {
                                        Text(monthFormatter.string(from: entry.date))
                                        Spacer()
                                        Text("\(entry.count) Filme")
                                            .font(.footnote)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // MARK: - Genres
                    
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Genres")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "square.stack.3d.up")
                                    .foregroundStyle(.secondary)
                            }
                            
                            if moviesByGenre.isEmpty {
                                Text("Keine Genres im ausgewählten Zeitraum/Ort.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Eure häufigsten Genres")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 90), spacing: 8)],
                                    alignment: .leading,
                                    spacing: 8
                                ) {
                                    ForEach(moviesByGenre.prefix(30), id: \.genre) { entry in
                                        HStack(spacing: 6) {
                                            Text(entry.genre)
                                                .font(.caption)
                                                .lineLimit(1)
                                            Text("(\(entry.count))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.12))
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // MARK: - Darsteller
                    
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Darsteller")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "person.2.fill")
                                    .foregroundStyle(.secondary)
                            }
                            
                            if actorsByCount.isEmpty {
                                Text("Keine Cast-Daten im ausgewählten Zeitraum/Ort.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Wen ihr am häufigsten seht")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 120), spacing: 8)],
                                    alignment: .leading,
                                    spacing: 8
                                ) {
                                    ForEach(actorsByCount.prefix(30), id: \.actor) { entry in
                                        HStack(spacing: 6) {
                                            Text(entry.actor)
                                                .font(.caption)
                                                .lineLimit(1)
                                            Text("(\(entry.count))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.12))
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // MARK: - Orte
                    
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Orte")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundStyle(.secondary)
                            }
                            
                            if moviesByLocation.isEmpty {
                                Text("Keine Filme im ausgewählten Zeitraum.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(moviesByLocation, id: \.location) { entry in
                                    HStack {
                                        Text(entry.location)
                                        Spacer()
                                        Text("\(entry.count)")
                                            .font(.footnote)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.gray.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // MARK: - Vorgeschlagen von
                    
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Vorgeschlagen von")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "person.fill.questionmark")
                                    .foregroundStyle(.secondary)
                            }
                            
                            if suggestionsByUser.isEmpty {
                                Text("Keine Vorschläge im ausgewählten Zeitraum/Ort.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(suggestionsByUser, id: \.name) { entry in
                                    HStack {
                                        Text(entry.name)
                                        Spacer()
                                        Text("\(entry.count)")
                                            .font(.footnote)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.orange.opacity(0.15))
                                            .clipShape(Capsule())
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // MARK: - Pro Person
                    
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Bewertungen pro Person")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "person.3.sequence.fill")
                                    .foregroundStyle(.secondary)
                            }
                            
                            if userStore.users.isEmpty {
                                Text("Noch keine Mitglieder in der Filmgruppe.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(userStore.users) { user in
                                        let stats = statsForUser(user)
                                        
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(user.name)
                                                    .font(.subheadline.weight(.semibold))
                                                Text("\(stats.movieCount) Filme bewertet")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            if let avg = stats.averageRating {
                                                Text(String(format: "%.1f", avg))
                                                    .font(.headline)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(Color.blue.opacity(0.12))
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                            } else {
                                                Text("–")
                                                    .font(.headline)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .padding(10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(.secondarySystemBackground))
                                        )
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .navigationTitle("Statistiken")
            }
        }
    }
    
    // MARK: - Kleine Helfer-View für Dashboard-Karten
    
    private func statsCard(
        title: String,
        subtitle: String,
        value: String,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            
            Text(value)
                .font(.title2.bold())
            
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Basis & Filter
    
    private var moviesForCurrentTimeRange: [Movie] {
        let calendar = Calendar.current
        let today = Date()
        
        return movieStore.movies.compactMap { movie in
            guard let date = movie.watchedDate else { return nil }
            
            switch selectedRange {
            case .all:
                return movie
            case .thisYear:
                if calendar.isDate(date, equalTo: today, toGranularity: .year) {
                    return movie
                }
            case .last30:
                if let from = calendar.date(byAdding: .day, value: -30, to: today),
                   date >= from {
                    return movie
                }
            case .last90:
                if let from = calendar.date(byAdding: .day, value: -90, to: today),
                   date >= from {
                    return movie
                }
            }
            return nil
        }
    }
    
    private var filteredMovies: [Movie] {
        guard let loc = selectedLocationFilter else {
            return moviesForCurrentTimeRange
        }
        return moviesForCurrentTimeRange.filter { normalizedLocation(for: $0) == loc }
    }
    
    private var availableLocations: [String] {
        let locations = moviesForCurrentTimeRange.map { normalizedLocation(for: $0) }
        let unique = Set(locations)
        return Array(unique).sorted()
    }
    
    private func normalizedLocation(for movie: Movie) -> String {
        let trimmed = movie.watchedLocation?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""
        return trimmed.isEmpty ? "Ohne Angabe" : trimmed
    }
    
    // MARK: - Aggregationen
    
    private var overallAverageRating: Double? {
        let allScores = filteredMovies.flatMap { movie in
            movie.ratings.map { $0.averageScoreNormalizedTo10 }
        }
        guard !allScores.isEmpty else { return nil }
        let total = allScores.reduce(0, +)
        return total / Double(allScores.count)
    }
    
    private var mostRecentWatchedDate: Date? {
        let dates = filteredMovies.compactMap { $0.watchedDate }
        return dates.max()
    }
    
    private var moviesPerMonth: [(date: Date, count: Int)] {
        let calendar = Calendar.current
        var counts: [Date: Int] = [:]
        
        for movie in filteredMovies {
            guard let date = movie.watchedDate else { continue }
            if let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) {
                counts[monthStart, default: 0] += 1
            }
        }
        
        return counts
            .map { (date: $0.key, count: $0.value) }
            .sorted { $0.date > $1.date }
    }
    
    private var moviesByGenre: [(genre: String, count: Int)] {
        var counts: [String: Int] = [:]
        
        for movie in filteredMovies {
            guard let genres = movie.genres else { continue }
            for g in genres {
                let name = g.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }
                counts[name, default: 0] += 1
            }
        }
        
        return counts
            .map { (genre: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    private var actorsByCount: [(actor: String, count: Int)] {
        var counts: [String: Int] = [:]
        
        for movie in filteredMovies {
            guard let cast = movie.cast else { continue }
            for name in cast {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                counts[trimmed, default: 0] += 1
            }
        }
        
        return counts
            .map { (actor: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    private var moviesByLocation: [(location: String, count: Int)] {
        var counts: [String: Int] = [:]
        
        for movie in filteredMovies {
            let loc = normalizedLocation(for: movie)
            counts[loc, default: 0] += 1
        }
        
        return counts
            .map { (location: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    private var suggestionsByUser: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        
        for movie in filteredMovies {
            guard let raw = movie.suggestedBy else { continue }
            let sugg = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sugg.isEmpty else { continue }
            counts[sugg, default: 0] += 1
        }
        
        return counts
            .map { (name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    private var monthFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy"
        return df
    }
    
    private func statsForUser(_ user: User) -> (movieCount: Int, averageRating: Double?) {
        var movieIds = Set<UUID>()
        var scores: [Double] = []
        
        for movie in filteredMovies {
            let userRatings = movie.ratings.filter { $0.reviewerName == user.name }
            if !userRatings.isEmpty {
                movieIds.insert(movie.id)
                scores.append(contentsOf: userRatings.map { $0.averageScoreNormalizedTo10 })
            }
        }
        
        guard !scores.isEmpty else {
            return (movieIds.count, nil)
        }
        
        let total = scores.reduce(0, +)
        let avg = total / Double(scores.count)
        return (movieIds.count, avg)
    }
}

#Preview {
    NavigationStack {
        StatsView()
            .environmentObject(MovieStore.preview())
            .environmentObject(UserStore())
    }
}

