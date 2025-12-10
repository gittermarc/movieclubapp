//
//  MovieStore.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

import Foundation
internal import SwiftUI
import Combine

/// Einfache Beschreibung einer bekannten Gruppe (zum Anzeigen & Wechseln)
struct GroupInfo: Identifiable, Codable, Equatable {
    /// groupId (Invite-Code)
    var id: String
    /// Anzeigename der Gruppe (optional)
    var name: String?
    
    var displayName: String {
        if let name, !name.isEmpty {
            return name
        } else {
            return "Gruppe \(id.prefix(6))"
        }
    }
}

@MainActor
class MovieStore: ObservableObject {
    
    // MARK: - Öffentlich beobachtbare Daten
    
    @Published var movies: [Movie] = [] {
        didSet {
            if isApplyingCloudUpdate { return }
            
            if let oldData = try? JSONEncoder().encode(oldValue),
               let newData = try? JSONEncoder().encode(movies),
               oldData == newData {
                return
            }
            
            PersistenceManager.shared.saveMovies(movies)
            
            if cloudStore != nil {
                let oldSnapshot = oldValue
                Task {
                    await self.syncChanges(
                        newList: movies,
                        oldList: oldSnapshot,
                        isBacklog: false
                    )
                }
            }
        }
    }
    
    @Published var backlogMovies: [Movie] = [] {
        didSet {
            if isApplyingCloudUpdate { return }
            
            if let oldData = try? JSONEncoder().encode(oldValue),
               let newData = try? JSONEncoder().encode(backlogMovies),
               oldData == newData {
                return
            }
            
            PersistenceManager.shared.saveBacklogMovies(backlogMovies)
            
            if cloudStore != nil {
                let oldSnapshot = oldValue
                Task {
                    await self.syncChanges(
                        newList: backlogMovies,
                        oldList: oldSnapshot,
                        isBacklog: true
                    )
                }
            }
        }
    }
    
    /// Wird in der UI für den iCloud-Spinner beim Laden verwendet
    @Published var isSyncing: Bool = false
    
    /// Aktuell ausgewählte Gruppe (Invite-Code)
    @Published var currentGroupId: String? {
        didSet {
            // Persistenz
            UserDefaults.standard.set(currentGroupId, forKey: "CurrentGroupId")
            // In Gruppenliste eintragen / aktualisieren
            addOrUpdateCurrentGroupInKnownGroups()
        }
    }
    
    /// Anzeigename der aktuellen Gruppe (nur Kosmetik)
    @Published var currentGroupName: String? {
        didSet {
            // Optional auch den Namen persistent halten
            UserDefaults.standard.set(currentGroupName, forKey: "CurrentGroupName")
            addOrUpdateCurrentGroupInKnownGroups()
        }
    }
    
    /// Liste aller bekannten Gruppen (für die Gruppenverwaltung)
    @Published var knownGroups: [GroupInfo] = [] {
        didSet {
            saveKnownGroups()
        }
    }
    
    // MARK: - Intern
    
    private let cloudStore: CloudKitMovieStore?
    private var isApplyingCloudUpdate = false
    
    private static let knownGroupsKey = "KnownGroups"
    
    // MARK: - Init
    
    init(useCloud: Bool = true) {
        if useCloud {
            self.cloudStore = CloudKitMovieStore()
        } else {
            self.cloudStore = nil
        }
        
        // ZUERST: bekannte Gruppen laden
        self.knownGroups = Self.loadKnownGroups()
        
        // Gruppe aus UserDefaults laden (kann nil sein)
        self.currentGroupId = UserDefaults.standard.string(forKey: "CurrentGroupId")
        self.currentGroupName = UserDefaults.standard.string(forKey: "CurrentGroupName")
        
        // Sicherstellen, dass aktuelle Gruppe in knownGroups auftaucht
        addOrUpdateCurrentGroupInKnownGroups()
        
        // Lokale Daten laden (für den Fall, dass Cloud noch nichts hat)
        let stored = PersistenceManager.shared.loadMovies()
        self.movies = stored
        
        let backlogStored = PersistenceManager.shared.loadBacklogMovies()
        self.backlogMovies = backlogStored
        
        // Cloud-Daten nachladen (falls aktiv)
        if useCloud {
            Task {
                await self.loadFromCloud()
            }
        }
    }
    
