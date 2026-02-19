# ARCHITECTURE_NOTES.md

## Scope der Notizen
Diese Datei fokussiert auf Wartbarkeit und Performance, mit Priorität auf:
1) Sync/Storage/Model (CloudKit + Local JSON)
2) Entry Points + Navigation
3) Große Views/Services
4) Konventionen + Workflows

Alles, was aus Code nicht eindeutig ableitbar ist, steht als **UNKNOWN** in „Open Questions“.

---

## Big Files List (Top 15 nach Zeilen)
> Quelle: statische Line-Counts der `.swift` Dateien im Projekt.

1. `DisplaySettings.swift` (598)  
   Zweck: Zentrale Darstellungseinstellungen (UserDefaults Persistenz, Metrics, Toggles).  
   Risiko: Viele Zustände als `EnvironmentObject` können großflächige View-Invalidations auslösen; Datei ist ein Sammelpunkt.

2. `TMDbAPI.swift` (591)  
   Zweck: TMDb API Modelle + Networking + Decoding.  
   Risiko: „God service“ (Modelle + Requests + Endpoints) erschwert Tests, Caching-Strategien und Fehlerbehandlung.

3. `Goals/CustomGoalEditorView.swift` (545)  
   Zweck: Editor-UI für Custom Goals inkl. Suche/Picker-Flows.  
   Risiko: Viele UI-States, viele Pfade, hoher Compile- und Review-Aufwand.

4. `SearchResultDetail/SearchResultDetailView.swift` (522)  
   Zweck: Detailansicht für TMDb Ergebnis (Details, Credits, Watch Providers).  
   Risiko: Mehrere async Loads über `Task { await loadDetails() }`, potenziell wiederholt, schwer reproduzierbare Lade-Races.

5. `CloudKitRatingStore.swift` (502)  
   Zweck: CloudKit Sync von Ratings (RecordID Encoding, Fetch by movieIds, Zone Changes).  
   Risiko: Zentraler Sync-Hotspot, Fehler führen zu „silent missing ratings“ oder Inkonsistenzen.

6. `CloudKitGroupStore.swift` (463)  
   Zweck: Gruppen (Private/Shared), Zones, Shares, Subscriptions, Account Status Handling.  
   Risiko: Viele CloudKit-Edge-Cases, iCloud Sign-In, Sharing Acceptance, Subscriptions.

7. `Stats/StatsView+Calculations.swift` (429)  
   Zweck: Aggregationen/Filter für StatsView.  
   Risiko: Wiederholte `map/filter` auf `movieStore.movies` in computed properties kann bei großen Datenmengen UI laggen.

8. `MovieSearch/MovieSearchView.swift` (421)  
   Zweck: Such-UI, Historie, Scanner, Empfehlungen, Pagination.  
   Risiko: Monolithische View; viele States und Nebenwirkungen.

9. `MovieNights/Sheets/MovieNightDetailSheet.swift` (410)  
   Zweck: Detail/Actions für Movie Night.  
   Risiko: Viele UI-Zustände, abhängig von Routing readiness (GroupContext), potenziell komplexe Fehlerzustände.

10. `Content/ContentView.swift` (402)  
    Zweck: Home-Screen und zentrale Navigation per Sheets.  
    Risiko: Viele Dependencies (mehrere EnvironmentObjects), viele `@State`; invalidiert schnell.

11. `MovieStore/MovieStore+CloudSync.swift` (396)  
    Zweck: Cloud Fetch + Merge von Movies, Ratings, initial Upload, Migration.  
    Risiko: Komplexer Merge, Fehler können Daten überschreiben oder UI in falschen Group-State bringen.

12. `MovieNights/MovieNightStore.swift` (390)  
    Zweck: Movie Nights State + Persistenz + Sync Hooks.  
    Risiko: Parallelität (Flush/Refresh), Konsistenz zwischen local snapshot und Cloud.

13. `UserStore.swift` (389)  
    Zweck: Mitglieder pro Gruppe, Selected User, Cloud Sync.  
    Risiko: MemberId Migrationslogik, mögliche Duplikate, UI-Dependence.

