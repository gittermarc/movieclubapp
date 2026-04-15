//
//  StatsView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 29.11.25.
//

internal import SwiftUI
import Foundation

struct StatsView: View {

    @EnvironmentObject var movieStore: MovieStore
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var displaySettings: DisplaySettings

    @State var selectedRange: StatsTimeRange = .all
    @State var selectedLocationFilter: String? = nil

    @StateObject var viewModel = StatsViewModel()

    // Darsteller UI
    @State var showAllActors: Bool = false
    @State var actorsDisclosureExpanded: Bool = false

    // Genres UI
    @State var genreDisplayOrder: [(genre: String, count: Int)] = []
    @State var genreSortGeneration: UUID = UUID()

    let collapsedActorsCount: Int = 25
    let expandedActorsCount: Int = 50

    // Drilldown
    @State var selectedDrilldown: StatsDrilldown? = nil

    // Actor Sheet
    @State var selectedActor: ActorEntry? = nil
    @State var selectedActorDetails: TMDbPersonDetails? = nil
    @State var isLoadingActor: Bool = false
    @State var actorError: String? = nil
    @State var showingActorSheet: Bool = false

    // Genre Sheet
    @State var selectedGenreDrilldown: GenreDrilldown? = nil

    static let recentDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df
    }()

    static let monthFormatter: DateFormatter = {
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

                    ratingDimensionsCard

                    tasteDynamicsCard

                    pickInsightsCard

                    trendsCard

                    highlightsCard

                    criticsCard

                    // ✅ Bestehende Bereiche – erstmal nur "schöner" (kein neuer Funktionsumfang)
                    genresCard
                    actorsCard
                    locationsCard
                    suggestionsCard
                    suggestionQualityCard
                    ratingsPerPersonCard
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 22)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Statistiken")
        }
        .task(id: statsRefreshInputs) {
            refreshStatsSnapshot()
        }
        .onReceive(viewModel.$snapshot) { _ in
            // Snapshot wird debounced/off-main gebaut. Sobald er wirklich da ist,
            // können wir die UI-Orders darauf basieren (Genre-Order) und bei Actors
            // die UI-Orders darauf basieren (Genre-Order).
            handleSnapshotUpdate()
        }
        .onChange(of: actorsDisclosureExpanded) {
            handleActorsDisclosureExpandedChange()
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
}

#Preview {
    NavigationStack {
        StatsView()
            .environmentObject(MovieStore.preview())
            .environmentObject(UserStore())
            .environmentObject(DisplaySettings())
    }
}
