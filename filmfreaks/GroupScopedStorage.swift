//
//  GroupScopedStorage.swift
//  filmfreaks
//
//  Centralized local storage path and key helpers.
//

import Foundation

enum GroupScopedStorage {
    static let appSupportFolderName = "FilmFreaks"
    static let legacyMovieNightFolderName = "filmfreaks"
    static let groupsFolderName = "groups"
    static let defaultGroupFolderName = "default"
    static let defaultSyncGroupKey = "__default__"
    static let selectedUserLocalGroupKey = "__local__"

    enum UserDefaultsKey {
        static let currentGroupId = "CurrentGroupId"
        static let currentGroupName = "CurrentGroupName"
        static let knownGroups = "KnownGroups"

        static let diskPersistenceMigration = "FilmFreaks.diskPersistence.v2.migrated"
        static let legacyMovies = "FilmFreaks.movies.v1"
        static let legacyBacklogMovies = "FilmFreaks.backlogMovies.v1"
        static let legacyUsersV1 = "FilmFreaks.users.v1"
        static let selectedUserName = "FilmFreaks.selectedUserName.v1"
        static let selectedUserByGroup = "ff.selectedUser.byGroup.v1"
        static let userStoreSyncStatusByGroup = "UserStore_SyncStatusByGroup"

        static let yearlyGoals = "ViewingGoalsByYear.v1"
        static let customGoalsPrefix = "ViewingCustomGoals.v3."

        static let movieStoreSyncMetaPrefix = "MovieStore.SyncMeta."
        static let movieNightSyncMetaPrefix = "MovieNightStore.SyncMeta."

        static func legacyUsers(groupId: String?) -> String {
            if let groupId, !groupId.isEmpty {
                return "Users_\(groupId)"
            }

            return "Users_Default"
        }

        static func customGoals(groupId: String?) -> String {
            customGoalsPrefix + (groupId ?? "")
        }

        static func movieStoreSyncMeta(groupId: String?, suffix: String) -> String {
            movieStoreSyncMetaPrefix + GroupScopedStorage.syncGroupKey(for: groupId) + "." + suffix
        }

        static func movieNightSyncMeta(groupId: String, suffix: String) -> String {
            movieNightSyncMetaPrefix + groupId + "." + suffix
        }
    }

    static func applicationSupportRootURL(fileManager: FileManager = .default) -> URL {
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return appSupport.appendingPathComponent(appSupportFolderName, isDirectory: true)
        }

        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        return docs.appendingPathComponent(appSupportFolderName, isDirectory: true)
    }

    static func groupDirectoryURL(root: URL, groupId: String?) -> URL {
        root
            .appendingPathComponent(groupsFolderName, isDirectory: true)
            .appendingPathComponent(safeGroupFolderName(for: groupId), isDirectory: true)
    }

    static func groupJSONFileURL(root: URL, groupId: String?, fileName: String) -> URL {
        groupDirectoryURL(root: root, groupId: groupId)
            .appendingPathComponent(fileName)
    }

    static func legacyMovieNightRootURL(
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let base = baseDirectory ?? appSupport ?? fileManager.temporaryDirectory
        return base.appendingPathComponent(legacyMovieNightFolderName, isDirectory: true)
    }

    static func movieNightSnapshotURL(
        fileName: String = "movieNights.json",
        baseDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) -> URL {
        legacyMovieNightRootURL(baseDirectory: baseDirectory, fileManager: fileManager)
            .appendingPathComponent(fileName)
    }

    static func safeGroupFolderName(for groupId: String?) -> String {
        let raw = (groupId?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { value in
            value.isEmpty ? nil : value
        }

        guard let raw else { return defaultGroupFolderName }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return raw.addingPercentEncoding(withAllowedCharacters: allowed) ?? defaultGroupFolderName
    }

    static func syncGroupKey(for groupId: String?) -> String {
        let trimmed = (groupId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultSyncGroupKey : trimmed
    }

    static func selectedUserGroupKey(for groupId: String?) -> String {
        let trimmed = (groupId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? selectedUserLocalGroupKey : trimmed
    }
}
