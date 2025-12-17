//
//  GoalsView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 17.12.25.
//

internal import SwiftUI

struct GoalsView: View {
    
    @EnvironmentObject var movieStore: MovieStore
    @EnvironmentObject var userStore: UserStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var goalsByYear: [Int: Int] = [:]
    @State private var isSyncingGoals: Bool = false
    
    private let storageKey = "ViewingGoalsByYear"
    private let defaultGoal = 50
    
    // MARK: - Abgeleitete Werte
    
    private var availableYears: [Int] {
        let calendar = Calendar.current
        
        let yearsFromMovies = movieStore.movies.compactMap { movie -> Int? in
            guard let date = movie.watchedDate else { return nil }
            return calendar.component(.year, from: date)
        }
        
        let yearsFromGoals = goalsByYear.keys
        
        var set = Set<Int>(yearsFromMovies + yearsFromGoals)
        let currentYear = Calendar.current.component(.year, from: Date())
        set.insert(currentYear)
        
        return Array(set).sorted()
    }
    
    private var moviesInSelectedYear: [Movie] {
        let calendar = Calendar.current
        return movieStore.movies.compactMap { movie in
            guard let date = movie.watchedDate else { return nil }
            let year = calendar.component(.year, from: date)
            return year == selectedYear ? movie : nil
        }
        .sorted { ($0.watchedDate ?? .distantPast) > ($1.watchedDate ?? .distantPast) }
    }
    
    private var targetForSelectedYear: Int {
        goalsByYear[selectedYear] ?? defaultGoal
    }
    
