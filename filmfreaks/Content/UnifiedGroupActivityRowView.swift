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

    var body: some View {
        switch event.payload {
        case .movie(let e):
            GroupActivityRowView(event: e)

        case .movieNight(let e):
            MovieNightActivityRowView(event: e)
        }
    }
}
