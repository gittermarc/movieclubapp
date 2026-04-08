//
//  UsersView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

internal import SwiftUI

struct UsersView: View {
    
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var movieStore: MovieStore
    @State private var newUserName: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Neue Person hinzufügen
                Section("Neue Person hinzufügen") {
                    HStack {
                        TextField("Name", text: $newUserName)
                        
                        Button {
                            userStore.addUser(name: newUserName)
                            newUserName = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newUserName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                
                // MARK: - Mitglieder der Filmgruppe
                Section("Mitglieder der Filmgruppe") {
                    if userStore.users.isEmpty {
                        Text("Noch keine Mitglieder hinzugefügt.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(userStore.users) { user in
                            HStack {
                                Text(user.name)
                                
                                if userStore.selectedUser == user {
                                    Spacer()
                                    Text("Aktiv")
                                        .font(.caption)
                                        .padding(4)
                                        .background(.blue.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                userStore.selectedUser = user
                            }
                        }
                        .onDelete(perform: userStore.deleteUsers)
                    }
                }
                
                // MARK: - Gruppenverwaltung
                Section("Gruppenverwaltung") {
                    NavigationLink {
                        GroupSettingsView()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "person.3.sequence.fill")
                                .foregroundStyle(Color.accentColor)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Gruppen verwalten")
                                    .font(.subheadline.weight(.semibold))
                                
                                if let name = movieStore.currentGroupName {
                                    Text("Aktuelle Gruppe: \(name)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Standard-Gruppe (ohne Invite-Code)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filmgruppe")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
    }
}

#Preview {
    UsersView()
        .environmentObject(UserStore())
        .environmentObject(MovieStore.preview())
}
