//
//  CloudKitRatingStore.swift
//  filmfreaks
//
//  Created by Marc Fechner on 03.01.26.
//

import Foundation
import CloudKit

/// CloudKit Store für per-User Ratings (Version B).
///
/// Jeder User ist Creator seines Rating-Records → darf ihn auch aktualisieren.
/// Andere User können die Ratings lesen.
///
/// Hinweis: Die Implementierung ist in Extension-Files aufgeteilt (Schema / Query / Modify / ZoneChanges).
struct CloudKitRatingStore {

    // MARK: - CloudKit Setup

    let container: CKContainer

    init(container: CKContainer = .default()) {
        self.container = container
    }

    /// Routing in Private/Shared/Public Datenbank + Zone, abhängig von GroupId.
    ///
    /// Muss `internal` sein, damit die Implementierung in separaten Dateien als Extensions leben kann.
    func routedDatabase(forGroupId groupId: String?) throws -> (db: CKDatabase, zoneID: CKRecordZone.ID?) {
        try CloudKitRouting.route(container: container, groupId: groupId)
    }
}
