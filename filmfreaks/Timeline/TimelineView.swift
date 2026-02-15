//
//  TimelineView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 21.12.25.
//

internal import SwiftUI

struct TimelineView: View {

    @EnvironmentObject var movieStore: MovieStore
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var displaySettings: DisplaySettings
    @Environment(\.dismiss) private var dismiss

    @State var filterMode: TimelineFilterMode = .year
    @State var selectedRange: TimelineTimeRange = .thisYear
    @State var selectedYear: Int = Calendar.current.component(.year, from: Date())

    // MARK: - Tuning (hier kannst du später easy nachjustieren)
    private let cardAspectRatio: CGFloat = 2.0 / 3.0      // 👈 Poster-Format (höher)
    private let parallaxStrength: CGFloat = 0.12           // subtil
    private let parallaxClamp: CGFloat = 26                // max +/- px

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14, pinnedViews: [.sectionHeaders]) {

                        TimelineHeaderView(
                            groupName: movieStore.currentGroupName,
                            filterMode: $filterMode,
                            selectedRange: $selectedRange,
                            selectedYear: $selectedYear,
                            availableYears: availableYears,
                            movieCount: filteredMovies.count
                        )
                        .padding(.horizontal)
                        .padding(.top)
                        .padding(.bottom, 6)

                        if filteredMovies.isEmpty {
                            TimelineEmptyStateView()
                                .padding(.horizontal)
                                .padding(.top, 12)
                        } else {
                            ForEach(monthGroups, id: \.monthStart) { group in
                                Section {
                                    LazyVStack(alignment: .leading, spacing: 18) {
                                        ForEach(group.movies) { movie in
                                            TimelineRowView(
                                                movie: movie,
                                                movieBinding: binding(for: movie),
                                                cardAspectRatio: cardAspectRatio,
                                                parallaxStrength: parallaxStrength,
                                                parallaxClamp: parallaxClamp
                                            )
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
                .coordinateSpace(name: TimelinePosterCardView.coordinateSpaceName) // 👈 wichtig für Parallax
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
}

#Preview {
    TimelineView()
        .environmentObject(MovieStore.preview())
        .environmentObject(UserStore())
        .environmentObject(DisplaySettings())
}
