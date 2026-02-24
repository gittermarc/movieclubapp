# ARCHITECTURE_NOTES — filmfreaks ("The Movie Club")

> Stand: 2026-02-24. Fokus: Sync/Storage/Model → Entry Points/Navigation → Wartbarkeit/Performance.

## Big Files List (Top 15 nach Zeilen)
- `SearchResultDetail/SearchResultDetailView.swift` — **522 LOC**
  - Zweck: TMDb-Suchergebnis-Detail (Movie/Person), lädt Details + Watch Providers, multiple Sheets
  - Risk: Task-Races/duplizierte Requests; viele States + Sheets
- `CloudKitGroupStore.swift` — **455 LOC**
  - Zweck: CloudKit Sharing Groups: list/create/share + GroupContext persistence + subscription setup
  - Risk: Sync-Bugs/Edge-Cases (Routing, Tokens, Offline); schwer reproduzierbar
- `MovieSearch/MovieSearchView.swift` — **434 LOC**
  - Zweck: TMDb Suche + Recommendations UI (search field, results, add-to-watched/backlog)
  - Risk: Merge-Konflikte + schwer testbar; hohe Coupling/State-Dichte
- `Content/ContentView.swift` — **412 LOC**
  - Zweck: Hauptscreen: Listen/Grids, Toolbar, Filters, Routing, Push DeepLink handling
  - Risk: Merge-Konflikte + schwer testbar; hohe Coupling/State-Dichte
- `MovieNights/Sheets/MovieNightDetailSheet.swift` — **410 LOC**
  - Zweck: MovieNight Detail/Responses/Actions Sheet
  - Risk: Merge-Konflikte + schwer testbar; hohe Coupling/State-Dichte
- `MovieStore/MovieStore+CloudSync.swift` — **396 LOC**
  - Zweck: MovieStore Cloud-Sync Wiring: refresh, pending queue, network reconnect, group context retries
  - Risk: Sync-Bugs/Edge-Cases (Routing, Tokens, Offline); schwer reproduzierbar
- `MovieNights/MovieNightStore.swift` — **390 LOC**
  - Zweck: MovieNightStore: State + sync transparency + cloud/local persistence coordination
  - Risk: Merge-Konflikte + schwer testbar; hohe Coupling/State-Dichte
- `UserStore.swift` — **389 LOC**
  - Zweck: UserStore: Users + selection + CloudKit sync + per-group sync status persistence
  - Risk: Merge-Konflikte + schwer testbar; hohe Coupling/State-Dichte
- `ViewingCustomGoal.swift` — **369 LOC**
  - Zweck: Custom Goals domain model + rules/types + codable schema
  - Risk: Merge-Konflikte + schwer testbar; hohe Coupling/State-Dichte
- `Movie.swift` — **366 LOC**
  - Zweck: Core domain model Movie + Rating + criteria + cast/director + encoding/decoding
  - Risk: Payload-Kompatibilität + Migration; ändert Serialization
- `SettingsView.swift` — **363 LOC**
  - Zweck: Settings UI (inkl. Sync transparency, Import, About etc.)
  - Risk: Merge-Konflikte + schwer testbar; hohe Coupling/State-Dichte
- `GroupSettingsView.swift` — **360 LOC**
  - Zweck: Groups UI: create/join/share groups, list owned/shared, actions
  - Risk: Merge-Konflikte + schwer testbar; hohe Coupling/State-Dichte
- `Stats/StatsView+Cards.Leaderboards.swift` — **355 LOC**
  - Zweck: Stats UI Cards: Leaderboards/Highlights (render heavy if large datasets)
  - Risk: Merge-Konflikte + schwer testbar; hohe Coupling/State-Dichte
- `Stats/StatsSnapshotBuilder.swift` — **348 LOC**
  - Zweck: Pure snapshot computation für Stats (filtering, aggregation)
  - Risk: O(n log n) Aggregationen; kann auf großen Datenmengen UI-Latenz erzeugen, wenn nicht sauber entkoppelt
- `MovieDetail/MovieDetailView.swift` — **345 LOC**
  - Zweck: Local Movie Detail screen: fields, onChange handling, sheets (ratings/providers)
  - Risk: Merge-Konflikte + schwer testbar; hohe Coupling/State-Dichte

## Hot Path Analyse

### Rendering / Scrolling (SwiftUI)
**1) Derived Lists & Search**
- Gute Vorarbeit: `Content/ContentMovieItemsModel.swift` berechnet filter/sort/search **außerhalb** von `ContentView.body`.  
  Nutzen: weniger „exzessive View invalidation“ durch wiederholte `filter/sort/map` im Renderpfad.
