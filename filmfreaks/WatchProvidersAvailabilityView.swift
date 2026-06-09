//
//  WatchProvidersAvailabilityView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 16.01.26.
//

internal import SwiftUI

/// Anzeige der Streaming-Anbieter inklusive sinnvoller Gruppierung:
/// Kostenlos (Streaming / Mit Werbung) und Kostenpflichtig (Abo / Leihen / Kaufen).
struct WatchProvidersAvailabilityView: View {

    let country: TMDbWatchProvidersCountry
    let link: URL?
    var preferredProviderIDs: Set<Int> = []

    @State private var showDetails: Bool = false

    private var bestEffort: [TMDbWatchProvider] {
        WatchProvidersAvailabilityPresentation.sortedDeduplicated(
            country.bestEffortProviders,
            preferredProviderIDs: preferredProviderIDs
        )
    }

    private var free: [TMDbWatchProvider] { sortedDedup(country.free ?? []) }
    private var ads: [TMDbWatchProvider] { sortedDedup(country.ads ?? []) }
    private var flatrate: [TMDbWatchProvider] { sortedDedup(country.flatrate ?? []) }
    private var rent: [TMDbWatchProvider] { sortedDedup(country.rent ?? []) }
    private var buy: [TMDbWatchProvider] { sortedDedup(country.buy ?? []) }

    private var preferredSummary: String? {
        WatchProvidersAvailabilityPresentation.preferredSummaryText(
            in: country,
            preferredProviderIDs: preferredProviderIDs
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let preferredSummary {
                Label(preferredSummary, systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.accentColor.opacity(0.10))
                    .clipShape(Capsule())
                    .accessibilityLabel(preferredSummary)
            }

            WatchProvidersIconsRow(
                providers: bestEffort,
                preferredProviderIDs: preferredProviderIDs
            )

            DisclosureGroup(isExpanded: $showDetails) {
                VStack(alignment: .leading, spacing: 14) {
                    if !free.isEmpty || !ads.isEmpty {
                        groupHeader("Kostenlos")

                        if !free.isEmpty {
                            providersRow(title: "Streaming", systemImage: "play.circle", providers: free)
                        }

                        if !ads.isEmpty {
                            providersRow(title: "Streaming (mit Werbung)", systemImage: "tv", providers: ads)
                        }
                    }

                    if !flatrate.isEmpty || !rent.isEmpty || !buy.isEmpty {
                        groupHeader("Kostenpflichtig")

                        if !flatrate.isEmpty {
                            providersRow(title: "Streaming (Abo)", systemImage: "rectangle.stack.badge.play", providers: flatrate)
                        }

                        if !rent.isEmpty {
                            providersRow(title: "Leihen", systemImage: "cart.badge.minus", providers: rent)
                        }

                        if !buy.isEmpty {
                            providersRow(title: "Kaufen", systemImage: "cart", providers: buy)
                        }
                    }
                }
                .padding(.top, 6)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundStyle(.secondary)
                    Text("Details (Kostenlos / Kostenpflichtig)")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .tint(.primary)

            if let link {
                Link(destination: link) {
                    Label("Mehr Infos", systemImage: "safari")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }

    // MARK: - Helpers

    private func sortedDedup(_ providers: [TMDbWatchProvider]) -> [TMDbWatchProvider] {
        WatchProvidersAvailabilityPresentation.sortedDeduplicated(
            providers,
            preferredProviderIDs: preferredProviderIDs
        )
    }

    @ViewBuilder
    private func groupHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.10))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func providersRow(title: String, systemImage: String, providers: [TMDbWatchProvider]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            WatchProvidersIconsRow(
                providers: providers,
                preferredProviderIDs: preferredProviderIDs
            )
        }
    }
}

#Preview {
    let sample = TMDbWatchProvidersCountry(
        link: "https://www.themoviedb.org",
        flatrate: [TMDbWatchProvider(provider_id: 1, provider_name: "Netflix", logo_path: nil, display_priority: 0)],
        ads: [TMDbWatchProvider(provider_id: 2, provider_name: "Pluto TV", logo_path: nil, display_priority: 0)],
        free: [TMDbWatchProvider(provider_id: 3, provider_name: "ARD", logo_path: nil, display_priority: 0)],
        rent: [TMDbWatchProvider(provider_id: 4, provider_name: "Apple TV", logo_path: nil, display_priority: 0)],
        buy: [TMDbWatchProvider(provider_id: 5, provider_name: "Amazon", logo_path: nil, display_priority: 0)]
    )

    return ScrollView {
        WatchProvidersAvailabilityView(
            country: sample,
            link: URL(string: sample.link ?? ""),
            preferredProviderIDs: [1, 4]
        )
        .padding()
    }
}
