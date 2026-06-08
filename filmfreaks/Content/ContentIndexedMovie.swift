//
//  ContentIndexedMovie.swift
//  filmfreaks
//
//  Created by Marc Fechner on 05.02.26.
//

import Foundation

/// Ein Content-Item für Grid und Liste mit stabiler Movie-Identität.
///
/// Das Item trägt bewusst keinen Source-Array-Index mehr. Navigation,
/// Binding-Lookup und Delete werden über `movieId` gegen den aktuellen Store
/// aufgelöst. So bleiben Filter, Sortierung, Deletes und Gruppenwechsel robust,
/// auch wenn SwiftUI kurz ältere Snapshot-Items rendert.
nonisolated struct ContentMovieItem: Identifiable, Sendable {
    let movieId: UUID
    let movie: Movie

    init(movie: Movie) {
        self.movieId = movie.id
        self.movie = movie
    }

    var id: UUID { movieId }
}
