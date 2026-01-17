//
//  StatsView+Cards.swift
//  filmfreaks
//
//  UI building blocks (dashboard cards) for StatsView.
//

internal import SwiftUI
internal import Charts

extension StatsView {

    // MARK: - Stable-ID bridging helpers

    /// Display names of all members in the current group.
    /// (Names are UI only; identity is handled via UUIDs elsewhere.)
    var memberNames: [String] {
        userStore.users
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Display names of reviewers that have at least one rating in the current filter.
    /// Uses stable reviewerId where possible; falls back to canonical name keys.
    var activeReviewerNamesSet: Set<String> {
        func canon(_ s: String) -> String {
            s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        var result: Set<String> = []
        for key in activeReviewerKeysSet {
            if key.hasPrefix("id:") {
                let idStr = String(key.dropFirst(3))
                if let uuid = UUID(uuidString: idStr), let u = userStore.users.first(where: { $0.id == uuid }) {
                    let name = u.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty { result.insert(name) }
                }
                continue
            }
            if key.hasPrefix("name:") {
                let nameKey = String(key.dropFirst(5))
                if let u = userStore.users.first(where: { canon($0.name) == nameKey }) {
                    let name = u.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty { result.insert(name) }
                } else if !nameKey.isEmpty {
                    result.insert(nameKey)
                }
                continue
            }
        }
        return result
    }

    // MARK: - Cards (Top-Level)

    var filterCard: some View {
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

    var heroCard: some View {
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

    var kpiRow: some View {
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

    var groupHealthCard: some View {
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

    var trendsCard: some View {
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

    var highlightsCard: some View {
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

    var criticsCard: some View {
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

    var genresCard: some View {
        StatsDashboardCard(title: "Genres", systemImage: "square.stack.3d.up") {
            VStack(alignment: .leading, spacing: 10) {
                if genresDisplaySource.isEmpty {
                    Text("Keine Genres im ausgewählten Zeitraum/Ort.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    let totalMovies = max(filteredMovies.count, 1)
                    let top = Array(genresDisplaySource.prefix(9))
                    let rest = Array(genresDisplaySource.dropFirst(9))
                    let maxCount = max(top.map(\.count).max() ?? 1, 1)

                    Text("Eure Top-Genres")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 8) {
                        ForEach(Array(top.enumerated()), id: \.element.genre) { index, entry in
                            Button {
                                genreChipTapped(entry.genre)
                            } label: {
                                genreLeaderboardRow(
                                    rank: index + 1,
                                    genre: entry.genre,
                                    count: entry.count,
                                    totalMovies: totalMovies,
                                    maxCount: maxCount
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transaction { $0.animation = nil }

                    if !rest.isEmpty {
                        DisclosureGroup("Mehr anzeigen (\(rest.count))") {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 95), spacing: 8)],
                                alignment: .leading,
                                spacing: 8
                            ) {
                                ForEach(rest.prefix(24), id: \.genre) { entry in
                                    Button {
                                        genreChipTapped(entry.genre)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(entry.genre)
                                                .font(.caption)
                                                .lineLimit(1)
                                            Text("\(entry.count)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .monospacedDigit()
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(Color(.tertiarySystemBackground))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .transaction { $0.animation = nil }
                            .padding(.top, 6)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    }

                    Text("Tippe ein Genre, um die passenden Filme im Zeitraum zu sehen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    var actorsCard: some View {
        StatsDashboardCard(title: "Darsteller", systemImage: "person.2.fill") {
            VStack(alignment: .leading, spacing: 10) {
                if actorsByCountRaw.isEmpty {
                    Text("Keine Cast-Daten im ausgewählten Zeitraum/Ort.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    let actorSource = actorsDisplaySource
                    let totalMovies = max(filteredMovies.count, 1)
                    let top = Array(actorSource.prefix(9))
                    let rest = Array(actorSource.dropFirst(9))
                    let maxCount = max(top.map(\.count).max() ?? 1, 1)

                    let totalLimit = showAllActors ? expandedActorsCount : collapsedActorsCount
                    let restLimit = max(0, totalLimit - top.count)
                    let displayedRest = Array(rest.prefix(restLimit))

                    Text("Eure Top-Stars")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 8) {
                        ForEach(Array(top.enumerated()), id: \.element.id) { index, entry in
                            Button {
                                actorChipTapped(entry)
                            } label: {
                                actorLeaderboardRow(
                                    rank: index + 1,
                                    entry: entry,
                                    totalMovies: totalMovies,
                                    maxCount: maxCount
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transaction { $0.animation = nil }

                    if !rest.isEmpty {
                        DisclosureGroup("Mehr anzeigen (\(rest.count))", isExpanded: $actorsDisclosureExpanded) {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 120), spacing: 8)],
                                alignment: .leading,
                                spacing: 8
                            ) {
                                ForEach(displayedRest) { entry in
                                    Button {
                                        actorChipTapped(entry)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(entry.name)
                                                .font(.caption)
                                                .lineLimit(1)

                                            Text("\(entry.count)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .monospacedDigit()
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(Color(.tertiarySystemBackground))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .transaction { $0.animation = nil }
                            .padding(.top, 6)

                            if rest.count > restLimit {
                                Button {
                                    showAllActors.toggle()
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(showAllActors ? "Weniger anzeigen" : "Noch mehr anzeigen")
                                            .font(.footnote.weight(.semibold))

                                        Image(systemName: showAllActors ? "chevron.up" : "chevron.down")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 2)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    }

                    Text("Tippe einen Darsteller, um Details & passende Filme zu sehen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    var locationsCard: some View {
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

    var suggestionsCard: some View {
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

    var ratingsPerPersonCard: some View {
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

    // MARK: - Intern: Leaderboard Rows

    @ViewBuilder
    private func genreLeaderboardRow(
        rank: Int,
        genre: String,
        count: Int,
        totalMovies: Int,
        maxCount: Int
    ) -> some View {
        let share = Double(count) / Double(max(totalMovies, 1))
        let impact = Double(count) / Double(max(maxCount, 1))

        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(genre)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text("\(count) · \(Int((share * 100).rounded()))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.quaternarySystemFill))

                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.35))
                            .frame(width: geo.size.width * impact)
                    }
                }
                .frame(height: 10)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func actorLeaderboardRow(
        rank: Int,
        entry: ActorEntry,
        totalMovies: Int,
        maxCount: Int
    ) -> some View {
        let share = Double(entry.count) / Double(max(totalMovies, 1))
        let impact = Double(entry.count) / Double(max(maxCount, 1))
        let pop = popularityStore.popularityValue(for: entry.personId)

        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(entry.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    HStack(spacing: 6) {
                        if pop > 0 {
                            Text("🔥 \(Int(pop.rounded()))")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        Text("\(entry.count) · \(Int((share * 100).rounded()))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.quaternarySystemFill))

                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.35))
                            .frame(width: geo.size.width * impact)
                    }
                }
                .frame(height: 10)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}
