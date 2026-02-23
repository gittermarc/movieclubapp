# ARCHITECTURE_NOTES

## Big Files List (Top 15 by lines)
- `filmfreaks/DisplaySettings.swift` — 598 lines
- `filmfreaks/Goals/CustomGoalEditorView.swift` — 545 lines
- `filmfreaks/SearchResultDetail/SearchResultDetailView.swift` — 522 lines
- `filmfreaks/CloudKitRatingStore.swift` — 502 lines
- `filmfreaks/Stats/StatsViewModel.swift` — 466 lines
- `filmfreaks/CloudKitGroupStore.swift` — 463 lines
- `filmfreaks/MovieSearch/MovieSearchView.swift` — 421 lines
- `filmfreaks/MovieNights/Sheets/MovieNightDetailSheet.swift` — 410 lines
- `filmfreaks/Content/ContentView.swift` — 402 lines
- `filmfreaks/MovieStore/MovieStore+CloudSync.swift` — 396 lines
- `filmfreaks/MovieNights/MovieNightStore.swift` — 390 lines
- `filmfreaks/UserStore.swift` — 389 lines
- `filmfreaks/ViewingCustomGoal.swift` — 369 lines
- `filmfreaks/Movie.swift` — 366 lines
- `filmfreaks/SettingsView.swift` — 363 lines

### Why big files are risky (context-specific)
- Hohe Merge-Konflikt-Wahrscheinlichkeit (viele Responsibilities in einem File).
- Schwer zu testen/zu isolieren (insb. wenn UI + State + Networking gemischt).
- Gefahr von Regressionen bei kleinen Änderungen.

## Hot Path Analyse

### Rendering / Scrolling
#### 1) Home list derivation (Search/Filter/Sort)
- **Where**: `filmfreaks/Content/ContentView.swift` (Trigger) + `filmfreaks/Content/ContentMovieItemsModel.swift` (Work)
- **Why hotspot**:
  - `ContentView` triggert `updateMovieItemsModel()` sehr oft (`.onReceive` und `.onChange` für Movies, SearchText, Sort, Filter).
  - `ContentMovieItemsModel.update(...)` ist `@MainActor` und führt `filter + sorted + map` über komplette Listen aus (`buildIndexedItems`).
  - Bei langen Listen + schnellem Tippen in der Suche: **Main-thread contention** + Frames droppen.
- **Concrete indicators**:
  - `ContentMovieItemsModel.buildIndexedItems` nutzt `enumerated → filter → sorted → map`.

#### 2) Stats aggregation snapshot
- **Where**: `filmfreaks/Stats/StatsViewModel.swift`
- **Why hotspot**:
  - `StatsViewModel.update` läuft auf `@MainActor` und setzt `snapshot = computeSnapshot(...)`.
  - `computeSnapshot` baut viele derived Collections (Set/Map/Sort/Groupings). Das ist CPU-lastig bei großen Datenmengen.
  - Zusätzlich: `Inputs: Equatable` enthält `[Movie]`/`[User]` → Equality kann O(n) sein, bevor überhaupt gerechnet wird.

#### 3) Search result detail load tasks
- **Where**: `filmfreaks/SearchResultDetail/SearchResultDetailView.swift`
- **Why hotspot**:
  - `.onAppear` und `.onChange` starten `Task { await loadDetails() }`.
  - `.onChange(of: watchProvidersRegionCode)` startet `Task { await reloadWatchProvidersOnly() }`.
  - Keine Cancellation/Coalescing → bei schnellen Änderungen können mehrere Requests parallel laufen.

#### 4) TMDb search task fan-out
- **Where**: `filmfreaks/MovieSearch/MovieSearchView.swift`
- **Why hotspot**:
  - Mehrere Stellen starten `Task { await performSearch(reset: true) }` und `Task { await loadMore() }`.
  - Wenn der User schnell tippt oder scrollt: Gefahr von unbounded in-flight Requests ohne Cancel.

### Sync / Storage
#### 1) CloudKit Routing safety guard
- **Where**: `filmfreaks/CloudKitRouting.swift`
- **Why it matters**:
  - UUID-like groupIds sind Sharing-Gruppen (Zone) und dürfen nicht in Public DB „leaken“.
  - Guard wirft `CloudKitRoutingError.groupContextNotReady` → Upload/Fetch wird blockiert bis `GroupContextStore` gefüllt ist.

