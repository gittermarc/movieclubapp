//
//  SearchResultDetailFilmInfoSectionView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 17.01.26.
//

internal import SwiftUI

struct SearchResultDetailFilmInfoSectionView: View {

    @EnvironmentObject private var displaySettings: DisplaySettings

    let runtimeText: String?
    let genreNames: [String]
    let director: String?
    let castList: [TMDbCast]
    let keywordsText: String?
    let shouldShowTrailer: Bool
    let posterURL: URL?
    let trailerWatchURL: URL?
    @Binding var isTrailerSafariShown: Bool
    let onTapPerson: (_ personId: Int, _ name: String, _ role: String?) -> Void

    var body: some View {
        SearchResultDetailSectionCard(title: "Infos zum Film") {
            VStack(alignment: .leading, spacing: 10) {

                if let runtimeText {
                    Text("Laufzeit: \(runtimeText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !genreNames.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Genre")
                            .font(.subheadline).bold()

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 80), spacing: 8)],
                            alignment: .leading,
                            spacing: 8
                        ) {
                            ForEach(genreNames, id: \.self) { genre in
                                Text(genre)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(displaySettings.tintChipBackground)
                                    .foregroundStyle(.primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                if let director {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("Regie:")
                            .font(.subheadline).bold()
                        Text(director)
                            .font(.subheadline)
                    }
                }

                if !castList.isEmpty {
                    castScroller
                }

                if let keywordsText {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Schlüsselwörter")
                            .font(.subheadline).bold()
                        Text(keywordsText)
                            .font(.subheadline)
                    }
                }

                if shouldShowTrailer {
                    SearchResultDetailTrailerInlineBlockView(
                        posterURL: posterURL,
                        trailerWatchURL: trailerWatchURL,
                        isTrailerSafariShown: $isTrailerSafariShown
                    )
                }
            }
        }
    }

    private var castScroller: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hauptdarsteller")
                .font(.subheadline).bold()

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 8, alignment: .top)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(castList, id: \.id) { person in
                    Button {
                        onTapPerson(person.id, person.name, person.character)
                    } label: {
                        HStack(alignment: .center, spacing: 8) {
                            SearchResultDetailCastAvatarView(profilePath: person.profile_path)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                if let role = person.character?.trimmingCharacters(in: .whitespacesAndNewlines),
                                   !role.isEmpty {
                                    Text(role)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(displaySettings.tintSoftBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SearchResultDetailCastAvatarView: View {
    let profilePath: String?

    var body: some View {
        let size: CGFloat = 34

        if let profilePath,
           let url = URL(string: "https://image.tmdb.org/t/p/w92\(profilePath)") {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Circle().foregroundStyle(.gray.opacity(0.18))
                        ProgressView().scaleEffect(0.75)
                    }

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()

                case .failure:
                    fallback

                @unknown default:
                    fallback
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        } else {
            fallback
                .frame(width: size, height: size)
                .overlay(
                    Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }

    private var fallback: some View {
        ZStack {
            Circle().foregroundStyle(.gray.opacity(0.18))
            Image(systemName: "person.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}
