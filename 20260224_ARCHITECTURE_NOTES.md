# ARCHITECTURE_NOTES.md — filmfreaks

Diese Datei ist die “tiefer rein”‑Doku: Hotspots, Tradeoffs, Risiken, Refactor‑Map.

---

## Big Files List (Top 15 nach Zeilen)
Quelle: `wc -l` über `filmfreaks/**/*.swift`.

| Lines | Pfad | Grober Zweck | Warum riskant / teuer |
|---:|---|---|---|
| 522 | `filmfreaks/SearchResultDetail/SearchResultDetailView.swift` | Search Result Detail Screen (Hero + Sections + Networking/State) | Große SwiftUI View mit vielen States/Tasks → hohes Risiko für Invalidations, schwer zu testen; Merge‑Konflikte. |
| 466 | `filmfreaks/Stats/StatsViewModel.swift` | Aggregation + Snapshot für Stats | Läuft auf `@MainActor`, viele vollständige Passes + Sorts → UI‑Stalls möglich bei großen Daten. |
| 455 | `filmfreaks/CloudKitGroupStore.swift` | Gruppenlisten, Zone‑Handling, Sharing, Subscriptions, Repair | Viele Verantwortlichkeiten in einem File; CloudKit Edge‑Cases + Lifecycle → Fehleranfällig. |
| 420 | `filmfreaks/MovieSearch/MovieSearchView.swift` | TMDb Search UI (Scanner/Recos/Pagination/Toast) | Viele UI‑States + Flows; leicht “spaghetti”; Risiko für Task‑Explosion/State races. |
| 412 | `filmfreaks/Content/ContentView.swift` | Root Screen + Orchestration | Zentraler Screen mit vielen Bindings/Triggers; Fehler wirken sich auf gesamte App aus. |
| 410 | `filmfreaks/MovieNights/Sheets/MovieNightDetailSheet.swift` | MovieNight Detail/Actions | Viel UI + Business logic; schwer “klein” zu halten; häufige Iterationen. |
| 396 | `filmfreaks/MovieStore/MovieStore+CloudSync.swift` | Cloud Fetch/Merge/ZoneChanges/Initial upload | Komplexe Logik (Merge, Routing, Guards) → Edge‑Cases + Regression‑Risiko. |
| 390 | `filmfreaks/MovieNights/MovieNightStore.swift` | MovieNight State + Persistence + sync | Cross‑cutting concerns; race conditions möglich. |
| 389 | `filmfreaks/UserStore.swift` | Members state + persistence + cloud | Group‑scoping + Cloud merges; Gefahr von UI/State Drift. |
| 369 | `filmfreaks/ViewingCustomGoal.swift` | Custom goal model + Codable | Viele Codable‑Migrationen; leicht breaking changes. |
| 366 | `filmfreaks/Movie.swift` | Movie + Rating model + Codable migration | Zentraler Domain‑Typ; Änderungen wirken überall; Migrationen/Decoding Risiken. |
| 363 | `filmfreaks/SettingsView.swift` | Settings Screen | Viel UI in einem File, aber eher niedrigeres Risiko als Sync. |
| 360 | `filmfreaks/GroupSettingsView.swift` | Group management UI + actions | CloudKit actions + UI in einer View; Fehler wirken direkt auf Sharing. |
| 355 | `filmfreaks/Stats/StatsView+Cards.Leaderboards.swift` | Leaderboards UI | UI‑Komplexität; weniger kritisch als Sync. |
| 345 | `filmfreaks/MovieDetail/MovieDetailView.swift` | Movie Detail Screen | Große View; kann Render‑Hotspot werden (Poster/Ratings/sections). |


---

## Hot Path Analyse

### Rendering / Scrolling
**1) Stats Snapshot Compute auf MainActor**
- Pfad: `filmfreaks/Stats/StatsViewModel.swift`
- Grund: `@MainActor final class StatsViewModel` + `snapshot = Self.computeSnapshot(...)` macht mehrere Passes, Set‑Builds, Sorts.
- Trigger: `filmfreaks/Stats/StatsView.swift` ruft `refreshStatsSnapshot()` in `.onAppear` und diversen `.onChange` auf.
- Risiko: Bei 300–1000 Movies kann ein “Filter togglen” / “Location wechseln” spürbar ruckeln.

**2) Derived List Building (filter/sort) pro Input‑Change**
- Pfad: `filmfreaks/Content/ContentMovieItemsModel.swift`
- Grund: `buildIndexedItems` macht `filter` + `sorted` über die gesamte Liste.
- Tradeoff: bewusst **aus** `body` ausgelagert → gut; aber dennoch MainActor‑Last bei häufigen Updates (Search typing, Filter toggles).