#### 2) Zone Changes delta fetch
- **Where**: `filmfreaks/CloudKitZoneChanges.swift` + `filmfreaks/CloudKitZoneChangeTokenStore.swift`
- **Potential risk**:
  - Große Deltas (viele changedRecords) → JSON decode loops (z.B. in `CloudKitRatingStore.fetchRatingChanges`).
  - Token corruption wird gelöscht, kann aber zu Full-Resync führen.

#### 3) Group refresh (zones listing + root fetch)
- **Where**: `filmfreaks/CloudKitGroupStore.swift`
- **Potential hotspot**:
  - `refresh()` listet Zonen und iteriert sie sequenziell; pro Zone wird Root Record geholt.
  - Subscriptions werden im Anschluss per Task erstellt (aktuell doppelt).

#### 4) Local JSON persistence frequency
- **Where**: `filmfreaks/PersistenceManager.swift`
- **Why hotspot**:
  - Writes sind debounced (gut), aber große Arrays werden komplett als JSON geschrieben.
  - Bei häufigen Mutations (z.B. viele Ratings nacheinander) kann das IO-lastig werden.

### Concurrency
- **Where**:
- `filmfreaks/Content/ContentView.swift` — Creates Task { } (cancellation / coalescing review)
- `filmfreaks/MovieSearch/MovieSearchView.swift` — Creates Task { } (cancellation / coalescing review)
- `filmfreaks/SearchResultDetail/SearchResultDetailView.swift` — Creates Task { } (cancellation / coalescing review)
- `filmfreaks/Stats/StatsViewModel.swift` — @MainActor computation uses filter/sort/map (potential main-thread cost)
- `filmfreaks/Content/ContentMovieItemsModel.swift` — @MainActor computation uses filter/sort/map (potential main-thread cost)
- **Primary concerns**:
  - Task lifetimes ohne Cancellation (UI event → Task spawn).
  - MainActor-heavy computation (`@MainActor` Aggregationen).
  - Mixing `print` + `Logger` erschwert Debugging in concurrency edge cases.

## Refactor Map

### A) Konkrete Splits (Extensions/Subviews)
1) `filmfreaks/CloudKitRatingStore.swift` (502 lines)
   - Split Vorschlag:
     - `filmfreaks/CloudKitRatingStore+Schema.swift` (keys + recordID encoding/decoding)
     - `filmfreaks/CloudKitRatingStore+ZoneChanges.swift` (fetchRatingChanges)
     - `filmfreaks/CloudKitRatingStore+Modify.swift` (saveRating, batch saves, deletes)
     - `filmfreaks/CloudKitRatingStore+Query.swift` (queries, helpers)
   - Nutzen: bessere Navigierbarkeit, weniger Risiko bei Änderungen an nur einem Pfad.

2) `filmfreaks/Stats/StatsViewModel.swift` (466 lines)
   - Split Vorschlag:
     - `filmfreaks/Stats/StatsAggregation.swift` (pure functions, no @MainActor)
     - `filmfreaks/Stats/StatsSnapshotModels.swift` (Snapshot + supporting structs)
     - `filmfreaks/Stats/StatsViewModel.swift` (thin coordinator: input diffing + task scheduling)

3) `filmfreaks/SearchResultDetail/SearchResultDetailView.swift` (522 lines)
   - Split Vorschlag:
     - `filmfreaks/SearchResultDetail/SearchResultDetailView+Loading.swift` (loadDetails/reloadWatchProvidersOnly + task mgmt)
     - `filmfreaks/SearchResultDetail/Sections/*` (Hero/Title/Providers/Overview/FilmInfo/AddToList) falls nicht bereits modular.

4) `filmfreaks/DisplaySettings.swift` (598 lines)
   - Split Vorschlag:
     - `filmfreaks/DisplaySettings+LayoutMetrics.swift`
     - `filmfreaks/DisplaySettings+PosterGrid.swift`
     - `filmfreaks/DisplaySettings+Persistence.swift` (UserDefaults keys)
     - `filmfreaks/DisplaySettings+Defaults.swift`

