import Foundation
import Testing
@testable import filmfreaks

struct MovieNightCloudDirtyJournalTests {

    @Test func pendingEventSaveSurvivesJournalReload() throws {
        let tempDirectory = try TemporaryDirectory()
        let event = makeEvent(title: "Heat")
        let token = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let journal = MovieNightCloudDirtyJournal(rootURL: tempDirectory.url)
        journal.recordEventSave(
            event,
            groupId: "group-a",
            token: token,
            updatedAt: updatedAt
        )

        let reloaded = MovieNightCloudDirtyJournal(rootURL: tempDirectory.url)
        let entry = try #require(reloaded.entries(groupId: "group-a").first)

        #expect(entry.groupId == "group-a")
        #expect(entry.recordType == .event)
        #expect(entry.recordId == event.id.uuidString)
        #expect(entry.operation == .save)
        #expect(entry.token == token)
        #expect(entry.updatedAt == updatedAt)
        #expect(entry.event == event)
    }

    @Test func deleteEntryReplacesPendingSaveForSameEvent() throws {
        let tempDirectory = try TemporaryDirectory()
        let event = makeEvent(title: "Alien")
        let deleteToken = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
        let journal = MovieNightCloudDirtyJournal(rootURL: tempDirectory.url)

        journal.recordEventSave(event, groupId: "group-a")
        journal.recordEventDelete(eventId: event.id, groupId: "group-a", token: deleteToken)

        let entries = journal.entries(groupId: "group-a")
        let entry = try #require(entries.first)

        #expect(entries.count == 1)
        #expect(entry.recordType == .event)
        #expect(entry.recordId == event.id.uuidString)
        #expect(entry.operation == .delete)
        #expect(entry.token == deleteToken)
        #expect(entry.event == nil)
    }

    @Test func responseDeletePersistsCompositeIdentity() throws {
        let tempDirectory = try TemporaryDirectory()
        let eventId = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        let userId = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
        let token = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
        let journal = MovieNightCloudDirtyJournal(rootURL: tempDirectory.url)

        journal.recordResponseDelete(
            eventId: eventId,
            userId: userId,
            groupId: "group-a",
            token: token
        )

        let entry = try #require(journal.entries(groupId: "group-a").first)

        #expect(entry.recordType == .response)
        #expect(entry.recordId == MovieNightCloudDirtyJournal.responseRecordId(eventId: eventId, userId: userId))
        #expect(entry.operation == .delete)
        #expect(entry.responseEventId == eventId)
        #expect(entry.responseUserId == userId)
        #expect(entry.token == token)
    }

    @Test func journalsAreSeparatedByGroup() throws {
        let tempDirectory = try TemporaryDirectory()
        let groupAEvent = makeEvent(title: "Arrival")
        let groupBEvent = makeEvent(title: "Collateral")
        let journal = MovieNightCloudDirtyJournal(rootURL: tempDirectory.url)

        journal.recordEventSave(groupAEvent, groupId: "group-a")
        journal.recordEventSave(groupBEvent, groupId: "group-b")

        #expect(journal.entries(groupId: "group-a").map(\.recordId) == [groupAEvent.id.uuidString])
        #expect(journal.entries(groupId: "group-b").map(\.recordId) == [groupBEvent.id.uuidString])
        #expect(journal.groupIdsWithEntries() == ["group-a", "group-b"])
    }

    @Test func successfulSyncRemovalRequiresMatchingToken() throws {
        let tempDirectory = try TemporaryDirectory()
        let activity = makeActivity()
        let savedToken = UUID(uuidString: "10000000-0000-0000-0000-000000000004")!
        let wrongToken = UUID(uuidString: "10000000-0000-0000-0000-000000000005")!
        let journal = MovieNightCloudDirtyJournal(rootURL: tempDirectory.url)

        journal.recordActivitySave(activity, groupId: "group-a", token: savedToken)
        journal.remove(
            recordType: .activity,
            recordId: activity.id.uuidString,
            matchingToken: wrongToken,
            groupId: "group-a"
        )
        #expect(journal.entries(groupId: "group-a").count == 1)

        journal.remove(
            recordType: .activity,
            recordId: activity.id.uuidString,
            matchingToken: savedToken,
            groupId: "group-a"
        )
        #expect(journal.entries(groupId: "group-a").isEmpty)
    }

