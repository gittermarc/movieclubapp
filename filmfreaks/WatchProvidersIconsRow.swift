//
//  WatchProvidersIconsRow.swift
//  filmfreaks
//
//  Created by Marc Fechner on 11.01.26.
//

internal import SwiftUI

// MARK: - Helpers

extension TMDbWatchProvidersCountry {
    /// Best-effort Liste von Anbietern, in sinnvoller Priorität:
    /// flatrate (Abo) -> free -> ads -> rent -> buy
    /// Dedupe nach provider_id und sortiert nach display_priority.
    var bestEffortProviders: [TMDbWatchProvider] {
        let groups: [[TMDbWatchProvider]] = [
            flatrate ?? [],
            free ?? [],
            ads ?? [],
            rent ?? [],
            buy ?? []
        ]

        var seen = Set<Int>()
        var output: [TMDbWatchProvider] = []

        for group in groups {
            let sorted = group.sorted {
                ($0.display_priority ?? Int.max) < ($1.display_priority ?? Int.max)
            }

            for p in sorted where !seen.contains(p.provider_id) {
                output.append(p)
                seen.insert(p.provider_id)
            }
        }

        return output
    }
}

// MARK: - UI

struct WatchProvidersIconsRow: View {
    let providers: [TMDbWatchProvider]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(providers) { provider in
                    VStack(spacing: 6) {
                        providerLogo(provider)
                            .frame(width: 30, height: 30)

                        Text(provider.provider_name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(width: 74)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text(provider.provider_name))
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func providerLogo(_ provider: TMDbWatchProvider) -> some View {
        if let path = provider.logo_path,
           let url = URL(string: "https://image.tmdb.org/t/p/w92\(path)") {
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
