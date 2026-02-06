//
//  MovieSearchSkeletonViews.swift
//  filmfreaks
//

internal import SwiftUI

struct MovieSearchSkeletonResultsView: View {

    @Binding var pulse: Bool
    let keyboardHeight: CGFloat
    let keyboardAnimationDuration: Double

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { _ in
                    skeletonCard
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .padding(.bottom, keyboardHeight)
        .animation(.easeOut(duration: keyboardAnimationDuration), value: keyboardHeight)
        .opacity(pulse ? 0.55 : 0.85)
    }

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.22))
                    .frame(width: MovieSearchUI.posterWidth, height: MovieSearchUI.posterHeight)

                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.22))
                        .frame(height: 14)
                        .frame(maxWidth: 240)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.18))
                        .frame(height: 12)
                        .frame(maxWidth: 160)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.16))
                        .frame(height: 26)
                        .frame(maxWidth: 170)
                        .padding(.top, 2)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: MovieSearchUI.cardCorner)
                .fill(Color(.secondarySystemBackground))
        )
        .redacted(reason: .placeholder)
    }
}

struct MovieSearchRecommendationsSkeletonView: View {

    @Binding var pulse: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in
                    skeletonCard
                }
            }
            .padding(.horizontal)
        }
        .opacity(pulse ? 0.55 : 0.85)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
        }
    }

    private var skeletonCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.22))
                .frame(width: MovieSearchUI.recPosterWidth, height: MovieSearchUI.recPosterHeight)

            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.20))
                .frame(height: 12)
                .frame(width: MovieSearchUI.recPosterWidth)

            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.16))
                .frame(height: 10)
                .frame(width: MovieSearchUI.recPosterWidth * 0.7)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: MovieSearchUI.recCardCorner)
                .fill(Color(.secondarySystemBackground))
        )
        .redacted(reason: .placeholder)
    }
}
