//
//  ContentContextBar.swift
//  filmfreaks
//
//  Created by Marc Fechner on 04.02.26.
//

internal import SwiftUI

/// Kompakte Context-Bar unter dem Titel: Gruppe + aktives Mitglied
/// Ziel: dezenter, besser integriert (Material), weniger vertikaler Platz als die bisherigen Gradient-Buttons.
struct ContentContextBar: View {

    let groupName: String
    let totalMoviesInGroup: Int

    let tintColor: Color

    let activeMemberDisplayName: String
    let activeMemberInitials: String
    let hasActiveMemberSelected: Bool

    let onTapGroup: () -> Void
    let onTapActiveMember: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onTapGroup) {
                groupLabel
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Aktuelle Gruppe: \(groupName)")

            Divider()
                .opacity(0.65)

            Button(action: onTapActiveMember) {
                activeMemberLabel
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Aktives Mitglied: \(activeMemberDisplayName)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var groupLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.3.sequence.fill")
                .font(.caption)
                .foregroundStyle(tintColor)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    Text("Gruppe")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(groupName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }

                Text(groupName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }

            if totalMoviesInGroup > 0 {
                Text("\(totalMoviesInGroup)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tintColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tintColor.opacity(0.14))
                    .clipShape(Capsule())
                    .accessibilityLabel("\(totalMoviesInGroup) Filme")
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var activeMemberLabel: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill((hasActiveMemberSelected ? tintColor : Color.secondary).opacity(0.18))

                Text(activeMemberInitials)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(hasActiveMemberSelected ? tintColor : .secondary)
            }
            .frame(width: 26, height: 26)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    Text("Aktiv")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(activeMemberDisplayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }

                Text(activeMemberInitials)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
