//
//  TMDbAttributionPrivacyView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 16.01.26.
//

internal import SwiftUI
internal import UIKit

/// TMDB verlangt eine gut sichtbare Attribution im „About/Credits“-Bereich.
/// Quelle (Stand Anfang 2026): https://developer.themoviedb.org/docs/faq
///
/// ✅ Wichtig:
/// - Hinterlege idealerweise ein *offizielles/approved* TMDB-Logo in den Assets.
/// - Lege es als Bild mit dem Namen **tmdb_logo** ab.
/// - Ohne Asset zeigt die View automatisch einen Text-Fallback.
struct TMDbAttributionPrivacyView: View {

    private enum Constants {
        static let tmdbHome = URL(string: "https://www.themoviedb.org")!
        static let tmdbDocs = URL(string: "https://developer.themoviedb.org")!
        static let tmdbFaq = URL(string: "https://developer.themoviedb.org/docs/faq")!
        static let tmdbTerms = URL(string: "https://www.themoviedb.org/terms-of-use")!
        static let tmdbPrivacy = URL(string: "https://www.themoviedb.org/privacy-policy")!

        // TMDB-Required Notice (bitte wörtlich so lassen)
        static let requiredNotice = "This product uses the TMDB API but is not endorsed or certified by TMDB."
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        TMDbLogoMark()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("The Movie Database")
                                .font(.headline)
                            Text("Datenquelle für Filme, Bilder & Streaming-Verfügbarkeit")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }

                    Text("In filmfreaks stammen Filminfos (Titel, Beschreibung, Cast/Crew, Poster/Backdrops) sowie Streaming-Anbieter aus der TMDB-API.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    // Required notice — gut sichtbar.
                    Text(Constants.requiredNotice)
                        .font(.footnote.weight(.semibold))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityLabel(Constants.requiredNotice)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Attribution")
            }

            Section("Links") {
                Link(destination: Constants.tmdbHome) {
                    Label("TMDB Website", systemImage: "link")
                }

                Link(destination: Constants.tmdbDocs) {
                    Label("TMDB API Dokumentation", systemImage: "book")
                }

                Link(destination: Constants.tmdbFaq) {
                    Label("Attribution-Anforderungen (FAQ)", systemImage: "checkmark.seal")
                }

                Link(destination: Constants.tmdbTerms) {
                    Label("TMDB Terms of Use", systemImage: "doc.text")
                }

                Link(destination: Constants.tmdbPrivacy) {
                    Label("TMDB Privacy Policy", systemImage: "hand.raised")
                }
            }

            Section("Datenschutz – kurz erklärt") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Wenn du Filmseiten öffnest oder suchst, ruft die App Daten bei TMDB ab. Dabei werden technisch notwendige Verbindungsdaten (z. B. IP-Adresse) an TMDB übertragen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("filmfreaks nutzt keinen TMDB-Login. Es werden keine TMDB-Konten verknüpft und keine persönlichen Profile bei TMDB erstellt.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("Details dazu findest du in der TMDB Privacy Policy.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }

            Section("Hinweis zu Inhalten") {
                Text("Bilder und Inhalte in der TMDB-API können urheberrechtlich geschützt sein. Rechte liegen bei den jeweiligen Rechteinhabern. Diese App zeigt die Inhalte nur an und beansprucht keine Eigentumsrechte.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("TMDB & Datenschutz")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Logo

private struct TMDbLogoMark: View {

    private var hasAssetLogo: Bool {
        UIImage(named: "tmdb_logo") != nil
    }

    var body: some View {
        Group {
            if hasAssetLogo {
                Image("tmdb_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                    Text("TMDB")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 44, height: 44)
                .accessibilityLabel("TMDB")
            }
        }
    }
}
