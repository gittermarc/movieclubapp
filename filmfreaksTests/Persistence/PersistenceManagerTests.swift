import Foundation
import Testing
@testable import filmfreaks

struct PersistenceManagerTests {

    @Test func saveAndLoadStayGroupScoped() throws {
        let tempDirectory = try TemporaryDirectory()
        let defaultsSuite = try TestUserDefaultsSuite()
        let manager = PersistenceManager(baseDir: tempDirectory.url, userDefaults: defaultsSuite.defaults, debounceSeconds: 0)

        let watchedMovie = makeMovie(title: "Arrival", year: "2016")
        let backlogMovie = makeMovie(title: "Heat", year: "1995")
        let users = [User(name: "Marc"), User(name: "Michi")]

        manager.saveMovies([watchedMovie], groupId: "group-a")
        manager.saveBacklogMovies([backlogMovie], groupId: "group-b")
        manager.saveUsers(users, groupId: nil)

        #expect(manager.loadMovies(groupId: "group-a") == [watchedMovie])
        #expect(manager.loadMovies(groupId: "group-b").isEmpty)
        #expect(manager.loadBacklogMovies(groupId: "group-b") == [backlogMovie])
        #expect(manager.loadBacklogMovies(groupId: "group-a").isEmpty)
        #expect(manager.loadUsers(groupId: nil) == users)
        #expect(manager.loadUsers(groupId: "group-a").isEmpty)
    }

    @Test func migrationImportsLegacyDefaultsIntoDiskPersistence() throws {
        let tempDirectory = try TemporaryDirectory()
        let defaultsSuite = try TestUserDefaultsSuite()

        let currentGroupId = "A0B1C2D3-E4F5-4A6B-8C7D-1234567890AB"
        let sharedLegacyGroupId = "legacy-shared-group"

        let watchedMovies = [makeMovie(title: "The Matrix", year: "1999")]
        let backlogMovies = [makeMovie(title: "Children of Men", year: "2006")]
        let currentUsers = [User(name: "Marc"), User(name: "Michi")]
        let sharedUsers = [User(name: "Steffen")]
        let knownGroups = [
            GroupInfo(id: currentGroupId, name: "Movie Club"),
            GroupInfo(id: sharedLegacyGroupId, name: "Freitagsrunde")
        ]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .deferredToDate

        defaultsSuite.defaults.set(currentGroupId, forKey: "CurrentGroupId")
        defaultsSuite.defaults.set(try encoder.encode(watchedMovies), forKey: "FilmFreaks.movies.v1")
        defaultsSuite.defaults.set(try encoder.encode(backlogMovies), forKey: "FilmFreaks.backlogMovies.v1")
        defaultsSuite.defaults.set(try encoder.encode(currentUsers), forKey: "FilmFreaks.users.v1")
        defaultsSuite.defaults.set(try encoder.encode(sharedUsers), forKey: "Users_\(sharedLegacyGroupId)")
        defaultsSuite.defaults.set(try encoder.encode(knownGroups), forKey: "KnownGroups")

        let manager = PersistenceManager(baseDir: tempDirectory.url, userDefaults: defaultsSuite.defaults, debounceSeconds: 0)

        #expect(manager.loadMovies(groupId: currentGroupId) == watchedMovies)
        #expect(manager.loadBacklogMovies(groupId: currentGroupId) == backlogMovies)
        #expect(manager.loadUsers(groupId: currentGroupId) == currentUsers)
        #expect(manager.loadUsers(groupId: sharedLegacyGroupId) == sharedUsers)
        #expect(defaultsSuite.defaults.bool(forKey: "FilmFreaks.diskPersistence.v2.migrated"))
    }

    @Test func corruptedWatchedMoviesFileFallsBackToEmptyArray() throws {
        let tempDirectory = try TemporaryDirectory()
        let defaultsSuite = try TestUserDefaultsSuite()
        let manager = PersistenceManager(baseDir: tempDirectory.url, userDefaults: defaultsSuite.defaults, debounceSeconds: 0)

        let groupId = "group-corrupted"
        let watchedURL = manager.fileURLForTesting(kind: .watchedMovies, groupId: groupId)
        try Data("{ definitely not valid json }".utf8).write(to: watchedURL, options: [.atomic])

        let backlogMovie = makeMovie(title: "Collateral", year: "2004")
        manager.saveBacklogMovies([backlogMovie], groupId: groupId)

        #expect(manager.loadMovies(groupId: groupId).isEmpty)
        #expect(manager.loadBacklogMovies(groupId: groupId) == [backlogMovie])
    }

    @Test func deleteGroupDataOnlyRemovesTargetGroup() throws {
        let tempDirectory = try TemporaryDirectory()
        let defaultsSuite = try TestUserDefaultsSuite()
        let manager = PersistenceManager(baseDir: tempDirectory.url, userDefaults: defaultsSuite.defaults, debounceSeconds: 0)

        let groupA = "group-a"
        let groupB = "group-b"
        let movieA = makeMovie(title: "Alien", year: "1979")
        let movieB = makeMovie(title: "Aliens", year: "1986")

        manager.saveMovies([movieA], groupId: groupA)
        manager.saveMovies([movieB], groupId: groupB)

        manager.deleteGroupData(groupId: groupA)

        #expect(manager.loadMovies(groupId: groupA).isEmpty)
        #expect(manager.loadMovies(groupId: groupB) == [movieB])
    }

    private func makeMovie(title: String, year: String) -> Movie {
        Movie(
            id: UUID(),
            title: title,
            year: year,
            tmdbRating: 8.0,
            ratings: [],
            posterPath: nil,
            watchedDate: Date(timeIntervalSince1970: 1_700_000_000),
            watchedLocation: nil,
            tmdbId: nil,
            genres: nil,
            genreIds: nil,
            keywords: nil,
            keywordIds: nil,
            suggestedBy: nil,
            cast: nil,
            directors: nil,
            addedAt: Date(timeIntervalSince1970: 1_700_000_100),
            addedById: nil,
            addedByName: nil
        )
    }
}
