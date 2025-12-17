//
//  GoalsView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 17.12.25.
//


internal import SwiftUI

struct GoalsView: View {
    
    @EnvironmentObject var movieStore: MovieStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var goalsByYear: [Int: Int] = [:]
    
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
                Text("Ziel für \(selectedYear)")
                    .font(.headline)
                
                HStack {
                    let binding = Binding<Int>(
                        get: { targetForSelectedYear },
                        set: { newValue in
                            goalsByYear[selectedYear] = max(newValue, 0)
                            saveGoals()
                        }
                    )
                    
                    Stepper(value: binding, in: 0...500) {
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
            Text("Filme in \(selectedYear)")
                .font(.headline)
            
            let seenMovies = moviesInSelectedYear
            let target = max(targetForSelectedYear, seenMovies.count)
            
            if target == 0 {
                Text("Lege oben ein Ziel fest, um mit der Challenge zu starten.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                    spacing: 8
                ) {
                    ForEach(0..<target, id: \.self) { index in
                        if index < seenMovies.count {
                            let movie = seenMovies[index]
                            posterTile(for: movie)
                        } else {
                            placeholderTile()
                        }
                    }
                }
            }
        }
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
                .frame(height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Rectangle()
                    .foregroundStyle(.gray.opacity(0.15))
                    .frame(height: 90)
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
            .frame(height: 90)
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
    
    // MARK: - Persistence
    
    private func loadGoals() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Int: Int].self, from: data) {
            goalsByYear = decoded
        } else {
            goalsByYear = [:]
        }
    }
    
    private func saveGoals() {
        if let data = try? JSONEncoder().encode(goalsByYear) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

#Preview {
    GoalsView()
        .environmentObject(MovieStore.preview())
}