14. `ViewingCustomGoal.swift` (369)  
    Zweck: Custom Goal Types + Codable Rule Encoding.  
    Risiko: Versionierung/Kompatibilität; Erweiterungen müssen backward compatible sein.

15. `Movie.swift` (366)  
    Zweck: Zentrales Domain Model (Movie, Rating, CastMember, Codable Migration).  
    Risiko: Änderungen wirken in Persistenz, Cloud Payload, Merge, UI.

---

## Entry Points + Navigation (konkret)
- App Entry: `filmfreaksApp.swift`
  - Injektion von `MovieStore`, `UserStore`, `MovieNightStore`, `CloudKitGroupStore`, `NetworkMonitor`, `DisplaySettings` als `EnvironmentObject`.  
  - `scenePhase` `.active` triggert Refresh-Kaskade (GroupStore.refresh → MovieNight flush → MovieStore.loadFromCloud → UserStore.refresh → GoalStore fetch). (filmfreaksApp.swift)

- CloudKit Sharing Lifecycle:
  - Push/Share Acceptance: `CloudKitShareAppDelegate.swift` + `CloudKitShareSceneDelegate.swift` + `CloudKitShareCoordinator.swift`.
  - Share Acceptance postet Notification `.cloudKitShareAccepted` und `CloudKitGroupStore` refreshes. (CloudKitShareAppDelegate.swift, CloudKitGroupStore.swift)

- In-App Navigation:
  - Root NavigationStack in `Content/ContentView.swift`.
  - Modal Sheets über `ContentRoute` + `Content/ContentRouting.swift` (Settings, Search, Users, Stats, Timeline, Calendar, Activity, Goals, GroupSettings).

---

## Hot Path Analyse

### Rendering/Scrolling
**Hotspot 1: Stats Recomputations in computed properties**
- Datei: `Stats/StatsView+Calculations.swift`
- Grund: Computed Vars wie `moviesForCurrentTimeRange`, `filteredMovies`, `availableLocations` iterieren über `movieStore.movies` mit `compactMap`, `filter`, `map`, `Set` und `sorted`.  
  Diese Properties werden bei jeder View-Invalidation neu ausgewertet (typisch bei Filter-Change, Theme-Change, Store Updates).  
- Risiko: Bei großen Movie-Listen (hundert bis tausend) entsteht CPU-Last auf MainActor, weil `StatsView` UI-gebunden ist.

**Hotspot 2: Monolithische SwiftUI Views mit vielen State-Variablen**
- Dateien: `Content/ContentView.swift`, `MovieSearch/MovieSearchView.swift`, `SearchResultDetail/SearchResultDetailView.swift`, `Goals/CustomGoalEditorView.swift`, `MovieNights/Sheets/MovieNightDetailSheet.swift`
- Grund: Viele `@State` und mehrere `EnvironmentObject` führen zu häufigen invalidations; große Bodies erhöhen Compile-Time und Review-Risiko.

**Hotspot 3: Wiederholte async Loads über `Task { await loadDetails() }` ohne klare Cancellation**
- Datei: `SearchResultDetail/SearchResultDetailView.swift`
- Indiz: Mehrere `Task { await loadDetails() }` Trigger. (SearchResultDetail/SearchResultDetailView.swift)
- Risiko: Bei schnellem Öffnen/Schließen oder mehrfacher Navigation können parallele Loads laufen; UI kann kurz „springen“, oder alte Antworten überschreiben neuere State.

**Hotspot 4: Global Theme Settings als EnvironmentObject**
- Datei: `DisplaySettings.swift`
- Grund: Viele UI-Komponenten hängen am selben Objekt; Änderungen daran invalidieren potenziell große Teile der UI.  
- Risiko: Wenn Settings häufig geändert werden (z.B. Slider), kann UI „stottern“. (DisplaySettings.swift)

### Sync/Storage (CloudKit + Local Files)
**Hotspot 5: Group Routing Safety**
- Datei: `CloudKitRouting.swift`
- Grund: UUID-like groupIds werden als Sharing-Gruppen behandelt und dürfen ohne `GroupContext` nicht in Public DB fallen (wirft `CloudKitRoutingError.groupContextNotReady`).  
- Risiko: Wenn UI-Aktionen stattfinden bevor GroupContext geladen ist (z.B. direkt nach Share Acceptance), müssen Calls sauber retryen oder UI muss blocken.

