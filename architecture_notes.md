
---

```markdown
# ARCHITECTURE_NOTES.md

## Big Files List (Top 15 nach Zeilen)
> Quelle: Lines grob aus Codebestand (Swift). Risiko = Änderungsfläche + Seiteneffekte + Wiederverwendung.

1. `MovieStore.swift` (~864)
   - Zweck: Zentrale Movie-Quelle + Persistenz + Cloud Sync Koordination + Ratings Merge + Group Switching.
   - Risiko: Viele Responsibilities, hohe Kopplung zu CloudKit/Persistence/UI-Sync.

2. `CloudKitMovieStore.swift` (~720)
   - Zweck: CloudKit CRUD + Routing (public vs zone) + Zone Changes + Batch modify.
   - Risiko: Komplexe Sync-Pfade, Fehler schwer reproduzierbar, Token/Zone-Edge-Cases.

3. `DisplaySettings.swift` (~599)
   - Zweck: UI Theme/Density/Appearance Presets, AppStorage, Metrics.
   - Risiko: Viele UI-Entscheidungen zentral; Änderungen wirken app-weit.

4. `TMDbAPI.swift` (~592)
   - Zweck: Alle TMDb Models + Endpoints + Decoding.
   - Risiko: API-Wachstum, fehlende Separation (Models vs Client), Testbarkeit.

5. `Goals/CustomGoalEditorView.swift` (~546)
   - Zweck: Custom Goal Editor (viel UI + Rule Handling).
   - Risiko: UI-Logik + Domain-Logik vermischt, schwer wartbar.

6. `SearchResultDetail/SearchResultDetailView.swift` (~523)
   - Zweck: Detail für Suchresultat inkl. Trailer/Watch Providers/Add-to-list.
   - Risiko: Viele States/Tasks, potenziell racey.

7. `CloudKitRatingStore.swift` (~509)
   - Zweck: Ratings separat syncen (RecordName Strategy, stability, fetch).
   - Risiko: Identity/RecordName muss konsistent bleiben; Migration/Legacy.

8. `TimelineView.swift` (~502)
   - Zweck: Timeline UI (wahrscheinlich Gruppierung/Sorting/Poster).
   - Risiko: Rendering/Scroll Hotspot je nach Datenmenge.

9. `CloudKitGroupStore.swift` (~446)
   - Zweck: Gruppen (owned/shared) listen/erstellen, Sharing, Repair.
   - Risiko: Sharing-Edge-Cases (AccountStatus, share acceptance, repair loops).

10. `Stats/StatsView+Calculations.swift` (~430)
    - Zweck: Aggregationen/Filter/Derivations für Stats.
    - Risiko: Wird im Renderpfad oft neu berechnet; perf-sensitiv.

11. `MovieSearch/MovieSearchView.swift` (~421)
    - Zweck: Suche + Empfehlungen + Query History + Navigation in Detail.
    - Risiko: Network-Task Lifecycle, Debounce, UI-State Explosion.

12. `ViewingCustomGoal.swift` (~370)
    - Zweck: Custom Goal Model + Codable Rule Varianten.
    - Risiko: Backward-compatibility bei Codable Änderungen.

13. `Movie.swift` (~367)
    - Zweck: Core Model + Migration (Codable), Ratings, Cast/Directors.
    - Risiko: Schemaänderungen betreffen Persistenz + Cloud Payload.

14. `SettingsView.swift` (~362)
    - Zweck: Einstellungen UI inkl. Cache/Appearance/Infos.
    - Risiko: Viele Toggles/Side Effects; schnell “God View”.

15. `GroupSettingsView.swift` (~359)
    - Zweck: Gruppenverwaltung UI (create/share/select/leave?).
    - Risiko: Share UX + Routing + CloudKit Abhängigkeiten.

---

## Hot Path Analyse

### Rendering / Scrolling

#### 1) Sort/Filter im Renderpfad (Listen)
- Dateien:
  - `Content/ContentView+MovieItems.swift`
- Konkreter Grund:
  - `buildIndexedItems(from:isBacklog:)` macht `enumerated().filter(...).sorted(...)` und mappt zu `IndexedMovie`.
  - Diese Derivations hängen an `selectedSort`, Search-Text, User-Filter, Mode – und werden bei jeder View-Invalidation neu evaluiert.
- Symptome:
  - Bei großen Listen: UI janky beim Tippen in Search, beim Umschalten von Sort/Filter oder wenn `MovieStore.movies` häufig updated wird.

#### 2) Stats: Wiederholte Aggregationen als computed properties
- Dateien:
  - `Stats/StatsView+Calculations.swift`
- Konkreter Grund:
  - computed properties wie `moviesForCurrentTimeRange`, `filteredMovies`, `availableLocations` laufen über `movieStore.movies` und werden potentiell mehrfach pro Renderpass abgefragt.
  - Kein Memoization/Cache zwischen Cards/Sections.
- Risiko:
  - Stats-View wird bei jedem State Change teurer, skaliert linear mit Movie-Anzahl.

#### 3) Binding auf Array-Index + “struct Movie” Updates
- Dateien:
  - `Content/ContentMoviesListSection.swift` (NavigationLink → `MovieDetailView(movie: $movies[item.index])`)
  - `MovieDetail/MovieDetailView.swift` (+ Extensions)
  - `MovieStore.swift` (`@Published var movies` didSet)
- Konkreter Grund:
  - Detail-View mutiert `Movie` (Struct) über Binding → triggert Array-Replace → `MovieStore.movies` didSet.
  - didSet startet Persistenz + queued Cloud Sync (debounced, aber dennoch frequent).
- Outcome:
  - Viele kleine Änderungen (z.B. Location tippen, Rating ändern) können zu häufigen “whole array” Updates führen.

#### 4) Images: Doppel-Caching + Disk IO im kritischen Pfad
- Dateien:
  - `filmfreaksApp.swift` (global `URLCache.shared` set)
  - `CachedAsyncImage.swift` (eigener Disk+Memory Cache via `ImageCacheStore` actor)
- Konkreter Grund:
  - HTTP Cache + eigener Disk Cache = potentiell redundante Speicherung.
  - Disk reads sind synchron (z.B. `Data(contentsOf:)`) – zwar im Actor, aber trotzdem blocking IO.
- Risiko:
  - Bei schnellen Scrolls: IO contention, Memory Pressure.

---

### Sync / Storage

#### 1) CloudKit: Multi-Pfad Routing (Legacy Public vs Zone Sharing)
- Dateien:
  - `CloudKitMovieStore.swift`, `CloudKitRatingStore.swift`, `CloudKitUserStore.swift`, `CloudKitGoalStore.swift`
  - `GroupContext.swift` (`GroupContextStore`)
- Konkreter Grund:
  - Wenn kein `GroupContext` vorhanden (oder groupId leer): Public DB ohne Zone.
  - Mit Kontext: private/shared DB + Zone.
- Risiko:
  - Drift: Falls `GroupContextStore` nicht sauber aktualisiert ist, liest/schreibt man in den falschen Scope.

#### 2) Inkrementelle Zone Changes + Token Persistenz
- Dateien:
  - `CloudKitZoneChanges.swift` (Wrapper um `CKFetchRecordZoneChangesOperation`)
  - `CloudKitZoneChangeTokenStore.swift`
  - `CloudKitMovieStore.swift` (nutzt fetchMovieChanges)
- Konkreter Grund:
  - ChangeTokens in UserDefaults; Korruption/Schemawechsel → kompletter Re-Sync nötig.
- Edge Cases:
  - Token invalid (Zone reset, share changes) → muss erkannt/cleared werden (**Handling im Detail: UNKNOWN**, abhängig vom Error-Handling in Stores).

#### 3) Refresh Trigger: App wird aktiv → Cloud Pull
- Dateien:
  - `filmfreaksApp.swift`
- Konkreter Grund:
  - `.onChange(of: scenePhase)` bei `.active` startet Task mit `groupStore.refresh()`, `movieStore.refreshFromCloud()`, `userStore.refreshFromCloud()`.
  - Kommentar sagt explizit: “Ohne Subscriptions ist das der einfachste Weg…”
- Risiko:
  - Parallelität/Overfetch bei häufigem Background/Foreground.
  - Throttle existiert in `MovieStore.swift` (`minRefreshInterval = 8`), aber nicht zwingend für alle Stores identisch.

#### 4) Cloud Writes: Debounced/Batched Coordinator (gut, aber zentral)
- Dateien:
  - `MovieCloudSyncCoordinator.swift`
  - `MovieStore.swift` (enqueueCloudSync, pending counts)
- Konkreter Grund:
  - Pending Saves/Deletes, scheduled flush Task, “flush on reconnect” via `NetworkMonitor`.
- Risiko:
  - Koordinator lebt auf MainActor (bewusst) → bei großem pending backlog könnte MainActor belastet werden.

#### 5) Local persistence: Debounced JSON, Group-scoped
- Dateien:
  - `PersistenceManager.swift`
- Konkreter Grund:
  - Jede Änderung am Movies/Backlog/Users Array kann einen debounced write triggern.
- Tradeoff:
  - Einfach und robust, aber speichert meist ganze Arrays (nicht incremental).

---

### Concurrency

#### 1) Unbounded Tasks aus View-Lifecycle
- Dateien:
  - `MovieDetail/MovieDetailView+Lifecycle.swift` (`Task { await loadDetails() }`, `reloadWatchProvidersOnly`)
  - `SearchResultDetail/SearchResultDetailView.swift` (Detail-Ladepfade: **konkret vorhanden, aber hier nicht vollständig zitiert**)
  - `filmfreaksApp.swift` (scenePhase Task)
- Konkreter Grund:
  - `Task { ... }` ohne gespeicherten Handle → keine explizite Cancellation bei `onDisappear` oder Route-Wechsel.
- Risiko:
  - “Stale updates”: Task beendet später und schreibt State in eine View, die nicht mehr sichtbar ist (SwiftUI schützt teils, aber nicht komplett).
  - Doppel-Requests.

#### 2) MainActor contention in zentralen Stores
- Dateien:
  - `MovieStore.swift` (`@MainActor`)
  - `UserStore.swift` (`@MainActor`)
- Konkreter Grund:
  - Große Operationen (Merge/Map/Sort) laufen potentiell auf MainActor, wenn nicht explizit offloaded.
- Risiko:
  - UI stalls bei großen Datenmengen.

#### 3) Actor für Image Cache (positiv), aber IO blocking
- Dateien:
  - `CachedAsyncImage.swift` (`actor ImageCacheStore`)
- Konkreter Grund:
  - IO im Actor ist seriell; das verhindert Data Races, aber kann Durchsatz limitieren.
- Risiko:
  - Viele gleichzeitige Image-Loads → Warteschlange.

---

## Refactor Map

### Konkrete Splits (Datei → neue Dateien)

#### A) `MovieStore.swift`
Ziel: klare Verantwortlichkeiten, weniger “God Store”.
Vorschlag:
- `MovieStore+LocalPersistence.swift`
  - Laden/Speichern via `PersistenceManager`
- `MovieStore+CloudRefresh.swift`
  - `loadFromCloud`, `refreshFromCloud`, group switch discard
- `MovieStore+Ratings.swift`
  - `upsertRating`, merge helpers, reviewerKey/stable id bridging
- `MovieStore+SyncMeta.swift`
  - pending count, last sync, error persistence (UserDefaults keys)

Risiko: mittel (viele cross-calls).
Nutzen: deutlich höhere Wartbarkeit + testbarer.

#### B) `CloudKitMovieStore.swift`
Ziel: CloudKit-Komplexität isolieren.
Vorschlag:
- `CloudKitMovieStore+Routing.swift` (db/zone selection, context lookup)
- `CloudKitMovieStore+ZoneChanges.swift` (fetchMovieChanges, token handling)
- `CloudKitMovieStore+Queries.swift` (Legacy public query fetch)
- `CloudKitMovieStore+Modify.swift` (batch modify, record encode/decode)

Risiko: mittel.
Nutzen: weniger Fehlerfläche pro Change.

#### C) `TMDbAPI.swift`
Ziel: Client vs Models trennen.
Vorschlag:
- `TMDbModels.swift` (Codable structs)
- `TMDbClient.swift` (request building, decoding, error mapping)
- `TMDbEndpoints.swift` (URL building, paths, image base)

Risiko: niedrig–mittel.
Nutzen: bessere Testbarkeit, weniger Merge-Konflikte.

#### D) `Stats/StatsView+Calculations.swift`
Ziel: Aggregationen einmalig pro Filterstate berechnen.
Vorschlag:
- `StatsEngine.swift` (pure functions, takes `[Movie]`, returns computed DTO)
- `StatsViewModel.swift` (`@MainActor`, memoized results keyed by range/location)
- `StatsView+Render.swift` bleibt UI.

Risiko: niedrig–mittel.
Nutzen: spürbar bessere Performance bei großen Datenmengen.

#### E) `Goals/CustomGoalEditorView.swift`
Ziel: Domain-Regeln aus UI lösen.
Vorschlag:
- `CustomGoalEditorState.swift` (state machine / validation)
- `CustomGoalRulePickerView.swift` (UI)
- `CustomGoalRuleBuilders.swift` (rule construction, TMDb ID integration)

Risiko: mittel.
Nutzen: schnelleres Weiterentwickeln neuer Goal-Typen.

---

### Cache-/Index-Ideen (was cachen, Keys, Invalidation)

#### 1) Content list derivations cache
- Problem:
  - Filter/Sort wird pro Invalidation neu gebaut (`ContentView+MovieItems.swift`).
- Cache Key:
  - `(groupId, selectedMode, selectedSort, filterUserId?, searchText, viewStyle)`
- Value:
  - `[IndexedMovie]` für watched/backlog.
- Invalidation:
  - Wenn `movieStore.movies`/`backlogMovies` geändert (z.B. via version counter).
  - Wenn Filter/Sort/Search/Mode wechselt.

#### 2) Stats pre-aggregation cache
- Problem:
  - `StatsView+Calculations` computed properties werden mehrfach abgefragt.
- Cache Key:
  - `(groupId, selectedRange, selectedLocationFilter)`
- Value:
  - Precomputed “StatsSnapshot” (counts, top lists, distributions)
- Invalidation:
  - On movies array change oder filter change.

#### 3) TMDb request dedupe + cancellation
- Problem:
  - Mehrere Tasks können gleiche Details laden.
- Ansatz:
  - Pro View: `@State private var detailsTask: Task<Void, Never>?`
  - cancel on `onDisappear`, dedupe by `tmdbId`.
- Optional:
  - global in-flight cache (ähnlich `ImageCacheStore.inFlight`).

---

### Vereinheitlichungen (Patterns, Services, DI)

#### CloudKit Routing wiederverwenden
- Aktuell:
  - `routedDatabase(forGroupId:)` ist in mehreren Stores dupliziert.
- Vorschlag:
  - `CloudKitRouting.swift` mit:
    - `resolve(groupId) -> (db, zoneID, scope)`
    - `scope enum` + mapping auf `CloudKitZoneChangeTokenStore.Scope`

#### Error Mapping
- Vorschlag:
  - `CloudKitErrorMapper.swift` (friendly messages, retryable vs fatal)
  - Konsistent in `MovieStore`, `UserStore`, `CloudKitGroupStore`, `CloudKitShareCoordinator`.

#### Dependency Injection (lightweight)
- Aktuell:
  - Stores instanziieren CloudKit Stores direkt.
- Vorschlag:
  - Protocols + default implementations oder init injection, um Tests zu ermöglichen (**Tests: UNKNOWN**).

---

## Risiken & Edge Cases

- **GroupContext Drift**
  - Wenn `GroupContextStore` nicht aktualisiert ist, routet man evtl. falsch (public vs zone). (Files: `GroupContext.swift`, CloudKit Stores)
- **Share acceptance timing**
  - Share acceptance postet `.cloudKitShareAccepted` → `CloudKitGroupStore.refresh()` (Observer in `CloudKitGroupStore.swift`).
  - Race möglich, wenn UI bereits Group-Switch macht (**genauer Ablauf: UNKNOWN**, abhängig von UI-Flows).
- **Token corruption / zone reset**
  - `CloudKitZoneChangeTokenStore` entfernt Token bei Decode-Fehler; ansonsten ist Re-Sync-Strategie je nach Error Handling in Stores (**Details: UNKNOWN**).
- **Array index binding hazards**
  - Du hast bereits Guard gegen out-of-range in `ContentMoviesListSection.swift`. Trotzdem bleibt Risiko bei schnellen Group Switches + UI stale state.
- **Offline write backlog**
  - Debounced writes + pending cloud changes: gut, aber worst-case backlog groß (MainActor pressure).
- **Secrets exposure**
  - `.gitignore` schützt, aber ZIP/Sharing kann Secrets enthalten.

---

## Observability / Debuggability

### Logging
- Positiv:
  - `PersistenceManager.swift` nutzt `os.Logger`.
  - Cloud-Sync hat Debug prints (z.B. `MovieStore.swift` “CloudKit: ...”).
- Verbesserung:
  - CloudKit prints → Logger mit Subsystem + Kategorien:
    - `Sync.Movie`, `Sync.Rating`, `Sync.Group`, `TMDb`, `UI.Routing`.

### Repro/Debug Checkliste
- Cloud Sharing:
  - Gruppe erstellen (`CloudKitGroupStore.createGroup`)
  - Share Link erzeugen (UI: `GroupShareSheetView.swift`)
  - Auf zweitem Gerät Share akzeptieren (Delegates + `CloudKitShareCoordinator`)
  - Prüfen: `CloudKitGroupStore.refresh()` → `GroupContextStore` upserts.
- Sync correctness:
  - Film hinzufügen → auf anderem Gerät sichtbar nach `.active` oder Pull-to-refresh.
  - Rating pro User ändern → anderer User sieht Update (RatingStore).
- Offline:
  - Flugmodus → Änderungen lokal → wieder online → `NetworkMonitor` triggert `flushPendingCloudChanges()`.

---

## Open Questions (UNKNOWN)
- **CloudKit Dashboard Schema**
  - Indexes, Required Fields, Query Constraints, Production vs Development setup: **UNKNOWN**
- **Subscription Strategy**
  - Aktuell wirkt es “ohne Subscriptions” (Kommentar in `filmfreaksApp.swift`). Ob geplant: **UNKNOWN**
- **Test Coverage**
  - Targets existieren (Project), aber konkrete Testfiles im ZIP: **UNKNOWN**
- **Conflict Resolution Semantics**
  - Movies vs Ratings: Ratings separat; “last writer wins” pro Record? (implizit via `updatedAt`, Record overwrites) Detailregeln: **UNKNOWN**
- **Background Sync**
  - BGTasks / silent push / fetch scheduling: **UNKNOWN**
- **Watch Providers Region Defaults**
  - Persist/Reset/UX Edge Cases über Länderwechsel: **UNKNOWN**

---

## First 3 Refactors I would do (P0)

### P0.1 – Cache/memoize Content list derivations
- Ziel:
  - Smooth scrolling & weniger CPU bei Search/Sort/Filter (kein Re-sort pro Render).
- Betroffene Dateien:
  - `Content/ContentView+MovieItems.swift`
  - `Content/ContentMainAreaView.swift`
  - (optional) `Content/ContentView.swift`
- Risiko:
  - Mittel: Gefahr von “stale results” wenn Invalidation falsch.
- Erwarteter Nutzen:
  - Spürbar flüssiger bei großen Listen; weniger Battery bei häufigen State Changes.

### P0.2 – Cancelable TMDb tasks in Detail Views
- Ziel:
  - Keine doppelten Requests, keine späten State-Writes in nicht sichtbare Views.
- Betroffene Dateien:
  - `MovieDetail/MovieDetailView+Lifecycle.swift` (Tasks für `loadDetails`, Watch Providers reload)
  - `SearchResultDetail/SearchResultDetailView.swift` (Detail-Ladepfade)
  - (optional) `TMDbAPI.swift` (dedupe layer)
- Risiko:
  - Niedrig–mittel: UI darf nicht “leer bleiben”, wenn Task zu aggressiv gecancelt wird.
- Erwarteter Nutzen:
  - Weniger Netztraffic, weniger race bugs, stabilere UX beim schnellen Navigieren.

### P0.3 – CloudKit routing + error handling vereinheitlichen
- Ziel:
  - Reduzierte Duplikation, konsistentes Verhalten zwischen Movie/Rating/User/Goal Stores.
- Betroffene Dateien:
  - `CloudKitMovieStore.swift`, `CloudKitRatingStore.swift`, `CloudKitUserStore.swift`, `CloudKitGoalStore.swift`
  - neu: `CloudKitRouting.swift`, `CloudKitErrorMapper.swift`
- Risiko:
  - Mittel: viele Call-Sites; falsches Routing wäre kritisch.
- Erwarteter Nutzen:
  - Wartbarkeit hoch, weniger “one-off fixes”, leichtere Weiterentwicklung (Subscriptions, background sync).

---
