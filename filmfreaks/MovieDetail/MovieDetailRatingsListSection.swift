//
//  MovieDetailRatingsListSection.swift
//  filmfreaks
//
//  Extracted from MovieDetailView.swift.
//

internal import SwiftUI

struct MovieDetailRatingsListSection: View {

    @EnvironmentObject private var displaySettings: DisplaySettings
    @EnvironmentObject private var userStore: UserStore
    let ratings: [Rating]
    let selectedUserID: UUID?
    let selectedUserName: String?
    let reviewTransitionNamespace: Namespace.ID

    private var summary: MovieRatingGroupSummary {
        MovieRatingGroupSummary(ratings: ratings)
    }

    private var orderedRatings: [Rating] {
        MovieRatingPresentation.orderedRatings(
            ratings,
            selectedUserID: selectedUserID,
            selectedUserName: selectedUserName
        )
    }

    var body: some View {
        if ratings.isEmpty {
            ContentUnavailableView(
                "Noch keine Bewertungen",
                systemImage: "person.2.slash",
                description: Text("Sobald jemand den Film bewertet, erscheint die Gruppenwertung hier.")
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                MovieRatingsGroupSummaryCard(
                    summary: summary,
                    tintColor: displaySettings.tintColor
                )

                ForEach(orderedRatings) { rating in
                    MovieRatingMemberCard(
                        rating: rating,
                        member: MemberAvatarResolver.member(for: rating, in: userStore.users),
                        groupId: userStore.currentGroupId,
                        isCurrentUser: MovieRatingPresentation.belongsToCurrentUser(
                            rating,
                            selectedUserID: selectedUserID,
                            selectedUserName: selectedUserName
                        ),
                        tintColor: displaySettings.tintColor,
                        reviewTransitionNamespace: reviewTransitionNamespace
                    )
                }
            }
        }
    }
}
