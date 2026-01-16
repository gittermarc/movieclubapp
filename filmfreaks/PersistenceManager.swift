//
//  PersistenceManager.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.11.25.
//

import Foundation
import os

/// File-basierte Persistenz (Application Support) statt UserDefaults.
///
/// Motivation:
/// - große Arrays (Movies/Backlog/Users) nicht in UserDefaults serialisieren
/// - atomic writes
/// - group-scoped Daten (pro Invite-Code)
/// - Debounce gegen viele Writes bei kleinen UI-Änderungen
final class PersistenceManager {

    static let shared = PersistenceManager()

    private enum Kind: String {
        case watchedMovies = "movies_watched"
        case backlogMovies = "movies_backlog"
        case users = "users"
    }

    private let log = Logger(subsystem: "filmfreaks", category: "Persistence")

    /// Debounce-Zeit für Writes
    private let debounceSeconds: TimeInterval = 0.55

    private let queue = DispatchQueue(label: "filmfreaks.persistence", qos: .utility)

    /// Für Debounce-Cancels (thread-safe via lock)
    private var pendingWrites: [URL: DispatchWorkItem] = [:]
    private let lock = NSLock()

    /// Base Directory: ~/Library/Application Support/FilmFreaks/
    private let baseDir: URL

    /// Migration-Flag (UserDefaults bleibt für Kleinkram ok)
    private let migrationFlagKey = "FilmFreaks.diskPersistence.v2.migrated"

    private init() {
        self.baseDir = Self.makeBaseDir()
        ensureDirectoryExists(baseDir)
        migrateFromUserDefaultsIfNeeded()
    }

    // MARK: - Public API

    // Movies

    func saveMovies(_ movies: [Movie], groupId: String?) {
        scheduleWrite(movies, to: fileURL(kind: .watchedMovies, groupId: groupId))
    }

    func loadMovies(groupId: String?) -> [Movie] {
        read([Movie].self, from: fileURL(kind: .watchedMovies, groupId: groupId)) ?? []
    }

    // Backlog

    func saveBacklogMovies(_ movies: [Movie], groupId: String?) {
        scheduleWrite(movies, to: fileURL(kind: .backlogMovies, groupId: groupId))
    }

    func loadBacklogMovies(groupId: String?) -> [Movie] {
        read([Movie].self, from: fileURL(kind: .backlogMovies, groupId: groupId)) ?? []
    }

    // Users

    func saveUsers(_ users: [User], groupId: String?) {
        scheduleWrite(users, to: fileURL(kind: .users, groupId: groupId))
    }

    func loadUsers(groupId: String?) -> [User] {
        read([User].self, from: fileURL(kind: .users, groupId: groupId)) ?? []
    }

    // Selected User (klein → UserDefaults bleibt ok)

    private let selectedUserNameKey = "FilmFreaks.selectedUserName.v1"

    func saveSelectedUserName(_ name: String?) {
        UserDefaults.standard.set(name, forKey: selectedUserNameKey)
    }

    func loadSelectedUserName() -> String? {
        UserDefaults.standard.string(forKey: selectedUserNameKey)
    }

    // MARK: - Internals

    private static func makeBaseDir() -> URL {
        let fm = FileManager.default

        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return appSupport.appendingPathComponent("FilmFreaks", isDirectory: true)
        }

