//
//  MovieDetailRatingsLockedCardView.swift
//  filmfreaks
//
//  Backlog-only rating state without exposing rating spoilers.
//

internal import SwiftUI

struct MovieDetailRatingsLockedCardView: View {
    let movieTitle: String

    var body: some View {
        MovieDetailSectionCard(title: "Bewertungen") {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "eye.slash.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(Color.secondary.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("Bewertungen nach dem Film")
                        .font(.subheadline.weight(.semibold))

                    Text("Bewertungen und die Gruppenwertung werden freigeschaltet, sobald \(movieTitle) als gesehen markiert wurde.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Markiere den Film oben als gesehen, wenn ihr ihn geschaut habt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