- Hotspot-Risiko bleibt bei:
  - `Content/ContentView.swift` (412 LOC): viele `@State` + `.onChange` Trigger → breite Invalidations-Fläche.  
    Konkrete Trigger: `.onChange(of: watchedSearchText/backlogSearchText/filterByUser/selectedSort/...)` (siehe `Content/ContentView.swift`).
  - `MovieSearch/MovieSearchView.swift` (434 LOC): Suchfeld + Recommendations + Results in einer View.  
    Risiko: „UI thrash“ wenn Query/Fokus schnell toggelt (mehrere `Task { ... }` aus `.task` + `.onChange(of: query)`).

**2) Network-driven details**
- `SearchResultDetail/SearchResultDetailView.swift` (522 LOC)
  - Konkreter Hotspot: **un-cancelled async Loads**.
    - `.onAppear` startet `Task { await loadDetails() }`.
    - `.onChange(of: result.id)` startet erneut `Task { await loadDetails() }`.
    - `.onChange(of: watchProvidersRegionCode)` startet `Task { await reloadWatchProvidersOnly() }`.
  - Risiko: parallele Loads bei schnellen Wechseln (z.B. Candidate-Picker, Region-Wechsel) → wasted work + state races.

**3) Large-card Stats UI**
- `Stats/StatsView+Cards.Leaderboards.swift` (355 LOC)
  - Risiko: Viele Cards/Rows, die aus Snapshot-Daten rendern. Bei großen Listen sind `ForEach` + image loading + text layout potentiell teuer.
  - Gute Basis: `StatsSnapshotBuilder.swift` ist „pure“ und wird in `StatsViewModel.swift` debounced im Background getriggert (siehe `DispatchQueue.global(...).asyncAfter`).

### Sync / Storage (CloudKit + Local)
**Local Persistence**
- `PersistenceManager.swift`
  - Gute Eigenschaften: debounced writes, atomic file writes, group-scoped files.
  - Hotspot-Risiko: sehr häufige Mutationen (z.B. viele `Movie`-Updates in kurzer Zeit) erzeugen viele geplante WorkItems → Lock/Cancel-Overhead (siehe `pendingWrites` + `NSLock`).

**CloudKit Routing & Safety**
- `CloudKitRouting.swift`
  - Positiv: zentrale Safety-Regel „UUID-like groupId erfordert GroupContext“ → verhindert Public-Fallback.
  - Risiko/Edge-Case: wenn GroupContext fehlt (z.B. nach Share Acceptance, Race zwischen UI/Sync), werfen die Stores Errors.  
    Das ist bewusst, aber braucht saubere Retry-Pfade in Stores/Coordinators.

**CloudKit Group Sharing**
- `CloudKitGroupStore.swift`
  - Hotspot-Risiko: Refresh macht (a) accountStatus check, (b) fetch contexts in private/shared DB, (c) sort, (d) Subscription ensure pro Gruppe.  
    Bei vielen Gruppen: `ensureSubscriptions` erzeugt `groups.count * 3` Subscriptions (Movie/Rating/MovieNightActivity) in `CloudKitActivitySubscriptionManager.swift`.

**Incremental Zone Changes**
- `CloudKitZoneChanges.swift` + Store-spezifisch `*+ZoneChanges.swift`
  - Vorteil: Skalierung für Sharing-Gruppen, statt „query all“.
  - Hotspot-Risiko: Token Drift / Reset
    - Wenn Token invalid oder gelöscht → Initial Fetch (isInitial) kann groß werden (siehe `CloudKitMovieStore+ZoneChanges.swift` und `CloudKitRatingStore+ZoneChanges.swift`).

**Legacy Migration Paths**
- `CloudKitMovieStore/CloudKitMovieStore+Routing.swift`
  - Risiko: Migration bei fehlendem `groupId` Feld kann einen breiten Scan im Public DB triggern (predicate `groupId == NULL OR ''`) und dann upserts ausführen.
- `CloudKitUserStore.swift`
  - Risiko: Legacy RecordName wird best-effort migriert beim Fetch; bei vielen Mitgliedern/Inkonsistenzen kann das extra Writes auslösen.

### Concurrency (MainActor, Tasks, Cancellation)
- Viele Stores sind `@MainActor` (z.B. `MovieStore`, `UserStore`, `MovieNightStore`).  
  Das ist UI-safe, aber es gibt zwei typische Risikopunkte:
  1) **MainActor contention**: wenn heavy work (aggregation, loops über große Arrays) auf MainActor läuft.
     - Beispiele, die gut sind: `StatsSnapshotBuilder` im Background; `ContentMovieItemsModel` als eigener Model-Build-Step.
     - Stellen, die man beobachten sollte: große Merge/Apply-Schritte nach Cloud Fetch (z.B. `MovieStore/MovieStore+CloudSync.swift`, `MovieNights/MovieNightStore.swift`).
  2) **Task lifetime / Cancellation**: Views starten `Task { ... }` in `.onChange`/`.onAppear` ohne Cancel-Strategie.
     - Konkretes Beispiel: `SearchResultDetail/SearchResultDetailView.swift` (siehe oben).

