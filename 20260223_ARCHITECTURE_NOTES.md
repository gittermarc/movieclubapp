# ARCHITECTURE_NOTES — filmfreaks (The Movie Club)

> Fokus: technische Details, Tradeoffs, Hotspots, Refactor-Hebel.
> Regeln: Unklares ist **UNKNOWN** und landet in Open Questions.

---

## Big Files List (Top 15 nach Zeilen)

> Quelle: Projekt-Scan der Swift Dateien. (Achtung: File-Splits existieren bereits an einigen Stellen.)

1. `filmfreaks/Goals/CustomGoalEditorView.swift` — ~545
   - Zweck: UI Editor für Custom Goals (viele Sections/Bindings).
   - Risiko: hoher UI-Binding-Druck, Review schwer, Compile-Time.

2. `filmfreaks/SearchResultDetail/SearchResultDetailView.swift` — ~522
   - Zweck: Detailansicht für TMDb-Suchergebnisse.
   - Risiko: großer Render-Tree + viele Zustände → Invalidation/Performance/Regression-Risiko.

3. `filmfreaks/Stats/StatsViewModel.swift` — ~466
   - Zweck: Stats Aggregation/State/Loading.
   - Risiko: Heavy compute/sorts → wenn am MainActor, UI Jank. Concurrency/Cache-Komplexität.

4. `filmfreaks/CloudKitGroupStore.swift` — ~455
   - Zweck: Group/Sharing/Context/Refresh (CloudKit).
   - Risiko: Sync-Bugs, edge cases (share accept, zone routing), schwer testbar.

5. `filmfreaks/MovieSearch/MovieSearchView.swift` — ~421
   - Zweck: Suche UI, Pagination, History, Recommendations.
   - Risiko: viele Tasks/State; Race Conditions bei Search/LoadMore.

6. `filmfreaks/MovieNights/Sheets/MovieNightDetailSheet.swift` — ~410
   - Zweck: Filmabend Detail Sheet (Responses, Actions).
   - Risiko: komplexer Sheet-State + Interaktionen → Regressionen.

7. `filmfreaks/Content/ContentView.swift` — ~402
   - Zweck: Root Screen (Listen/Filter/Search/Routing/Preview).
   - Risiko: Invalidation + derived computations; „Hot Path“ für Scroll/Render.

8. `filmfreaks/MovieStore/MovieStore+CloudSync.swift` — ~396
   - Zweck: Cloud Sync Wiring (Coordinator, refresh hooks, meta).
   - Risiko: Sync correctness + MainActor contention.

9. `filmfreaks/MovieNights/MovieNightStore.swift` — ~390
   - Zweck: Event/Response Store + Persistence/Sync hooks.
   - Risiko: Konsistenz (composite IDs), group scoping, offline queue.

10. `filmfreaks/UserStore.swift` — ~389
   - Zweck: Users + selection + Cloud sync.
   - Risiko: Sync merges + UI consistency (selectedUser).

11. `filmfreaks/ViewingCustomGoal.swift` — ~369
   - Zweck: Custom Goal domain logic + helpers.
   - Risiko: Logik + Codable migrations.

12. `filmfreaks/Movie.swift` — ~366
   - Zweck: Domain models (Movie/Rating/etc.).
   - Risiko: Codable compatibility + Cloud payload size.

13. `filmfreaks/SettingsView.swift` — ~363
   - Zweck: Settings (Sync status, appearance, cache).
   - Risiko: eher moderat; aber viele kleine async actions.

14. `filmfreaks/GroupSettingsView.swift` — ~360
   - Zweck: Group administration UI.
   - Risiko: Share/Invite flows; kann Sync-Routing beeinflussen.

15. `filmfreaks/Stats/StatsView+Cards.Leaderboards.swift` — ~355
   - Zweck: Stats UI Cards/Leaderboards.
   - Risiko: Render cost bei großen Listen + sorting/aggregation im View.

---

## Hot Path Analyse

### A) Rendering / Scrolling (SwiftUI)

#### Hotspot 1: Activity Feed wird im UI-Pfad aus großen Arrays abgeleitet
- Datei: `filmfreaks/Content/ContentView.swift`
- Symptom/Grund:
  - `activityPreviewItems` ruft `movieStore.activityEvents(...)` auf.
  - `activityEvents(...)` iteriert über `movies + backlogMovies`, iteriert je Movie alle `ratings`, sortiert Events, dann `prefix(limit)`.
  - Datei: `filmfreaks/MovieStore/MovieStore+Activity.swift`
