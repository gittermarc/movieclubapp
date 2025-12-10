//
//  GroupSettingsView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 06.12.25.
//

internal import SwiftUI
import UIKit

struct GroupSettingsView: View {
    
    @EnvironmentObject var movieStore: MovieStore
    @EnvironmentObject var userStore: UserStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var newGroupName: String = ""
    @State private var joinCode: String = ""
    @State private var didCopyInviteCode: Bool = false
    @State private var showLeaveAlert: Bool = false
    
    // MARK: - Aktuelle Gruppe
    
    private var currentGroupTitle: String {
        movieStore.currentGroupName ?? "Ohne Namen"
    }
    
    private var currentGroupCode: String {
        movieStore.currentGroupId ?? "–"
    }
    
    private var hasInviteCode: Bool {
        movieStore.currentGroupId != nil
    }
    
    private var totalMoviesInCurrentGroup: Int {
        movieStore.movies.count + movieStore.backlogMovies.count
    }
    
    private var watchedCount: Int {
        movieStore.movies.count
    }
    
    private var backlogCount: Int {
        movieStore.backlogMovies.count
    }
    
    private var lastActivityDate: Date? {
        movieStore.movies.compactMap { $0.watchedDate }.max()
    }
    
    private var lastActivityText: String? {
        guard let date = lastActivityDate else { return nil }
        return GroupSettingsView.dateFormatter.string(from: date)
    }
    
    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                List {
                    // MARK: Aktuelle Gruppe als "Dashboard-Header"
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.3.sequence.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white.opacity(0.9))
                                    .padding(10)
                                    .background(
                                        Circle()
                                            .fill(Color.white.opacity(0.18))
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Aktuelle Gruppe")
                                        .font(.caption2)
                                        .textCase(.uppercase)
                                        .foregroundStyle(.white.opacity(0.8))
                                    
                                    Text(currentGroupTitle)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    
                                    if hasInviteCode {
                                        Text("Invite-Code: \(currentGroupCode)")
                                            .font(.footnote.monospacedDigit())
                                            .foregroundStyle(.white.opacity(0.85))
                                    } else {
                                        Text("Standard-Gruppe ohne Invite-Code")
                                            .font(.footnote)
                                            .foregroundStyle(.white.opacity(0.85))
                                    }
                                }
                                
