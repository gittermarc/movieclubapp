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
    
    @State private var showSplash = true   // NEU
    
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
                    .zIndex(1)   // liegt über der ContentView
                }
            }
        }
    }
}
