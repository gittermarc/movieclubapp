//
//  CloudKitMovieStore.swift
//  filmfreaks
//
//  Created by Marc Fechner on 05.12.25.
//

import Foundation
import CloudKit

/// Hilfs-Typ, damit wir aus CloudKit nicht nur den Film,
/// sondern auch die Info "Backlog oder gesehen?" zurückbekommen.
struct CloudMovieEntry {
    let movie: Movie
    let isBacklog: Bool
}

/// Kapselt alle Zugriffe auf CloudKit für Movie-Objekte.
///
/// P0.2: Split-only Refactor
/// - Public surface + shared state lives here.
/// - Implementation is split into focused extensions.
struct CloudKitMovieStore {

    let container: CKContainer

    // Schema / keys
    let recordType   = "Movie"       // Record-Typ in CloudKit
    let payloadKey   = "payload"     // Data (codierter Movie)
    let isBacklogKey = "isBacklog"   // Bool
    let updatedAtKey = "updatedAt"   // Date
    let groupIdKey   = "groupId"     // String: aktuelle Gruppen-ID (Invite-Code) oder leer

    init(container: CKContainer = .default()) {
        self.container = container
    }
}
