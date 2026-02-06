//
//  ContentView+Refresh.swift
//  filmfreaks
//
//  Extracted from ContentView to keep the main file smaller and easier to maintain.
//

internal import SwiftUI

extension ContentView {

    // MARK: - Pull to Refresh

    /// Pull-to-refresh entry point:
    /// - refresh Movies (CloudKit)
    /// - refresh Members (CloudKit)
    func performPullToRefresh() async {
        // Parallelisieren, damit die UI schneller wieder „da“ ist.
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await movieStore.refreshFromCloud(force: true)
            }
            group.addTask {
                await userStore.refreshFromCloud(force: true)
            }
            await group.waitForAll()
        }
    }
}
