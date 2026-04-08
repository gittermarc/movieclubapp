//
//  User.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

import Foundation

struct User: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
}

let sampleUsers: [User] = [
    User(name: "Marc"),
    User(name: "Michi"),
    User(name: "Steffen"),
    User(name: "Thomas")
]
