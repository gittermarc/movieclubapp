//
//  MovieRatingsSheetView.swift
//  filmfreaks
//
//  Ratings moved out of MovieDetailView into a dedicated sheet.
//

internal import SwiftUI

/// Separates rating input + all individual ratings into a dedicated sheet.
/// The actual saving logic stays in `MovieDetailView` (via `onSave`).
struct MovieRatingsSheetView: View {

    @Binding var movie: Movie

    @Binding var localScores: [RatingCriterion: Int]
    @Binding var localComment: String
    @Binding var localFazitScore: Int?
    @Binding var expandedRatingIds: Set<UUID>
    @Binding var hasPendingRatingChanges: Bool

    let onSave: () -> Void

    @EnvironmentObject private var userStore: UserStore
    @Environment(\.dismiss) private var dismiss

    private var sortedRatings: [Rating] {
        movie.ratings.sorted {
            $0.reviewerName.localizedCaseInsensitiveCompare($1.reviewerName) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        headerCard

                        MovieDetailSectionCard(title: "Deine Bewertung") {
                            VStack(alignment: .leading, spacing: 10) {
                                if let name = userStore.selectedUser?.name {
                                    HStack(spacing: 8) {
                                        Image(systemName: "person.crop.circle")
                                            .foregroundStyle(.secondary)

                                        Text("Als: \(name)")
                                            .font(.subheadline.weight(.semibold))

                                        Spacer(minLength: 0)

                                        if hasPendingRatingChanges {
                                            Text("Ungespeichert")
                                                .font(.caption.weight(.semibold))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Color.orange.opacity(0.16))
                                                .clipShape(Capsule())
                                        }
                                    }
                                } else {
                                    HStack(spacing: 8) {
                                        Image(systemName: "person.crop.circle.badge.questionmark")
                                            .foregroundStyle(.secondary)
                                        Text("Wähle oben in der App eine Person aus, um zu bewerten.")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                MovieDetailRatingInputSection(
                                    hasSelectedUser: userStore.selectedUser != nil,
                                    localScores: $localScores,
                                    localComment: $localComment,
                                    localFazitScore: $localFazitScore,
                                    hasPendingRatingChanges: $hasPendingRatingChanges
                                ) {
                                    onSave()
                                }
                            }
                        }

                        MovieDetailSectionCard(title: "Alle Bewertungen") {
                            MovieDetailRatingsListSection(
                                ratings: sortedRatings,
                                expandedRatingIds: $expandedRatingIds
                            )
                        }

                        Spacer(minLength: 0)
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Bewertungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var headerCard: some View {
        MovieDetailSectionCard {
            HStack(alignment: .top, spacing: 12) {
                posterThumbnail

                VStack(alignment: .leading, spacing: 8) {
                    Text(movie.title)
                        .font(.headline.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(movie.year)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        averageChip(title: "Bewertung Ø", value: movie.averageRating)
                        averageChip(title: "Fazit Ø", value: movie.averageFazit)
                        Spacer(minLength: 0)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(.secondary)

                        Text("\(movie.ratings.count) \(movie.ratings.count == 1 ? "Bewertung" : "Bewertungen")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 0)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var posterThumbnail: some View {
        Group {
            if let url = movie.posterURL {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .foregroundStyle(.gray.opacity(0.18))
                            ProgressView()
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        RoundedRectangle(cornerRadius: 12)
                            .foregroundStyle(.gray.opacity(0.18))
                            .overlay {
                                Image(systemName: "film")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                    @unknown default:
                        RoundedRectangle(cornerRadius: 12)
                            .foregroundStyle(.gray.opacity(0.18))
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .foregroundStyle(.gray.opacity(0.18))
                    .overlay {
                        Image(systemName: "film")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 68, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func averageChip(title: String, value: Double?) -> some View {
        if let value {
            Text(String(format: "\(title) %.1f", value))
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.12))
                .clipShape(Capsule())
        } else {
            Text("\(title) –")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.10))
                .clipShape(Capsule())
        }
    }
}

#Preview {
    MovieRatingsSheetView(
        movie: .constant(
            Movie(
                title: "Inception",
                year: "2010",
                tmdbRating: 8.8,
                ratings: [
                    Rating(
                        reviewerId: UUID(),
                        reviewerName: "Marc",
                        scores: [.action: 3, .suspense: 3, .emotion: 2],
                        comment: "Mega Film.",
                        fazitScore: 9
                    ),
                    Rating(
                        reviewerId: UUID(),
                        reviewerName: "Claudia",
                        scores: [.action: 2, .suspense: 3, .emotion: 3],
                        comment: "Sehr spannend.",
                        fazitScore: 8
                    )
                ],
                posterPath: nil,
                tmdbId: 27205
            )
        ),
        localScores: .constant([.action: 2]),
        localComment: .constant(""),
        localFazitScore: .constant(nil),
        expandedRatingIds: .constant([]),
        hasPendingRatingChanges: .constant(false)
    ) {
        // no-op
    }
    .environmentObject(UserStore())
}
