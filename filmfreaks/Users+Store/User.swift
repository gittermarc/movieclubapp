//
//  User.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

import Foundation

nonisolated struct User: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    /// Version token for the group-scoped profile image stored outside the JSON member record.
    /// `nil` deliberately represents a member without a profile image and keeps legacy JSON readable.
    var avatarVersion: String? = nil
}

let sampleUsers: [User] = [
    User(name: "Marc"),
    User(name: "Michi"),
    User(name: "Steffen"),
    User(name: "Thomas")
]