**3) Große SwiftUI Views als Merge‑Hotspot**
- Pfade: `ContentView.swift`, `MovieSearchView.swift`, `SearchResultDetailView.swift`, `MovieNightDetailSheet.swift`, `MovieDetailView.swift`
- Grund: viele `@State` + mehrere Sheets/Tasks in einem File → hoher Invalidations‑Footprint.

### Sync / Storage
**4) App resume refresh cascade**
- Pfad: `filmfreaks/filmfreaksApp.swift`
- Grund: `.onChange(scenePhase)` trigger: `groupStore.refresh()`, `movieNightStore.flushPendingCloudChanges()`, `movieStore.refreshFromCloud(...)`, `userStore.refreshFromCloud(...)`, `movieNightStore.refreshFromCloud(...)`.
- Positiv: `AppRefreshCoordinator` coalesced (`filmfreaks/AppRefreshCoordinator.swift`).
- Risiko: trotzdem relativ viel CloudKit‑Traffic beim häufigen App‑Switching (Share sheets etc.).

**5) CloudKitGroupStore.refresh: sequenzielles Zone‑Scannen**
- Pfad: `filmfreaks/CloudKitGroupStore.swift` (`fetchGroupContexts`)
- Grund: list zones → for each zone fetch root record (loop). Kein TaskGroup parallelism.
- Risiko: viele Gruppen → spürbar langsamer “Group list refresh”.

**6) MovieStore didSet Cost**
- Pfade: `filmfreaks/MovieStore/MovieStore.swift`, `filmfreaks/MovieStore/MovieStore+Persistence.swift`
- Grund: `oldValue == movies` / `oldValue == backlogMovies` ist Deep‑Equality über `[Movie]` (O(n)).
- Risiko: bei vielen Mutations/Batch updates (Cloud delta) kann unnötig kosten.

**7) Zone Change Tokens als UserDefaults**
- Pfad: `filmfreaks/CloudKitZoneChangeTokenStore.swift`
- Grund: Tokens per (namespace/scope/zone/owner) persistent.
- Edge: Tokens werden nicht offensichtlich gecleared, wenn man eine Gruppe verlässt oder Zone gelöscht wird.

### Concurrency
**8) View‑State Mutation in async functions ohne explizites MainActor**
- Pfad: `filmfreaks/MovieSearch/MovieSearchView+Search.swift`
- Grund: in `performSearch` werden `isLoading = true`, `errorMessage = nil` außerhalb `MainActor.run` gesetzt.
- Risiko: je nach Call‑Site/Thread kann das Concurrency‑Warnings/undefiniertes Verhalten erzeugen (SwiftUI erwartet Main thread).

**9) Task Explosion ohne Cancellation**
- Pfade: u.a. `MovieSearchView.swift`/`MovieSearchView+Search.swift`, `Goals/CustomGoals/CustomGoalEditorView.swift` (Tasks bei Text‑Änderungen), `ContentView.handlePushDeepLink` (Task ohne Cancellation).
- Grund: `Task { await ... }` wird häufig aus UI Events gestartet, ohne Task‑Handle zu speichern/abzubrechen.
- Risiko: mehrere in‑flight Requests → “out of order” State updates.

---

## Refactor Map

### A) Konkrete Splits (Datei → neue Dateien)

**Search Result Detail**
- Ist‑File: `filmfreaks/SearchResultDetail/SearchResultDetailView.swift` (522)
- Split Vorschlag:
  - `SearchResultDetailView.swift` (Host + Routing/State)
  - `SearchResultDetailHeroHeaderView.swift` (existiert schon)
  - `SearchResultDetailSections.swift` (composed sections)
  - `SearchResultDetail+Loading.swift` (loadDetails / reloadWatchProvidersOnly)
  - `SearchResultDetail+Actions.swift` (Add to watched/backlog, trailer open)

**CloudKitGroupStore**
- Ist‑File: `filmfreaks/CloudKitGroupStore.swift` (455)
- Split Vorschlag:
  - `CloudKitGroupStore.swift` (state + public API)
  - `CloudKitGroupStore+Refresh.swift` (refresh pipeline + iCloud status)
  - `CloudKitGroupStore+Groups.swift` (create/delete/leave)
  - `CloudKitGroupStore+Sharing.swift` (fetchOrCreateShare)
  - `CloudKitGroupStore+Repair.swift` (share hierarchy repair)
  - `CloudKitGroupStore+Zones.swift` (fetchAllZones, deleteZone helpers)

