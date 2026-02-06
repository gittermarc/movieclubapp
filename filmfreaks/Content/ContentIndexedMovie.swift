//
//  ContentIndexedMovie.swift
//  filmfreaks
//
//  Created by Marc Fechner on 05.02.26.
//

import Foundation

/// Ein Movie zusammen mit seinem Index im Quell-Array.
///
/// Wir nutzen das für Grid **und** Liste, damit:
/// - Navigation über Binding (`movies[item.index]`) sauber bleibt
/// - Delete immer den richtigen Eintrag im Source-Array entfernt
struct IndexedMovie: Identifiable {
    let index: Int
    let movie: Movie

    var id: UUID { movie.id }
}
