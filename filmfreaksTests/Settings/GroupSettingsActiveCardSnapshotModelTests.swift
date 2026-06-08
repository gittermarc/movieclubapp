import Foundation
import Testing
@testable import filmfreaks

struct GroupSettingsActiveCardSnapshotModelTests {

    @Test func updateSkipsRebuildForSameInputSignature() {
        let builder = CountingSnapshotBuilder()
        let model = GroupSettingsActiveCardSnapshotModel(builder: builder)
        let input = makeInput()

        let didBuildInitialSnapshot = model.update(input: input, now: Date(timeIntervalSince1970: 1_000))
        let didBuildDuplicateSnapshot = model.update(input: input, now: Date(timeIntervalSince1970: 2_000))

        #expect(didBuildInitialSnapshot)
        #expect(!didBuildDuplicateSnapshot)
        #expect(builder.buildCount == 1)
    }

    @Test func updateRebuildsWhenRelevantInputsChange() {
        let builder = CountingSnapshotBuilder()
        let model = GroupSettingsActiveCardSnapshotModel(builder: builder)
        let input = makeInput()
        let changedInput = makeInput(users: [User(name: "Marc"), User(name: "Michi")])

        #expect(model.update(input: input, now: Date(timeIntervalSince1970: 1_000)))
        #expect(model.update(input: changedInput, now: Date(timeIntervalSince1970: 1_001)))
        #expect(builder.buildCount == 2)
    }

    @Test func inputSignatureTracksMovieNightActivityForCurrentHeroSnapshot() {
        let builder = CountingSnapshotBuilder()
        let model = GroupSettingsActiveCardSnapshotModel(builder: builder)
        let firstInput = makeInput(movieNightEvents: [makeMovieNightEvent(kind: .proposed)])
        let secondInput = makeInput(movieNightEvents: [makeMovieNightEvent(kind: .statusChanged)])

        #expect(model.update(input: firstInput, now: Date(timeIntervalSince1970: 1_000)))
        #expect(model.update(input: secondInput, now: Date(timeIntervalSince1970: 1_001)))
        #expect(builder.buildCount == 2)
    }
}

private final class CountingSnapshotBuilder: GroupSettingsActiveCardSnapshotBuilding {
    private(set) var buildCount = 0

    func build(input: GroupSettingsActiveCardSnapshotInput, now: Date) -> GroupSettingsActiveCardSnapshot {
        buildCount += 1
        return GroupSettingsActiveCardSnapshot(
            members: input.users.map { GroupSettingsActiveCardSnapshot.MemberPreview(id: $0.id, name: $0.name) },
            hiddenMemberCount: 0,
            memberSummaryText: input.users.isEmpty ? nil : GroupSettingsPresentation.memberCountText(input.users.count),
            recentActivityText: nil,
            backgroundPosterURL: nil,
            backgroundSystemImage: "film"
        )
    }
}

private func makeInput(
    users: [User] = [User(name: "Marc")],
    movieEvents: [GroupActivityEvent] = [],
    movieNightEvents: [MovieNightActivityEvent] = [],
    movies: [Movie] = [Movie(title: "Heat", year: "1995", posterPath: "/heat.jpg")],
    backlogMovies: [Movie] = []
) -> GroupSettingsActiveCardSnapshotInput {
    GroupSettingsActiveCardSnapshotInput(
        users: users,
        movieEvents: movieEvents,
        movieNightEvents: movieNightEvents,
        movies: movies,
        backlogMovies: backlogMovies
    )
}

private func makeMovieNightEvent(kind: MovieNightActivityEvent.Kind) -> MovieNightActivityEvent {
    MovieNightActivityEvent(
        id: UUID(),
        groupId: "group-1",
        kind: kind,
        createdAt: Date(timeIntervalSince1970: kind == .proposed ? 1_000 : 2_000),
        eventId: UUID(),
        eventStart: Date(timeIntervalSince1970: 3_000),
        actorUserId: UUID(),
        actorName: "Michi",
        decision: nil,
        newStatus: kind == .statusChanged ? .scheduled : nil,
        note: nil
    )
}