**MovieSearchView**
- Ist‑File: `filmfreaks/MovieSearch/MovieSearchView.swift` (420)
- Split Vorschlag:
  - `MovieSearchView.swift` (layout + routing)
  - `MovieSearchView+State.swift` (State grouping / derived props)
  - `MovieSearchView+Search.swift` (existiert)
  - `MovieSearchView+Recommendations.swift` (existiert)
  - `MovieSearchView+Scanner.swift` (existiert)
  - Neu: `MovieSearchTaskCoordinator.swift` (Cancellation/Debounce, siehe unten)

**Stats**
- Ist‑File: `filmfreaks/Stats/StatsViewModel.swift` (466)
- Split Vorschlag:
  - `StatsViewModel.swift` (public API + published snapshot)
  - `StatsSnapshotBuilder.swift` (pure functions / computeSnapshot)
  - Optional: `StatsSnapshotWorker.swift` (background Task/actor)


### B) Cache-/Index Ideen

**1) “Inputs hashing” statt Deep‑Equality**
- Problem: `[Movie] == [Movie]` ist teuer und wird z.B. in `MovieStore+Persistence` genutzt.
- Idee: statt `oldValue == movies`:
  - Version counter `moviesRevision += 1` in Mutations.
  - Oder stable checksum (z.B. rolling hash über `id` + `updatedAt`), falls vorhanden.
- Betroffene Files: `MovieStore/MovieStore.swift`, `MovieStore/MovieStore+Persistence.swift`.

**2) Stats incremental updates**
- Problem: `computeSnapshot` läuft full‑recompute.
- Idee:
  - Snapshot nach TimeRange/Location cachen.
  - Oder “pre‑aggregation” (movies grouped by month, genre, location) im Background und nur Filter anwenden.
- Betroffene Files: `Stats/StatsViewModel.swift`.

**3) CloudKitGroupStore: cached zone list**
- Problem: jedes refresh: fetch zones + root record fetch.
- Idee:
  - Cache zones for a short TTL (z.B. 5–10s), nur bei `.cloudKitShareAccepted` hart refresh.
- Betroffene Files: `CloudKitGroupStore.swift`.


### C) Vereinheitlichungen (Patterns)

**1) “Store surface + extension impl” als Standard**
- Im Projekt bereits gut genutzt (z.B. `CloudKitMovieStore` und `MovieStore`).
- Kandidaten für Adoption:
  - `UserStore.swift` (389)
  - `MovieNightStore.swift` (390)

**2) Logging**
- Today: Mix aus `print` und `Logger`.
- Vorschlag: ein `Logger` pro Subsystem/Category (z.B. `Logger(subsystem:"filmfreaks", category:"CloudKit.Movie")`).
- Betroffene Files: viele; Start bei `MovieStore+CloudSync.swift`, `CloudKitGroupStore.swift`, `CloudKitUserStore.swift`.

**3) “Cancelable Task” Pattern für Views**
- Introduce small helper:
  - store `@State private var searchTask: Task<Void, Never>?`.
  - on new request: cancel old, start new.
- Kandidaten: `MovieSearchView`, `CustomGoalEditorView`.

---

## Risiken & Edge Cases

### Datenverlust / Consistency
- **Ratings split**: Movies werden in Cloud ohne Ratings gespeichert (`CloudKitMovieStore+Modify.swift` und `CloudKitMovieStore+Schema.swift`), Ratings kommen separat.
  - Risiko: falsches Merge order / Delete handling könnte Ratings “verschwinden lassen” (App‑State, nicht Cloud).
  - Relevant: `MovieStore/MovieStore+CloudSync.swift` konserviert lokale Ratings und merged Cloud.

- **Group routing safety**: UUID‑like groupId ohne GroupContext wirft (`CloudKitRouting.swift`).
  - Positiv: verhindert “Public DB drift”.
  - Edge: wenn GroupContext persistiert/verfügbar zu spät → Refresh/Flush failt bis Notification `.groupContextDidUpsert` reinläuft.
  - Relevant: `MovieStore+CloudSync.setupGroupContextRetryHandling`.

### Offline / Multi‑Device
- Lokale Persistenz ist pro Gruppe gescoped (`PersistenceManager.fileURL(kind:groupId:)`).
- Writes sind debounced → bei Crash kurz nach UI‑Änderung können letzte 0.55s fehlen.
- Multi‑device conflict handling ist vorhanden (Movie save: 3‑way merge in `CloudKitMovieStore+Modify.swift`).

