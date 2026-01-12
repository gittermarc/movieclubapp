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

    @State var selectedRange: StatsTimeRange = .all
    @State var selectedLocationFilter: String? = nil

    // ✅ Popularity Store (persistiert + TTL)
    @ObservedObject var popularityStore = PersonPopularityStore.shared

    // Darsteller UI
    @State var showAllActors: Bool = false
    @State var actorsDisclosureExpanded: Bool = false
    @State var actorDisplayOrder: [ActorEntry] = []
    @State var actorSortGeneration: UUID = UUID()

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
        .onChange(of: actorsDisclosureExpanded) {
            if !actorsDisclosureExpanded {
                showAllActors = false
            } else {
                preloadPopularityForVisibleActors()
            }
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
    }
}
