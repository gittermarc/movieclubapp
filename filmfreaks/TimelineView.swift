//
//  TimelineView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 21.12.25.
//

internal import SwiftUI

private enum TimelineFilterMode: String, CaseIterable, Identifiable {
    case year = "Jahr"
    case range = "Zeitraum"
    var id: Self { self }
}

private enum TimelineTimeRange: String, CaseIterable, Identifiable {
    case last30 = "Letzte 30 Tage"
    case last90 = "Letzte 90 Tage"
    case thisYear = "Dieses Jahr"
    case all = "Gesamte Zeit"
    var id: Self { self }
}

struct TimelineView: View {

    @EnvironmentObject var movieStore: MovieStore
    @EnvironmentObject var userStore: UserStore
    @Environment(\.dismiss) private var dismiss

    @State private var filterMode: TimelineFilterMode = .year
    @State private var selectedRange: TimelineTimeRange = .thisYear
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    // MARK: - Tuning (hier kannst du später easy nachjustieren)
    private let cardAspectRatio: CGFloat = 2.0 / 3.0      // 👈 Poster-Format (höher)
    private let parallaxStrength: CGFloat = 0.12           // subtil
    private let parallaxClamp: CGFloat = 26                // max +/- px

    private var availableYears: [Int] {
        let cal = Calendar.current
        let years = movieStore.movies.compactMap { movie -> Int? in
            guard let d = movie.watchedDate else { return nil }
            return cal.component(.year, from: d)
        }
        let current = cal.component(.year, from: Date())
        return Array(Set(years + [current])).sorted(by: >)
    }

    private var filteredMovies: [Movie] {
        let cal = Calendar.current
        let today = Date()

        let watched = movieStore.movies.compactMap { movie -> Movie? in
            guard movie.watchedDate != nil else { return nil }
            return movie
        }

        let filtered: [Movie] = watched.filter { movie in
            guard let date = movie.watchedDate else { return false }

            switch filterMode {
            case .year:
                return cal.component(.year, from: date) == selectedYear

            case .range:
                switch selectedRange {
                case .all:
                    return true
                case .thisYear:
                    return cal.isDate(date, equalTo: today, toGranularity: .year)
                case .last30:
                    if let from = cal.date(byAdding: .day, value: -30, to: today) {
                        return date >= from
                    }
                    return false
                case .last90:
                    if let from = cal.date(byAdding: .day, value: -90, to: today) {
                        return date >= from
                    }
                    return false
                }
            }
        }

        return filtered.sorted { ($0.watchedDate ?? .distantPast) > ($1.watchedDate ?? .distantPast) }
    }

    private var monthGroups: [(monthStart: Date, movies: [Movie])] {
        let cal = Calendar.current
        var dict: [Date: [Movie]] = [:]

        for movie in filteredMovies {
            guard let d = movie.watchedDate else { continue }
            let comps = cal.dateComponents([.year, .month], from: d)
            if let monthStart = cal.date(from: comps) {
                dict[monthStart, default: []].append(movie)
            }
        }

        return dict
            .map { key, value in
                let sorted = value.sorted { ($0.watchedDate ?? .distantPast) > ($1.watchedDate ?? .distantPast) }
                return (monthStart: key, movies: sorted)
            }
            .sorted { $0.monthStart > $1.monthStart }
    }

