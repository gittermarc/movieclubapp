//
//  MovieNightPlanningView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 15.04.26.
//

internal import SwiftUI

/// Small planning hub that keeps hosting/routing responsibilities out of the
/// calendar feature while keeping the planning tools in one place.
struct MovieNightPlanningView: View {

    @State private var selectedSection: MovieNightPlanningSection = .defaultSection

    var body: some View {
        NavigationStack {
            sectionContent
                .navigationTitle(selectedSection.navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .top, spacing: 0) {
                    planningSectionPicker
                }
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .calendar:
            MovieNightCalendarContentView()
        case .roulette:
            MovieRouletteView()
        }
    }

    private var planningSectionPicker: some View {
        VStack(spacing: 8) {
            Picker("Bereich", selection: $selectedSection) {
                ForEach(MovieNightPlanningSection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

#Preview {
    MovieNightPlanningView()
        .environmentObject(MovieStore.preview())
        .environmentObject(MovieNightStore())
        .environmentObject(UserStore())
        .environmentObject(CloudKitGroupStore())
        .environmentObject(DisplaySettings())
}
