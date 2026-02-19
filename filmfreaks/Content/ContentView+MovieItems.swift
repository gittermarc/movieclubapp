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
    var watchedGridItems: [IndexedMovie] { movieItemsModel.watchedItems }

    /// Grid: Backlog
    var backlogGridItems: [IndexedMovie] { movieItemsModel.backlogItems }

    /// Liste: Gesehen
    var watchedListItems: [IndexedMovie] { movieItemsModel.watchedItems }

    /// Liste: Backlog
    var backlogListItems: [IndexedMovie] { movieItemsModel.backlogItems }
}
