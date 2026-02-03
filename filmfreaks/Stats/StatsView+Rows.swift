//
//  StatsView+Rows.swift
//  filmfreaks
//
//  Reusable row renderers used in multiple StatsView sheets/cards.
//

internal import SwiftUI

extension StatsView {

    // MARK: - Movie Row

    @ViewBuilder
    func criticGapRow(_ entry: CriticGapEntry, kind: StatsCriticGapKind) -> some View {
        let badgeBackground: Color = (kind == .groupHigher) ? Color.green.opacity(0.15) : Color.red.opacity(0.15)
        let badgeForeground: Color = (kind == .groupHigher) ? Color.green : Color.red
        let deltaText = String(format: "%+.1f", entry.delta)

        HStack(spacing: 12) {
            if let url = entry.movie.posterURL {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle().foregroundStyle(.gray.opacity(0.2))
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Rectangle()
                            .foregroundStyle(.gray.opacity(0.2))
                            .overlay { Image(systemName: "film") }
                    @unknown default:
                        Rectangle().foregroundStyle(.gray.opacity(0.2))
                    }
                }
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Rectangle()
                    .foregroundStyle(.gray.opacity(0.1))
                    .frame(width: 40, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.movie.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(entry.movie.year)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let dateText = entry.movie.watchedDateText {
                        Text("• \(dateText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 6) {
                Text(deltaText)
                    .font(.headline.bold())
                    .monospacedDigit()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(badgeBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(badgeForeground)

                HStack(spacing: 6) {
                    Text(String(format: "Ihr %.1f", entry.groupAverage))
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Capsule())

                    Text(String(format: "TMDB %.1f", entry.tmdbAverage))
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    func movieRow(
        _ movie: Movie,
        trailingText: String? = nil,
        trailingBackground: Color = Color.blue.opacity(0.12)
    ) -> some View {
        HStack(spacing: 12) {
            if let url = movie.posterURL {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Rectangle().foregroundStyle(.gray.opacity(0.2))
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Rectangle()
                            .foregroundStyle(.gray.opacity(0.2))
                            .overlay { Image(systemName: "film") }
                    @unknown default:
                        Rectangle().foregroundStyle(.gray.opacity(0.2))
                    }
                }
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Rectangle()
                    .foregroundStyle(.gray.opacity(0.1))
                    .frame(width: 40, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(movie.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(movie.year).font(.caption).foregroundStyle(.secondary)

                    if let dateText = movie.watchedDateText {
                        Text("• \(dateText)").font(.caption).foregroundStyle(.secondary)
                    }

                    if let loc = movie.watchedLocation, !loc.isEmpty {
                        Text("• \(loc)").font(.caption).foregroundStyle(.secondary)
                    }
                }

                if let sugg = movie.suggestedBy,
                   !sugg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Vorgeschlagen von: \(sugg)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            let badgeText: String? = {
                if let trailingText { return trailingText }
                if let avg = movie.displayAverage(for: displaySettings.ratingDisplayMode) { return String(format: "%.1f", avg) }
                return nil
            }()

            if let badgeText {
                Text(badgeText)
                    .font(.caption.bold())
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(trailingText == nil ? displaySettings.tintColor.opacity(0.12) : trailingBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 4)
    }
}
