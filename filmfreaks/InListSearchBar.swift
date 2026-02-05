//
//  InListSearchBar.swift
//  filmfreaks
//
//  Created by Marc Fechner on 05.02.26.
//

internal import SwiftUI


struct InListSearchBar: View {

    let placeholder: String
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let metrics: DisplaySettings.LayoutMetrics

    private var isActive: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        // Apple-Music-ish: unten eine dezente, transparente Such-Pille.
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .focused($isFocused)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .lineLimit(1)

            if isActive {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Suche löschen")
            }

            if isFocused {
                Button("Abbrechen") {
                    isFocused = false
                }
                .font(.subheadline)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, max(CGFloat(8), metrics.chipVerticalPadding - 1))
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
    }
}
