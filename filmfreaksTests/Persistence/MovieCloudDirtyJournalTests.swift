import Foundation
import Testing
@testable import filmfreaks

struct MovieCloudDirtyJournalTests {

    @Test func pendingSaveSurvivesJournalReload() throws {
        let tempDirectory = try TemporaryDirectory()
        let movie = makeMovie(title: "Heat", year: "1995")
        let token = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let journal = MovieCloudDirtyJournal(rootURL: tempDirectory.url)
        journal.recordSave(
            movie: movie,
            isBacklog: false,
            groupId: "group-a",
            token: token,
            updatedAt: updatedAt
        )

        let reloaded = MovieCloudDirtyJournal(rootURL: tempDirectory.url)
        let entry = try #require(reloaded.entries(groupId: "group-a").first)

        #expect(entry.movieId == movie.id)
        #expect(entry.operation == .save)
        #expect(entry.token == token)
        #expect(entry.updatedAt == updatedAt)
        #expect(entry.isBacklog == false)
        #expect(entry.movie == movie)
    }

    @Test func deleteEntryReplacesPendingSaveForSameMovie() throws {
        let tempDirectory = try TemporaryDirectory()
        let movie = makeMovie(title: "Alien", year: "1979")
        let journal = MovieCloudDirtyJournal(rootURL: tempDirectory.url)

        journal.recordSave(movie: movie, isBacklog: true, groupId: "group-a")
        let deleteToken = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        journal.recordDelete(movieID: movie.id, groupId: "group-a", token: deleteToken)

        let entries = journal.entries(groupId: "group-a")
        let entry = try #require(entries.first)

        #expect(entries.count == 1)
        #expect(entry.movieId == movie.id)
        #expect(entry.operation == .delete)
        #expect(entry.token == deleteToken)
        #expect(entry.movie == nil)
        #expect(entry.isBacklog == nil)
    }

    @Test func journalsAreSeparatedByGroup() throws {
        let tempDirectory = try TemporaryDirectory()
        let groupAMovie = makeMovie(title: "Arrival", year: "2016")
        let groupBMovie = makeMovie(title: "Collateral", year: "2004")
        let localMovie = makeMovie(title: "The Matrix", year: "1999")
        let journal = MovieCloudDirtyJournal(rootURL: tempDirectory.url)

        journal.recordSave(movie: groupAMovie, isBacklog: false, groupId: "group-a")
        journal.recordSave(movie: groupBMovie, isBacklog: true, groupId: "group-b")
        journal.recordSave(movie: localMovie, isBacklog: false, groupId: nil)

        #expect(journal.entries(groupId: "group-a").map(\.movieId) == [groupAMovie.id])
        #expect(journal.entries(groupId: "group-b").map(\.movieId) == [groupBMovie.id])
        #expect(journal.entries(groupId: nil).map(\.movieId) == [localMovie.id])
    }

    @Test func successfulSyncRemovalRequiresMatchingToken() throws {
        let tempDirectory = try TemporaryDirectory()
        let movie = makeMovie(title: "Children of Men", year: "2006")
        let savedToken = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let wrongToken = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
        let journal = MovieCloudDirtyJournal(rootURL: tempDirectory.url)

        journal.recordSave(movie: movie, isBacklog: false, groupId: "group-a", token: savedToken)
        journal.remove(movieID: movie.id, matchingToken: wrongToken, groupId: "group-a")
        #expect(journal.entries(groupId: "group-a").count == 1)

        journal.remove(movieID: movie.id, matchingToken: savedToken, groupId: "group-a")
        #expect(journal.entries(groupId: "group-a").isEmpty)
    }

    @Test func newerSaveIsNotRemovedByOlderFlushToken() throws {
        let tempDirectory = try TemporaryDirectory()
        let original = makeMovie(title: "Blade Runner", year: "1982")
        var updated = original
        updated.title = "Blade Runner: Final Cut"

        let oldToken = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
        let newToken = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!
        let journal = MovieCloudDirtyJournal(rootURL: tempDirectory.url)

        journal.recordSave(movie: original, isBacklog: false, groupId: "group-a", token: oldToken)
        journal.recordSave(movie: updated, isBacklog: false, groupId: "group-a", token: newToken)
        journal.remove(movieID: original.id, matchingToken: oldToken, groupId: "group-a")

        let entry = try #require(journal.entries(groupId: "group-a").first)
        #expect(journal.entries(groupId: "group-a").count == 1)
        #expect(entry.token == newToken)
        #expect(entry.movie == updated)
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
