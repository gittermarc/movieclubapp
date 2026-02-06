//
//  ContentView+Toolbar.swift
//  filmfreaks
//
//  Created by Marc Fechner on 05.02.26.
//

internal import SwiftUI

/// Extracted toolbar content for `ContentView`.
///
/// We pass the route binding + tracking closure in, so `ContentView` can keep
/// its routing state and helper methods `private`.
struct ContentToolbar: ToolbarContent {

    @Binding var route: ContentRoute?
    let trackSearchOpened: () -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        // Wichtigste Aktion als Quick-Button – bleibt immer erreichbar.
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    route = .users
                } label: {
                    Label("Mitglieder", systemImage: "person.3")
                }

                Button {
                    route = .groupSettings
                } label: {
                    Label("Gruppen", systemImage: "person.3.sequence")
                }

                Divider()

                Button {
                    route = .stats
                } label: {
                    Label("Statistiken", systemImage: "chart.bar.fill")
                }

                Button {
                    route = .timeline
                } label: {
                    Label("Timeline", systemImage: "rectangle.stack.fill")
                }

                Button {
                    route = .goals
                } label: {
                    Label("Ziele", systemImage: "target")
                }

                Divider()

                Button {
                    route = .settings
                } label: {
                    Label("Einstellungen", systemImage: "gearshape")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Mehr")
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                trackSearchOpened()
                route = .movieSearch
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .accessibilityLabel("Film suchen")
        }
    }
}
