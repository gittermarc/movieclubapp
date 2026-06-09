//
//  WatchProviderPreferenceRowView.swift
//  filmfreaks
//

internal import SwiftUI

struct WatchProviderPreferenceRowView: View {
    let provider: TMDbWatchProvider
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            providerLogo
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(provider.provider_name)
                    .font(.body)
                    .foregroundStyle(.primary)

                if let priority = provider.display_priority {
                    Text("Priorität \(priority)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: Text {
        if isSelected {
            return Text("\(provider.provider_name), ausgewählt")
        }
        return Text(provider.provider_name)
    }

    @ViewBuilder
    private var providerLogo: some View {
        if let url = MovieMetadataPresentation.imageURL(path: provider.logo_path, width: .w92) {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholder
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
        } else {
            fallback
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .foregroundStyle(.gray.opacity(0.18))
            ProgressView()
                .scaleEffect(0.75)
        }
    }

    private var fallback: some View {
        let initial = provider.provider_name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(1)
            .uppercased()

        return ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .foregroundStyle(.gray.opacity(0.18))
            Text(initial.isEmpty ? "▶︎" : initial)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
    }
}
