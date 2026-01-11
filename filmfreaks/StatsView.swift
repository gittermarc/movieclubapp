//
//  StatsView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 29.11.25.
//

internal import SwiftUI
internal import Charts

enum StatsTimeRange: String, CaseIterable, Identifiable {
    case last30 = "Letzte 30 Tage"
    case last90 = "Letzte 90 Tage"
    case thisYear = "Dieses Jahr"
    case all = "Gesamte Zeit"

    var id: Self { self }
}

enum StatsCriticGapKind: String, CaseIterable, Identifiable {
    /// Eure Gruppe bewertet höher als TMDB ("underrated" bei TMDB).
    case groupHigher = "Eure Gruppe > TMDB"
    /// TMDB bewertet höher als eure Gruppe ("overrated" bei TMDB).
    case groupLower = "TMDB > Eure Gruppe"

    var id: Self { self }

    var headline: String {
        switch self {
        case .groupHigher:
            return "Eure Gruppe findet besser als TMDB"
        case .groupLower:
            return "TMDB findet besser als eure Gruppe"
        }
    }

    var sheetTitle: String {
        switch self {
        case .groupHigher:
            return "Underrated bei TMDB"
        case .groupLower:
            return "Overrated bei TMDB"
        }
    }

    var helpText: String {
        switch self {
        case .groupHigher:
            return "Filme, die eure Gruppe deutlich höher bewertet als der TMDB-Score."
        case .groupLower:
            return "Filme, die TMDB deutlich höher bewertet als eure Gruppe."
        }
    }
}

enum StatsDrilldown: Identifiable {
    case month(Date)
    case location(String)
    case suggestedBy(String)
    case critics(StatsCriticGapKind)

    var id: String {
        switch self {
        case .month(let date):
            let comps = Calendar.current.dateComponents([.year, .month], from: date)
            let y = comps.year ?? 0
            let m = comps.month ?? 0
            return "month_\(y)_\(m)"
        case .location(let loc):
            return "location_\(loc)"
        case .suggestedBy(let name):
            return "suggestedBy_\(name)"
        case .critics(let kind):
            return "critics_\(kind.rawValue)"
        }
    }
}

private struct GenreDrilldown: Identifiable, Hashable {
    let genre: String
    var id: String { genre }
}

private struct ActorEntry: Identifiable, Hashable {
    let personId: Int
    let name: String
    let count: Int
    var id: Int { personId }
}

private struct StatsMonthTrend: Identifiable, Hashable {
    let monthStart: Date
    let movieCount: Int
    let averageRating: Double?

    var id: Date { monthStart }
}

private struct MovieHighlight: Identifiable {
    let movie: Movie
    let value: Double

    var id: UUID { movie.id }
}

private struct CriticGapEntry: Identifiable {
    let movie: Movie
    let groupAverage: Double
    let tmdbAverage: Double

    /// groupAverage - tmdbAverage (positiv: Gruppe höher, negativ: TMDB höher)
    let delta: Double

    var id: UUID { movie.id }
}

private struct StatsDashboardCard<Content: View>: View {
    let title: String
    let systemImage: String?
    @ViewBuilder let content: () -> Content

