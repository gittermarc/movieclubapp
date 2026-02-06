//
//  GoalLeadingBadgeView.swift
//  filmfreaks
//

internal import SwiftUI

/// Leading badge shown in custom goal cards.
/// Keeps icon/profile rendering consistent across goal types.
struct GoalLeadingBadgeView: View {

    let goal: ViewingCustomGoal
    var size: CGFloat = 44
    var cornerRadius: CGFloat = 10

    @EnvironmentObject var displaySettings: DisplaySettings

    var body: some View {
        Group {
            switch goal.type {
            case .decade:
                iconBadge(systemImage: ViewingCustomGoalType.decade.systemImage, hierarchical: true)

            case .person:
                personBadge(fallbackSystemImage: ViewingCustomGoalType.person.systemImage)

            case .director:
                personBadge(fallbackSystemImage: ViewingCustomGoalType.director.systemImage)

            case .genre:
                iconBadge(systemImage: ViewingCustomGoalType.genre.systemImage, hierarchical: true)

            case .keyword:
                iconBadge(systemImage: ViewingCustomGoalType.keyword.systemImage, hierarchical: true)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    // MARK: - Building blocks

    private func iconBadge(systemImage: String, hierarchical: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(displaySettings.tintSoftBackground)

            Image(systemName: systemImage)
                .if(hierarchical) { view in
                    view.symbolRenderingMode(.hierarchical)
                }
                .foregroundStyle(.tint)
        }
    }

    @ViewBuilder
    private func personBadge(fallbackSystemImage: String) -> some View {
        if let path = goal.profilePath,
           !path.isEmpty,
           let url = URL(string: "https://image.tmdb.org/t/p/w185\(path)") {
            CachedAsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .foregroundStyle(.gray.opacity(0.15))
                        .overlay { ProgressView() }
                case .success(let img):
                    img.resizable().scaledToFill()
                case .failure:
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .foregroundStyle(.gray.opacity(0.15))
                        .overlay { Image(systemName: fallbackSystemImage) }
                @unknown default:
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .foregroundStyle(.gray.opacity(0.15))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(displaySettings.tintSoftBackground)
                Image(systemName: fallbackSystemImage)
                    .foregroundStyle(.tint)
            }
        }
    }
}

// MARK: - Small helper

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
