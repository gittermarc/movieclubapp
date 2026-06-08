//
//  ContentView+MovieItems.swift
//  filmfreaks
//
//  Created by Marc Fechner on 05.02.26.
//

internal import SwiftUI

extension ContentView {

    // MARK: - List/Grid Items (gefiltert + sortiert)

    /// Grid: Gesehen
    var watchedGridItems: [ContentMovieItem] { movieItemsModel.watchedItems }

    /// Grid: Backlog
    var backlogGridItems: [ContentMovieItem] { movieItemsModel.backlogItems }

    /// Liste: Gesehen
    var watchedListItems: [ContentMovieItem] { movieItemsModel.watchedItems }

    /// Liste: Backlog
    var backlogListItems: [ContentMovieItem] { movieItemsModel.backlogItems }
}
