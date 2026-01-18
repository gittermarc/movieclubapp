//
//  NetworkMonitor.swift
//  filmfreaks
//
//  Lightweight network reachability monitor.
//  Used to show "Offline" in the UI and to avoid pointless CloudKit retries.
//

import Foundation
import Network
import Combine

@MainActor
final class NetworkMonitor: ObservableObject {

    static let shared = NetworkMonitor()

    @Published private(set) var isConnected: Bool = true

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "de.marcfechner.filmfreaks.networkmonitor")

    private init() {
        monitor = NWPathMonitor()

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let connected = (path.status == .satisfied)
            Task { @MainActor in
                self.isConnected = connected
            }
        }

        monitor.start(queue: queue)
    }
}
