//
//  UsersView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

internal import SwiftUI

struct UsersView: View {
    
    @EnvironmentObject var userStore: UserStore
    @State private var newUserName: String = ""
    
    var body: some View {
        NavigationStack {
            List {
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
}
