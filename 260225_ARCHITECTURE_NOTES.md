# ARCHITECTURE_NOTES

Last updated: 2026-02-25

## Scope & Method

- Basis: statischer Code‑Scan des ZIP‑Inhalts (Dateien/Zeilen, einfache Pattern‑Suche, manuelles Lesen der wichtigsten Stores/Views).
- Keine Laufzeit‑Messungen/Instrumente in diesem Schritt → Alles, was echte Runtime‑Beweise bräuchte, ist als **UNKNOWN** in „Open Questions“ gelistet.

---

## Big Files List (Top 15 nach Zeilen)

| # | Datei | Zeilen | Grober Zweck | Warum riskant |
|---:|---|---:|---|---|
| 1 | `filmfreaks/MovieSearch/MovieSearchView.swift` | 434 | Movie Search Host UI + State | Große SwiftUI View → Compile‑Zeit + Merge‑Konflikte + Render‑Hotspots |
| 2 | `filmfreaks/Content/ContentView.swift` | 424 | Home: Header + List/Grid + Routing | Große SwiftUI View → Compile‑Zeit + Merge‑Konflikte + Render‑Hotspots |
| 3 | `filmfreaks/MovieNights/MovieNightStore.swift` | 398 | MovieNight State + Actions + Cloud hooks | State+Sync gemischt → MainActor contention + Hard‑to‑test |
| 4 | `filmfreaks/MovieStore/MovieStore+CloudSync.swift` | 396 | MovieStore Cloud refresh + diff + initial upload | State+Sync gemischt → MainActor contention + Hard‑to‑test |
| 5 | `filmfreaks/UserStore.swift` | 389 | Users State + Selection + persistence + cloud sync | State+Sync gemischt → MainActor contention + Hard‑to‑test |
| 6 | `filmfreaks/ViewingCustomGoal.swift` | 369 | Custom goal model + evaluation helpers | Große SwiftUI View → Compile‑Zeit + Merge‑Konflikte + Render‑Hotspots |
| 7 | `filmfreaks/Movie.swift` | 366 | Core domain model + migrations | Model + Migration → Datenkompatibilität |
| 8 | `filmfreaks/Stats/StatsSnapshotBuilder.swift` | 363 | Off‑main stats aggregation | Wartbarkeit/Refactor‑Schmerz |
| 9 | `filmfreaks/SettingsView.swift` | 363 | Settings UI (Appearance/Support/…)  | Große SwiftUI View → Compile‑Zeit + Merge‑Konflikte + Render‑Hotspots |
| 10 | `filmfreaks/GroupSettingsView.swift` | 360 | Group settings + sharing management | Große SwiftUI View → Compile‑Zeit + Merge‑Konflikte + Render‑Hotspots |
| 11 | `filmfreaks/Stats/StatsView+Cards.Leaderboards.swift` | 355 | Stats UI (Genres/Actors/… leaderboards) | UI‑Komplexität + viele Derived Values → Recompute/Invalidation‑Risiko |
| 12 | `filmfreaks/MovieDetail/MovieDetailView.swift` | 345 | Movie detail screen (sections + sheets) | Große SwiftUI View → Compile‑Zeit + Merge‑Konflikte + Render‑Hotspots |
| 13 | `filmfreaks/CloudKitUserStore.swift` | 335 | CloudKit GroupMember operations | State+Sync gemischt → MainActor contention + Hard‑to‑test |
| 14 | `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift` | 333 | MovieNight Cloud batching | Nebenläufigkeit + Cancellation + Correctness |
| 15 | `filmfreaks/CloudKitMovieStore/CloudKitMovieStore+Modify.swift` | 332 | CloudKit movie record writes | State+Sync gemischt → MainActor contention + Hard‑to‑test |

---

## Hot Path Analyse

### Rendering / Scrolling (SwiftUI)

#### 1) Sort/Filter im Renderpfad (konkret gefunden)

- `filmfreaks/MovieNights/Sheets/ProposeMovieNightSheet.swift`
  - line ~160: `movieStore.backlogMovies.filter { ... }`
  - line ~171: `backlogMovies.sorted { ... }`
  - **Warum Hotspot**: Filter + Sort auf potentiell großem Backlog passieren im `body` → jede View‑Invalidation kann O(n log n) Arbeit auslösen.

