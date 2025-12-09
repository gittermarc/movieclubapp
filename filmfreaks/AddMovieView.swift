//
//  AddMovieView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

internal import SwiftUI

struct AddMovieView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var year: String = ""
    @State private var tmdbRatingText: String = ""
    
    var onAdd: (Movie) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Film") {
                    TextField("Titel", text: $title)
                    
                    TextField("Jahr", text: $year)
                        .keyboardType(.numberPad)
                    
                    TextField("TMDb-Bewertung (optional, 0–10)", text: $tmdbRatingText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Film hinzufügen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveMovie()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveMovie() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        let trimmedYear = year.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalYear = trimmedYear.isEmpty ? "n/a" : trimmedYear
        
        // Komma in Punkt umwandeln, falls du z.B. "7,5" eintippst
        let normalizedRatingText = tmdbRatingText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let tmdbRating = Double(normalizedRatingText)
        
        let newMovie = Movie(
            title: trimmedTitle,
            year: finalYear,
            tmdbRating: tmdbRating,
            ratings: [],          // WICHTIG: keine Ratings hier, die macht ihr im Detail
            posterPath: nil
        )
        
        onAdd(newMovie)
        dismiss()
    }
}

#Preview {
    AddMovieView { _ in }
}
