import Foundation

/// Builds small, deterministic CloudKit modification batches for MovieNight sync.
///
/// CloudKit can reject oversized modify operations. Keeping the batching logic
/// pure makes the write path easy to test without depending on CloudKit.
enum MovieNightCloudKitModificationBatcher {
    static let defaultMaxItemsPerBatch = 200

    struct ModificationBatch<SaveItem, DeleteItem> {
        let saves: [SaveItem]
        let deletes: [DeleteItem]

        var itemCount: Int {
            saves.count + deletes.count
        }

        var isEmpty: Bool {
            itemCount == 0
        }
    }

    static func chunks<Item>(
        items: [Item],
        maxItemsPerBatch: Int = defaultMaxItemsPerBatch
    ) -> [[Item]] {
        guard !items.isEmpty else { return [] }

        let limit = max(1, maxItemsPerBatch)
        var result: [[Item]] = []
        result.reserveCapacity((items.count + limit - 1) / limit)

        var start = 0
        while start < items.count {
            let end = min(start + limit, items.count)
            result.append(Array(items[start..<end]))
            start = end
        }

        return result
    }

    static func modificationBatches<SaveItem, DeleteItem>(
        saves: [SaveItem],
        deletes: [DeleteItem],
        maxItemsPerBatch: Int = defaultMaxItemsPerBatch
    ) -> [ModificationBatch<SaveItem, DeleteItem>] {
        guard !saves.isEmpty || !deletes.isEmpty else { return [] }

        let limit = max(1, maxItemsPerBatch)
        var result: [ModificationBatch<SaveItem, DeleteItem>] = []
        result.reserveCapacity((saves.count + deletes.count + limit - 1) / limit)

        var saveIndex = saves.startIndex
        var deleteIndex = deletes.startIndex

        while saveIndex < saves.endIndex || deleteIndex < deletes.endIndex {
            let remainingSaveCount = saves.distance(from: saveIndex, to: saves.endIndex)
            let saveCount = min(remainingSaveCount, limit)
            let remainingCapacity = limit - saveCount
            let remainingDeleteCount = deletes.distance(from: deleteIndex, to: deletes.endIndex)
            let deleteCount = min(remainingDeleteCount, remainingCapacity)

            let nextSaveIndex = saves.index(saveIndex, offsetBy: saveCount)
            let nextDeleteIndex = deletes.index(deleteIndex, offsetBy: deleteCount)

            let batch = ModificationBatch(
                saves: Array(saves[saveIndex..<nextSaveIndex]),
                deletes: Array(deletes[deleteIndex..<nextDeleteIndex])
            )

            if !batch.isEmpty {
                result.append(batch)
            }

            saveIndex = nextSaveIndex
            deleteIndex = nextDeleteIndex
        }

        return result
    }
}