- `filmfreaks/WatchProvidersAvailabilityView.swift`
  - line ~93: `providers.sorted { ... }`
  - **Warum Hotspot**: Sort im `body`; vermutlich kleineres Array, aber Pattern ist prinzipiell riskant.

- `filmfreaks/Goals/GoalsView.swift`
  - line ~163: `Array(Set(...)).sorted(...)`
  - **Warum Hotspot**: klein, aber wird im Renderpfad neu gebaut; lohnt sich zu „derived state“ zu ziehen, wenn GoalsView häufig invalidiert.

- `filmfreaks/Goals/CustomGoals/CustomGoalEditorSection.Person.swift`
  - line ~181: `personResults.filter { ... }`
  - **Warum Hotspot**: Filter im Renderpfad; bei großen Result‑Listen kann das spürbar werden.

- `filmfreaks/GroupShareSheetView.swift`
  - line ~68: `share.participants.filter { ... }`
  - **Warum Hotspot**: vermutlich klein, aber Render‑Compute; kann in eine derived property ausgelagert werden.

#### 2) Aggregationen in Sheets (nicht im Body, aber trotzdem UI‑kritisch)

- `filmfreaks/Stats/StatsView+Actors.swift`
  - `moviesForSelectedActor` filtert `filteredMovies` jedes Mal, wenn die Property abgefragt wird.
  - **Warum Hotspot**: beim Öffnen/Redraw des Actor‑Sheets ist das eine O(n) Filterung; je nach Movie‑Count kann das beim Sheet‑Aufpoppen ruckeln.

#### 3) Gute Beispiele (bereits entschärft)

- `filmfreaks/Stats/StatsViewModel.swift`
  - `update(...)` debounced + `Task.detached` → Snapshot compute off‑main (siehe `StatsSnapshotBuilder`).
  - **Warum gut**: verhindert UI‑Hitches, wenn mehrere `.onChange` kurz hintereinander feuern (`StatsView.swift`).

- `filmfreaks/Content/ContentView.swift`
  - Derived List/Grid Items über `@StateObject ContentMovieItemsModel` (Kommentar im Code: „off render path“).

### Sync / Storage (CloudKit + Local Disk)

#### 1) MainActor contention durch Diff‑Berechnung im didSet

- `filmfreaks/MovieStore/MovieStore+CloudSync.swift` → `enqueueCloudSync(newList:oldList:isBacklog:)`
  - baut `Dictionary(uniqueKeysWithValues:)` für alt/neu + `Set` diff + `filter` über `newList` (line ~311–325).
  - **Warum Hotspot**: läuft auf dem MainActor im didSet‑Pfad von `@Published movies/backlog` (`MovieStore+Persistence.swift`). Bei großen Listen kann das bei jeder Änderung (z.B. Edit in Movie‑Meta) merkbar hitchen.

#### 2) Disk Writes sind ok, aber Trigger‑Frequenz im Blick behalten

- `filmfreaks/PersistenceManager.swift`
  - Writes laufen auf Utility‑Queue + debounced + `.atomic` → gut.
  - **Risk**: sehr viele schnelle Mutationen am Array können trotzdem viel JSON‑Encode Arbeit erzeugen (auch wenn debounced).

#### 3) Push Fetch ist Debug‑only (Correctness‑Hotspot)

- `filmfreaks/CloudKit/CloudKitActivityPushFetchCoordinator.swift`
  - `fetchAndHandle` ist in `#if DEBUG` implementiert; im Release `return false` (line ~65–67).
  - **Warum Hotspot**: App hat `UIBackgroundModes = remote-notification` (`Info.plist`) und AppDelegate ruft fetch auf — aber im Release passiert faktisch nichts. Entweder bewusst (dann dokumentieren), oder Bug/TODO.

### Concurrency (Tasks, Cancellation, Thread Safety)

#### 1) User‑getriggerte Tasks ohne Cancellation

- `filmfreaks/Stats/StatsView+Actors.swift`
  - `actorChipTapped` startet `Task { ... fetchPersonDetails ... }` pro Tap, ohne vorherigen Task abzubrechen.
  - **Risiko**: mehrere in‑flight Requests → out‑of‑order UI‑Updates („ältere Antwort überschreibt neuere“).

