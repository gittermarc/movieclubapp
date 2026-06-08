import Testing
@testable import filmfreaks

@MainActor
struct MovieDetailLoadCoordinatorAliasTests {

    @Test func movieDetailCoordinatorUsesSharedMetadataCoordinator() async {
        let coordinator = MovieDetailLoadCoordinator()
        #expect(coordinator.details == nil)
        #expect(coordinator.isLoadingDetails == false)
    }
}