**Hotspot 6: Cloud Fetch + Merge (Movies + Ratings)**
- Datei: `MovieStore/MovieStore+CloudSync.swift`
- Gründe:
  - Zwei Fetch Pfade: Zone Changes für Sharing-Gruppen und „full query“ für legacy/public. (MovieStore/MovieStore+CloudSync.swift, CloudKitMovieStore/CloudKitMovieStore+ZoneChanges.swift)
  - Ratings werden separat geladen und in Movie-Structs gemerged, um Offline-Ratings zu konservieren. (MovieStore/MovieStore+CloudSync.swift)
  - Merge Policy: server-wins bei Konflikten in Movie Merge Helpers. (CloudKitMovieStore/CloudKitMovieStore+Merge.swift)
- Risiken:
  - „Server wins“ kann lokale Änderungen überschreiben (bewusst, aber wichtig zu kennen).
  - Große Gruppen: full query kann teuer werden, falls legacy/public Gruppe sehr viele Records hat.

**Hotspot 7: Local JSON Persistence mit großen Arrays**
- Datei: `PersistenceManager.swift`
- Grund: Movies/Backlog werden als komplette Arrays als JSON geschrieben (debounced und off-main, aber Payload ist groß).  
- Risiken:
  - Bei sehr großen Arrays ist Encoding/Decoding teuer.
  - Capturing großer Arrays in DispatchWorkItem kann Memory-Spikes erzeugen (Implementation Detail, abhängig von Copy-on-Write Verhalten).

**Hotspot 8: CloudKit Group Store als Multi-Responsibility**
- Datei: `CloudKitGroupStore.swift`
- Grund: Account-Status, Zones, Group Records, Shares, Hierarchy Repair, Subscriptions.  
- Risiko: Änderungen hier haben viele Seiteneffekte; schwierig zu testen ohne integrierte CloudKit Umgebung.

**Hotspot 9: Push -> Fetch -> Local Notification Pipeline**
- Dateien: `CloudKit/CloudKitActivityPushFetchCoordinator.swift`, `CloudKit/CloudKitActivitySubscriptionManager.swift`, `Notifications/GroupActivityLocalNotifier.swift`
- Grund: Remote Push triggert Cloud Record Fetch; dedupe und „own action suppression“ sind best effort.  
- Risiko: Edge-Cases (fehlender GroupContext, fehlende recordID Normalisierung) führen zu stillen Drops.

### Concurrency (MainActor, Task Lifetimes, Cancellation)
**MainActor Contention**
- Stores laufen auf MainActor (MovieStore, UserStore, MovieNightStore, CloudKitGroupStore). (MovieStore.swift, UserStore.swift, MovieNights/MovieNightStore.swift, CloudKitGroupStore.swift)
- Risiko: Große Merge- oder Aggregationsschritte blockieren UI.

**Task Lifetimes**
- App-level refresh on `.active` startet eine Task-Kette, aber ohne Cancellation-Gate, wenn scenePhase schnell toggelt. (filmfreaksApp.swift)
- Views nutzen `Task { await loadDetails() }` für Loads; nicht überall ist klar, ob ein neuer Task ältere Ergebnisse superseded. (SearchResultDetail/SearchResultDetailView.swift, MovieSearch/MovieSearchView.swift)

---

## Refactor Map

### Konkrete Splits (dateibasiert, low risk)
1) `TMDbAPI.swift` splitten
- Ziel: Endpoint-Ownership klar, Tests einfacher.
- Vorschlag:
  - `TMDbAPI+Models.swift` (Codable Models)
  - `TMDbAPI+Search.swift` (Search + Pagination)
  - `TMDbAPI+Details.swift` (Details, Credits)
  - `TMDbAPI+WatchProviders.swift`
  - `TMDbAPI+Networking.swift` (Request building, decode, error mapping)

2) `Stats/StatsView+Calculations.swift` in ViewModel überführen
- Ziel: Aggregationen nur recompute wenn Inputs sich ändern.
- Vorschlag:
  - NEU: `Stats/StatsViewModel.swift` (`@MainActor` oder Actor + snapshot Inputs)
  - `StatsView` bindet nur Outputs (counts, series, location lists)

