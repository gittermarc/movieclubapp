//
//  filmfreaksApp.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

internal import SwiftUI
import Foundation

@main
struct filmfreaksApp: App {
    @UIApplicationDelegateAdaptor(CloudKitShareAppDelegate.self) private var appDelegate

    init() {
        // Make HTTP caching for images much more effective across app launches.
        let memory = 100 * 1024 * 1024  // 100 MB
        let disk   = 500 * 1024 * 1024  // 500 MB
        URLCache.shared = URLCache(memoryCapacity: memory, diskCapacity: disk, diskPath: "filmfreaks-urlcache")
    }

    @StateObject var movieStore = MovieStore(useCloud: true)
    @StateObject var movieNightStore = MovieNightStore()
    @StateObject var userStore = UserStore()
    @StateObject var groupStore = CloudKitGroupStore()
    @StateObject var networkMonitor = NetworkMonitor.shared

    @StateObject var displaySettings = DisplaySettings()

    @StateObject private var appRefresh = AppRefreshCoordinator()

    @Environment(\.scenePhase) private var scenePhase

    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(movieStore)
                    .environmentObject(movieNightStore)
                    .environmentObject(userStore)
                    .environmentObject(groupStore)
                    .environmentObject(networkMonitor)

                // Non-blocking banner/toast for things like CloudKit share acceptance.
                ToastHost()
                    .zIndex(4)

                if showSplash {
                    SplashView {
                        withAnimation {
                            showSplash = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(3)
                }
            }
            .environmentObject(displaySettings)
            .preferredColorScheme(displaySettings.preferredColorScheme)
            .tint(displaySettings.tintColor)
            .fontDesign(displaySettings.preferredFontDesign)
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }

                // Wenn die App wieder aktiv wird: Cloud-Daten nachziehen.
                // (Ohne Subscriptions ist das der einfachste Weg, damit Bewertungen/Filme anderer Geräte sichtbar werden.)
                appRefresh.triggerRefresh {
                    await groupStore.refresh()

                    // Sobald GroupContexts geladen sind, können ausstehende Filmabend-Änderungen
                    // sicher in die richtige DB/Zone geflusht werden (ohne Public-Fallback).
                    movieNightStore.flushPendingCloudChanges()

                    await movieStore.refreshFromCloud(force: false)
                    await userStore.refreshFromCloud(force: false)
                    await movieNightStore.refreshFromCloud(groupId: movieStore.currentGroupId, force: false)
                }
            }
        }
    }
}
