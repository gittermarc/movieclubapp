//
//  AppRefreshCoordinator.swift
//  filmfreaks
//
//  Created by Marc Fechner on 19.02.26.
//

import Foundation
internal import SwiftUI
import Combine

/// Coalesces app-resume refresh triggers into a single in-flight refresh.
///
/// Goals:
/// - Debounce rapid `.active` toggles (app switching, share sheets, etc.)
/// - Never run two refresh cascades in parallel
/// - If a refresh is requested while one is running, run exactly one more afterwards
@MainActor
final class AppRefreshCoordinator: ObservableObject {

    private var scheduledTask: Task<Void, Never>?
    private var inFlightTask: Task<Void, Never>?

    private var rerunRequested: Bool = false
    private var latestAction: (@MainActor @Sendable () async -> Void)?

    /// Triggers a refresh cascade, coalescing repeated calls.
    func triggerRefresh(
        debounceSeconds: TimeInterval = 0.35,
        action: @escaping @MainActor @Sendable () async -> Void
    ) {
        latestAction = action

        scheduledTask?.cancel()
        scheduledTask = Task { @MainActor [weak self] in
            guard let self else { return }

            if debounceSeconds > 0 {
                let ns = UInt64(debounceSeconds * 1_000_000_000)
                do {
                    try await Task.sleep(nanoseconds: ns)
                } catch {
                    return
                }
            }

            await self.runLatestOrQueue()
        }
    }

    /// Cancels a pending debounced refresh trigger (does not cancel an in-flight refresh).
    func cancelPending() {
        scheduledTask?.cancel()
        scheduledTask = nil
        rerunRequested = false
    }

    private func runLatestOrQueue() async {
        guard let action = latestAction else { return }

        if inFlightTask != nil {
            rerunRequested = true
            return
        }

        inFlightTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.inFlightTask = nil
            }

            await action()

            if self.rerunRequested {
                self.rerunRequested = false
                await Task.yield()
                await self.runLatestOrQueue()
            }
        }
    }
}
