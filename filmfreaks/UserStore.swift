//
//  UserStore.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

import Foundation
import Combine
internal import SwiftUI

@MainActor
class UserStore: ObservableObject {
    
    @Published var users: [User] = [] {
        didSet {
            saveUsers()
        }
    }
    
    /// Wer gerade bewertet etc.
    @Published var selectedUser: User?
    
    /// Zu welcher Gruppe gehören diese `users`?
    private var currentGroupId: String?
    
    // MARK: - Init
    
    init() {
        // gleiche Group-ID wie MovieStore verwenden
        let groupIdFromDefaults = UserDefaults.standard.string(forKey: "CurrentGroupId")
        self.currentGroupId = groupIdFromDefaults
        self.users = Self.loadUsers(forGroupId: groupIdFromDefaults)
        
        if let first = users.first {
            self.selectedUser = first
        } else {
            self.selectedUser = nil
        }
    }
    
    // MARK: - Öffentliche API
    
    /// Wird aufgerufen, wenn die Gruppe wechselt (neue Gruppe / join / wechseln)
    func loadUsers(forGroupId groupId: String?) {
        self.currentGroupId = groupId
        self.users = Self.loadUsers(forGroupId: groupId)
        
        if let first = users.first {
            self.selectedUser = first
        } else {
            self.selectedUser = nil
        }
    }
    
    /// Neuen User für die aktuelle Gruppe anlegen
    func addUser(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // doppelte Namen optional vermeiden
        if users.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return
        }
        
        let newUser = User(name: trimmed)
        users.append(newUser)
        
        if selectedUser == nil {
            selectedUser = newUser
        }
    }
    
    /// Löscht User an den übergebenen Indizes
    func deleteUsers(at offsets: IndexSet) {
        users.remove(atOffsets: offsets)
        if let selected = selectedUser, !users.contains(selected) {
            selectedUser = users.first
        }
    }
    
    // MARK: - Persistenz
    
    private func storageKey(for groupId: String?) -> String {
        if let id = groupId, !id.isEmpty {
            return "Users_\(id)"
        } else {
            return "Users_Default"
        }
    }
    
    private func saveUsers() {
        let key = storageKey(for: currentGroupId)
        do {
            let data = try JSONEncoder().encode(users)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("UserStore: Fehler beim Speichern der Users für Key \(key): \(error)")
        }
    }
    
    private static func loadUsers(forGroupId groupId: String?) -> [User] {
        let key: String
        if let id = groupId, !id.isEmpty {
            key = "Users_\(id)"
        } else {
            key = "Users_Default"
        }
        
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return []
        }
        
        do {
            let decoded = try JSONDecoder().decode([User].self, from: data)
            return decoded
        } catch {
            print("UserStore: Fehler beim Laden der Users für Key \(key): \(error)")
            return []
        }
    }
}

#Preview {
    let store = UserStore()
    store.users = [
        User(name: "Marc"),
        User(name: "Michi")
    ]
    
    return NavigationStack {
        List {
            ForEach(store.users) { user in
                Text(user.name)
            }
        }
    }
    .environmentObject(store)
}