    // MARK: - Cloud Laden
    
    private func loadFromCloud() async {
        guard let cloudStore else { return }
        
        print("CloudKit: loadFromCloud() START (groupId=\(currentGroupId ?? "nil"))")
        isSyncing = true
        defer {
            isSyncing = false
            print("CloudKit: loadFromCloud() END (groupId=\(currentGroupId ?? "nil"))")
        }
        
        do {
            let entries = try await cloudStore.fetchAllMovies()
            print("CloudKit: fetchAllMovies returned \(entries.count) entries (all groups)")
            
            // Nach Gruppe filtern
            let filteredEntries: [CloudMovieEntry]
            if let groupId = currentGroupId {
                filteredEntries = entries.filter { entry in
                    entry.movie.groupId == groupId
                }
            } else {
                filteredEntries = entries.filter { entry in
                    entry.movie.groupId == nil
                }
            }
            
            let watched = filteredEntries
                .filter { !$0.isBacklog }
                .map { $0.movie }
            let backlog = filteredEntries
                .filter { $0.isBacklog }
                .map { $0.movie }
            
            // Gruppennamen aus Daten ableiten (falls gesetzt)
            let nameFromData = filteredEntries
                .compactMap { $0.movie.groupName }
                .first
            
            isApplyingCloudUpdate = true
            self.movies = watched
            self.backlogMovies = backlog
            self.currentGroupName = nameFromData
            isApplyingCloudUpdate = false
            
            print("CloudKit: applied group data → watched: \(watched.count), backlog: \(backlog.count)")
            
            // Falls die komplette DB leer ist → initialer Upload
            if entries.isEmpty {
                try await initialUploadIfNeeded(using: cloudStore)
            }
            
        } catch {
            print("Fehler beim Laden aus CloudKit: \(error)")
        }
    }
    
    private func initialUploadIfNeeded(using cloudStore: CloudKitMovieStore) async throws {
        print("CloudKit: initial upload starting (watched: \(movies.count), backlog: \(backlogMovies.count))")
        
        await withTaskGroup(of: Void.self) { group in
            for movie in movies {
                group.addTask {
                    do {
                        try await cloudStore.save(movie: movie, isBacklog: false)
                    } catch {
                        print("CloudKit initial upload (watched) error: \(error)")
                    }
                }
            }
            
            for movie in backlogMovies {
                group.addTask {
                    do {
                        try await cloudStore.save(movie: movie, isBacklog: true)
                    } catch {
                        print("CloudKit initial upload (backlog) error: \(error)")
                    }
                }
            }
            
            await group.waitForAll()
        }
        
        print("CloudKit: initial upload finished")
    }
    
    // MARK: - Cloud Sync bei Änderungen
    
    private func syncChanges(newList: [Movie], oldList: [Movie], isBacklog: Bool) async {
        guard let cloudStore else { return }
        if isApplyingCloudUpdate {
            print("CloudKit: syncChanges skipped (isApplyingCloudUpdate = true)")
            return
        }
        
        print("CloudKit: syncChanges START (isBacklog = \(isBacklog), newCount = \(newList.count), oldCount = \(oldList.count))")
        
        let oldIDs = Set(oldList.map { $0.id })
        let newIDs = Set(newList.map { $0.id })
        let removedIDs = oldIDs.subtracting(newIDs)
        
        for id in removedIDs {
            do {
                try await cloudStore.delete(movieID: id)
                print("CloudKit: deleted record for movieID \(id)")
            } catch {
                print("CloudKit delete error: \(error)")
            }
        }
        
        await withTaskGroup(of: Void.self) { group in
            for movie in newList {
                group.addTask {
                    do {
                        try await cloudStore.save(movie: movie, isBacklog: isBacklog)
                    } catch {
                        print("CloudKit save error: \(error)")
                    }
                }
            }
            await group.waitForAll()
        }
        
        print("CloudKit: syncChanges END (isBacklog = \(isBacklog))")
    }
    