- Warum Hot Path:
  - Jede View-Recompute kann diese Ableitung neu auslösen (computed var → keine Memoization).
  - Bei großen Gruppen (viele Filme + Ratings) wird das spürbar.

**Hebel:**
- Activity Events als Cache/DTO pro Group im Store oder eigenem Model halten.
- Invalidation nur bei Änderungen an `movies/backlogMovies/ratings/displayMode`.

#### Hotspot 2: Root Screen ist „State-heavy“
- Datei: `filmfreaks/Content/ContentView.swift`
- Symptom/Grund:
  - Viele `@State` / `@AppStorage` / EnvironmentObjects.
  - Hohe Wahrscheinlichkeit für „exzessive View invalidation“ (kleine State-Änderung → großer Tree update).
- Positives Gegenbeispiel:
  - `@StateObject var movieItemsModel = ContentMovieItemsModel()` ist explizit als „off render path“ gedacht.

**Hebel:**
- Weitere derived computations (activity preview, leaderboard previews, heavy sorts) in Models verschieben.

#### Hotspot 3: Große Feature Views (Search/Detail/Goals) = hoher Render Tree
- Dateien:
  - `filmfreaks/MovieSearch/MovieSearchView.swift`
  - `filmfreaks/SearchResultDetail/SearchResultDetailView.swift`
  - `filmfreaks/Goals/CustomGoalEditorView.swift`
- Risiko:
  - Schwer zu sehen, wo teure Computations liegen.
  - Häufig: `.sorted/.filter/.map` und dynamische Sections direkt im body (konkrete Stellen: **UNKNOWN** ohne detaillierte Pattern-Scan je Datei).

**Hebel:**
- Split in Subviews (Row Views, Sections, Sheets) und „pure view“ vs „compute“ trennen.
- Bei Listen: `EquatableView`/stable IDs/DTOs prüfen (nur wenn messbar).

---

### B) Sync / Storage (CloudKit + Persistence)

#### Hotspot 4: App refresh on scene `.active` kann CloudKit-Fetch-Sturm erzeugen
- Datei: `filmfreaks/filmfreaksApp.swift`
- Verhalten:
  - Bei `scenePhase == .active`:
    - `groupStore.refresh()`
    - `movieNightStore.flushPendingCloudChanges()`
    - `movieStore.refreshFromCloud(force: false)`
    - `userStore.refreshFromCloud(force: false)`
    - `movieNightStore.refreshFromCloud(groupId: ..., force: false)`
- Warum Hotspot:
  - Häufiges App-Wechseln (Control Center, Links, Multitasking) → wiederholte Refreshes.
  - Netzwerk/Batterie/Rate-Limits Risiko.
- Tradeoff:
  - Ohne Subscriptions ist „active refresh“ ein simpler Konsistenz-Hammer (steht auch als Kommentar im Code).

**Hebel:**
- Throttling/Dedup im `AppRefreshCoordinator` (Pfad: **UNKNOWN**).
- Subscription/Push stärker nutzen und active refresh seltener/inkrementell machen.

#### Hotspot 5: Zone Changes sammeln Records in Memory
- Datei: `filmfreaks/CloudKitZoneChanges.swift`
- Verhalten:
  - `fetchAllChanges = true`, sammelt `changedRecords: [CKRecord]` + deletes arrays.
- Warum Hotspot:
  - In sehr großen Zonen kann das RAM-Spikes verursachen.
- Tradeoff:
  - Implementation ist simpel und korrekt; Optimierung lohnt erst bei echten Skalierungsproblemen.

**Hebel:**
- Streaming decode/merge (recordWasChangedBlock → direkt persistieren/merge) statt „erst sammeln, dann verarbeiten“.
- Chunked merges + autoreleasepool (wenn UIKit/ObjC-lastig; in SwiftUI selten nötig).

#### Hotspot 6: Token + Routing State Split zwischen UserDefaults und Files
- Dateien:
  - `filmfreaks/CloudKitZoneChangeTokenStore.swift` (UserDefaults)
  - `filmfreaks/GroupContext.swift` (UserDefaults)
  - `filmfreaks/PersistenceManager.swift` (Application Support)
- Risiko:
  - Group Switch + Token mismatch → falsches Delta/Refresh Verhalten (konkret: **UNKNOWN** ohne Bugberichte).
- Hebel:
  - Einheitliches „Group-scoped storage“ Keying + Clear-on-group-leave.