    init(title: String, systemImage: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(title)
                    .font(.headline)

                Spacer(minLength: 0)
            }

            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct StatsKPICard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title3.bold())
                .monospacedDigit()

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(width: 155, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

struct StatsView: View {

    @EnvironmentObject var movieStore: MovieStore
    @EnvironmentObject var userStore: UserStore

    @State private var selectedRange: StatsTimeRange = .all
    @State private var selectedLocationFilter: String? = nil

    // ✅ Popularity Store (persistiert + TTL)
    @ObservedObject private var popularityStore = PersonPopularityStore.shared

    // Darsteller UI
    @State private var showAllActors: Bool = false
    @State private var actorDisplayOrder: [ActorEntry] = []
    @State private var actorSortGeneration: UUID = UUID()

    // Genres UI
    @State private var genreDisplayOrder: [(genre: String, count: Int)] = []
    @State private var genreSortGeneration: UUID = UUID()

    private let collapsedActorsCount: Int = 25
    private let expandedActorsCount: Int = 50

    // Drilldown
    @State private var selectedDrilldown: StatsDrilldown? = nil

    // Actor Sheet
    @State private var selectedActor: ActorEntry? = nil
    @State private var selectedActorDetails: TMDbPersonDetails? = nil
    @State private var isLoadingActor: Bool = false
    @State private var actorError: String? = nil
    @State private var showingActorSheet: Bool = false

    // Genre Sheet
    @State private var selectedGenreDrilldown: GenreDrilldown? = nil

    private static let recentDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df
    }()

    private static let monthFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy"
        return df
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    filterCard

                    heroCard

                    kpiRow

                    groupHealthCard

                    trendsCard

                    highlightsCard

                    criticsCard

                    // ✅ Bestehende Bereiche – erstmal nur "schöner" (kein neuer Funktionsumfang)
                    genresCard
                    actorsCard
                    locationsCard
                    suggestionsCard
                    ratingsPerPersonCard
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 22)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Statistiken")
        }
        .onAppear {
            setGenreDisplayOrderNow()
            triggerActorPopularityPreload()
        }
        .onChange(of: selectedRange) {
            setGenreDisplayOrderNow()
            triggerActorPopularityPreload()
        }
        .onChange(of: selectedLocationFilter) {
            setGenreDisplayOrderNow()
            triggerActorPopularityPreload()
        }
        .onChange(of: movieStore.movies.count) {
            triggerGenreDisplayRecomputeDebounced()
            triggerActorPopularityPreload()
        }
        .onChange(of: showAllActors) {
            preloadPopularityForVisibleActors()
        }
        .sheet(isPresented: $showingActorSheet) {
            actorDetailSheet()
        }
        .sheet(item: $selectedGenreDrilldown) { selection in
            genreMoviesSheet(for: selection.genre)
        }
        .sheet(item: $selectedDrilldown) { drilldown in
            drilldownMoviesSheet(drilldown)
        }
    }

    // MARK: - Cards (Top-Level)

    private var filterCard: some View {
        StatsDashboardCard(title: "Filter", systemImage: "line.3.horizontal.decrease.circle") {
            VStack(alignment: .leading, spacing: 12) {

                if let groupName = movieStore.currentGroupName {
                    Text("Statistiken für „\(groupName)“")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Statistiken für deine aktuelle Gruppe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Zeitraum")
                        .font(.subheadline.weight(.semibold))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(StatsTimeRange.allCases) { range in
                                let isSelected = (range == selectedRange)

                                Button { selectedRange = range } label: {
                                    Text(range.rawValue)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(
                                            RoundedRectangle(cornerRadius: 999)
                                                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.gray.opacity(0.12))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 999)
                                                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                                        )
                                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                HStack {
                    Text("Ort")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)

                    Menu {
                        Button {
                            selectedLocationFilter = nil
                        } label: {
                            Label("Alle Orte", systemImage: selectedLocationFilter == nil ? "checkmark" : "")
                        }

                        Divider()

                        ForEach(availableLocations, id: \.self) { loc in
                            Button {
                                selectedLocationFilter = loc
                            } label: {
                                Label(loc, systemImage: selectedLocationFilter == loc ? "checkmark" : "")
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(selectedLocationFilter ?? "Alle Orte")
                                .font(.caption)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var heroCard: some View {
        StatsDashboardCard(title: "Dashboard", systemImage: "rectangle.3.group") {
            VStack(alignment: .leading, spacing: 10) {

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(heroTitle)
                            .font(.title3.bold())
                            .lineLimit(2)

                        Text(heroSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Ø")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(overallAverageRating != nil ? String(format: "%.1f", overallAverageRating!) : "–")
                            .font(.title2.bold())
                            .monospacedDigit()
                    }
                }

                HStack(spacing: 10) {
                    Label("\(filteredMovies.count) Filme", systemImage: "film")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())

                    Label("\(activeReviewersCount) aktiv", systemImage: "person.2.fill")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())

                    if let date = mostRecentWatchedDate {
                        Label(Self.recentDateFormatter.string(from: date), systemImage: "clock")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var kpiRow: some View {
        StatsDashboardCard(title: "KPIs", systemImage: "speedometer") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    StatsKPICard(
                        title: "Filme",
                        value: "\(filteredMovies.count)",
                        subtitle: "im Zeitraum",
                        systemImage: "film"
                    )

                    StatsKPICard(
                        title: "Ø Bewertung",
                        value: overallAverageRating != nil ? String(format: "%.1f", overallAverageRating!) : "–",
                        subtitle: "0–10 Skala",
                        systemImage: "star.fill"
                    )

                    StatsKPICard(
                        title: "Bewertungen",
                        value: "\(totalRatingsCount)",
                        subtitle: "alle Nutzer",
                        systemImage: "text.bubble.fill"
                    )

                    StatsKPICard(
                        title: "Aktive",
                        value: "\(activeReviewersCount)",
                        subtitle: "haben bewertet",
                        systemImage: "person.2.fill"
                    )

                    StatsKPICard(
                        title: "Coverage",
                        value: "\(ratedMoviesCount)/\(max(1, filteredMovies.count))",
                        subtitle: ratingCoveragePercentText,
                        systemImage: "checkmark.seal.fill"
                    )
                }
                .padding(.vertical, 2)
            }
        }
    }


    private var groupHealthCard: some View {
        StatsDashboardCard(title: "Group Health", systemImage: "heart.text.square") {
            VStack(alignment: .leading, spacing: 12) {

                let members = memberNames
                let membersCount = members.count
                let activeCount = activeReviewersCount
                let unrated = unratedMoviesCount

                HStack(spacing: 10) {
                    Label("\(membersCount) Mitglieder", systemImage: "person.2.fill")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())

                    Label("\(activeCount) aktiv", systemImage: "bolt.fill")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())

                    if unrated > 0 {
                        Label("\(unrated) unbewertet", systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Aktivität")
                        .font(.subheadline.weight(.semibold))

                    if membersCount == 0 {
                        Text("Keine Mitglieder in der Gruppe.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        let activity = Double(activeCount) / Double(max(1, membersCount))
                        ProgressView(value: activity)
                            .tint(Color.accentColor)

                        Text("\(activeCount) von \(membersCount) Mitgliedern haben im Zeitraum mindestens einmal bewertet (\(String(format: "%.0f", activity * 100))%).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Coverage")
                        .font(.subheadline.weight(.semibold))

                    let cov = Double(ratedMoviesCount) / Double(max(1, filteredMovies.count))
                    ProgressView(value: cov)
                        .tint(Color.accentColor)

                    Text("\(ratedMoviesCount) von \(max(1, filteredMovies.count)) Filmen haben mindestens eine Bewertung (\(String(format: "%.0f", cov * 100))%).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Alle haben bewertet")
                        .font(.subheadline.weight(.semibold))

                    if activeReviewerNamesSet.isEmpty {
                        Text("Noch keine Bewertungen im ausgewählten Zeitraum.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        let allActive = moviesRatedByAllActiveMembersCount
                        let pActive = Double(allActive) / Double(max(1, filteredMovies.count))

                        ProgressView(value: pActive)
                            .tint(Color.accentColor)

                        Text("\(allActive) von \(max(1, filteredMovies.count)) Filmen wurden von allen aktiven Mitgliedern bewertet (\(String(format: "%.0f", pActive * 100))%).")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if membersCount > 0 && Set(members).count != activeReviewerNamesSet.count {
                            let allMembers = moviesRatedByAllMembersCount
                            let pMembers = Double(allMembers) / Double(max(1, filteredMovies.count))

                            Text("Strenger gemessen an allen Mitgliedern: \(allMembers) Filme (\(String(format: "%.0f", pMembers * 100))%).")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var trendsCard: some View {
        StatsDashboardCard(title: "Trends", systemImage: "chart.xyaxis.line") {
            VStack(alignment: .leading, spacing: 12) {
                if monthTrends.isEmpty {
                    Text("Keine Daten im ausgewählten Zeitraum.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Filme pro Monat")
                            .font(.subheadline.weight(.semibold))

                        Chart(monthTrends) { item in
                            BarMark(
                                x: .value("Monat", item.monthStart, unit: .month),
                                y: .value("Filme", item.movieCount)
                            )
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.month(.abbreviated))
                            }
                        }
                        .frame(height: 160)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ø Bewertung pro Monat")
                            .font(.subheadline.weight(.semibold))

                        Chart(monthTrends.compactMap { item -> StatsMonthTrend? in
                            guard let avg = item.averageRating else { return nil }
                            return StatsMonthTrend(monthStart: item.monthStart, movieCount: item.movieCount, averageRating: avg)
                        }) { item in
                            LineMark(
                                x: .value("Monat", item.monthStart, unit: .month),
                                y: .value("Ø", item.averageRating ?? 0)
                            )
                            PointMark(
                                x: .value("Monat", item.monthStart, unit: .month),
                                y: .value("Ø", item.averageRating ?? 0)
                            )
                        }
                        .chartYScale(domain: 0...10)
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.month(.abbreviated))
                            }
                        }
                        .frame(height: 160)

                        Text("Tipp: Tippe einen Monat unten an, um die Filme als Liste zu öffnen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(moviesPerMonth, id: \.date) { entry in
                                Button {
                                    selectedDrilldown = .month(entry.date)
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(Self.monthFormatter.string(from: entry.date))
                                            .font(.caption)
                                            .lineLimit(1)

                                        Text("\(entry.count)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Color.gray.opacity(0.12))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private var highlightsCard: some View {
        StatsDashboardCard(title: "Highlights", systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 14) {

                VStack(alignment: .leading, spacing: 8) {
                    Text("Top bewertet")
                        .font(.subheadline.weight(.semibold))

                    if topRatedHighlights.isEmpty {
                        Text("Noch keine Bewertungen im ausgewählten Zeitraum.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(topRatedHighlights) { entry in
                            movieRow(entry.movie, trailingText: String(format: "%.1f", entry.value), trailingBackground: Color.blue.opacity(0.12))
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Kontrovers")
                        .font(.subheadline.weight(.semibold))

                    Text("Je höher, desto mehr gehen eure Meinungen auseinander (Standardabweichung).")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if controversialHighlights.isEmpty {
                        Text("Dafür braucht es mindestens 2 Bewertungen pro Film.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(controversialHighlights) { entry in
                            movieRow(entry.movie, trailingText: String(format: "±%.1f", entry.value), trailingBackground: Color.orange.opacity(0.15))
                        }
                    }
                }
            }
        }
    }

    private var criticsCard: some View {
        StatsDashboardCard(title: "Kritik vs TMDB", systemImage: "theatermasks") {
            VStack(alignment: .leading, spacing: 14) {

                if criticGapEntries.isEmpty {
                    Text("Für diesen Bereich brauchen Filme sowohl eine TMDB-Bewertung als auch mindestens eine Gruppenbewertung im aktuellen Filter.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Je größer der Abstand, desto mehr weicht eure Gruppenmeinung vom TMDB-Score ab.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Underrated bei TMDB")
                                .font(.subheadline.weight(.semibold))

                            Spacer(minLength: 0)

                            if criticGapGroupHigher.count > 3 {
                                Button("Alle") {
                                    selectedDrilldown = .critics(.groupHigher)
                                }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.accentColor)
                            }
                        }

                        Text("Eure Gruppe bewertet höher als TMDB")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if criticGapGroupHigher.isEmpty {
                            Text("Keine klaren Abweichungen im aktuellen Filter.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(criticGapGroupHigher.prefix(3)) { entry in
                                criticGapRow(entry, kind: .groupHigher)
                            }
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Overrated bei TMDB")
                                .font(.subheadline.weight(.semibold))

                            Spacer(minLength: 0)

                            if criticGapGroupLower.count > 3 {
                                Button("Alle") {
                                    selectedDrilldown = .critics(.groupLower)
                                }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.accentColor)
                            }
                        }

                        Text("TMDB bewertet höher als eure Gruppe")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if criticGapGroupLower.isEmpty {
                            Text("Keine klaren Abweichungen im aktuellen Filter.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(criticGapGroupLower.prefix(3)) { entry in
                                criticGapRow(entry, kind: .groupLower)
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            selectedDrilldown = .critics(.groupHigher)
                        } label: {
                            Label("Underrated", systemImage: "arrow.up.right")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            selectedDrilldown = .critics(.groupLower)
                        } label: {
                            Label("Overrated", systemImage: "arrow.down.right")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.red.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer(minLength: 0)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private var genresCard: some View {
        StatsDashboardCard(title: "Genres", systemImage: "square.stack.3d.up") {
            VStack(alignment: .leading, spacing: 10) {
                if genresDisplaySource.isEmpty {
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
                        ForEach(genresDisplaySource.prefix(30), id: \.genre) { entry in
                            Button {
                                genreChipTapped(entry.genre)
                            } label: {
                                HStack(spacing: 6) {
                                    Text(entry.genre)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Text("(\(entry.count))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.blue.opacity(0.12))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transaction { $0.animation = nil }

                    Text("Tippe ein Genre, um die passenden Filme im Zeitraum zu sehen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var actorsCard: some View {
        StatsDashboardCard(title: "Darsteller", systemImage: "person.2.fill") {
            VStack(alignment: .leading, spacing: 10) {
                if actorsByCountRaw.isEmpty {
                    Text("Keine Cast-Daten im ausgewählten Zeitraum/Ort.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Wen ihr am häufigsten seht")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    let actorSource = actorsDisplaySource
                    let limit = showAllActors ? expandedActorsCount : collapsedActorsCount
                    let displayedActors = Array(actorSource.prefix(limit))

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 120), spacing: 8)],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        ForEach(displayedActors) { entry in
                            Button {
                                actorChipTapped(entry)
                            } label: {
                                HStack(spacing: 6) {
                                    Text(entry.name)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Text("(\(entry.count))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.blue.opacity(0.12))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transaction { $0.animation = nil }

                    if actorSource.count > collapsedActorsCount {
                        Button {
                            showAllActors.toggle()
                        } label: {
                            HStack(spacing: 6) {
                                Text(showAllActors ? "Weniger anzeigen" : "Mehr anzeigen")
                                    .font(.footnote.weight(.semibold))
                                Image(systemName: showAllActors ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var locationsCard: some View {
        StatsDashboardCard(title: "Orte", systemImage: "mappin.and.ellipse") {
            VStack(alignment: .leading, spacing: 10) {
                if moviesByLocation.isEmpty {
                    Text("Keine Filme im ausgewählten Zeitraum.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(moviesByLocation, id: \.location) { entry in
                        HStack {
                            Text(entry.location)
                            Spacer(minLength: 0)
                            Button { selectedDrilldown = .location(entry.location) } label: {
                                Text("\(entry.count)")
                                    .font(.footnote)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.gray.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private var suggestionsCard: some View {
        StatsDashboardCard(title: "Vorgeschlagen von", systemImage: "person.fill.questionmark") {
            VStack(alignment: .leading, spacing: 10) {
                if suggestionsByUser.isEmpty {
                    Text("Keine Vorschläge im ausgewählten Zeitraum/Ort.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(suggestionsByUser, id: \.name) { entry in
                        HStack {
                            Text(entry.name)
                            Spacer(minLength: 0)
                            Button { selectedDrilldown = .suggestedBy(entry.name) } label: {
                                Text("\(entry.count)")
                                    .font(.footnote)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.orange.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private var ratingsPerPersonCard: some View {
        StatsDashboardCard(title: "Bewertungen pro Person", systemImage: "person.3.sequence.fill") {
            VStack(alignment: .leading, spacing: 10) {
                if userStore.users.isEmpty {
                    Text("Noch keine Mitglieder in der Filmgruppe.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    let totalMovies = filteredMovies.count
                    let denom = max(1, totalMovies)

                    VStack(alignment: .leading, spacing: 10) {

                        HStack(spacing: 8) {
                            if totalMovies == 0 {
                                Text("Im aktuellen Filter gibt es keine Filme.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Bezogen auf \(totalMovies) Filme im aktuellen Filter.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)

                            if !activeReviewerNamesSet.isEmpty {
                                Text("\(activeReviewerNamesSet.count) aktiv")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.gray.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }

                        VStack(spacing: 10) {
                            ForEach(userStore.users) { user in
                                let stats = statsForUser(user)
                                let progress = Double(stats.movieCount) / Double(denom)
                                let missing = max(0, totalMovies - stats.movieCount)

                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(user.name)
                                                .font(.subheadline.weight(.semibold))

                                            HStack(spacing: 6) {
                                                Text("\(stats.movieCount)/\(totalMovies) Filme")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)

                                                Text("• \(stats.ratingsCount) Bewertungen")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)

                                                if missing > 0 && totalMovies > 0 {
                                                    Text("• \(missing) fehlen")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                        }

                                        Spacer(minLength: 0)

                                        if let avg = stats.averageRating {
                                            Text(String(format: "%.1f", avg))
                                                .font(.headline)
                                                .monospacedDigit()
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

                                    ProgressView(value: progress)
                                        .tint(Color.accentColor)

                                    HStack {
                                        Text("Coverage: \(String(format: "%.0f", progress * 100))%")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Spacer(minLength: 0)

                                        if totalMovies > 0 && stats.movieCount == totalMovies {
                                            Text("Komplett")
                                                .font(.caption2.weight(.semibold))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 5)
                                                .background(Color.green.opacity(0.15))
                                                .clipShape(Capsule())
                                        } else if stats.ratingsCount == 0 {
                                            Text("Noch nichts bewertet")
                                                .font(.caption2.weight(.semibold))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 5)
                                                .background(Color.orange.opacity(0.15))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(.tertiarySystemBackground))
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Hero Copy

    private var heroTitle: String {
        if let groupName = movieStore.currentGroupName {
            return "\(groupName) – Überblick"
        }
        return "Eure Filmgruppe – Überblick"
    }

    private var heroSubtitle: String {
        let rangeText = selectedRange.rawValue
        let locText = selectedLocationFilter ?? "Alle Orte"
        return "\(rangeText) • \(locText)"
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
                if calendar.isDate(date, equalTo: today, toGranularity: .year) { return movie }
            case .last30:
                if let from = calendar.date(byAdding: .day, value: -30, to: today),
                   date >= from { return movie }
            case .last90:
                if let from = calendar.date(byAdding: .day, value: -90, to: today),
                   date >= from { return movie }
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
        let trimmed = movie.watchedLocation?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Ohne Angabe" : trimmed
    }

    // MARK: - KPIs

    private var totalRatingsCount: Int {
        filteredMovies.reduce(0) { $0 + $1.ratings.count }
    }

    private var activeReviewersCount: Int {
        let all = filteredMovies.flatMap { $0.ratings.map { $0.reviewerName } }
        return Set(all).count
    }

    private var ratedMoviesCount: Int {
        filteredMovies.filter { !$0.ratings.isEmpty }.count
    }

    private var ratingCoveragePercentText: String {
        guard filteredMovies.count > 0 else { return "0%" }
        let pct = (Double(ratedMoviesCount) / Double(filteredMovies.count)) * 100.0
        return String(format: "%.0f%% bewertet", pct)
    }

    // MARK: - Group Health

    private var memberNames: [String] {
        userStore.users
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var activeReviewerNamesSet: Set<String> {
        let names = filteredMovies
            .flatMap { $0.ratings.map { $0.reviewerName.trimmingCharacters(in: .whitespacesAndNewlines) } }
            .filter { !$0.isEmpty }
        return Set(names)
    }

    private var unratedMoviesCount: Int {
        max(0, filteredMovies.count - ratedMoviesCount)
    }

    /// Filme, die von *allen aktiven* Mitgliedern (mind. eine Bewertung im Zeitraum) bewertet wurden.
    private var moviesRatedByAllActiveMembersCount: Int {
        let active = activeReviewerNamesSet
        guard !active.isEmpty else { return 0 }

        return filteredMovies.filter { movie in
            let reviewers = Set(movie.ratings.map { $0.reviewerName.trimmingCharacters(in: .whitespacesAndNewlines) })
            return active.isSubset(of: reviewers)
        }.count
    }

    /// Filme, die von *allen Mitgliedern* (laut Member-Liste) bewertet wurden.
    private var moviesRatedByAllMembersCount: Int {
        let members = Set(memberNames)
        guard !members.isEmpty else { return 0 }

        return filteredMovies.filter { movie in
            let reviewers = Set(movie.ratings.map { $0.reviewerName.trimmingCharacters(in: .whitespacesAndNewlines) })
            return members.isSubset(of: reviewers)
        }.count
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
        filteredMovies.compactMap { $0.watchedDate }.max()
    }

    private var monthTrends: [StatsMonthTrend] {
        let calendar = Calendar.current
        var buckets: [Date: (movies: Int, scores: [Double])] = [:]

        for movie in filteredMovies {
            guard let date = movie.watchedDate else { continue }
            guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else { continue }

            var entry = buckets[monthStart] ?? (movies: 0, scores: [])
            entry.movies += 1
            entry.scores.append(contentsOf: movie.ratings.map { $0.averageScoreNormalizedTo10 })
            buckets[monthStart] = entry
        }

        let result = buckets.map { (monthStart, data) -> StatsMonthTrend in
            let avg: Double?
            if data.scores.isEmpty {
                avg = nil
            } else {
                avg = data.scores.reduce(0, +) / Double(data.scores.count)
            }
            return StatsMonthTrend(monthStart: monthStart, movieCount: data.movies, averageRating: avg)
        }

        return result.sorted { $0.monthStart < $1.monthStart }
    }

    /// Für Chips (aktuellste Monate zuerst)
    private var moviesPerMonth: [(date: Date, count: Int)] {
        monthTrends
            .map { (date: $0.monthStart, count: $0.movieCount) }
            .sorted { $0.date > $1.date }
    }

    private var topRatedHighlights: [MovieHighlight] {
        let base = filteredMovies.compactMap { movie -> MovieHighlight? in
            guard let avg = movie.averageRating else { return nil }
            return MovieHighlight(movie: movie, value: avg)
        }

        return base
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0 }
    }

    private var controversialHighlights: [MovieHighlight] {
        let base = filteredMovies.compactMap { movie -> MovieHighlight? in
            let values = movie.ratings.map { $0.averageScoreNormalizedTo10 }
            guard values.count >= 2 else { return nil }
            let sd = standardDeviation(values)
            return MovieHighlight(movie: movie, value: sd)
        }

        return base
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Kritik vs TMDB

    private var criticGapEntries: [CriticGapEntry] {
        filteredMovies.compactMap { movie -> CriticGapEntry? in
            guard let groupAvg = movie.averageRating else { return nil }
            guard let tmdb = movie.tmdbRating else { return nil }

            let delta = groupAvg - tmdb
            return CriticGapEntry(movie: movie, groupAverage: groupAvg, tmdbAverage: tmdb, delta: delta)
        }
    }

    private var criticGapGroupHigher: [CriticGapEntry] {
        criticGapEntriesFiltered(kind: .groupHigher)
    }

    private var criticGapGroupLower: [CriticGapEntry] {
        criticGapEntriesFiltered(kind: .groupLower)
    }

    private func criticGapEntriesFiltered(kind: StatsCriticGapKind) -> [CriticGapEntry] {
        let minInterestingDelta = 0.8
        let eps = 0.0001

        let base: [CriticGapEntry]
        switch kind {
        case .groupHigher:
            let strong = criticGapEntries.filter { $0.delta >= minInterestingDelta }
            base = strong.isEmpty ? criticGapEntries.filter { $0.delta > eps } : strong
            return base.sorted { $0.delta > $1.delta }

        case .groupLower:
            let strong = criticGapEntries.filter { $0.delta <= -minInterestingDelta }
            base = strong.isEmpty ? criticGapEntries.filter { $0.delta < -eps } : strong
            return base.sorted { $0.delta < $1.delta } // negative zuerst (stärkste Abweichung)
        }
    }

    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values
            .map { ($0 - mean) * ($0 - mean) }
            .reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }

    private var moviesByGenreRaw: [(genre: String, count: Int)] {
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
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.genre.localizedCaseInsensitiveCompare($1.genre) == .orderedAscending
            }
    }

    private var genresDisplaySource: [(genre: String, count: Int)] {
        genreDisplayOrder.isEmpty ? moviesByGenreRaw : genreDisplayOrder
    }

    /// ✅ Rohdaten: Häufigkeit pro Darsteller – personId-basiert
    private var actorsByCountRaw: [ActorEntry] {
        var counts: [Int: (name: String, count: Int)] = [:]

        for movie in filteredMovies {
            guard let cast = movie.cast else { continue }
            for member in cast {
                let trimmed = member.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }

                if var existing = counts[member.personId] {
                    existing.count += 1
                    // Namen behalten wir stabil (erster gewinnt)
                    counts[member.personId] = existing
                } else {
                    counts[member.personId] = (name: trimmed, count: 1)
                }
            }
        }

        return counts
            .map { ActorEntry(personId: $0.key, name: $0.value.name, count: $0.value.count) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private var actorsDisplaySource: [ActorEntry] {
        actorDisplayOrder.isEmpty ? actorsByCountRaw : actorDisplayOrder
    }

    /// Sortierung: Häufigkeit, dann Popularität (per personId), dann Name
    private func computeActorsSortedUsingPopularity() -> [ActorEntry] {
        let raw = actorsByCountRaw
        return raw.sorted { a, b in
            if a.count != b.count { return a.count > b.count }

            let popA = popularityStore.popularityValue(for: a.personId)
            let popB = popularityStore.popularityValue(for: b.personId)
            if popA != popB { return popA > popB }

            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
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

    private func statsForUser(_ user: User) -> (movieCount: Int, ratingsCount: Int, averageRating: Double?) {
        var movieIds = Set<UUID>()
        var scores: [Double] = []

        for movie in filteredMovies {
            let userRatings = movie.ratings.filter { $0.reviewerName == user.name }
            if !userRatings.isEmpty {
                movieIds.insert(movie.id)
                scores.append(contentsOf: userRatings.map { $0.averageScoreNormalizedTo10 })
            }
        }

        guard !scores.isEmpty else { return (movieIds.count, 0, nil) }

        let total = scores.reduce(0, +)
        let avg = total / Double(scores.count)
        return (movieIds.count, scores.count, avg)
    }

    // MARK: - Actor Filme

    private var moviesForSelectedActor: [Movie] {
        guard let actor = selectedActor else { return [] }
        return filteredMovies.filter { movie in
            guard let cast = movie.cast else { return false }
            return cast.contains(where: { $0.personId == actor.personId })
        }
    }

    // MARK: - Genre UI Stabilisierung

    private func setGenreDisplayOrderNow() {
        let gen = UUID()
        genreSortGeneration = gen
        genreDisplayOrder = moviesByGenreRaw
    }

    private func triggerGenreDisplayRecomputeDebounced() {
        let gen = UUID()
        genreSortGeneration = gen

        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            await MainActor.run {
                guard genreSortGeneration == gen else { return }
                genreDisplayOrder = moviesByGenreRaw
            }
        }
    }

    // MARK: - Popularity Preload (✅ nur /person/{id}, TTL-Cache)

    private func triggerActorPopularityPreload() {
        let generation = UUID()
        actorSortGeneration = generation

        let base = actorsByCountRaw
        actorDisplayOrder = base

        Task {
            let visibleLimit = showAllActors ? expandedActorsCount : collapsedActorsCount
            let visibleIds = Array(base.prefix(visibleLimit)).map { $0.personId }
            await popularityStore.preloadPopularity(for: visibleIds)

            let allIds = base.map { $0.personId }
            await popularityStore.preloadPopularity(for: allIds)

            await MainActor.run {
                guard actorSortGeneration == generation else { return }
                actorDisplayOrder = computeActorsSortedUsingPopularity()
            }
        }
    }

    private func preloadPopularityForVisibleActors() {
        let base = actorsByCountRaw
        if base.isEmpty { return }

        let visibleLimit = showAllActors ? expandedActorsCount : collapsedActorsCount
        let visibleIds = Array(base.prefix(visibleLimit)).map { $0.personId }

        Task {
            await popularityStore.preloadPopularity(for: visibleIds)
        }
    }

    // MARK: - Actor Interaction

    private func actorChipTapped(_ actor: ActorEntry) {
        selectedActor = actor
        selectedActorDetails = nil
        actorError = nil
        isLoadingActor = true
        showingActorSheet = true

        // ✅ Actor-Sheet lädt Details per ID (keine Suche)
        Task {
            do {
                let details = try await TMDbAPI.shared.fetchPersonDetails(id: actor.personId)
                await MainActor.run {
                    self.selectedActorDetails = details
                    self.isLoadingActor = false
                }
            } catch {
                await MainActor.run {
                    self.actorError = "Fehler beim Laden der Personendaten."
                    self.isLoadingActor = false
                }
            }
        }
    }

    @ViewBuilder
    private func actorDetailSheet() -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    if isLoadingActor {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Lade Personendaten …")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)

                    } else if let error = actorError {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.top, 40)

                    } else if let details = selectedActorDetails {

                        if let path = details.profile_path,
                           let url = URL(string: "https://image.tmdb.org/t/p/w500\(path)") {
                            CachedAsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    Rectangle()
                                        .foregroundStyle(.gray.opacity(0.2))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 260)

                                case .success(let image):
                                    // ✅ Option A: nix abschneiden, aber trotzdem "Hero"-artig und sauber gerahmt
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 260)
                                        .background(Color.gray.opacity(0.08))

                                case .failure:
                                    Rectangle()
                                        .foregroundStyle(.gray.opacity(0.2))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 260)
                                        .overlay {
                                            Image(systemName: "person.crop.rectangle")
                                                .font(.largeTitle)
                                                .foregroundStyle(.secondary)
                                        }

                                @unknown default:
                                    Rectangle()
                                        .foregroundStyle(.gray.opacity(0.2))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 260)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(details.name)
                                .font(.title2.bold())

                            if let dept = details.known_for_department, !dept.isEmpty {
                                Text(dept)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 10) {
                                if let birthday = details.birthday, !birthday.isEmpty {
                                    Label(birthday, systemImage: "gift.fill")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.12))
                                        .clipShape(Capsule())
                                }

                                if let place = details.place_of_birth, !place.isEmpty {
                                    Label(place, systemImage: "mappin.and.ellipse")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.12))
                                        .clipShape(Capsule())
                                }

                                if let popularity = details.popularity {
                                    Label(String(format: "Popularity %.1f", popularity),
                                          systemImage: "sparkles")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.yellow.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        if let aliases = details.also_known_as, !aliases.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Auch bekannt als")
                                    .font(.subheadline.weight(.semibold))
                                Text(aliases.joined(separator: ", "))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Biografie").font(.headline)

                            if let bio = details.biography,
                               !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(bio).font(.body)
                            } else {
                                Text("Keine Biografie verfügbar.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                    } else {
                        Text("Keine Personendaten geladen.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    }

                    if let actor = selectedActor,
                       !moviesForSelectedActor.isEmpty {

                        Divider().padding(.vertical, 8)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("In eurer Gruppe gesehen")
                                .font(.headline)

                            Text("Filme im aktuell gewählten Zeitraum und Ort, in denen \(actor.name) mitspielt.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(moviesForSelectedActor) { movie in
                                movieRow(movie)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Darsteller")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { showingActorSheet = false }
                }
            }
        }
    }

    // MARK: - Genre Interaction

    private func genreChipTapped(_ genre: String) {
        selectedGenreDrilldown = GenreDrilldown(genre: genre)
    }

    @ViewBuilder
    private func genreMoviesSheet(for genre: String) -> some View {
        NavigationStack {
            List {
                let movies = filteredMovies.filter { movie in
                    (movie.genres ?? []).contains(where: { $0.lowercased() == genre.lowercased() })
                }

                if movies.isEmpty {
                    Text("Keine Filme für „\(genre)“ im aktuellen Filter.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(movies) { movie in
                        movieRow(movie)
                    }
                }
            }
            .navigationTitle(genre)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { selectedGenreDrilldown = nil }
                }
            }
        }
    }

    // MARK: - Drilldown Sheets

    @ViewBuilder
    private func drilldownMoviesSheet(_ drilldown: StatsDrilldown) -> some View {
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
    private func drilldownMoviesSheetMonth(_ date: Date) -> some View {
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
    private func drilldownMoviesSheetLocation(_ loc: String) -> some View {
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
    private func drilldownMoviesSheetSuggestedBy(_ name: String) -> some View {
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
    private func drilldownMoviesSheetCritics(_ kind: StatsCriticGapKind) -> some View {
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

    // MARK: - Movie Row

    @ViewBuilder
    private func criticGapRow(_ entry: CriticGapEntry, kind: StatsCriticGapKind) -> some View {
        let badgeBackground: Color = (kind == .groupHigher) ? Color.green.opacity(0.15) : Color.red.opacity(0.15)
        let badgeForeground: Color = (kind == .groupHigher) ? Color.green : Color.red
        let deltaText = String(format: "%+.1f", entry.delta)

        HStack(spacing: 12) {
            if let url = entry.movie.posterURL {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle().foregroundStyle(.gray.opacity(0.2))
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Rectangle()
                            .foregroundStyle(.gray.opacity(0.2))
                            .overlay { Image(systemName: "film") }
                    @unknown default:
                        Rectangle().foregroundStyle(.gray.opacity(0.2))
                    }
                }
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Rectangle()
                    .foregroundStyle(.gray.opacity(0.1))
                    .frame(width: 40, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.movie.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(entry.movie.year)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let dateText = entry.movie.watchedDateText {
                        Text("• \(dateText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 6) {
                Text(deltaText)
                    .font(.headline.bold())
                    .monospacedDigit()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(badgeBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(badgeForeground)

                HStack(spacing: 6) {
                    Text(String(format: "Ihr %.1f", entry.groupAverage))
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Capsule())

                    Text(String(format: "TMDB %.1f", entry.tmdbAverage))
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func movieRow(
        _ movie: Movie,
        trailingText: String? = nil,
        trailingBackground: Color = Color.blue.opacity(0.12)
    ) -> some View {
        HStack(spacing: 12) {
            if let url = movie.posterURL {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle().foregroundStyle(.gray.opacity(0.2))
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Rectangle()
                            .foregroundStyle(.gray.opacity(0.2))
                            .overlay { Image(systemName: "film") }
                    @unknown default:
                        Rectangle().foregroundStyle(.gray.opacity(0.2))
                    }
                }
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Rectangle()
                    .foregroundStyle(.gray.opacity(0.1))
                    .frame(width: 40, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(movie.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(movie.year).font(.caption).foregroundStyle(.secondary)

                    if let dateText = movie.watchedDateText {
                        Text("• \(dateText)").font(.caption).foregroundStyle(.secondary)
                    }

                    if let loc = movie.watchedLocation, !loc.isEmpty {
                        Text("• \(loc)").font(.caption).foregroundStyle(.secondary)
                    }
                }

                if let sugg = movie.suggestedBy,
                   !sugg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Vorgeschlagen von: \(sugg)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            let badgeText: String? = {
                if let trailingText { return trailingText }
                if let avg = movie.averageRating ?? movie.tmdbRating { return String(format: "%.1f", avg) }
                return nil
            }()

            if let badgeText {
                Text(badgeText)
                    .font(.caption.bold())
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(trailingText == nil ? Color.blue.opacity(0.12) : trailingBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        StatsView()
            .environmentObject(MovieStore.preview())
            .environmentObject(UserStore())
    }
}