    @Test func newerPresetSaveIsNotRemovedByOlderFlushToken() throws {
        let tempDirectory = try TemporaryDirectory()
        let original = makePreset(name: "Action")
        var updated = original
        updated.name = "Action Night"

        let oldToken = UUID(uuidString: "10000000-0000-0000-0000-000000000006")!
        let newToken = UUID(uuidString: "10000000-0000-0000-0000-000000000007")!
        let journal = MovieNightCloudDirtyJournal(rootURL: tempDirectory.url)

        journal.recordPresetSave(original, groupId: "group-a", token: oldToken)
        journal.recordPresetSave(updated, groupId: "group-a", token: newToken)
        journal.remove(
            recordType: .preset,
            recordId: original.id.uuidString,
            matchingToken: oldToken,
            groupId: "group-a"
        )

        let entry = try #require(journal.entries(groupId: "group-a").first)
        #expect(journal.entries(groupId: "group-a").count == 1)
        #expect(entry.token == newToken)
        #expect(entry.preset == updated)
    }

    @Test func allEntriesIncludesDifferentRecordTypes() throws {
        let tempDirectory = try TemporaryDirectory()
        let event = makeEvent(title: "The Matrix")
        let response = makeResponse(eventId: event.id)
        let activity = makeActivity(eventId: event.id)
        let preset = makePreset(name: "Classics")
        let journal = MovieNightCloudDirtyJournal(rootURL: tempDirectory.url)

        journal.recordEventSave(event, groupId: "group-a")
        journal.recordResponseSave(response, groupId: "group-a")
        journal.recordActivitySave(activity, groupId: "group-a")
        journal.recordPresetSave(preset, groupId: "group-a")

        let allEntries = journal.entriesForAllGroups()
        #expect(allEntries.count == 4)
        #expect(Set(allEntries.map(\.recordType)) == [.event, .response, .activity, .preset])
    }

    private func makeEvent(title: String) -> MovieNightEvent {
        MovieNightEvent(
            id: UUID(),
            groupId: "group-a",
            proposedStart: Date(timeIntervalSince1970: 1_700_010_000),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100),
            proposerUserId: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
            proposerName: "Marc",
            suggestedMovie: MovieNightMovieRef(
                movieId: UUID(uuidString: "30000000-0000-0000-0000-000000000002")!,
                title: title,
                year: "1995",
                posterPath: nil,
                tmdbId: nil
            ),
            note: "Test",
            status: .open
        )
    }

    private func makeResponse(eventId: UUID) -> MovieNightResponse {
        MovieNightResponse(
            eventId: eventId,
            userId: UUID(uuidString: "30000000-0000-0000-0000-000000000003")!,
            userName: "Michi",
            decision: .accepted,
            respondedAt: Date(timeIntervalSince1970: 1_700_000_200)
        )
    }

    private func makeActivity(eventId: UUID = UUID()) -> MovieNightActivityEvent {
        MovieNightActivityEvent(
            id: UUID(),
            groupId: "group-a",
            kind: .proposed,
            createdAt: Date(timeIntervalSince1970: 1_700_000_300),
            eventId: eventId,
            eventStart: Date(timeIntervalSince1970: 1_700_010_000),
            actorUserId: UUID(uuidString: "30000000-0000-0000-0000-000000000004")!,
            actorName: "Steffen",
            decision: nil,
            newStatus: nil,
            note: "Test"
        )
    }

    private func makePreset(name: String) -> MovieRoulettePreset {
        MovieRoulettePreset(
            id: UUID(),
            groupId: "group-a",
            name: name,
            sortIndex: 0,
            movieRefs: [
                MovieNightMovieRef(
                    movieId: UUID(uuidString: "30000000-0000-0000-0000-000000000005")!,
                    title: "Heat",
                    year: "1995",
                    posterPath: nil,
                    tmdbId: nil
                )
            ],
            updatedAt: Date(timeIntervalSince1970: 1_700_000_400)
        )
    }
}