---

### C) Concurrency

#### Beobachtung 1: Store/Sync Coordinator bewusst am MainActor
- Datei: `filmfreaks/MovieCloudSyncCoordinator.swift`
- Grund:
  - Kommentar: „intentionally lives on the MainActor“, um Sendable issues zu vermeiden.
- Risiko:
  - Wenn pending queues groß werden und flush scheduling häufig triggert, kann MainActor beschäftigt werden (Scheduling + dictionary churn).
- Positiv:
  - Debounce + `scheduledFlush?.cancel()` ist sauber, `isFlushing` guard verhindert parallel flush.

**Hebel:**
- Heavy serialization/encoding/CloudKit payload build off-main (nur wenn Profiling zeigt, dass MainActor blockt).

#### Beobachtung 2: Push Handling in AppDelegate startet async Task
- Datei: `filmfreaks/CloudKitShareAppDelegate.swift`
- Risiko:
  - Background fetch time window; muss zuverlässig completionHandler triggern.
- Positiv:
  - completionHandler wird nach `fetchAndLog` gerufen (kein „fire and forget“).

---

## Refactor Map

### 1) Konkrete Splits (Datei → neue Dateien)

#### A) `ContentView` weiter entkoppeln
- Datei: `filmfreaks/Content/ContentView.swift`
- Split Vorschlag:
  - `ContentView+ActivityPreviewModel.swift` (caching/DTO building)
  - `ContentView+ListSectionViews.swift` (watched/backlog sections)
  - `ContentView+SearchUI.swift` (search field/focus handling)
- Ziel:
  - Renderpfad wird „dümmer“, Logik testbarer.

#### B) `MovieSearchView` in kleinere Einheiten
- Datei: `filmfreaks/MovieSearch/MovieSearchView.swift`
- Split Vorschlag:
  - `MovieSearchState.swift` (State + derived flags)
  - `MovieSearchResultsList.swift` (List UI)
  - `MovieSearchRecommendations.swift` (Idle recommendations/history UI)
  - `MovieSearchNetworking.swift` (performSearch/loadMore, cancellation)
- Ziel:
  - Race conditions sichtbarer, UI stabiler, Compile-Zeit runter.

#### C) `CloudKitGroupStore` splitten nach Verantwortlichkeit
- Datei: `filmfreaks/CloudKitGroupStore.swift`
- Split Vorschlag:
  - `CloudKitGroupStore+Sharing.swift` (CKShare accept/create/invite)
  - `CloudKitGroupStore+Refresh.swift` (refresh, subscriptions, tokens)
  - `CloudKitGroupStore+Persistence.swift` (GroupContext storage glue)
- Ziel:
  - Weniger „eine Datei regiert alles“, leichteres Review bei Sync-Änderungen.

---

### 2) Cache-/Index-Ideen

#### Activity Feed Cache (Group-scoped)
- Dateien:
  - `filmfreaks/MovieStore/MovieStore+Activity.swift`
  - `filmfreaks/Content/ContentView.swift`
- Key:
  - `(groupId, displayMode, moviesRevision)` → `[GroupActivityEvent]` oder `[UnifiedGroupActivityEvent]`
- Invalidation:
  - wenn `movies/backlogMovies` oder `ratings.updatedAt` sich ändern
- Nutzen:
  - UI Recompute wird billig; Scroll/Interaktionen flüssiger.

#### Stats Snapshot Cache
- Dateien:
  - `filmfreaks/Stats/StatsViewModel.swift` (+ Stats Views)
- Status:
  - Existenz eines Snapshot-Systems: **UNKNOWN** ohne Deep-Scan.
- Idee:
  - Group-scoped snapshots, background compute, commit in einem Rutsch.

---

### 3) Vereinheitlichungen (Patterns, Services, DI)

- **Stores als Protocol + Impl**
  - UI könnte gegen `MovieStoreProtocol` testen (Preview/Testability).
  - Aufwand: mittel; Nutzen v.a. bei CloudKit Bugs.

- **Einheitliche Logger Strategy**
  - `PersistenceManager` nutzt `Logger(subsystem:, category:)`.
  - CloudKit Stores/Coordinators könnten identisch instrumentiert werden.

- **Central Task/Cancellation Utilities**
  - Debounce/Throttle Patterns in Search/Refresh/Sync konsolidieren.

---

## Risiken & Edge Cases

