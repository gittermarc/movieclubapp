//
//  timelinerow.swift
//  filmfreaks
//

internal import SwiftUI

struct TimelineRowView: View {

    let movie: Movie
    let movieBinding: Binding<Movie>?

    let cardAspectRatio: CGFloat
    let parallaxStrength: CGFloat
    let parallaxClamp: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            timelineMarker

            if let movieBinding {
                NavigationLink {
                    MovieDetailView(movie: movieBinding, isBacklog: false)
                } label: {
                    TimelinePosterCardView(
                        movie: movie,
                        cardAspectRatio: cardAspectRatio,
                        parallaxStrength: parallaxStrength,
                        parallaxClamp: parallaxClamp
                    )
                }
                .buttonStyle(.plain)
            } else {
                TimelinePosterCardView(
                    movie: movie,
                    cardAspectRatio: cardAspectRatio,
                    parallaxStrength: parallaxStrength,
                    parallaxClamp: parallaxClamp
                )
            }
        }
    }

    private var timelineMarker: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .strokeBorder(Color(.systemBackground), lineWidth: 2)
                )
                .padding(.top, 18)

            Rectangle()
                .fill(Color.gray.opacity(0.25))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
                .padding(.top, 4)
        }
        .frame(width: 16)
        .accessibilityHidden(true)
    }
}
