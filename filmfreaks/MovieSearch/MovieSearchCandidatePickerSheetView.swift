//
//  MovieSearchCandidatePickerSheetView.swift
//  filmfreaks
//

internal import SwiftUI

/// Sheet, das nach einem Scan die erkannten Kandidaten zeigt und die Auswahl erleichtert.
///
/// Ziel: MovieSearchView bleibt schlank – dieses Sheet ist reine UI.
struct MovieSearchCandidatePickerSheetView: View {

    let tappedText: String?
    let candidates: [String]

    let onSelectCandidate: (String) -> Void
    let onManualEdit: (String) -> Void
    let onCancel: () -> Void

    private var trimmedTappedText: String? {
        let trimmed = tappedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        NavigationStack {
            List {
                if let tapped = trimmedTappedText {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Du hast angetippt:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(tapped)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(3)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Erkannten Titel auswählen") {
                    if candidates.isEmpty {
                        Text("Keine brauchbaren Vorschläge erkannt. Tippe auf „Manuell bearbeiten“.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(candidates, id: \.self) { candidate in
                            Button {
                                onSelectCandidate(candidate)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(candidate)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text("Suche starten")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        // Best effort: nimm Top-Kandidat (oder tapped) rein, aber starte NICHT automatisch
                        let fallback = candidates.first
                            ?? trimmedTappedText
                            ?? ""
                        onManualEdit(fallback)
                    } label: {
                        Label("Manuell bearbeiten", systemImage: "pencil")
                    }
                }
            }
            .navigationTitle("Scan-Vorschläge")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        onCancel()
                    }
                }
            }
        }
    }
}

#Preview {
    MovieSearchCandidatePickerSheetView(
        tappedText: "The Matrix",
        candidates: ["The Matrix", "Matrix", "The Matrix (1999)"],
        onSelectCandidate: { _ in },
        onManualEdit: { _ in },
        onCancel: {}
    )
}
