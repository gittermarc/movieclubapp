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

    @EnvironmentObject private var displaySettings: DisplaySettings

    @Binding var movie: Movie

    @Binding var localScores: [RatingCriterion: Int]
    @Binding var localComment: String
    @Binding var localFazitScore: Int?
    @Binding var hasPendingRatingChanges: Bool

    let onSave: () -> Void

    @EnvironmentObject private var userStore: UserStore
    @Environment(\.dismiss) private var dismiss
    @Namespace private var reviewTransitionNamespace
    @State private var reviewPath: [MovieRatingReviewRoute] = []
    @State private var selectedDetent: PresentationDetent = .medium

    var body: some View {
        NavigationStack(path: $reviewPath) {
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
                                if let selectedUser = userStore.selectedUser {
                                    HStack(spacing: 8) {
                                        MemberAvatarView(
                                            member: selectedUser,
                                            groupId: userStore.currentGroupId,
                                            size: 34,
                                            tintColor: displaySettings.tintColor
                                        )

                                        Text("Als: \(selectedUser.name)")
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
                                ratings: movie.ratings,
                                selectedUserID: userStore.selectedUser?.id,
                                selectedUserName: userStore.selectedUser?.name,
                                reviewTransitionNamespace: reviewTransitionNamespace
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
            .navigationDestination(for: MovieRatingReviewRoute.self) { route in
                reviewDestination(for: route)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if reviewPath.isEmpty {
                        Button("Schließen") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .onChange(of: reviewPath) { _, newPath in
            if newPath.isEmpty == false {
                selectedDetent = .large
            }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }

    private var headerCard: some View {
        MovieDetailSectionCard {
            HStack(alignment: .top, spacing: 12) {
                MovieRatingPosterThumbnailView(
                    movie: movie,
                    width: 68,
                    height: 100,
                    cornerRadius: 12
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text(movie.title)
                        .font(.headline.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(movie.year)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        averageChip(
                            title: "Bewertung Ø",
                            value: movie.averageRating,
                            color: displaySettings.tintColor
                        )
                        averageChip(
                            title: "Fazit Ø",
                            value: movie.averageFazit,
                            color: MovieRatingFazitScale.color(
                                for: movie.averageFazit.map { Int($0.rounded()) }
                            )
                        )
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
    private func averageChip(title: String, value: Double?, color: Color) -> some View {
        if let value {
            Text(String(format: "\(title) %.1f", value))
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(color.opacity(0.14))
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

    @ViewBuilder
    private func reviewDestination(for route: MovieRatingReviewRoute) -> some View {
        if let rating = MovieRatingReviewPresentation.rating(for: route, in: movie.ratings),
           let comment = MovieRatingReviewPresentation.comment(for: rating) {
            MovieRatingReviewReaderView(
                movie: movie,
                rating: rating,
                comment: comment,
                member: MemberAvatarResolver.member(for: rating, in: userStore.users),
                groupId: userStore.currentGroupId,
                isCurrentUser: MovieRatingPresentation.belongsToCurrentUser(
                    rating,
                    selectedUserID: userStore.selectedUser?.id,
                    selectedUserName: userStore.selectedUser?.name
                ),
                tintColor: displaySettings.tintColor
            )
            .navigationTransition(
                .zoom(sourceID: route.ratingID, in: reviewTransitionNamespace)
            )
        } else {
            ContentUnavailableView(
                "Rezension nicht verfügbar",
                systemImage: "quote.bubble",
                description: Text("Die Bewertung wurde zwischenzeitlich geändert oder entfernt.")
            )
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
        hasPendingRatingChanges: .constant(false)
    ) {
        // no-op
    }
    .environmentObject(UserStore())
    .environmentObject(DisplaySettings())
}
