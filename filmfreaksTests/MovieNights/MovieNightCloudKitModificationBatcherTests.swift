import Foundation
import Testing
@testable import filmfreaks

struct MovieNightCloudKitModificationBatcherTests {

    @Test func emptyInputsProduceNoBatches() {
        let batches = MovieNightCloudKitModificationBatcher.modificationBatches(
            saves: [Int](),
            deletes: [Int](),
            maxItemsPerBatch: 3
        )

        #expect(batches.isEmpty)
    }

    @Test func smallSaveAndDeleteSetStaysInSingleBatch() throws {
        let batches = MovieNightCloudKitModificationBatcher.modificationBatches(
            saves: ["event", "response"],
            deletes: ["activity"],
            maxItemsPerBatch: 3
        )

        let batch = try #require(batches.first)

        #expect(batches.count == 1)
        #expect(batch.saves == ["event", "response"])
        #expect(batch.deletes == ["activity"])
        #expect(batch.itemCount == 3)
    }

    @Test func largeSaveSetIsSplitIntoSafeBatches() {
        let saves = Array(0..<450)
        let batches = MovieNightCloudKitModificationBatcher.modificationBatches(
            saves: saves,
            deletes: [Int](),
            maxItemsPerBatch: 200
        )

        #expect(batches.map(\.itemCount) == [200, 200, 50])
        #expect(batches.flatMap(\.saves) == saves)
    }

    @Test func mixedSavesAndDeletesPreserveAllItems() {
        let saves = ["s1", "s2", "s3", "s4"]
        let deletes = ["d1", "d2", "d3"]
        let batches = MovieNightCloudKitModificationBatcher.modificationBatches(
            saves: saves,
            deletes: deletes,
            maxItemsPerBatch: 3
        )

        #expect(batches.allSatisfy { $0.itemCount <= 3 })
        #expect(batches.flatMap(\.saves) == saves)
        #expect(batches.flatMap(\.deletes) == deletes)
        #expect(batches.map(\.itemCount) == [3, 3, 1])
    }

    @Test func chunkingUsesAtLeastOneItemPerBatchForInvalidLimit() {
        let chunks = MovieNightCloudKitModificationBatcher.chunks(
            items: [1, 2, 3],
            maxItemsPerBatch: 0
        )

        #expect(chunks == [[1], [2], [3]])
    }
}