- `filmfreaks/MovieSearch/MovieSearchView.swift`
  - `.onChange` (query/focus) startet `Task { await loadRecommendationsIfNeeded() }` zusätzlich zum `.task { ... }`.
  - **Mitigation im Code**: `loadRecommendationsIfNeeded` hat Guards (`isLoadingRecommendations`, `results.isEmpty`, …) → minimiert Doppelarbeit, aber Task‑Lifetime bleibt verteilt.

#### 2) Debounce Tasks in Coordinators (gut, aber braucht harte Invariants)

- `filmfreaks/MovieCloudSyncCoordinator.swift`
  - `scheduledFlush: Task<Void, Never>?` + `pendingSaves/pendingDeletes` Dicts.
  - **Risiko**: stateful Debounce + in‑flight flush → muss strikt sicherstellen, dass „neuere Version“ Tokens sauber gehandhabt werden (siehe `PendingSave.token`).

---

## Refactor Map

### Konkrete Splits (mechanisch, wenig Risiko)

- `filmfreaks/UserStore.swift` (~389 Zeilen)
  - Cut (Vorschlag):
    - `UserStore.swift` (Facade + Published State)
    - `UserStore+Persistence.swift` (load/save + defaults keys)
    - `UserStore+CloudSync.swift` (refresh/merge/flush, CloudKitUserStore usage)
    - `UserStore+Selection.swift` (selected user + per-group selection store)
  - Nutzen: weniger Merge‑Konflikte, klarere Verantwortlichkeiten, gezielteres Testen.

- `filmfreaks/SettingsView.swift` (~363 Zeilen)
  - Cut (Vorschlag):
    - `SettingsView.swift` (Host + sections composition)
    - `SettingsView+Appearance.swift`
    - `SettingsView+WatchProviders.swift`
    - `SettingsView+About.swift` (ggf. vorhandene `SettingsAboutSectionView.swift` weiterverwenden)

- `filmfreaks/GroupSettingsView.swift` (~360 Zeilen)
  - Cut (Vorschlag):
    - `GroupSettingsView.swift` (Host)
    - `GroupSettingsView+Members.swift`
    - `GroupSettingsView+Sharing.swift`
    - `GroupSettingsView+Diagnostics.swift`

### Cache-/Index-Ideen (Performance)

- **MovieStore Diffing**
  - Problem: O(n) Dict/Set Arbeit im didSet (MainActor).
  - Idee A (niedrig–mittel): Diff‑Vorbereitung off‑main (Snapshot) und nur `coordinator.queue...` auf MainActor anwenden.
  - Idee B (mittel): mutierende Aktionen zentralisieren (statt „Array direkt mutieren“), so dass die Aktion bereits weiß, welche IDs sich geändert haben (incremental).

- **Actor drilldown** (`StatsView+Actors.moviesForSelectedActor`)
  - Idee: in `StatsSnapshotBuilder.computeSnapshot` zusätzlich einen Index `moviesByPersonId: [Int: [UUID]]` (oder direkt `[Int: [Movie]]` wenn vertretbar) bauen.
  - Benefit: Actor‑Sheet öffnet ohne O(n) Filter.
  - Risiko: mehr Speicher; muss mit TimeRange/Location Filter konsistent sein.

- **ProposeMovieNightSheet** (Backlog Filter+Sort im Body)
  - Idee: `@StateObject` kleines ViewModel/Derived‑Cache (ähnlich `ContentMovieItemsModel`), Task/Signature‑based recompute nur bei relevanten Inputs.

### Vereinheitlichungen (Patterns/Services/DI)

- **CloudKit routing & „context ready“ retry**
  - Mehrere Stores haben GroupContext‑Retry Logic (`MovieStore`, `MovieNightStore`).
  - Vorschlag: gemeinsamer Helper (z.B. `GroupContextAvailabilityMonitor`) der ein AsyncStream/Publisher für „groupId became routable“ bietet.

- **Logging**
  - `print(...)` in Cloud/Pipeline durch `os.Logger` ersetzen (Categories: `CloudKit`, `Sync`, `Push`, `TMDb`).

---

## Risiken & Edge Cases

