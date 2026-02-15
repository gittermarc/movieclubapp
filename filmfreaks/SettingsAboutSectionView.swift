//
//  SettingsAboutSectionView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 15.02.26.
//

internal import SwiftUI

/// "Über"-Sektion in den Einstellungen.
///
/// - Zeigt eine kurze App-Beschreibung.
/// - Verlinkt auf Anleitung & FAQ.
struct SettingsAboutSectionView: View {

    private let faqURL = URL(string: "https://apps.marcfechner.de/apps/tmc-the-movie-club/anleitung-faq/")!

    var body: some View {
        Section("Über") {
            Text("The Movie Club ist dein gemeinsames Filmtagebuch: Filme in Gruppen sammeln, bewerten und diskutieren – ohne Chaos in Chats. Dazu bekommst du Stats, Timeline und Filmabende, damit ihr euch schneller auf den nächsten Film einigt. Kurz: weniger Suchen, mehr Schauen.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Link(destination: faqURL) {
                Label("Anleitung & FAQ", systemImage: "questionmark.circle")
            }
            .accessibilityHint("Öffnet die Anleitung und häufige Fragen im Browser")
        }
    }
}