## Refactor Map (konkrete Splits)
> Ziel: weniger „eine Datei regiert alles“, bessere Navigierbarkeit, weniger Merge-Konflikte.  
> Stil: kleine, thematische Files; Split über Subviews oder Extensions.

### UI Splits
- `SearchResultDetail/SearchResultDetailView.swift`
  - Split-Vorschlag:
    - `SearchResultDetail/SearchResultDetailViewModel.swift` (async loading state + cancellation)
    - `SearchResultDetail/SearchResultDetailHeaderView.swift`
    - `SearchResultDetail/SearchResultDetailWatchProvidersSection.swift`
    - `SearchResultDetail/SearchResultDetailCastCrewSection.swift`
  - Nebenbei: `loadDetails()` + `reloadWatchProvidersOnly()` über einen cancelbaren Task-Handle.

- `Content/ContentView.swift`
  - Split-Vorschlag:
    - `Content/ContentHeaderBar.swift` (Toolbar + group selector + quick actions)
    - `Content/ContentFiltersBar.swift` (user filter, sort, view style)
    - `Content/ContentEmptyStates.swift` (onboarding, empty list placeholders)
  - Vorteil: kleinere View invalidation surface + leichteres Testen einzelner Layouts.

- `MovieNights/Sheets/MovieNightDetailSheet.swift`
  - Split-Vorschlag:
    - `MovieNights/Sheets/MovieNightDetailHeader.swift`
    - `MovieNights/Sheets/MovieNightResponsesSection.swift`
    - `MovieNights/Sheets/MovieNightActionsSection.swift`
  - Risiko: niedrig-mittel (Bindings/Sheets), aber klarer.

### Sync/Store Splits
- `MovieStore/MovieStore+CloudSync.swift`
  - Split-Vorschlag (Extensions):
    - `MovieStore/MovieStore+CloudRefresh.swift`
    - `MovieStore/MovieStore+CloudPendingQueue.swift`
    - `MovieStore/MovieStore+NetworkReconnect.swift`
    - `MovieStore/MovieStore+GroupContextRetry.swift`
  - Vorteil: Sync-Edge-Cases besser isoliert, weniger Konflikte.

- `UserStore.swift`
  - Split-Vorschlag:
    - `UserStore+CloudSync.swift`
    - `UserStore+SelectionPersistence.swift`
    - `UserStore+SyncStatusPersistence.swift`
  - Vorteil: UI-unabhängige Teile getrennt, und Cloud Sync ist leichter zu auditieren.

## Cache-/Index-Ideen (konkret + Invalidations)
- **Search Tokens Cache**: bereits vorhanden (`Content/ContentMovieItemsModel.swift` nutzt `MovieSearchIndexCache`).
  - Nächster Schritt: Token-Invaldiation nur für geänderte Movies (statt kompletten rebuild), falls Performance-Probleme auftreten.
- **Cloud Sync Pending Queues**:
  - `MovieCloudSyncCoordinator.swift` hält pending saves/deletes in Dictionaries.  
    Idee: pro groupId ein „namespace“ für pending queues (falls group switching während pending work vorkommt → Edge-Case).  
    Status: Teilweise vorhanden über `pendingCountDidChange(count, groupId)`; genaue Queue-Scope ist **UNKNOWN** ohne tieferen Audit des gesamten Flows.
- **Stats**:
  - Falls datasets wachsen: pre-index `movieId → ratings` oder `reviewerKey` Cache, um wiederholte String-Key-Builds zu vermeiden (in `StatsSnapshotBuilder.swift`).

## Vereinheitlichungen (Patterns, Services, DI)
- CloudKit Helpers sind aktuell mehrfach implementiert (z.B. `queryAllRecords(...)` taucht in mehreren Files auf: `CloudKitUserStore.swift`, `CloudKitGoalStore.swift`, `CloudKitGroupStore.swift`, `CloudKitRatingStore+Query.swift`, `CloudKitMovieNightStore+Snapshot.swift`, `CloudKitMovieStore+Routing.swift`).
  - Vorschlag: `CloudKit/CloudKitQueryHelpers.swift` (async query all, chunking, error mapping) + optional `CloudKit/CloudKitModifyHelpers.swift`.
  - Nutzen: weniger Copy-Paste Bugs, konsistente Cancellation/Retry, weniger Wartungsfläche.

## Risiken & Edge Cases
- **Datenverlust / Doppelte Writes**:
  - Local persistence ist debounced; App-Kill kurz nach Mutationen könnte letzte Writes verlieren (**UNKNOWN**, ob beobachtet; siehe Quick Win „flush now“).
