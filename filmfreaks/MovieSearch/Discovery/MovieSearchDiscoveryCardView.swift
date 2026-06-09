//
//  MovieSearchDiscoveryCardView.swift
//  filmfreaks
//

internal import SwiftUI

struct MovieSearchDiscoveryCardView: View {
    let result: TMDbMovieResult
    let isInWatched: Bool
    let isInBacklog: Bool

    let onOpenDetail: () -> Void
    let onAddToWatched: () -> Void
    let onAddToBacklog: () -> Void

    var body: some View {
        MovieSearchRecommendationCardView(
            result: result,
            isInWatched: isInWatched,
            isInBacklog: isInBacklog,
            onOpenDetail: onOpenDetail,
            onAddToWatched: onAddToWatched,
            onAddToBacklog: onAddToBacklog
        )
    }
}