                                Spacer()
                            }
                            
                            // Stats-Chips zur Gruppe
                            if totalMoviesInCurrentGroup > 0 {
                                HStack(spacing: 8) {
                                    Label("\(totalMoviesInCurrentGroup) Filme gesamt", systemImage: "film.stack")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.16))
                                        .clipShape(Capsule())
                                    
                                    Label("\(watchedCount) gesehen", systemImage: "checkmark.circle")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.95))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.16))
                                        .clipShape(Capsule())
                                    
                                    Label("\(backlogCount) im Backlog", systemImage: "tray.full")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.95))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.16))
                                        .clipShape(Capsule())
                                }
                                .padding(.top, 4)
                            }
                            
                            if let lastActivityText {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.caption2)
                                    Text("Zuletzt aktiv: \(lastActivityText)")
                                }
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.85))
                            }
                            
                            // Invite- & Copy-Aktionen + Gruppe verlassen
                            if let id = movieStore.currentGroupId {
                                VStack(spacing: 6) {
                                    HStack(spacing: 10) {
                                        Spacer()
                                        
                                        ShareLink(
                                            item: "Komm in unsere Filmgruppe in FilmFreaks! Invite-Code: \(id)",
                                            subject: Text("FilmFreaks Invite-Code"),
                                            message: Text("Mit diesem Code kannst du unserer Filmgruppe in FilmFreaks beitreten:\n\(id)")
                                        ) {
                                            Label("Invite-Code teilen", systemImage: "square.and.arrow.up")
                                                .font(.footnote.weight(.semibold))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Color.white.opacity(0.18))
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                        
                                        Button {
                                            copyInviteCodeToClipboard(id)
                                        } label: {
                                            Label("Code kopieren", systemImage: "doc.on.doc")
                                                .font(.footnote.weight(.semibold))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Color.white.opacity(0.18))
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                        
                                        Spacer()
                                    }
                                    
                                    // 👇 NEU: Gruppe verlassen
                                    HStack {
                                        Spacer()
                                        Button {
                                            showLeaveAlert = true
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                                Text("Gruppe verlassen")
                                            }
                                            .font(.footnote.weight(.semibold))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.white.opacity(0.14))
                                            .foregroundStyle(.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                        .buttonStyle(.plain)
                                        Spacer()
                                    }
                                }
                                .padding(.top, 6)
                                
                                if didCopyInviteCode {
                                    HStack {
                                        Spacer()
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption2)
                                            Text("Invite-Code kopiert")
                                                .font(.caption2)
                                        }
                                        .foregroundStyle(.white.opacity(0.9))
                                        Spacer()
                                    }
                                    .padding(.top, 2)
                                }
                                
                            } else {
                                Text("Diese Gruppe ist nur auf deinem Gerät sichtbar. Erstelle eine neue Gruppe, um einen Invite-Code zu erhalten und gemeinsam mit anderen Filme zu verwalten.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .padding(.top, 4)
                            }
                        }
                        .padding(14)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    } header: {
                        Text("Aktuelle Gruppe")
                    }
                    
                    // MARK: Bekannte Gruppen
                    Section {
                        if movieStore.knownGroups.isEmpty {
                            Text("Noch keine weiteren Gruppen.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(movieStore.knownGroups) { info in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(info.displayName)
                                            .font(.subheadline.weight(.semibold))
                                        
                                        Text(info.id)
                                            .font(.footnote.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                        
                                        if info.id == movieStore.currentGroupId {
                                            Text("Diese Gruppe ist aktuell aktiv.")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if info.id == movieStore.currentGroupId {
                                        Text("Aktiv")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.green.opacity(0.18))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    } else {
                                        Button {
                                            movieStore.joinGroup(withInviteCode: info.id)
                                            userStore.loadUsers(forGroupId: movieStore.currentGroupId)
                                            dismiss()
                                        } label: {
                                            Text("Wechseln")
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemBackground))
                                )
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                            }
                            // 👇 NEU: Gruppen per Swipe löschen
                            .onDelete { indexSet in
                                let idsToDelete = indexSet.map { movieStore.knownGroups[$0].id }
                                
                                movieStore.knownGroups.remove(atOffsets: indexSet)
                                
                                // Falls die aktive Gruppe gelöscht wurde → auch verlassen
                                if let currentId = movieStore.currentGroupId,
                                   idsToDelete.contains(currentId) {
                                    movieStore.leaveCurrentGroup()
                                    userStore.loadUsers(forGroupId: movieStore.currentGroupId)
                                }
                            }
                        }
                    } header: {
                        Text("Bekannte Gruppen")
                    } footer: {
                        if !movieStore.knownGroups.isEmpty {
                            Text("Tippe auf „Wechseln“, um deine Filmansicht auf eine andere Gruppe umzustellen. Streiche nach links, um eine Gruppe von diesem Gerät zu entfernen.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // MARK: Neue Gruppe erstellen
                    Section("Neue Gruppe erstellen") {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Name der Gruppe", text: $newGroupName)
                                .textInputAutocapitalization(.words)
                            
                            Button {
                                let trimmed = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                
                                movieStore.createNewGroup(withName: trimmed)
                                userStore.loadUsers(forGroupId: movieStore.currentGroupId)
                                
                                joinCode = ""
                                newGroupName = ""
                                
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Gruppe erstellen")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("• Für jede Gruppe werden Filme, Bewertungen und Mitglieder getrennt gespeichert.")
                                Text("• Ideal für z.B. „Filmcrew“, „Familienabend“ oder „Marc & Claudi“.")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                        }
                    }
                    
                    // MARK: Einer bestehenden Gruppe beitreten
                    Section("Einer Gruppe beitreten") {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Invite-Code (Group-ID)", text: $joinCode)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .font(.footnote.monospacedDigit())
                            
                            Button {
                                let code = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !code.isEmpty else { return }
                                
                                movieStore.joinGroup(withInviteCode: code)
                                userStore.loadUsers(forGroupId: movieStore.currentGroupId)
                                
                                joinCode = ""
                                newGroupName = ""
                                
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "person.3.sequence.fill")
                                    Text("Gruppe beitreten")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Den Invite-Code bekommst du von einem Mitglied deiner Filmgruppe.")
                                Text("Er ist identisch mit der Group-ID dieser Gruppe.")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
                .navigationTitle("Gruppen verwalten")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fertig") {
                            dismiss()
                        }
                    }
                }
                // 👇 NEU: Bestätigungsdialog für „Gruppe verlassen“
                .alert("Gruppe verlassen?", isPresented: $showLeaveAlert) {
                    Button("Abbrechen", role: .cancel) {}
                    Button("Verlassen", role: .destructive) {
                        movieStore.leaveCurrentGroup()
                        userStore.loadUsers(forGroupId: movieStore.currentGroupId)
                    }
                } message: {
                    Text("Du verlässt diese Gruppe auf diesem Gerät. Die Filme bleiben für andere Mitglieder in iCloud erhalten.")
                }
            }
        }
    }
    
    // MARK: - Helper
    
    private func copyInviteCodeToClipboard(_ code: String) {
        UIPasteboard.general.string = code
        withAnimation {
            didCopyInviteCode = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation {
                didCopyInviteCode = false
            }
        }
    }
}

#Preview {
    GroupSettingsView()
        .environmentObject(MovieStore.preview())
        .environmentObject(UserStore())
}