### Sharing / Permissions
- In Shared Zones können bestimmte Writes scheitern (z.B. Migration Writes in `CloudKitUserStore.fetchMembers`).
- Share hierarchy repair versucht parent references zu setzen (`CloudKitGroupStore.repairShareHierarchy`).

### Push Notifications
- `CloudKitShareAppDelegate.didReceiveRemoteNotification` ruft `CloudKitActivityPushFetchCoordinator.fetchAndLog`.
- `CloudKitActivityPushFetchCoordinator.fetchAndHandle` ist `#if DEBUG` gated → Release Build verarbeitet Pushes aktuell nicht.

---

## Observability / Debuggability

### Logging
- `PersistenceManager` nutzt `os.Logger` (`filmfreaks/PersistenceManager.swift`).
- CloudKit nutzt überwiegend `print` (z.B. `MovieStore+CloudSync.swift`, `CloudKitGroupStore.swift`).

### Tools im Projekt
- `CloudKit/CloudKitRemoteNotificationDebugger.swift`: debug logs für Push payload.
- `CloudKit/CloudKitActivityPushFetchCoordinator.swift`: debug fetch + local notifications (nur DEBUG).
- `Notifications/ActivityNotificationStateStore.swift` (falls vorhanden) deduped notifications.

### Repro‑Checklisten
**Cloud Group / Sharing**
- [ ] Create group (`GroupSettingsView` → “Neue Cloud‑Gruppe”).
- [ ] Share group (Menu “Gruppe teilen”).
- [ ] Accept share on second device (`CloudKitShareCoordinator` toasts).
- [ ] Verify routing (movies created on owner appear on participant).

**Zone Changes**
- [ ] In shared group: add movie on device A.
- [ ] Device B foreground → `MovieStore.loadFromCloud` takes zone changes path.
- [ ] Verify token persistence: subsequent refresh should be incremental.

---

## Open Questions (UNKNOWN)
1) **Deployment target 26.0**: ist das beabsichtigt (iOS 26) oder ein Placeholder? (`project.pbxproj`).
2) **Release push behavior**: sollen Group Activity notifications in Release aktiv sein? Aktuell Debug‑only (`CloudKitActivityPushFetchCoordinator`).
3) **Token cleanup strategy**: sollen ZoneChangeTokens beim Verlassen/Löschen einer Gruppe gecleared werden? (keine explizite Clear‑Stelle gefunden).
4) **CloudKit schema guarantees**: welche RecordTypes/Indexes sind in Production wirklich deployed (Movie, MovieRating, GroupMember, FFGroup, …)?
5) **Test coverage**: Targets existieren, aber keine Tests. Welche Hotspots sollen durch Tests abgesichert werden?

---

## First 3 Refactors I would do (P0)

### P0.1 — MovieSearch: Cancellation + MainActor‑Sauberkeit
- **Ziel**: Keine parallel laufenden Searches/Loads; state updates garantiert auf Main thread; weniger “out of order” UI.
- **Betroffene Dateien**:
  - `filmfreaks/MovieSearch/MovieSearchView.swift`
  - `filmfreaks/MovieSearch/MovieSearchView+Search.swift`
  - ggf. `filmfreaks/MovieSearch/MovieSearchView+Recommendations.swift`
- **Risiko**: niedrig‑mittel (UI state flow; aber lokal begrenzt auf Search).
- **Erwarteter Nutzen**: spürbar stabilere Suche (kein Flackern), weniger unnötige TMDb Calls, weniger Concurrency‑Warnings.

### P0.2 — Stats Snapshot off‑main (Background compute + publish)
- **Ziel**: UI‑Stalls vermeiden, wenn Stats recompute getriggert wird.
- **Betroffene Dateien**:
  - `filmfreaks/Stats/StatsViewModel.swift`
  - optional neue Datei: `filmfreaks/Stats/StatsSnapshotWorker.swift`
- **Risiko**: mittel (Threading/Consistency; muss deterministisch bleiben).
- **Erwarteter Nutzen**: deutlich smoother Stats UI bei größeren Movie‑Listen; geringere MainActor contention.

### P0.3 — CloudKitGroupStore split + refresh parallelism
- **Ziel**: Responsibilities trennen + schnellere group refreshes (zones/root record fetch parallel).
- **Betroffene Dateien**:
  - `filmfreaks/CloudKitGroupStore.swift` (split in `+Refresh/+Sharing/+Repair/+Zones`)
- **Risiko**: niedrig‑mittel (CloudKit edge cases; aber behavior kann unverändert bleiben).
- **Erwarteter Nutzen**: bessere Wartbarkeit, weniger Merge‑Konflikte, schnellere “Gruppenliste” bei vielen Gruppen.
