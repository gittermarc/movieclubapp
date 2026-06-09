//
//  WatchProvidersIconsRow.swift
//  filmfreaks
//
//  Created by Marc Fechner on 11.01.26.
//

internal import SwiftUI

// MARK: - UI

struct WatchProvidersIconsRow: View {
    let providers: [TMDbWatchProvider]
    var preferredProviderIDs: Set<Int> = []

    private var sortedProviders: [TMDbWatchProvider] {
        WatchProvidersAvailabilityPresentation.sortedDeduplicated(
            providers,
            preferredProviderIDs: preferredProviderIDs
        )
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 72), spacing: 12, alignment: .top)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(sortedProviders) { provider in
                VStack(spacing: 6) {
                    ZStack(alignment: .topTrailing) {
                        providerLogo(provider)
                            .frame(width: 30, height: 30)

                        if preferredProviderIDs.contains(provider.provider_id) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2.weight(.bold))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor)
                                .offset(x: 5, y: -5)
                                .accessibilityHidden(true)
                        }
                    }

                    Text(provider.provider_name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityLabel(for: provider))
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func accessibilityLabel(for provider: TMDbWatchProvider) -> Text {
        if preferredProviderIDs.contains(provider.provider_id) {
            return Text("\(provider.provider_name), bevorzugter Anbieter")
        }
        return Text(provider.provider_name)
    }

    @ViewBuilder
    private func providerLogo(_ provider: TMDbWatchProvider) -> some View {
        if let url = MovieMetadataPresentation.imageURL(path: provider.logo_path, width: .w92) {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .foregroundStyle(.gray.opacity(0.18))
                        ProgressView().scaleEffect(0.75)
                    }

                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()

                case .failure:
                    fallbackLogo(for: provider)

                @unknown default:
                    fallbackLogo(for: provider)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            )
        } else {
            fallbackLogo(for: provider)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private func fallbackLogo(for provider: TMDbWatchProvider) -> some View {
        let initial = provider.provider_name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(1)
            .uppercased()

        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .foregroundStyle(.gray.opacity(0.18))

            Text(initial.isEmpty ? "▶︎" : initial)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
    }
}