- **Konfliktauflösung**
  - Movies: `CloudKitMovieStore+Merge.swift` nutzt „server wins“ bei echten Konflikten.
  - Risiko: lokale Änderungen können verloren gehen, wenn parallel geändert wird. (Bewusst? Dann dokumentieren.)

- **Offline + Pending Queue**
  - Pending counts pro Gruppe werden in UserDefaults persistiert (z.B. `MovieStore+Persistence.swift`).
  - Risiko: wenn groupId wechselt, muss UI die korrekten pending counts anzeigen (es gibt `groupKey` helpers).

- **GroupId Heuristik** (`CloudKitRouting.requiresGroupContext`)
  - UUID‑ähnliche groupIds werden als Sharing/Zone behandelt.
  - Risiko: ein „legacy/public“ groupId, der zufällig UUID‑Format hat, würde Routing blockieren (dann `groupContextNotReady`).

- **Push handling in Release**
  - Wenn Activity‑Pushes ein Produktfeature sind: Release‑Build muss `fetchAndHandle` aktivieren + Notification permission flows sauber behandeln.

---

## Observability / Debuggability

- Persistence logging: `filmfreaks/PersistenceManager.swift` nutzt `os.Logger(subsystem: "filmfreaks", category: "Persistence")`.
- Push debugging: `filmfreaks/CloudKit/CloudKitRemoteNotificationDebugger.swift` loggt userInfo (DEBUG).
- Empfehlung:
  - Pro Store/Feature einen Logger (z.B. `Logger(subsystem: "filmfreaks", category: "CloudKitMovie")`).
  - Einen „Diagnostics“ Screen/Section (evtl. in `GroupSettingsView`) mit:
    - Current groupId + scope + zoneName
    - pending queue sizes
    - last sync timestamps/errors
    - push subscription IDs (read-only)

---


## CloudKit Schema & Routing Details (konkret aus Code)

### Routing‑Regeln

- Datei: `filmfreaks/CloudKitRouting.swift`
  - `normalizedGroupId(_:)`: trim + empty → nil.
  - `requiresGroupContext(for:)`: UUID‑Format → Sharing/Zone Gruppe.
  - `route(container:groupId:)`:
    - nil → Public DB, keine Zone
    - GroupContext vorhanden → Private/Shared DB + ZoneID(zoneName, ownerName)
    - UUID‑ähnlich aber kein GroupContext → **throw** `groupContextNotReady` (kein Public‑Fallback).

### Persistierte Routing‑Metadaten

- Datei: `filmfreaks/GroupContext.swift`
  - `GroupContextStore` persistiert `[groupId -> GroupContext]` als JSON Data in UserDefaults.
  - Notifications: `.groupContextDidUpsert` / `.groupContextDidRemove` (können für Retry‑Flows genutzt werden).

### ZoneChange Tokens (inkrementeller Sync)

- Datei: `filmfreaks/CloudKitZoneChangeTokenStore.swift`
  - Persistiert `CKServerChangeToken` pro (namespace, scope, zoneName, ownerName) in UserDefaults.
  - Zweck: `CKFetchRecordZoneChangesOperation` inkrementell statt „full query“.

### Record Types & „Keys“ (Auszug)

- `Movie` Records: `filmfreaks/CloudKitMovieStore/CloudKitMovieStore.swift`
  - keys: `payload` (Data), `isBacklog` (Bool), `updatedAt` (Date), `groupId` (String).
- `MovieRating` Records: `filmfreaks/CloudKitRatingStore/CloudKitRatingStore+Schema.swift`
  - keys: `payload` (Data), `movieId` (String UUID), `groupId` (String), `reviewerId` (String UUID), `reviewerName` (String), `updatedAt` (Date).
- `ViewingGoal` / `ViewingCustomGoals`: `filmfreaks/CloudKitGoalStore.swift`
  - `ViewingGoal`: keys `groupId`, `year`, `target`, `updatedAt`.
  - `ViewingCustomGoals`: key `payload` (versionierter JSON).
- Movie Nights:
  - Record Types: `MovieNightEvent`, `MovieNightResponse`, `MovieNightActivity` (`filmfreaks/CloudKitMovieNightStore/*`).

## App Resume Refresh Pipeline

