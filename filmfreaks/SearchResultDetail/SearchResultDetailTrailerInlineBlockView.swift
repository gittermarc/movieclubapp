//
//  SearchResultDetailTrailerInlineBlockView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 17.01.26.
//

internal import SwiftUI

struct SearchResultDetailTrailerInlineBlockView: View {

    @EnvironmentObject private var displaySettings: DisplaySettings

    let previewURL: URL?
    let trailerWatchURL: URL?
    @Binding var isTrailerSafariShown: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Trailer")
                .font(.subheadline).bold()

            if trailerWatchURL != nil {
                Button {
                    isTrailerSafariShown = true
                } label: {
                    ZStack {
                        posterPreview
                            .frame(maxWidth: .infinity)
                            .aspectRatio(16.0/9.0, contentMode: .fit)
                            .clipped()
                            .overlay(
                                LinearGradient(
                                    colors: [
                                        Color.black.opacity(0.25),
                                        Color.black.opacity(0.55)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                        HStack(spacing: 10) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 42, weight: .semibold))
                            Text("Trailer abspielen")
                                .font(.headline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    Button {
                        isTrailerSafariShown = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "safari.fill")
                            Text("In App öffnen")
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    if let trailerWatchURL {
                        Link(destination: trailerWatchURL) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.right.square")
                                Text("In YouTube öffnen")
                            }
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(displaySettings.tintSoftBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }

            } else {
                Text("Trailer nicht verfügbar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            privacyNote
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var posterPreview: some View {
        if let url = previewURL {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    Rectangle().foregroundStyle(.gray.opacity(0.15))
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Rectangle().foregroundStyle(.gray.opacity(0.15))
                @unknown default:
                    Rectangle().foregroundStyle(.gray.opacity(0.15))
                }
            }
        } else {
            Rectangle().foregroundStyle(.gray.opacity(0.15))
        }
    }

    private var privacyNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Datenschutz")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Beim Abspielen wird ein YouTube-Video geöffnet. Dabei kann eine Verbindung zu YouTube/Google hergestellt und personenbezogene Daten (z. B. IP-Adresse) übertragen werden.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Link(destination: URL(string: "https://policies.google.com/privacy")!) {
                Text("Google/YouTube Datenschutzerklärung öffnen")
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.top, 2)
    }
}