        // Fallback (sollte praktisch nie passieren)
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("FilmFreaks", isDirectory: true)
    }

    private func fileURL(kind: Kind, groupId: String?) -> URL {
        let gid = safeGroupFolderName(for: groupId)
        let groupDir = baseDir
            .appendingPathComponent("groups", isDirectory: true)
            .appendingPathComponent(gid, isDirectory: true)

        ensureDirectoryExists(groupDir)

        return groupDir.appendingPathComponent("\(kind.rawValue).json")
    }

    private func safeGroupFolderName(for groupId: String?) -> String {
        let raw = (groupId?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }

        // Default-Gruppe
        guard let raw else { return "default" }

        // Relativ robuste Dateinamen ohne extra Dependencies.
        // Erlaubt: A–Z a–z 0–9 - _
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return raw.addingPercentEncoding(withAllowedCharacters: allowed) ?? "default"
    }

    private func ensureDirectoryExists(_ dir: URL) {
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            log.error("Could not create directory: \(dir.path, privacy: .public) – \(error.localizedDescription, privacy: .public)")
        }
    }

    private func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        do {
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .deferredToDate
            return try decoder.decode(T.self, from: data)
        } catch {
            log.error("Read/decode failed: \(url.lastPathComponent, privacy: .public) – \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func writeNow<T: Encodable>(_ value: T, to url: URL) {
        do {
            ensureDirectoryExists(url.deletingLastPathComponent())
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .deferredToDate
            let data = try encoder.encode(value)
            try data.write(to: url, options: [.atomic])
        } catch {
            log.error("Write failed: \(url.lastPathComponent, privacy: .public) – \(error.localizedDescription, privacy: .public)")
        }
    }

    private func scheduleWrite<T: Encodable>(_ value: T, to url: URL) {
        lock.lock()
        pendingWrites[url]?.cancel()

        let item = DispatchWorkItem { [log] in
            do {
                // Encoder pro Write (JSONEncoder ist nicht garantiert thread-safe)
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .deferredToDate
                let data = try encoder.encode(value)

                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                try data.write(to: url, options: [.atomic])
            } catch {
                log.error("Debounced write failed: \(url.lastPathComponent, privacy: .public) – \(error.localizedDescription, privacy: .public)")
            }
        }

        pendingWrites[url] = item
        lock.unlock()

        queue.asyncAfter(deadline: .now() + debounceSeconds, execute: item)
    }

    // MARK: - Migration (UserDefaults → Files)

    private func migrateFromUserDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: migrationFlagKey) == false else { return }

        // Wenn jemand frisch installiert, gibt's nichts zu migrieren.
        let hasOldMovies = defaults.data(forKey: "FilmFreaks.movies.v1") != nil
        let hasOldBacklog = defaults.data(forKey: "FilmFreaks.backlogMovies.v1") != nil
        let hasOldUsersV1 = defaults.data(forKey: "FilmFreaks.users.v1") != nil

        // Users_... Keys (UserStore)
        let hasAnyOldUserKey = defaults.dictionaryRepresentation().keys.contains { $0.hasPrefix("Users_") }

        guard hasOldMovies || hasOldBacklog || hasOldUsersV1 || hasAnyOldUserKey else {
            defaults.set(true, forKey: migrationFlagKey)
            return
        }

        let currentGroupId = defaults.string(forKey: "CurrentGroupId")
        let targetGroupId = (currentGroupId?.isEmpty == false) ? currentGroupId : nil

        log.info("Migration: UserDefaults → Files (targetGroupId=\(targetGroupId ?? "nil", privacy: .public))")

        // Movies (global v1 → group-scoped file für aktuelle Gruppe)
        if let data = defaults.data(forKey: "FilmFreaks.movies.v1") {
            if read([Movie].self, from: fileURL(kind: .watchedMovies, groupId: targetGroupId)) == nil {
                do {
                    let movies = try JSONDecoder().decode([Movie].self, from: data)
                    writeNow(movies, to: fileURL(kind: .watchedMovies, groupId: targetGroupId))
                } catch {
                    log.error("Migration decode movies failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        if let data = defaults.data(forKey: "FilmFreaks.backlogMovies.v1") {
            if read([Movie].self, from: fileURL(kind: .backlogMovies, groupId: targetGroupId)) == nil {
                do {
                    let movies = try JSONDecoder().decode([Movie].self, from: data)
                    writeNow(movies, to: fileURL(kind: .backlogMovies, groupId: targetGroupId))
                } catch {
                    log.error("Migration decode backlog failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        // Users: einmal global v1 (falls noch verwendet wurde)
        if let data = defaults.data(forKey: "FilmFreaks.users.v1") {
            if read([User].self, from: fileURL(kind: .users, groupId: targetGroupId)) == nil {
                do {
                    let users = try JSONDecoder().decode([User].self, from: data)
                    writeNow(users, to: fileURL(kind: .users, groupId: targetGroupId))
                } catch {
                    log.error("Migration decode users.v1 failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        // Users_... Keys pro bekannte Gruppe
        var groupIdsToMigrate: Set<String?> = [nil, targetGroupId]

        if let knownGroupsData = defaults.data(forKey: "KnownGroups") {
            if let known = try? JSONDecoder().decode([GroupInfo].self, from: knownGroupsData) {
                for g in known {
                    groupIdsToMigrate.insert(g.id)
                }
            }
        }

        for gid in groupIdsToMigrate {
            let key: String
            if let gid, !gid.isEmpty {
                key = "Users_\(gid)"
            } else {
                key = "Users_Default"
            }

            guard let data = defaults.data(forKey: key) else { continue }
            if read([User].self, from: fileURL(kind: .users, groupId: gid)) != nil { continue }

            do {
                let users = try JSONDecoder().decode([User].self, from: data)
                writeNow(users, to: fileURL(kind: .users, groupId: gid))
            } catch {
                log.error("Migration decode \(key, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        // Wir lassen die alten Keys bewusst erstmal stehen (Rollback-freundlich).
        defaults.set(true, forKey: migrationFlagKey)
        log.info("Migration done")
    }
}
