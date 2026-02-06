//
//  GoalDetailView.swift
//  filmfreaks
//

internal import SwiftUI

// MARK: - Goal Detail View

struct GoalDetailView: View {
    let goal: ViewingCustomGoal
    let movies: [Movie]
    let selectedYear: Int

    @EnvironmentObject var movieStore: MovieStore
    @EnvironmentObject var displaySettings: DisplaySettings

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text(goal.title).font(.headline)
                        Spacer()
                        Text("\(movies.count) / \(goal.target)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                if movies.isEmpty {
                    Text(verbatim: "Keine passenden Filme in \(selectedYear).")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(movies) { m in
                        if let idx = movieStore.movies.firstIndex(where: { $0.id == m.id }) {
                            NavigationLink {
                                MovieDetailView(
                                    movie: $movieStore.movies[idx],
                                    isBacklog: false
                                )
                            } label: {
                                goalDetailMovieRow(m)
                            }
                        } else {
                            goalDetailMovieRow(m)
                        }
                    }
                }
            }
            .navigationTitle("Passende Filme")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func goalDetailMovieRow(_ m: Movie) -> some View {
        HStack(spacing: 12) {
            if let url = m.posterURL {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle().foregroundStyle(.gray.opacity(0.2))
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Rectangle().foregroundStyle(.gray.opacity(0.15))
                            .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
                    @unknown default:
                        Rectangle().foregroundStyle(.gray.opacity(0.2))
                    }
                }
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Rectangle()
                    .foregroundStyle(.gray.opacity(0.15))
                    .frame(width: 40, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(m.title)
                        .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(m.year)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let date = m.watchedDateText {
                        Text(verbatim: "• \(date)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if displaySettings.showRatings {
                let avg = displaySettings.showTMDbRatingsInLists
                ? m.displayAverage(for: displaySettings.ratingDisplayMode)
                : m.groupAverage(for: displaySettings.ratingDisplayMode)

                if let avg {
                    Text(String(format: "%.1f", avg))
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(displaySettings.tintColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
    }
}
