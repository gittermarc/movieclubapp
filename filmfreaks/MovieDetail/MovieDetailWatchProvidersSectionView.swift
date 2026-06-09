//
//  MovieDetailWatchProvidersSectionView.swift
//  filmfreaks
//
//  Extracted from MovieDetailView.swift.
//

internal import SwiftUI

struct MovieDetailWatchProvidersSectionView: View {
    let isLoading: Bool
    let didLoad: Bool
    let country: TMDbWatchProvidersCountry?
    let link: URL?
    let regionCode: String
    let isAutomatic: Bool
    let onPickRegion: () -> Void

    private var preferredProviderIDs: Set<Int> {
        WatchProviderPreferencesStore().preferredProviderIDs(regionCode: regionCode)
    }

    var body: some View {
        Group {
            if isLoading {
                MovieDetailSectionCard(title: "Film ist verfügbar bei:") {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Suche Streaming-Anbieter …")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if didLoad {
                MovieDetailSectionCard(title: "Film ist verfügbar bei:") {
                    if let country,
                       !country.bestEffortProviders.isEmpty {
                        WatchProvidersAvailabilityView(country: country, link: link, preferredProviderIDs: preferredProviderIDs)
                    } else {
                        WatchProvidersNoDataHintView(
                            regionCode: regionCode,
                            isAutomatic: isAutomatic,
                            onShowOtherCountries: onPickRegion
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    MovieDetailWatchProvidersSectionView(
        isLoading: true,
        didLoad: false,
        country: nil,
        link: nil,
        regionCode: "DE",
        isAutomatic: false,
        onPickRegion: {}
    )
    .padding()
}