- Entry: `filmfreaks/filmfreaksApp.swift` `.onChange(of: scenePhase)` wenn `.active`
  - action wrapped via `AppRefreshCoordinator.triggerRefresh` (`filmfreaks/AppRefreshCoordinator.swift`).
- Cascade (in Reihenfolge):
  1) `groupStore.refresh()` (owned/shared groups + subscriptions)
  2) `movieNightStore.flushPendingCloudChanges()` (verhindert „public fallback“ bevor GroupContexts da sind)
  3) `movieStore.refreshFromCloud(force: false)`
  4) `userStore.refreshFromCloud(force: false)`
  5) `movieNightStore.refreshFromCloud(groupId: movieStore.currentGroupId, force: false)`
- Gut: `AppRefreshCoordinator` coalesced rapid `.active` toggles + verhindert parallele Refreshes.
- Risiko: Wenn eine der Refresh‑Stufen lange blockiert (CloudKit latency), hängt die ganze Cascade an einem „inFlight“. (Ob das UX‑Problem ist, ist **UNKNOWN** ohne Runtime‑Messung.)
## Open Questions

- **UNKNOWN**: Wie genau sehen die CloudKit Dashboard‑Indizes/Query‑Constraints aus (z.B. für `groupIdKey`)? Code nennt Felder, aber Dashboard‑Konfiguration ist nicht im Repo.
- **UNKNOWN**: Ist „Push fetch“ absichtlich nur Debug? Wenn nein: welcher minimale Production‑Use‑Case (nur fetch+log vs fetch+local notification)?
- **UNKNOWN**: Welche Daten gelten als „source of truth“ bei Konflikten (server wins ist implementiert, aber sind User‑Flows darauf abgestimmt)?
- **UNKNOWN**: Gibt es automatisierte Tests/Fixtures für CloudKit Merge/Payload Migration (`Movie.swift` Migration path)?

---

## First 3 Refactors I would do (P0)

### P0.1 — MovieStore Cloud‑Diff aus dem MainActor‑didSet ziehen
- **Ziel**: UI‑Hitches vermeiden, wenn große Movie‑Arrays geändert werden.
- **Betroffene Dateien**:
  - `filmfreaks/MovieStore/MovieStore+CloudSync.swift` (enqueueCloudSync)
  - `filmfreaks/MovieStore/MovieStore+Persistence.swift` (didSet hooks)
  - optional: `filmfreaks/MovieCloudSyncCoordinator.swift` (API ggf. erweitern)
- **Risiko**: mittel (Sync‑Correctness, Race Conditions bei schnellen Mutationen).
- **Erwarteter Nutzen**: spürbar bei großen Listen; weniger MainActor contention; besseres Scroll/Editing‑Feeling.

### P0.2 — Cancellable TMDb Requests (Search + Actor Sheet)
- **Ziel**: „latest request wins“ + weniger Netz/CPU; keine out‑of‑order UI‑Updates.
- **Betroffene Dateien**:
  - `filmfreaks/Stats/StatsView+Actors.swift`
  - `filmfreaks/MovieSearch/MovieSearchView+Search.swift` (und ggf. `+Recommendations.swift`)
  - optional: kleiner `TaskBox`/Helper (neue Datei, z.B. `filmfreaks/Concurrency/CancelableTask.swift`).
- **Risiko**: niedrig.
- **Erwarteter Nutzen**: stabileres UI bei schnellem Tippen/Tappen; weniger „Ghost updates“.

### P0.3 — Push Fetch Strategie festzurren (Debug‑only vs Production)
- **Ziel**: Klarheit + ggf. Feature‑Funktionalität in Release herstellen.
- **Betroffene Dateien**:
  - `filmfreaks/CloudKitShareAppDelegate.swift` (Remote notification entry)
  - `filmfreaks/CloudKit/CloudKitActivityPushFetchCoordinator.swift` (`#if DEBUG` block)
  - `filmfreaks/Notifications/*` (Permissions/Local notifications, falls Production)
- **Risiko**: niedrig–mittel (Background execution quirks, Notification permissions, CloudKit quotas).
- **Erwarteter Nutzen**: korrekte/erwartete Activity‑Updates; weniger „warum passiert nichts in Release?“‑Überraschungen.