3) `MovieSearch/MovieSearchView.swift` modularisieren
- Ziel: Compile-Time runter, UI-State besser isolieren.
- Vorschlag:
  - `MovieSearch/MovieSearchState.swift` (State struct)
  - `MovieSearch/MovieSearchActions.swift` (performSearch, loadMore, recommendations, scanner)
  - `MovieSearch/Views/*` (RecentQueries, Recommendations, ResultsList, SortMenu, ScannerSheets)

4) `DisplaySettings.swift` splitten
- Ziel: Änderungen in einem Subbereich invalidieren weniger, Code navigierbarer.
- Vorschlag:
  - `DisplaySettings+Persistence.swift` (UserDefaults keys, load/save)
  - `DisplaySettings+LayoutMetrics.swift`
  - `DisplaySettings+Presets.swift` (Default Presets)
  - `DisplaySettings+Derived.swift` (computed properties)

### Cache-/Index-Ideen (konkret)
- **Stats Cache**: Precompute aggregations pro Gruppe und Zeitrange. Cache Key: `(groupId, range, locationFilter)`; invalidieren bei MovieStore movies/backlog change.  
  Dateien: NEU `Stats/StatsCache.swift`, Anpassung `StatsViewModel.swift`.
- **MovieSearch Duplicate Check**: `localWatchedKeys`/`localBacklogKeys` sind Sets, gut. Für sehr große Listen: Keys in `MovieStore` zentral anbieten, um SearchView init kopierarm zu halten.  
  Dateien: `MovieSearch/MovieSearchView.swift`, `MovieStore/MovieStore+Derived.swift` (NEU oder bestehend).
- **CloudKit ChangeToken Namespaces**: Bereits vorhanden für movies und ratings. Sicherstellen, dass movie nights/activity eigene Namespaces nutzen (falls Zone Changes dort implementiert sind).  
  Dateien: `CloudKitZoneChangeTokenStore.swift`, `CloudKitMovieNightStore/*` (**UNKNOWN**: ob Zone Changes dort genutzt werden).

### Vereinheitlichungen (Patterns, Services, DI)
- Einheitliches Routing-API: Alle CloudKit Stores sollten `CloudKitRouting.route(container:groupId:)` verwenden und keine eigenen Normalizer besitzen.  
  Beispiel: `CloudKitRatingStore.normalizedGroupId` vs. `CloudKitRouting.normalizedGroupId`. (CloudKitRatingStore.swift, CloudKitRouting.swift)
- Fehler-Typisierung: `CloudKitRoutingError` ist sauber; analog könnten Stores Domain Errors definieren statt `print` und `NSError(domain:code:userInfo:)`.  
  Dateien: `CloudKitGroupStore.swift`, `MovieStore/MovieStore+CloudSync.swift`, `MovieNights/*`

---

## Risiken & Edge Cases
- **Datenverlust durch Konflikte**: Movie Merge ist „server wins“. Bei parallelen Offline-Edits und späterem Cloud-Reload kann lokales überschrieben werden. (CloudKitMovieStore/CloudKitMovieStore+Merge.swift)
- **GroupContext Not Ready**: UUID-like groupId ohne GroupContext blockt CloudKit. UI muss das abfangen oder retryen. (CloudKitRouting.swift)
- **Legacy/Public Groups Skalierung**: Ohne Zone Changes bleibt „query all“. Große Gruppen können langsam werden. (CloudKitMovieStore/CloudKitMovieStore+Routing.swift, CloudKitRatingStore.swift)
- **Rating Identity**: Legacy Daten können `reviewerId == nil` haben; Stable IDs werden deterministisch erzeugt, aber nur best effort. (Movie.swift, CloudKitRatingStore.swift)
- **Share Hierarchy Repair**: `CloudKitGroupStore` hat Reparatur-Mechanik; Fehler hier können dazu führen, dass Shares fehlen oder inkonsistent sind. (CloudKitGroupStore.swift)
- **Push Delivery**: Push-Pipeline ist in `#if DEBUG` aktiv; Release-Verhalten ist **UNKNOWN** (CloudKitActivityPushFetchCoordinator.swift).
- **Offline First**: Local JSON ist Autorität im UI; Cloud kann nachträglich deltas applizieren. Wenn lokal gelöscht wurde und Cloud später „server wins“, kann ein Record zurückkommen, wenn Delete nicht erfolgreich war.