### B) Cache-/Index-Ideen
- **Stats snapshot caching**: Cache Key = (groupId, selectedRange, locationFilter, ratingDisplayMode, moviesFingerprint).
  - Fingerprint z.B. `(movies.count, max(watchedDate), max(ratings.updatedAt))`.
  - Invalidations: MovieStore didSet, Rating changes, group switch.
- **Search/Sort**: Debounced + cancellable background index build (ähnlich `MovieSearchIndexCache`, aber Pipeline Task).
- **CloudKit decode**: Bei großen Deltas: decode im background Task und nur apply auf MainActor.

### C) Vereinheitlichungen
- **Error mapping**: CKError → human readable in allen Stores (MovieStore aktuell stringifies Error).
- **Logging**: `os.Logger` categories pro subsystem, statt `print`.
- **Routing**: Niemals direkt `container.public/private/sharedCloudDatabase` außerhalb von `CloudKitRouting`.

## Risiken & Edge Cases
- **Sharing Hierarchy**: Records ohne `parent` sind für Share-Participants unsichtbar.
  - Repair exists: `filmfreaks/CloudKitGroupStore.swift` (`repairShareHierarchyIfNeeded`).
  - Risiko: neue RecordTypes müssen das Pattern ebenfalls anwenden.
- **Token lifecycle**: Clearing corrupted tokens kann zu großen Full-Resyncs führen.
- **Offline edits**: Pending queues müssen group-scoped sein, sonst drohen writes in falsche DB/Zone.
- **Public vs Sharing group migration**: Legacy public data + new zone-based groups: Übergangspfad ist komplex (mehrere Schemas parallel).

## Observability / Debuggability
- Push debug: `filmfreaks/CloudKit/CloudKitRemoteNotificationDebugger.swift`.
- Suggestion: zentrale „Sync Diagnostics“ Seite in Settings (keine Feature-Anforderung hier; nur Hinweis).

## Open Questions
- **UNKNOWN**: Wie ist CloudKit Dashboard Schema (Indices/queryable fields) konfiguriert und versioniert.
- **UNKNOWN**: Welche Limits/Policies gelten für Record sharing + Subscriptions in euren Deployments (z.B. production vs development containers).
- **UNKNOWN**: Gibt es automatisierte Tests/CI für CloudKit flows.

## First 3 Refactors I would do (P0)

### P0.1 — Move heavy aggregations off MainActor (Stats + Home list)
- **Ziel**: UI-Jank reduzieren (Scroll/Typing bleibt flüssig), CPU-Work cancellable machen.
- **Betroffene Dateien**:
  - `filmfreaks/Stats/StatsViewModel.swift`
  - `filmfreaks/Content/ContentMovieItemsModel.swift`
  - Trigger in `filmfreaks/Content/ContentView.swift`
- **Risiko**: Mittel (Race Conditions, outdated snapshots, Cancellation correctness).
- **Erwarteter Nutzen**: Spürbar bei großen Listen; weniger Main-thread contention.

### P0.2 — Cancellable task pipeline for TMDb search + detail reload
- **Ziel**: Keine parallelen, veralteten Requests; weniger Datenverbrauch; sauberer State.
- **Betroffene Dateien**:
  - `filmfreaks/MovieSearch/MovieSearchView.swift`
  - `filmfreaks/SearchResultDetail/SearchResultDetailView.swift`
- **Risiko**: Niedrig-Mittel (UI state transitions, loading indicators).
- **Erwarteter Nutzen**: Stabilere Suche, weniger Flackern, weniger "late" UI updates.

### P0.3 — Split CloudKitRatingStore into focused extensions + unify error/logging
- **Ziel**: Wartbarkeit + geringere Regression-Rate im Sync Layer.
- **Betroffene Dateien**:
  - `filmfreaks/CloudKitRatingStore.swift`
  - Optional: `filmfreaks/CloudKitMovieStore/*` (gleiches Pattern)
- **Risiko**: Niedrig (Refactor ohne Verhalten ändern, wenn sauber gesplittet).
- **Erwarteter Nutzen**: Schnellere Navigation, klarere Ownership pro Funktion, weniger Merge-Konflikte.
