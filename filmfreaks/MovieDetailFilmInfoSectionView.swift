//
//  MovieDetailFilmInfoSectionView.swift
//  filmfreaks
//
//  Extracted from MovieDetailView.swift.
//

internal import SwiftUI

struct MovieDetailFilmInfoSectionView: View {

    @EnvironmentObject private var displaySettings: DisplaySettings
    let movie: Movie
    let runtimeText: String?
    let genreNames: [String]
    let director: String?
    let castList: [TMDbCast]
    let keywordsText: String?
    let trailerKey: String?
    let trailerWatchURL: URL?

    @Binding var selectedPerson: SelectedPerson?
    @Binding var isTrailerSafariShown: Bool

    var body: some View {
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
                castRow
            }

            if let keywordsText {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Schlüsselwörter")
                        .font(.subheadline).bold()
                    Text(keywordsText)
                        .font(.subheadline)
                }
            }

            // Trailer: Inline-Embed deaktiviert (zu oft "Video nicht verfuegbar" in WKWebView).
            if let key = trailerKey {
                MovieDetailTrailerSectionView(
                    movie: movie,
                    trailerKey: key,
                    trailerWatchURL: trailerWatchURL,
                    isTrailerSafariShown: $isTrailerSafariShown
                )
            }
        }
    }

    private var castRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hauptdarsteller")
                .font(.subheadline).bold()

            ZStack(alignment: .trailing) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(castList, id: \.id) { person in
                            Button {
                                selectedPerson = SelectedPerson(
                                    id: person.id,
                                    name: person.name,
                                    subtitle: person.character
                                )
                            } label: {
                                HStack(alignment: .center, spacing: 8) {
                                    castAvatar(profilePath: person.profile_path)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(person.name)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        if let role = person.character?.trimmingCharacters(in: .whitespacesAndNewlines),
                                           !role.isEmpty {
                                            Text(role)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(displaySettings.tintSoftBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if castList.count >= 9 {
                    LinearGradient(
                        colors: [
                            Color(.secondarySystemBackground),
                            Color(.secondarySystemBackground).opacity(0.0)
                        ],
                        startPoint: .trailing,
                        endPoint: .leading
                    )
                    .frame(width: 28)
                    .allowsHitTesting(false)
                }
            }
        }
    }

    @ViewBuilder
    private func castAvatar(profilePath: String?) -> some View {
        let size: CGFloat = 34

        if let path = profilePath,
           let url = URL(string: "https://image.tmdb.org/t/p/w92\(path)") {
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
                    ZStack {
                        Circle().foregroundStyle(.gray.opacity(0.18))
                        Image(systemName: "person.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                @unknown default:
                    ZStack {
                        Circle().foregroundStyle(.gray.opacity(0.18))
                        Image(systemName: "person.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        } else {
            ZStack {
                Circle().foregroundStyle(.gray.opacity(0.18))
                Image(systemName: "person.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: size, height: size)
            .overlay(
                Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
}