- **CloudKit Account Status**:
  - `CloudKitGroupStore.refresh()` leert Owned/Shared bei `.noAccount`/`.restricted`. UI muss das sauber abfangen (ist im Store adressiert).
- **Public vs Zone Gruppen-Mix**:
  - Legacy-Records ohne `groupId` Feld können Migration triggern (teuer).
  - UUID-like groupId ohne GroupContext wirft (richtig), aber braucht sauberen Retry/Queueing.
- **Multi-Device / Share Acceptance**:
  - Share Acceptance postet `.cloudKitShareAccepted` (siehe `CloudKitShareCoordinator.swift`), Refresh-Kaskade muss GroupContexts früh genug persistieren.

## Observability / Debuggability
- Bereits vorhanden:
  - `CloudKitRemoteNotificationDebugger.swift` (Logging von push payloads)
  - `PersistenceManager.swift` nutzt `Logger(subsystem: "filmfreaks", category: "Persistence")`
- Vorschläge:
  - Einheitliche `Logger`-Kategorien für CloudKit (Routing, ZoneChanges, Modify, Subscriptions).
  - Settings-Diagnostics Screen (read-only) für: aktuelle groupId, GroupContext vorhanden ja/nein, letzte ZoneChangeToken Zeitstempel.

## Open Questions (alles was im Code nicht eindeutig ist)
- **CloudKit Schema in Dashboard:** Indexe, Query Limits, Record Zone Setup pro Gruppe (**UNKNOWN**, nicht aus Code ableitbar).
- **Production Push Setup:** `aps-environment` ist im Repo auf `development` (`filmfreaks.entitlements`). Wie wird Production signiert/deployed? (**UNKNOWN**)
- **Datenvolumen / Performance Budget:** erwartete maximale Movies/Ratings pro Gruppe? (**UNKNOWN**)
- **GroupId Lifecycle:** werden Legacy-Public-Gruppen langfristig weiter genutzt oder migriert? (**UNKNOWN**)
- **Tests:** Es existieren Test-Targets (`filmfreaksTests`, `filmfreaksUITests`), aber Abdeckung/CI ist aus dem Zip nicht ersichtlich (**UNKNOWN**).

## First 3 Refactors I would do (P0)

### P0.1 — Cancelbare Detail-Loads in SearchResultDetail
- **Ziel:** Keine parallelen TMDb/WatchProvider Loads; saubere State-Maschine.
- **Betroffene Dateien:**
  - `SearchResultDetail/SearchResultDetailView.swift`
  - (neu) `SearchResultDetail/SearchResultDetailViewModel.swift`
- **Risiko:** niedrig-mittel (UI-State + async races).
- **Erwarteter Nutzen:** weniger duplicated network calls, weniger flakey UI states, bessere Wartbarkeit.

### P0.2 — CloudKit Query/Modify Helpers zentralisieren
- **Ziel:** Duplicate Implementierungen (`queryAllRecords`, modify helpers) reduzieren und CloudKit-Error Handling vereinheitlichen.
- **Betroffene Dateien (mindestens):**
  - `CloudKitUserStore.swift`
  - `CloudKitGoalStore.swift`
  - `CloudKitGroupStore.swift`
  - `CloudKitMovieStore/CloudKitMovieStore+Routing.swift`
  - `CloudKitRatingStore/CloudKitRatingStore+Query.swift`
  - `CloudKitMovieNightStore/CloudKitMovieNightStore+Snapshot.swift`
  - (neu) `CloudKit/CloudKitQueryHelpers.swift`, optional `CloudKit/CloudKitModifyHelpers.swift`
- **Risiko:** niedrig (mechanischer Refactor, gleiche Semantik).
- **Erwarteter Nutzen:** weniger Copy-Paste Bugs, konsistenteres Verhalten bei Limit/Errors, leichtere Weiterentwicklung.

### P0.3 — MovieStore CloudSync in kleine, auditierbare Extensions splitten
- **Ziel:** Sync-Hotspots isolieren (Refresh, Pending Queue, Network Reconnect, GroupContext Retry), damit Cloud-Edge-Cases leichter zu verstehen sind.
- **Betroffene Dateien:**
  - `MovieStore/MovieStore+CloudSync.swift` → Splits in `MovieStore+CloudRefresh.swift`, `MovieStore+CloudPendingQueue.swift`, `MovieStore+NetworkReconnect.swift`, `MovieStore+GroupContextRetry.swift`
- **Risiko:** niedrig (Split-only, keine Logik-Änderung).
- **Erwarteter Nutzen:** weniger Merge-Konflikte, schnellere Orientierung, geringeres Risiko bei künftigen Sync-Fixes.