    // MARK: - Gruppen-API
    
    /// Neue Filmgruppe erstellen (Invite-Code = groupId), startet mit leeren Listen
    func createNewGroup(withName name: String) {
        let newId = UUID().uuidString
        
        currentGroupId = newId
        currentGroupName = name
        
        // Lokale Listen leeren, ohne Cloud-Löschungen
        isApplyingCloudUpdate = true
        movies = []
        backlogMovies = []
        isApplyingCloudUpdate = false
        
        print("MovieStore: created NEW EMPTY group '\(name)' with id \(newId)")
        
        addOrUpdateCurrentGroupInKnownGroups()
    }
    
    /// Einer bestehenden Gruppe beitreten – Invite-Code = groupId (String)
    func joinGroup(withInviteCode code: String) {
        currentGroupId = code
        // Name holen wir später aus den Filmdaten (falls vorhanden)
        currentGroupName = currentGroupName // bleibt unverändert, wird bei loadFromCloud evtl. gesetzt
        
        // Lokale Listen leeren, ohne Cloud-Löschungen
        isApplyingCloudUpdate = true
        movies = []
        backlogMovies = []
        isApplyingCloudUpdate = false
        
        addOrUpdateCurrentGroupInKnownGroups()
        
        Task {
            await self.loadFromCloud()
        }
    }
    
    /// Aktuelle Gruppe lokal verlassen (ohne Filme für andere zu löschen)
    func leaveCurrentGroup() {
        guard let oldId = currentGroupId else { return }
        
        print("MovieStore: leaving group with id \(oldId)")
        
        // Aus der bekannten Gruppenliste entfernen
        knownGroups.removeAll { $0.id == oldId }
        
        // Gruppe zurücksetzen
        currentGroupId = nil
        currentGroupName = nil
        
        // Lokale Listen leeren, ohne Cloud-Löschungen auszulösen
        isApplyingCloudUpdate = true
        movies = []
        backlogMovies = []
        isApplyingCloudUpdate = false
        
        // Optional: Standard-/„nil“-Gruppe aus Cloud laden (falls es dort Daten gibt)
        Task {
            await self.loadFromCloud()
        }
    }
    
    // MARK: - bekannte Gruppen verwalten
    
    private func addOrUpdateCurrentGroupInKnownGroups() {
        guard let id = currentGroupId else { return }
        
        if let index = knownGroups.firstIndex(where: { $0.id == id }) {
            // Name aktualisieren, falls sich einer ergeben hat
            if let name = currentGroupName, !name.isEmpty, knownGroups[index].name != name {
                knownGroups[index].name = name
            }
        } else {
            let info = GroupInfo(id: id, name: currentGroupName)
            knownGroups.append(info)
        }
    }
    
    private func saveKnownGroups() {
        if let data = try? JSONEncoder().encode(knownGroups) {
            UserDefaults.standard.set(data, forKey: Self.knownGroupsKey)
        }
    }
    
    private static func loadKnownGroups() -> [GroupInfo] {
        guard let data = UserDefaults.standard.data(forKey: knownGroupsKey),
              let decoded = try? JSONDecoder().decode([GroupInfo].self, from: data) else {
            return []
        }
        return decoded
    }
    
    // MARK: - Preview
    
    static func preview() -> MovieStore {
        let store = MovieStore(useCloud: false)
        if store.movies.isEmpty {
            store.movies = sampleMovies
        }
        return store
    }
}
