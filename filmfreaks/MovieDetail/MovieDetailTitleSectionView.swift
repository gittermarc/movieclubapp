//
//  MovieDetailTitleSectionView.swift
//  filmfreaks
//
//  Extracted from MovieDetailView.swift.
//

internal import SwiftUI

struct MovieDetailTitleSectionView: View {
    let title: String
    let year: String
    let taglineText: String?
    let releaseDateText: String?
    let originalTitleText: String?
    let originalLanguageText: String?
    let tmdbRating: Double?

    var body: some View {
        MovieDetailSectionCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)

                if let taglineText {
                    Text("„\(taglineText)“")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .italic()
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Jahr: \(year)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let releaseDateText {
                        Text("Release: \(releaseDateText)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let originalTitleText {
                        Text("Originaltitel: \(originalTitleText)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let originalLanguageText {
                        Text("Originalsprache: \(originalLanguageText)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if let tmdbRating {
                    HStack(spacing: 6) {
                        Image(systemName: "star.circle")
                        Text(String(format: "TMDb: %.1f / 10", tmdbRating))
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}