- **Sharing Routing correctness**
  - Wenn `GroupContext` fehlt/korrupt ist → Daten könnten in falscher DB/Zone landen.
  - Aktuelle Schutzmechanismen: teilweise sichtbar (Kommentare in App Refresh; GroupContextStore).
  - Konkrete Fallback-Policy: **UNKNOWN** ohne Deep-Scan von CloudKitRouting code.

- **Codable payload migrations**
  - `Movie`/`Rating` als payload in CloudKit; Änderungen müssen backward compatible sein.
  - Risiko: decoding failures → dropped items oder silent data loss (abhängig von error handling: **UNKNOWN**).

- **Offline + Pending changes**
  - Pending behalten bei Cloud errors (`MovieCloudSyncCoordinator`).
  - MovieNight pending flush existiert als Hook (`flushPendingCloudChanges()`), aber Umsetzung: **UNKNOWN**.

---

## Observability / Debuggability

- Vorhanden:
  - `Logger` in `filmfreaks/PersistenceManager.swift`
  - Push Debug: `CloudKitRemoteNotificationDebugger.log(...)` in `filmfreaks/CloudKitShareAppDelegate.swift`
- Fehlend / Hebel:
  - Konsistente OSLog Kategorien für CloudKit Ops (fetch/modify/zone changes)
  - Lightweight metrics (count records fetched, merge durations, pending sizes)
  - Repro steps für typische Sync Bugs als Checkliste.

---

## Open Questions (alles **UNKNOWN**)

1. **SPM / Dependencies**
   - Gibt es versteckte Packages (z.B. per Xcode UI hinzugefügt)? Scan zeigte kein `Package.resolved` und keine `XCRemoteSwiftPackageReference` im pbxproj.

2. **CloudKitRatingStore / CloudKitMovieNightStore Details**
   - RecordTypes, merge strategy, conflict resolution, routing correctness.

3. **ImageCacheStore Implementierung**
   - `SettingsView` referenziert `ImageCacheStore.shared` → Speicherort/Policy/Threading unbekannt.

4. **AppRefreshCoordinator Implementierung**
   - Throttle/Dedup Policy bei `.active` refresh unklar.

5. **Tests**
   - Keine offensichtliche Test Target Struktur im Scan (konkret: **UNKNOWN**).

---

## First 3 Refactors I would do (P0)

### P0.1 — Activity Feed aus dem Renderpfad raus (Cache/DTO)
- Ziel:
  - `ContentView` Recomputes billig machen; Activity Preview nicht jedes Mal über alle Movies/Ratings iterieren + sortieren.
- Betroffene Dateien:
  - `filmfreaks/Content/ContentView.swift`
  - `filmfreaks/MovieStore/MovieStore+Activity.swift`
  - optional neu: `filmfreaks/Content/ActivityPreviewModel.swift` (oder in `Content/` als StateObject)
- Risiko:
  - Niedrig (UI-only Ableitung; keine Datenmigration).
- Erwarteter Nutzen:
  - Spürbar flüssiger bei großen Gruppen; weniger CPU bei vielen kleinen State-Änderungen.

### P0.2 — `.active` Refresh Throttle/Dedup (weniger CloudKit „Sturm“)
- Ziel:
  - Weniger unnötige CloudKit fetches bei häufigem App-Wechseln; bessere Batterie/Netzwerk.
- Betroffene Dateien:
  - `filmfreaks/filmfreaksApp.swift`
  - `AppRefreshCoordinator` (Pfad **UNKNOWN**, aber Instanz existiert in App: `@StateObject private var appRefresh = AppRefreshCoordinator()`)
- Risiko:
  - Niedrig–Mittel (kann „stale data“ kurzfristig erhöhen, wenn Push/Subscriptions nicht zuverlässig sind).
- Erwarteter Nutzen:
  - Weniger Rate-Limit/Timeouts; stabilere UX, weniger „sync flicker“.

### P0.3 — Secrets Handling fix (TMDb API Key raus aus dem Repo)
- Ziel:
  - API Key nicht im Klartext committed; sauberer CI/Dev Flow.
- Betroffene Dateien:
  - `filmfreaks/Secrets.xcconfig`
  - `filmfreaks/Debug.xcconfig`
  - `filmfreaks/Release.xcconfig`
  - optional: `filmfreaks/Info.plist` (bleibt bei `$(TMDB_API_KEY)`)
- Risiko:
  - Niedrig (Build-Konfig Änderung).
- Erwarteter Nutzen:
  - Security + Release hygiene; weniger „oops, key leaked“.