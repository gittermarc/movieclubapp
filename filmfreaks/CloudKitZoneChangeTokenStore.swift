//
//  CloudKitZoneChangeTokenStore.swift
//  filmfreaks
//
//  Phase 2 (Skalierung): Persistente ChangeTokens pro Zone,
//  damit wir mit CKFetchRecordZoneChangesOperation inkrementell syncen können.
//

import Foundation
import CloudKit

/// Persistiert `CKServerChangeToken` pro (Scope/Zone/Owner) + Namespace.
///
/// - Namespace trennt z.B. "movies" vs. "ratings".
/// - Wir speichern Token als `Data` via NSKeyedArchiver (NSSecureCoding).
///
/// Warum UserDefaults?
/// - Kleine Datenmenge
/// - Einfaches Keying
/// - Transaktionssicher genug für Tokens
enum CloudKitZoneChangeTokenStore {

    /// Stable key component for DB scope.
    enum Scope: String {
        case `public`
        case `private`
        case shared
    }

    /// Create a stable token key for a zone + namespace.
    private static func tokenKey(namespace: String, scope: Scope, zoneID: CKRecordZone.ID) -> String {
        // ownerName can contain chars like "__defaultOwner__"; keep as-is.
        return "CKZoneToken.\(namespace).\(scope.rawValue).\(zoneID.zoneName).\(zoneID.ownerName)"
    }

    static func token(namespace: String, scope: Scope, zoneID: CKRecordZone.ID) -> CKServerChangeToken? {
        let key = tokenKey(namespace: namespace, scope: scope, zoneID: zoneID)
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
        } catch {
            // Corrupted token: discard.
            UserDefaults.standard.removeObject(forKey: key)
            return nil
        }
    }

    static func setToken(_ token: CKServerChangeToken?, namespace: String, scope: Scope, zoneID: CKRecordZone.ID) {
        let key = tokenKey(namespace: namespace, scope: scope, zoneID: zoneID)
        guard let token else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            // If archiving fails, better clear than keep an unusable token.
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    static func clear(namespace: String, scope: Scope, zoneID: CKRecordZone.ID) {
        let key = tokenKey(namespace: namespace, scope: scope, zoneID: zoneID)
        UserDefaults.standard.removeObject(forKey: key)
    }
}