---

## Observability/Debuggability
- Logging ist aktuell gemischt (`print` und `os.Logger`). (MovieStore/MovieStore+CloudSync.swift, PersistenceManager.swift)
- Vorschlag:
  - Einheitlicher Logger pro Subsystem: `logger = Logger(subsystem: "de.marcfechner.filmfreaks", category: "cloudkit")`
  - Sync-Repro-Checkliste:
    1. iCloud sign-in status prüfen (CloudKitGroupStore.refresh). (CloudKitGroupStore.swift)
    2. Aktive groupId und GroupContext prüfen (GroupContextStore.context(forGroupId:)). (GroupContext.swift)
    3. pendingCloudChangesCount beobachten (MovieStore/MovieStore+Persistence.swift)
    4. Zone Change Tokens resetten falls notwendig (UserDefaults Keys `CKZoneToken.*`). (CloudKitZoneChangeTokenStore.swift)

---

## Open Questions (alles **UNKNOWN**)
- **UNKNOWN**: Welche CloudKit Indexes/Subcriptions sind live in der CloudKit Console (RecordType-Felder und Query Subscriptions)
- **UNKNOWN**: Release-Mode Verhalten für Push Fetch Coordinator (Datei ist `#if DEBUG` gated)
- **UNKNOWN**: Welche Datenmengen sind realistisch (typische Movies/Backlog Größe pro Gruppe), um Hotspots zu priorisieren
- **UNKNOWN**: Gibt es UI Tests oder Snapshot Tests (Tests target existiert, aber Umfang ist nicht ersichtlich)
- **UNKNOWN**: Umgang mit Background Fetch im Release (UIBackgroundModes ist gesetzt, konkrete Background Handler sind nicht komplett ersichtlich)

---

## First 3 Refactors I would do (P0)

### P0.1 — Stats Aggregationen aus dem Renderpfad holen
- Ziel: UI flüssig halten bei großen Gruppen; Stats sollen nur neu rechnen, wenn Inputs sich ändern.
- Betroffene Dateien:
  - `Stats/StatsView.swift`
  - `Stats/StatsView+Calculations.swift`
  - NEU: `Stats/StatsViewModel.swift`
- Risiko: Niedrig bis mittel (UI-Refactor, aber Logik ist deterministisch und testbar).
- Erwarteter Nutzen:
  - Weniger MainActor CPU-Spikes, schnelleres Scrollen und Filtern.
  - Bessere Testbarkeit der Aggregationen.

### P0.2 — TMDbAPI in Endpoints + Networking splitten
- Ziel: Wartbarkeit und Debugging verbessern; klarer, welche Calls wo passieren; einfacher Caching/Retry.
- Betroffene Dateien:
  - `TMDbAPI.swift`
  - NEU: `TMDbAPI+Models.swift`, `TMDbAPI+Search.swift`, `TMDbAPI+Details.swift`, `TMDbAPI+WatchProviders.swift`, `TMDbAPI+Networking.swift`
- Risiko: Niedrig (mechanischer Split, wenn API-Surface gleich bleibt).
- Erwarteter Nutzen:
  - Schnellere Orientierung, weniger Merge-Konflikte, bessere Fehlersicht.

### P0.3 — MovieSearchView modulär machen (State + Sections)
- Ziel: Compile-Time senken, UI-Fehler lokalisierbar machen, Nebenwirkungen isolieren (Scanner, Recommendations, Pagination).
- Betroffene Dateien:
  - `MovieSearch/MovieSearchView.swift`
  - `MovieSearch/*` (NEU: State/Actions/Views Split)
- Risiko: Mittel (viele States; erfordert sorgfältige Bindings).
- Erwarteter Nutzen:
  - Deutlich bessere Wartbarkeit; leichteres Hinzufügen neuer Sorts/Filter; weniger SwiftUI Invalidations pro Teilbereich.
