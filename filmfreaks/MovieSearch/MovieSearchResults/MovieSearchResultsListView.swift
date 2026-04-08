//
//  MovieSearchResultsListView.swift
//  filmfreaks
//

internal import SwiftUI

struct MovieSearchResultsListView<Row: View>: View {

    @EnvironmentObject private var displaySettings: DisplaySettings

    let results: [TMDbMovieResult]
    let canLoadMore: Bool
    let isLoadingMore: Bool
    let totalResults: Int

    let keyboardHeight: CGFloat
    let keyboardAnimationDuration: Double

    let onLoadMore: () -> Void
    @ViewBuilder let rowContent: (TMDbMovieResult) -> Row

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(results) { result in
                    rowContent(result)
                        .onAppear {
                            // Infinite Scroll: wenn das letzte Element auftaucht -> laden
                            if results.last?.id == result.id, canLoadMore {
                                onLoadMore()
                            }
                        }
                }

                footer
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .padding(.bottom, keyboardHeight)
            .animation(.easeOut(duration: keyboardAnimationDuration), value: keyboardHeight)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if isLoadingMore {
            HStack(spacing: 10) {
                ProgressView()
                Text("Lade weitere Treffer…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 14)
        } else if canLoadMore {
            Button(action: onLoadMore) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                    Text("Mehr laden")
                }
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(displaySettings.tintSoftBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            .padding(.bottom, 12)
        } else if totalResults > 0 {
            Text("Ende der Trefferliste.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 10)
        }
    }
}
