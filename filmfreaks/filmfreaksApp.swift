//
//  filmfreaksApp.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

internal import SwiftUI

@main
struct filmfreaksApp: App {
    @StateObject var movieStore = MovieStore(useCloud: true)
    @StateObject var userStore = UserStore()

    @Environment(\.scenePhase) private var scenePhase

    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(movieStore)
                    .environmentObject(userStore)

                if showSplash {
                    SplashView {
                        withAnimation {
                            showSplash = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }

                // Wenn die App wieder aktiv wird: Cloud-Daten nachziehen.
                // (Ohne Subscriptions ist das der einfachste Weg, damit Bewertungen/Filme anderer Geräte sichtbar werden.)
                Task {
                    await movieStore.refreshFromCloud(force: false)
                    await userStore.refreshFromCloud(force: false)
                }
            }
        }
    }
}
