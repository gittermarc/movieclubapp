//
//  GroupActivityRowView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 06.02.26.
//

internal import SwiftUI

struct GroupActivityRowView: View {

    @EnvironmentObject private var displaySettings: DisplaySettings

    let event: GroupActivityEvent

    private var actorName: String {
        let trimmed = (event.actorName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Jemand" : trimmed
    }

    private var verbText: String {
        switch event.kind {
        case .movieAdded:
            return "hat hinzugefügt"
        case .movieRated:
            return "hat bewertet"
        }
    }

    private var movieText: String {
        if let y = event.movieYear, !y.isEmpty {
            return "\(event.movieTitle) (\(y))"
        }
        return event.movieTitle
    }

    private var relativeTimeText: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: event.date, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                (Text(actorName).fontWeight(.semibold)
                 + Text(" \(verbText) ")
                 + Text(movieText))
                .font(.subheadline)
                .lineLimit(2)

                Text(relativeTimeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if event.kind == .movieRated {
                RatingBadgeView(value: event.ratingValue, font: .subheadline, isCompactContext: true, placeholder: "-")
                    .environmentObject(displaySettings)
            }

            poster
        }
        .padding(.vertical, 2)
    }

    private var avatar: some View {
        let initials = initials(from: actorName)

        return Text(initials)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(width: 34, height: 34)
            .background(
                Circle()
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }

    private var poster: some View {
        Group {
            if let url = event.posterURL {
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
            } else {
                Rectangle()
                    .foregroundStyle(.gray.opacity(0.12))
                    .overlay { Image(systemName: "film").foregroundStyle(.secondary) }
            }
        }
        .frame(width: 28, height: 42)
        .clipShape(RoundedRectangle(cornerRadius: displaySettings.posterCornerRadius))
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ").map(String.init)
        if parts.count >= 2 {
            let first = (parts.first ?? "").prefix(1)
            let last = (parts.last ?? "").prefix(1)
            return String(first + last).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
