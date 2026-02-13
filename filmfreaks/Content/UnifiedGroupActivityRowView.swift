//
//  UnifiedGroupActivityRowView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

internal import SwiftUI

/// Single row for the unified activity feed.
///
/// Delegates rendering to existing row views:
/// - `GroupActivityRowView` for movies/ratings
/// - `MovieNightActivityRowView` for movie night planning
struct UnifiedGroupActivityRowView: View {

    let event: UnifiedGroupActivityEvent

    @Binding var movieNightSelection: MovieNightSheetSelection?

    init(
        event: UnifiedGroupActivityEvent,
        movieNightSelection: Binding<MovieNightSheetSelection?> = .constant(nil)
    ) {
        self.event = event
        self._movieNightSelection = movieNightSelection
    }

    var body: some View {
        switch event.payload {
        case .movie(let e):
            GroupActivityRowView(event: e)

        case .movieNight(let e):
            Button {
                movieNightSelection = MovieNightSheetSelection(groupId: e.groupId, eventId: e.eventId)
            } label: {
                MovieNightActivityRowView(event: e)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityHint("Öffnet den Filmabend")
        }
    }
}
