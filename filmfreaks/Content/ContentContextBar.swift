//
//  ContentContextBar.swift
//  filmfreaks
//
//  Created by Marc Fechner on 04.02.26.
//

internal import SwiftUI

/// Kompakte Context-Bar unter dem Titel: Gruppe + aktives Mitglied + Aktivitätszugang.
/// Ziel: dezenter, besser integriert (Material), weniger vertikaler Platz als eine eigene Social-Karte.
///
/// Anpassung 15.04.26:
/// - Gruppenaktivität lebt nicht mehr als große Karte unterhalb des Headers,
///   sondern als kleine Kontext-Aktion rechts in der Bar.
struct ContentContextBar: View {

    @EnvironmentObject private var displaySettings: DisplaySettings

    let groupName: String
    let totalMoviesInGroup: Int // bewusst beibehalten, um Call-Sites nicht anzufassen

    let tintColor: Color

    let activeMemberDisplayName: String
    let activeMemberInitials: String
    let hasActiveMemberSelected: Bool

    let showsActivityButton: Bool
    let activityNewEventsCount: Int

    let onTapGroup: () -> Void
    let onTapActiveMember: () -> Void
    let onTapActivity: () -> Void

    private var m: DisplaySettings.LayoutMetrics { displaySettings.metrics }

    var body: some View {
        HStack(alignment: .center, spacing: m.contextBarItemSpacing) {
            HStack(alignment: .top, spacing: m.contextBarItemSpacing) {
                Button(action: onTapGroup) {
                    groupLabel
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Aktuelle Gruppe: \(groupName)")

                verticalDivider

                Button(action: onTapActiveMember) {
                    activeMemberLabel
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Aktives Mitglied: \(activeMemberDisplayName)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsActivityButton {
                GroupActivityStatusButton(
                    tintColor: tintColor,
                    newEventsCount: activityNewEventsCount,
                    action: onTapActivity
                )
                .fixedSize(horizontal: true, vertical: true)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, m.contextBarHorizontalPadding)
        .padding(.vertical, m.contextBarVerticalPadding)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1)
            .frame(maxHeight: .infinity)
            .padding(.vertical, m.contextBarDividerVerticalPadding)
            .accessibilityHidden(true)
    }

    private var groupLabel: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "person.3.sequence.fill")
                .font(.caption)
                .foregroundStyle(tintColor)

            ContextBarTitleView(label: "Gruppe", value: groupName, wrappedLineLimit: 2)
                .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var activeMemberLabel: some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                Circle()
                    .fill((hasActiveMemberSelected ? tintColor : Color.secondary).opacity(0.18))

                Text(activeMemberInitials)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(hasActiveMemberSelected ? tintColor : .secondary)
            }
            .frame(width: 26, height: 26)

            ContextBarTitleView(label: "Aktiv", value: activeMemberDisplayName, wrappedLineLimit: 2)
                .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
