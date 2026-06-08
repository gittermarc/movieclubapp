//
//  MovieRouletteHeaderCard.swift
//  filmfreaks
//
//  Created by ChatGPT on 08.06.26.
//

internal import SwiftUI

struct MovieRouletteHeaderCard: View {
    @EnvironmentObject private var displaySettings: DisplaySettings
    @ObservedObject var viewModel: MovieRouletteViewModel

    let onManagePresets: () -> Void

    private var m: DisplaySettings.LayoutMetrics { displaySettings.metrics }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Label {
                        Text("Filmroulette")
                            .font(.title3.weight(.semibold))
                    } icon: {
                        Image(systemName: "sparkles.tv")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(displaySettings.tintColor)
                    }

                    Text(viewModel.sourceDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                countBadge
            }

            Picker(
                "Quelle",
                selection: Binding(
                    get: { viewModel.selectedSource },
                    set: { viewModel.selectSource($0) }
                )
            ) {
                ForEach(MovieRouletteSource.allCases) { source in
                    Text(source.title).tag(source)
                }
            }
            .pickerStyle(.segmented)

            if viewModel.selectedSource == .preset {
                presetSelectionCard
            }

            HStack(spacing: 8) {
                sourceBadge(title: "Quelle", value: viewModel.sourceBadgeText)
                sourceBadge(title: "Status", value: viewModel.isSpinning ? "Dreht" : "Bereit")
            }
        }
        .padding(m.cardPadding + 2)
        .background(cardBackground)
    }

    @ViewBuilder
    private var presetSelectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vordefinierte Auswahl")
                        .font(.headline)

                    if viewModel.selectedPresetSummary.isEmpty == false {
                        Text(viewModel.selectedPresetSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 10)

                Button(viewModel.availablePresets.isEmpty ? "Anlegen" : "Verwalten") {
                    onManagePresets()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!viewModel.canManagePresets)
            }

            if viewModel.availablePresets.isEmpty == false {
                Picker("Auswahl", selection: Binding(
                    get: { viewModel.selectedPresetId ?? viewModel.availablePresets.first?.id ?? UUID() },
                    set: { viewModel.selectPreset($0) }
                )) {
                    ForEach(viewModel.availablePresets) { preset in
                        Text(preset.displayName).tag(preset.id)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius, style: .continuous)
                .fill(displaySettings.tintColor.opacity(0.08))
        )
    }

    private var countBadge: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(viewModel.candidateCountText)
                .font(.headline)
            Text(viewModel.selectedSource == .preset ? "in Auswahl" : "im Backlog")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius, style: .continuous)
                .fill(displaySettings.tintColor.opacity(0.12))
        )
    }

    private func sourceBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .circular)
                .fill(.ultraThinMaterial)
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius, style: .continuous)
            .fill(.thinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
    }
}
