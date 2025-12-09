//
//  PersistenceManager.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

import Foundation

class PersistenceManager {
    
    static let shared = PersistenceManager()
    
    private let moviesKey = "FilmFreaks.movies.v1"
    private let usersKey = "FilmFreaks.users.v1"
    private let selectedUserNameKey = "FilmFreaks.selectedUserName.v1"
    private let backlogMoviesKey = "FilmFreaks.backlogMovies.v1"

    
    private init() {}
    
    // MARK: - Movies
    
    func saveMovies(_ movies: [Movie]) {
        do {
            let data = try JSONEncoder().encode(movies)
            UserDefaults.standard.set(data, forKey: moviesKey)
        } catch {
            print("Fehler beim Speichern der Filme: \(error)")
        }
    }
    
    func loadMovies() -> [Movie] {
        guard let data = UserDefaults.standard.data(forKey: moviesKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([Movie].self, from: data)
        } catch {
            print("Fehler beim Laden der Filme: \(error)")
            return []
        }
    }
    
    // MARK: - Users
    
    func saveUsers(_ users: [User]) {
        do {
            let data = try JSONEncoder().encode(users)
            UserDefaults.standard.set(data, forKey: usersKey)
        } catch {
            print("Fehler beim Speichern der User: \(error)")
        }
    }
    
    func loadUsers() -> [User] {
        guard let data = UserDefaults.standard.data(forKey: usersKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([User].self, from: data)
        } catch {
            print("Fehler beim Laden der User: \(error)")
            return []
        }
    }
    
    // MARK: - Selected User
    
    func saveSelectedUserName(_ name: String?) {
        UserDefaults.standard.set(name, forKey: selectedUserNameKey)
    }
    
    func loadSelectedUserName() -> String? {
        UserDefaults.standard.string(forKey: selectedUserNameKey)
    }
    
    // MARK: - Backlog Movies
    func saveBacklogMovies(_ movies: [Movie]) {
        do {
            let data = try JSONEncoder().encode(movies)
            UserDefaults.standard.set(data, forKey: backlogMoviesKey)
        } catch {
            print("Fehler beim Speichern der Backlog-Filme: \(error)")
        }
    }

    func loadBacklogMovies() -> [Movie] {
        guard let data = UserDefaults.standard.data(forKey: backlogMoviesKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([Movie].self, from: data)
        } catch {
            print("Fehler beim Laden der Backlog-Filme: \(error)")
            return []
        }
    }
}
