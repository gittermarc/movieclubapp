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
    @State private var avatarEditorMember: User?
    
    var body: some View {
        NavigationStack {
            List {
                if let selectedUser = userStore.selectedUser {
                    Section("Dein Profil") {
                        Button {
                            avatarEditorMember = selectedUser
                        } label: {
                            HStack(spacing: 14) {
                                MemberAvatarView(
                                    member: selectedUser,
                                    groupId: userStore.currentGroupId,
                                    size: 52
                                )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Profilbild bearbeiten")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)

                                    Text("Als \(selectedUser.name) bewertest du Filme in dieser Gruppe.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer(minLength: 8)

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if userStore.pendingCloudChangesCount > 0,
                           CloudKitRouting.normalizedGroupId(userStore.currentGroupId) != nil {
                            Label(
                                "Mitgliederänderungen werden synchronisiert.",
                                systemImage: "arrow.triangle.2.circlepath"
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                            if let errorMessage = userStore.lastCloudSyncErrorMessage {
                                Label(
                                    "Wird erneut versucht: \(errorMessage)",
                                    systemImage: "exclamationmark.triangle.fill"
                                )
                                .font(.footnote)
                                .foregroundStyle(.orange)
                            }
                        }
                    }
                }

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
                            HStack(spacing: 12) {
                                MemberAvatarView(
                                    member: user,
                                    groupId: userStore.currentGroupId,
                                    size: 42
                                )

                                Text(user.name)
                                    .font(.body.weight(userStore.selectedUser?.id == user.id ? .semibold : .regular))

                                if userStore.selectedUser?.id == user.id {
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
            .sheet(item: $avatarEditorMember) { member in
                MemberAvatarEditorSheet(member: member)
            }
        }
    }
}

#Preview {
    UsersView()
        .environmentObject(UserStore())
        .environmentObject(MovieStore.preview())
}
