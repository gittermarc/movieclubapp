//
//  MovieNightCalendarView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

internal import SwiftUI

/// Standalone screen wrapper for the Movie Night calendar.
///
/// The actual calendar content lives in `MovieNightCalendarContentView` so it
/// can also be embedded in the planning hub without moving hosting concerns
/// into the calendar feature itself.
struct MovieNightCalendarView: View {

    var body: some View {
        NavigationStack {
            MovieNightCalendarContentView()
                .navigationTitle("Kalender")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    MovieNightCalendarView()
        .environmentObject(MovieStore.preview())
        .environmentObject(MovieNightStore())
        .environmentObject(UserStore())
        .environmentObject(CloudKitGroupStore())
        .environmentObject(DisplaySettings())
}
