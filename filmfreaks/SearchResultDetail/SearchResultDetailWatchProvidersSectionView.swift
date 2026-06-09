//
//  SearchResultDetailWatchProvidersSectionView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 17.01.26.
//

internal import SwiftUI

struct SearchResultDetailWatchProvidersSectionView: View {

    let isLoading: Bool
    let didLoad: Bool
    let country: TMDbWatchProvidersCountry?
    let link: URL?
    let effectiveRegionCode: String
    let isAutomatic: Bool
    let onShowOtherCountries: () -> Void

    private var preferredProviderIDs: Set<Int> {
        WatchProviderPreferencesStore().preferredProviderIDs(regionCode: effectiveRegionCode)
    }

    var body: some View {
        if isLoading {
            SearchResultDetailSectionCard(title: "Film ist verfügbar bei:") {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Suche Streaming-Anbieter …")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } else if didLoad {
            SearchResultDetailSectionCard(title: "Film ist verfügbar bei:") {
                if let country = country,
                   !country.bestEffortProviders.isEmpty {
                    WatchProvidersAvailabilityView(country: country, link: link, preferredProviderIDs: preferredProviderIDs)
                } else {
                    WatchProvidersNoDataHintView(
                        regionCode: effectiveRegionCode,
                        isAutomatic: isAutomatic
                    ) {
                        onShowOtherCountries()
                    }
                }
            }
        }
    }
}