    private var progressText: String {
        let seen = moviesInSelectedYear.count
        let target = max(targetForSelectedYear, 1)
        let percent = (Double(seen) / Double(target)) * 100.0
        return String(format: "%.0f %% erreicht", min(percent, 100.0))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        
                        // Header / Filter
                        headerSection
                        
                        // Grid mit Postern / Platzhaltern
                        gridSection
                        
                        Spacer(minLength: 16)
                    }
                    .padding()
                }
                
                // Optional: kleiner Sync-Indikator für Ziele
                if isSyncingGoals {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Ziele werden synchronisiert …")
                                    .font(.caption)
                            }
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(radius: 4)
                            .padding()
                        }
                    }
                    .transition(.opacity)
                }
            }
            .navigationTitle("Ziele")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadGoals()
                
                // Sicherstellen, dass ein Jahr gewählt ist, das es gibt
                if !availableYears.contains(selectedYear),
                   let first = availableYears.first {
                    selectedYear = first
                }
            }
        }
    }
    
    // MARK: - Header / Ziel-Einstellungen
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Jahr-Auswahl als Chips
            VStack(alignment: .leading, spacing: 6) {
                Text("Jahr")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableYears, id: \.self) { year in
                            let isSelected = year == selectedYear
                            
                            Button {
                                selectedYear = year
                            } label: {
                                Text(String(year))
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 999)
                                            .fill(
                                                isSelected
                                                ? Color.accentColor.opacity(0.2)
                                                : Color.gray.opacity(0.15)
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 999)
                                            .strokeBorder(
                                                isSelected ? Color.accentColor : .clear,
                                                lineWidth: 1
                                            )
                                    )
                                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                            }
                        }
                    }
                }
            }
            
            // Ziel-Definition
            VStack(alignment: .leading, spacing: 8) {
                Text("Ziel für \(selectedYear.formatted(.number.grouping(.never)))")
                    .font(.headline)
                
                HStack {
                    let binding = Binding<Int>(
                        get: { targetForSelectedYear },
                        set: { newValue in
                            let clamped = max(newValue, 1)
                            goalsByYear[selectedYear] = clamped
                            goalChanged(forYear: selectedYear, target: clamped)
                        }
                    )
                    
                    Stepper(value: binding, in: 1...500) {
                        Text("\(binding.wrappedValue) Filme")
                            .font(.subheadline)
                    }
                    
                    Spacer()
                }
                
                let seen = moviesInSelectedYear.count
                let target = max(targetForSelectedYear, 1)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bisher gesehen: \(seen) von \(targetForSelectedYear)")
                        .font(.subheadline)
                    
                    // Kleine „Progress-Bar“
                    GeometryReader { geo in
                        let width = geo.size.width
                        let fraction = min(Double(seen) / Double(target), 1.0)
                        let filledWidth = width * fraction
                        
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.2))
                            
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor.opacity(0.7))
                                .frame(width: max(0, filledWidth))
                        }
                    }
                    .frame(height: 8)
                    
                    Text(progressText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    
    // MARK: - Grid mit Covern / Platzhaltern
    
    private var gridSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Filme in \(selectedYear.formatted(.number.grouping(.never)))")
                .font(.headline)
            
            let seenMovies = moviesInSelectedYear
            let target = max(targetForSelectedYear, seenMovies.count)
            
            if target == 0 {
                Text("Lege oben ein Ziel fest, um mit der Challenge zu starten.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                // Adaptive Spalten, damit Poster immer im typischen Portrait-Format bleiben
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 80, maximum: 110), spacing: 8)],
                    spacing: 12
                ) {
                    ForEach(0..<target, id: \.self) { index in
                        if index < seenMovies.count {
                            let movie = seenMovies[index]
                            
                            if let binding = binding(for: movie) {
                                NavigationLink {
                                    MovieDetailView(movie: binding, isBacklog: false)
                                } label: {
                                    posterTile(for: movie)
                                }
                                .buttonStyle(.plain)
                            } else {
                                // Fallback: wenn wir aus irgendeinem Grund kein Binding finden
                                posterTile(for: movie)
                            }
                            
                        } else {
                            placeholderTile()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Binding-Helfer
    
    /// Sucht den Movie im Store und gibt ein Binding darauf zurück,
    /// damit Änderungen in der Detail-View sauber im Store landen.
    private func binding(for movie: Movie) -> Binding<Movie>? {
        guard let index = movieStore.movies.firstIndex(where: { $0.id == movie.id }) else {
            return nil
        }
        return $movieStore.movies[index]
    }
    
    // MARK: - Kacheln
    
    @ViewBuilder
    private func posterTile(for movie: Movie) -> some View {
        VStack(spacing: 4) {
            if let url = movie.posterURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .foregroundStyle(.gray.opacity(0.2))
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Rectangle()
                            .foregroundStyle(.gray.opacity(0.2))
                            .overlay {
                                Image(systemName: "film")
                                    .foregroundStyle(.secondary)
                            }
                    @unknown default:
                        Rectangle()
                            .foregroundStyle(.gray.opacity(0.2))
                    }
                }
                // Typisches Movie-Cover: 2:3 Portrait-Format
                .aspectRatio(2.0 / 3.0, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Rectangle()
                    .foregroundStyle(.gray.opacity(0.15))
                    .aspectRatio(2.0 / 3.0, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        Image(systemName: "film")
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }
    
    @ViewBuilder
    private func placeholderTile() -> some View {
        Rectangle()
            .foregroundStyle(.gray.opacity(0.08))
            .aspectRatio(2.0 / 3.0, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: "popcorn")
                        .font(.title3)
                    Text("frei")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
    }
    
    // MARK: - Persistence (lokal + CloudKit)
    
    /// Lokale Ziele laden + aus CloudKit nachziehen
    private func loadGoals() {
        // 1. Lokal (Cache)
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Int: Int].self, from: data) {
            goalsByYear = decoded
        } else {
            goalsByYear = [:]
        }
        
        // 2. CloudKit für aktuelle Gruppe
        let groupId = movieStore.currentGroupId ?? ""
        
        isSyncingGoals = true
        Task {
            do {
                let remote = try await CloudKitGoalStore.shared.fetchGoals(forGroupId: groupId)
                await MainActor.run {
                    self.goalsByYear = remote
                    self.saveGoalsToCache()
                    self.isSyncingGoals = false
                }
            } catch {
                print("CloudKit ViewingGoal fetch error: \(error)")
                await MainActor.run {
                    self.isSyncingGoals = false
                }
            }
        }
    }
    
    /// Nur lokalen Cache aktualisieren
    private func saveGoalsToCache() {
        if let data = try? JSONEncoder().encode(goalsByYear) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    /// Reagiert auf eine Änderung des Ziels für ein bestimmtes Jahr.
    private func goalChanged(forYear year: Int, target: Int) {
        saveGoalsToCache()
        let groupId = movieStore.currentGroupId ?? ""
        
        isSyncingGoals = true
        Task {
            do {
                try await CloudKitGoalStore.shared.saveGoal(year: year, target: target, groupId: groupId)
            } catch {
                print("CloudKit ViewingGoal save error: \(error)")
            }
            await MainActor.run {
                self.isSyncingGoals = false
            }
        }
    }
}

#Preview {
    GoalsView()
        .environmentObject(MovieStore.preview())
        .environmentObject(UserStore())
}
