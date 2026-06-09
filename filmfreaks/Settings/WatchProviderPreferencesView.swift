//
//  WatchProviderPreferencesView.swift
//  filmfreaks
//

internal import SwiftUI

struct WatchProviderPreferencesView: View {

    @AppStorage(WatchProvidersRegionSettings.storageKey)
    private var storedRegionCode: String = WatchProvidersRegionSettings.deviceRegionCode()

    @State private var providers: [TMDbWatchProvider] = []
    @State private var selectedProviderIDs: Set<Int> = []
    @State private var searchText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let preferencesStore: WatchProviderPreferencesStore
    private let catalogRepository: WatchProviderCatalogRepository

    init(
        preferencesStore: WatchProviderPreferencesStore = WatchProviderPreferencesStore(),
        catalogRepository: WatchProviderCatalogRepository = WatchProviderCatalogRepository()
    ) {
        self.preferencesStore = preferencesStore
        self.catalogRepository = catalogRepository
    }

    private var effectiveRegionCode: String {
        WatchProvidersRegionSettings.effectiveRegionCode(from: storedRegionCode)
        ?? WatchProvidersRegionSettings.deviceRegionCode()
    }

    private var regionLabel: String {
        let flag = WatchProvidersRegionSettings.flagEmoji(for: effectiveRegionCode)
        let name = WatchProvidersRegionSettings.germanDisplayName(for: effectiveRegionCode)
        return "\(flag) \(name) (\(effectiveRegionCode))"
    }

    private var filteredProviders: [TMDbWatchProvider] {
        WatchProviderPreferencesPresentation.filteredCatalog(providers, query: searchText)
    }

    private var summaryText: String {
        WatchProviderPreferencesPresentation.summaryText(
            selectedIDs: selectedProviderIDs,
            providers: providers
        )
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Label("Streaming-Land", systemImage: "globe")
                    Spacer()
                    Text(regionLabel)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Ausgewählt")
                    Spacer()
                    Text(summaryText)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            } footer: {
                Text("Die Auswahl gilt nur lokal auf diesem Gerät und wird pro Streaming-Land gespeichert.")
            }

            Section {
                if isLoading && providers.isEmpty {
                    WatchProviderPreferencesLoadingView()
                } else if let errorMessage, providers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Katalog konnte nicht geladen werden", systemImage: "exclamationmark.triangle")
                            .font(.subheadline.weight(.semibold))
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Erneut versuchen") {
                            Task { await loadCatalog(forceRefresh: true) }
                        }
                    }
                    .padding(.vertical, 8)
                } else if filteredProviders.isEmpty {
                    Text("Keine Anbieter gefunden.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(filteredProviders) { provider in
                        Button {
                            toggle(provider)
                        } label: {
                            WatchProviderPreferenceRowView(
                                provider: provider,
                                isSelected: selectedProviderIDs.contains(provider.provider_id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("Anbieter")
            } footer: {
                Text("Bevorzugte Anbieter werden in Detailseiten hervorgehoben und für Discovery-Vorschläge genutzt.")
            }

            if !selectedProviderIDs.isEmpty {
                Section {
                    Button(role: .destructive) {
                        preferencesStore.clear(regionCode: effectiveRegionCode)
                        selectedProviderIDs = []
                    } label: {
                        Label("Alle entfernen", systemImage: "xmark.circle")
                    }
                }
            }
        }
        .navigationTitle("Bevorzugte Anbieter")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Anbieter suchen")
        .task(id: effectiveRegionCode) {
            selectedProviderIDs = preferencesStore.preferredProviderIDs(regionCode: effectiveRegionCode)
            await loadCatalog(forceRefresh: false)
        }
        .refreshable {
            await loadCatalog(forceRefresh: true)
        }
    }

    private func toggle(_ provider: TMDbWatchProvider) {
        selectedProviderIDs = preferencesStore.toggleProvider(provider.provider_id, regionCode: effectiveRegionCode)
    }

    private func loadCatalog(forceRefresh: Bool) async {
        isLoading = true
        errorMessage = nil
        do {
            let loaded = try await catalogRepository.providers(regionCode: effectiveRegionCode, forceRefresh: forceRefresh)
            providers = WatchProviderPreferencesPresentation.sortedCatalog(loaded)
        } catch TMDbError.missingAPIKey {
            errorMessage = "TMDb API-Key fehlt. Bitte TMDB_API_KEY in der Info.plist setzen."
        } catch {
            errorMessage = "Bitte prüfe deine Verbindung und versuche es erneut."
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        WatchProviderPreferencesView()
    }
}
