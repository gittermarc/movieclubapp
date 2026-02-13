//
//  ContentRouting.swift
//  filmfreaks
//
//  Created by Marc Fechner on 05.02.26.
//

internal import SwiftUI

/// Central routing enum for sheets opened from `ContentView`.
internal enum ContentRoute: String, Identifiable {
    case settings
    case quickStart
    case movieSearch
    case users
    case stats
    case timeline
    case calendar
    case activity
    case goals
    case groupSettings

    internal var id: String { rawValue }
}

internal extension View {

    /// Attaches all sheet routing used by `ContentView`.
    func contentRouting(
        route: Binding<ContentRoute?>,
        hasSeenQuickStart: Binding<Bool>,
        trackSearchOpened: @escaping () -> Void
    ) -> some View {
        modifier(
            ContentRoutingModifier(
                route: route,
                hasSeenQuickStart: hasSeenQuickStart,
                trackSearchOpened: trackSearchOpened
            )
        )
    }
}

private struct ContentRoutingModifier: ViewModifier {

    @Binding var route: ContentRoute?
    @Binding var hasSeenQuickStart: Bool

    let trackSearchOpened: () -> Void

    @EnvironmentObject private var movieStore: MovieStore
    @EnvironmentObject private var userStore: UserStore
    @EnvironmentObject private var displaySettings: DisplaySettings

    @State private var lastPresentedRoute: ContentRoute? = nil

    func body(content: Content) -> some View {
        content
            .sheet(item: $route, onDismiss: handleDismiss) { presented in
                routedSheet(for: presented)
                    .onAppear {
                        lastPresentedRoute = presented
                    }
            }
    }

    private func handleDismiss() {
        if lastPresentedRoute == .quickStart {
            // Matches the previous behavior: once the quick start is dismissed,
            // it should not be shown again on next launch.
            hasSeenQuickStart = true
        }
        lastPresentedRoute = nil
    }

    @ViewBuilder
    private func routedSheet(for route: ContentRoute) -> some View {
        switch route {
        case .settings:
            themed(SettingsView())

        case .quickStart:
            themed(
                QuickStartView(
                    onOpenGroups: { switchRoute(to: .groupSettings) },
                    onOpenUsers: { switchRoute(to: .users) },
                    onOpenSearch: {
                        trackSearchOpened()
                        switchRoute(to: .movieSearch)
                    },
                    onDone: {
                        hasSeenQuickStart = true
                        self.route = nil
                    }
                )
            )

        case .movieSearch:
            themed(
                MovieSearchView(
                    existingWatched: movieStore.movies,
                    existingBacklog: movieStore.backlogMovies,
                    onAddToWatched: addMovieToWatched(_:),
                    onAddToBacklog: addMovieToBacklog(_:) 
                )
            )

        case .users:
            themed(UsersView())

        case .stats:
            themed(StatsView())

        case .timeline:
            themed(
                TimelineView()
                    .environmentObject(movieStore)
                    .environmentObject(userStore)
            )

        case .calendar:
            themed(MovieNightCalendarView())

        case .activity:
            themed(
                GroupActivityListView()
                    .environmentObject(movieStore)
                    .environmentObject(displaySettings)
            )

        case .goals:
            themed(
                GoalsView()
                    .environmentObject(movieStore)
                    .environmentObject(userStore)
            )

        case .groupSettings:
            themed(GroupSettingsView())
        }
    }

    private func themed<V: View>(_ view: V) -> some View {
        view
            .preferredColorScheme(displaySettings.preferredColorScheme)
            .tint(displaySettings.tintColor)
    }

    private func switchRoute(to newRoute: ContentRoute) {
        // Close current sheet first, then open the target sheet.
        route = nil
        DispatchQueue.main.async {
            route = newRoute
        }
    }

    private func addMovieToWatched(_ newMovie: Movie) {
        // Film mit Gruppen-Infos „anreichern“
        var movieWithGroup = newMovie
        movieWithGroup.groupId = movieStore.currentGroupId
        movieWithGroup.groupName = movieStore.currentGroupName

        // Activity-Meta: wer hat hinzugefuegt + wann.
        if movieWithGroup.addedAt == nil {
            movieWithGroup.addedAt = Date()
        }
        if (movieWithGroup.addedByName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            if let u = userStore.selectedUser {
                movieWithGroup.addedById = u.id
                movieWithGroup.addedByName = u.name
            }
        }

        // Eindeutigkeit weiterhin über Titel + Jahr
        let isSame: (Movie) -> Bool = { movie in
            movie.title == movieWithGroup.title && movie.year == movieWithGroup.year
        }

        // Wenn noch nicht in „Gesehen“, hinzufügen
        if !movieStore.movies.contains(where: isSame) {
            movieStore.movies.append(movieWithGroup)
        }

        // Falls im Backlog vorhanden, dort entfernen
        movieStore.backlogMovies.removeAll(where: isSame)
    }

    private func addMovieToBacklog(_ newMovie: Movie) {
        var movieWithGroup = newMovie
        movieWithGroup.groupId = movieStore.currentGroupId
        movieWithGroup.groupName = movieStore.currentGroupName

        // Activity-Meta: wer hat hinzugefuegt + wann.
        if movieWithGroup.addedAt == nil {
            movieWithGroup.addedAt = Date()
        }
        if (movieWithGroup.addedByName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            if let u = userStore.selectedUser {
                movieWithGroup.addedById = u.id
                movieWithGroup.addedByName = u.name
            }
        }

        let isSame: (Movie) -> Bool = { movie in
            movie.title == movieWithGroup.title && movie.year == movieWithGroup.year
        }

        // Wenn der Film schon als gesehen markiert ist → nicht in den Backlog aufnehmen
        guard !movieStore.movies.contains(where: isSame) else {
            return
        }

        // Nur hinzufügen, wenn noch nicht im Backlog
        if !movieStore.backlogMovies.contains(where: isSame) {
            movieStore.backlogMovies.append(movieWithGroup)
        }
    }
}
