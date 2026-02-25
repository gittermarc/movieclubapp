//
//  PersonPopularityStore.swift
//  filmfreaks
//
//  Caches & persistiert Popularity per TMDb Person-ID.
//  Ziel: 1 Request pro unbekannter/abgelaufener Person, nicht pro App-Start.
//

import Foundation
import Combine

@MainActor
final class PersonPopularityStore: ObservableObject {

    static let shared = PersonPopularityStore()

    struct PopularityRecord: Codable {
        var popularity: Double
        var lastUpdated: Date

        /// Wenn ein Fetch fehlgeschlagen ist, markieren wir das – damit die TTL
        /// deutlich kürzer sein kann (sonst "klebt" ein Fehler 30 Tage lang).
        var isFailure: Bool = false
    }

    private struct PersistedEntry: Codable {
        let personId: Int
        let record: PopularityRecord
    }

    // ✅ TTL (z.B. 30 Tage). Danach wird beim nächsten Bedarf neu geladen.
    private let ttlSeconds: TimeInterval = 30 * 24 * 60 * 60

    // Fehler-TTL: wir wollen bei transienten Problemen (Offline, Rate-Limit, etc.)
    // zeitnah wieder versuchen, statt 30 Tage "0" zu cachen.
    private let failureTtlSeconds: TimeInterval = 6 * 60 * 60

    private let storageKey = "FilmFreaks.personPopularity.v1"

    @Published private(set) var records: [Int: PopularityRecord] = [:]
    private var inFlight: Set<Int> = []

    private init() {
        loadFromDisk()
    }

    func popularityValue(for personId: Int) -> Double {
        guard let r = records[personId], !isExpired(r) else { return 0 }
        return r.popularity
    }

    /// Value-only Snapshot (nur nicht-expired Werte), damit andere Komponenten
    /// synchron sortieren können, ohne Actor-Überquerungen.
    func popularitySnapshot() -> [Int: Double] {
        var out: [Int: Double] = [:]
        for (id, record) in records {
            guard !isExpired(record) else { continue }
            out[id] = record.popularity
        }
        return out
    }

    func needsRefresh(personId: Int) -> Bool {
        guard let r = records[personId] else { return true }
        return isExpired(r)
    }

    func preloadPopularity(for personIds: [Int]) async {
        let ids = Array(Set(personIds))
            .filter { $0 > 0 } // Legacy-IDs (negativ) können wir nicht sauber nachladen
        if ids.isEmpty { return }

        let missing = ids.filter { id in
            if inFlight.contains(id) { return false }
            return needsRefresh(personId: id)
        }

        if missing.isEmpty { return }

        for id in missing {
            inFlight.insert(id)
        }

        // Netzwerk freundlich: kleine Batches
        let batchSize = 6
        var idx = 0

        while idx < missing.count {
            let end = min(idx + batchSize, missing.count)
            let batch = Array(missing[idx..<end])
            idx = end

            await withTaskGroup(of: (Int, Double?).self) { group in
                for id in batch {
                    group.addTask {
                        do {
                            let details = try await TMDbAPI.shared.fetchPersonDetails(id: id)
                            return (id, details.popularity)
                        } catch {
                            return (id, nil)
                        }
                    }
                }

                for await (id, pop) in group {
                    if let pop {
                        records[id] = PopularityRecord(popularity: pop, lastUpdated: Date(), isFailure: false)
                    } else {
                        // Fehler: wenn wir bereits einen Wert haben, behalten wir ihn (besser für Sortierung)
                        // und geben dem Fehler nur eine kurze TTL.
                        if let existing = records[id] {
                            records[id] = PopularityRecord(
                                popularity: existing.popularity,
                                lastUpdated: Date(),
                                isFailure: true
                            )
                        } else {
                            records[id] = PopularityRecord(popularity: 0, lastUpdated: Date(), isFailure: true)
                        }
                    }
                    inFlight.remove(id)
                }
            }
        }

        saveToDisk()
    }

    // MARK: - Disk

    private func isExpired(_ record: PopularityRecord) -> Bool {
        let ttl = record.isFailure ? failureTtlSeconds : ttlSeconds
        return Date().timeIntervalSince(record.lastUpdated) > ttl
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let entries = try JSONDecoder().decode([PersistedEntry].self, from: data)
            var dict: [Int: PopularityRecord] = [:]
            for e in entries {
                dict[e.personId] = e.record
            }
            self.records = dict
        } catch {
            // wenn kaputt: einfach ignorieren
            self.records = [:]
        }
    }

    private func saveToDisk() {
        let entries: [PersistedEntry] = records.map { (key, value) in
            PersistedEntry(personId: key, record: value)
        }
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            // ignore
        }
    }
}
