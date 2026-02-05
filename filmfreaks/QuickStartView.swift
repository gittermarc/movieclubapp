//
//  QuickStartView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 05.02.26.
//

internal import SwiftUI

/// Lightweight onboarding sheet shown on first launch (or until dismissed).
///
/// Extracted from `ContentView.swift` to keep `ContentView` focused on layout & routing.
struct QuickStartView: View {

    var onOpenGroups: () -> Void
    var onOpenUsers: () -> Void
    var onOpenSearch: () -> Void
    var onDone: () -> Void

    @State private var page: Int = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                TabView(selection: $page) {
                    QuickStartPage(
                        icon: "person.3.sequence.fill",
                        title: "Erstmal eine Gruppe",
                        text: "Erstelle eine Gruppe oder tritt einer bestehenden bei. So bleiben Filme & Bewertungen sauber getrennt."
                    )
                    .tag(0)

                    QuickStartPage(
                        icon: "person.3.fill",
                        title: "Mitglieder hinzufügen",
                        text: "Füg die Leute hinzu, die bewerten sollen. Sonst heißt am Ende jeder „Unbekannt“ – und das ist nur bei Thrillern cool."
                    )
                    .tag(1)

                    QuickStartPage(
                        icon: "magnifyingglass",
                        title: "Ersten Film reinwerfen",
                        text: "Suche auf TMDb und füge Filme zu „Gesehen“ oder in den Backlog hinzu. Ab dann läuft’s von allein."
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(maxHeight: 420)

                // Action Buttons (kontextabhängig)
                VStack(spacing: 10) {
                    if page == 0 {
                        Button {
                            onOpenGroups()
                        } label: {
                            Label("Gruppen verwalten", systemImage: "person.3.sequence.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    } else if page == 1 {
                        Button {
                            onOpenUsers()
                        } label: {
                            Label("Mitglieder hinzufügen", systemImage: "person.3")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            onOpenSearch()
                        } label: {
                            Label("Film suchen", systemImage: "magnifyingglass")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    HStack(spacing: 12) {
                        Button("Überspringen") {
                            onDone()
                        }
                        .buttonStyle(.bordered)

                        Button(page == 2 ? "Fertig" : "Weiter") {
                            if page < 2 {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    page += 1
                                }
                            } else {
                                onDone()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                Spacer(minLength: 0)
            }
            .padding(.top, 10)
            .navigationTitle("Willkommen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schließen") { onDone() }
                }
            }
        }
    }
}

private struct QuickStartPage: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.tint)

            Text(title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)

            Spacer(minLength: 0)
        }
        .padding(.top, 18)
        .padding(.horizontal, 18)
    }
}

#Preview {
    QuickStartView(
        onOpenGroups: {},
        onOpenUsers: {},
        onOpenSearch: {},
        onDone: {}
    )
}
