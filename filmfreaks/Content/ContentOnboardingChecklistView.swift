//
//  ContentOnboardingChecklistView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 05.02.26.
//

internal import SwiftUI

/// Quick-Start / Setup-Checkliste, die neuen Gruppen den Einstieg erleichtert.
///
/// Ziel: UI aus der ContentView ziehen (UI-only).
struct ContentOnboardingChecklistView: View {

    @Binding var isExpanded: Bool

    let stepsCompletedCount: Int

    let isGroupStepComplete: Bool
    let isMembersStepComplete: Bool
    let isFirstMovieStepComplete: Bool
    let isFirstRatingStepComplete: Bool

    let hasAnyMoviesInCurrentGroup: Bool

    let onTapGroups: () -> Void
    let onTapMembers: () -> Void
    let onTapSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.tint)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quick Start")
                            .font(.subheadline.weight(.semibold))
                        Text("\(stepsCompletedCount) von 4 erledigt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    ContentOnboardingRow(
                        isDone: isGroupStepComplete,
                        title: "Gruppe einrichten",
                        subtitle: "Erstellen oder per iCloud-Einladung beitreten",
                        actionTitle: "Gruppen",
                        action: onTapGroups
                    )

                    ContentOnboardingRow(
                        isDone: isMembersStepComplete,
                        title: "Mitglieder hinzufügen",
                        subtitle: "Damit Bewertungen & Vorschläge Sinn ergeben",
                        actionTitle: "Mitglieder",
                        action: onTapMembers
                    )

                    ContentOnboardingRow(
                        isDone: isFirstMovieStepComplete,
                        title: "Ersten Film hinzufügen",
                        subtitle: "Suche bei TMDb und pack ihn in „Gesehen“ oder Backlog",
                        actionTitle: "Suche",
                        action: onTapSearch
                    )

                    ContentOnboardingRow(
                        isDone: isFirstRatingStepComplete,
                        title: "Erste Bewertung abgeben",
                        subtitle: hasAnyMoviesInCurrentGroup
                            ? "Tippe auf einen Film in der Liste und bewerte ihn"
                            : "Sobald ein Film drin ist, kannst du ihn bewerten",
                        actionTitle: nil,
                        action: nil
                    )
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
    }
}

private struct ContentOnboardingRow: View {

    let isDone: Bool
    let title: String
    let subtitle: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isDone ? Color.green : Color.secondary)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let actionTitle, let action, !isDone {
                Button(actionTitle) {
                    action()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
            }
        }
    }
}