    private var monthFormatter: DateFormatter {
        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = "LLLL yyyy"
        return df
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14, pinnedViews: [.sectionHeaders]) {

                        header
                            .padding(.horizontal)
                            .padding(.top)
                            .padding(.bottom, 6)

                        if filteredMovies.isEmpty {
                            emptyState
                                .padding(.horizontal)
                                .padding(.top, 12)
                        } else {
                            ForEach(monthGroups, id: \.monthStart) { group in
                                Section {
                                    LazyVStack(alignment: .leading, spacing: 18) {
                                        ForEach(group.movies) { movie in
                                            timelineRow(movie: movie)
                                                .padding(.horizontal)
                                        }
                                    }
                                    .padding(.top, 10)
                                    .padding(.bottom, 2)
                                } header: {
                                    monthHeader(date: group.monthStart)
                                }
                            }
                        }

                        Spacer(minLength: 16)
                    }
                }
                .coordinateSpace(name: "timelineScroll") // 👈 wichtig für Parallax
            }
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .onAppear {
                if !availableYears.contains(selectedYear), let first = availableYears.first {
                    selectedYear = first
                }
            }
        }
    }

    // MARK: - Sticky Month Header

    private func monthHeader(date: Date) -> some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color(.systemGroupedBackground))
                .overlay(.ultraThinMaterial.opacity(0.9))

            Text(monthFormatter.string(from: date))
                .font(.title3.bold())
                .padding(.horizontal)
                .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.35)
        }
    }

    // MARK: - Header / Filter

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {

            if let groupName = movieStore.currentGroupName, !groupName.isEmpty {
                Text("Für „\(groupName)“")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Für deine aktuelle Gruppe")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Ansicht")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Ansicht", selection: $filterMode) {
                    ForEach(TimelineFilterMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if filterMode == .year {
                    Text("Jahr")
                        .font(.subheadline)

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
                                                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 999)
                                                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1)
                                        )
                                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                } else {
                    Text("Zeitraum")
                        .font(.subheadline)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(TimelineTimeRange.allCases) { range in
                                let isSelected = range == selectedRange
                                Button {
                                    selectedRange = range
                                } label: {
                                    Text(range.rawValue)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 999)
                                                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 999)
                                                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1)
                                        )
                                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Text("\(filteredMovies.count) Filme")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "film")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Keine Filme in der Timeline")
                .font(.headline)

            Text("Für diese Auswahl gibt’s keine Filme mit Datum.\nGib in einem Film ein „Gemeinsam geschaut am“-Datum an – dann taucht er hier auf.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Timeline Row

    @ViewBuilder
    private func timelineRow(movie: Movie) -> some View {
        HStack(alignment: .top, spacing: 12) {
            timelineMarker(for: movie)

            if let binding = binding(for: movie) {
                NavigationLink {
                    MovieDetailView(movie: binding, isBacklog: false)
                } label: {
                    posterCard(movie: movie)
                }
                .buttonStyle(.plain)
            } else {
                posterCard(movie: movie)
            }
        }
    }

    private func timelineMarker(for movie: Movie) -> some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .strokeBorder(Color(.systemBackground), lineWidth: 2)
                )
                .padding(.top, 18)

            Rectangle()
                .fill(Color.gray.opacity(0.25))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
                .padding(.top, 4)
        }
        .frame(width: 16)
        .accessibilityHidden(true)
    }

    // MARK: - Poster Card + Parallax

    private func posterCard(movie: Movie) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {

                // 👇 Parallax-Layer (jetzt im Poster-Format)
                parallaxPoster(movie: movie)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.0),
                        Color.black.opacity(0.60)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(movie.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        if let dateText = movie.watchedDateText {
                            Label(dateText, systemImage: "calendar")
                        }

                        if let loc = movie.watchedLocation, !loc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Label(loc, systemImage: "mappin.and.ellipse")
                                .lineLimit(1)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))

                    HStack(spacing: 10) {
                        Text(movie.year)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))

                        if let avg = movie.averageRating ?? movie.tmdbRating {
                            Label(String(format: "%.1f", avg), systemImage: "star.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.16))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(12)
            }
        }
        .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(movie.title), \(movie.year)")
    }

    /// Parallax: Bild wird minimal gegen die Scrollrichtung verschoben.
    /// Da die Card jetzt höher ist, geben wir mehr "Überhang", damit keine Lücken entstehen.
    private func parallaxPoster(movie: Movie) -> some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named("timelineScroll")).minY

            let raw = -minY * parallaxStrength
            let offsetY = clamp(raw, -parallaxClamp, parallaxClamp)

            let extra: CGFloat = 70 // mehr Overhang, weil höheres Posterformat

            ZStack {
                posterImage(movie: movie)
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height + extra)
                    .offset(y: offsetY - (extra / 2))
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(cardAspectRatio, contentMode: .fit) // 👈 HIER wird’s größer/höher
        .clipped()
    }

    @ViewBuilder
    private func posterImage(movie: Movie) -> some View {
        if let url = movie.posterURL {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .foregroundStyle(.gray.opacity(0.2))
                        .overlay { ProgressView() }
                case .success(let image):
                    image.resizable()
                case .failure:
                    Rectangle()
                        .foregroundStyle(.gray.opacity(0.2))
                        .overlay {
                            Image(systemName: "film")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                @unknown default:
                    Rectangle()
                        .foregroundStyle(.gray.opacity(0.2))
                }
            }
        } else {
            Rectangle()
                .foregroundStyle(.gray.opacity(0.18))
                .overlay {
                    Image(systemName: "film")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
        }
    }

    // MARK: - Binding Helper

    private func binding(for movie: Movie) -> Binding<Movie>? {
        guard let idx = movieStore.movies.firstIndex(where: { $0.id == movie.id }) else {
            return nil
        }
        return $movieStore.movies[idx]
    }

    // MARK: - Utils

    private func clamp(_ value: CGFloat, _ minValue: CGFloat, _ maxValue: CGFloat) -> CGFloat {
        min(max(value, minValue), maxValue)
    }
}

#Preview {
    TimelineView()
        .environmentObject(MovieStore.preview())
        .environmentObject(UserStore())
}
