# ARCHITECTURE_NOTES.md

## Big Files List (Top 15 nach Zeilen)

1. `filmfreaks/MovieSearch/MovieSearchView.swift` — **434 Zeilen**
   - Zweck: komplette Suchoberfläche inkl. Query-State, Loading, Scanner-Entry, Header/UI.
   - Risiko: große SwiftUI-View mit viel State und UI-Verhalten; hoher Änderungsradius.

2. `filmfreaks/Content/ContentView.swift` — **424 Zeilen**
   - Zweck: App-Home, Routing, Onboarding, Push-Deep-Link, Activity Preview, Refresh-Hooks.
   - Risiko: zentrale Orchestrierung; viele `.onReceive`/`.onChange`; exzessive View-Invalidation möglich.

3. `filmfreaks/MovieNights/MovieNightStore.swift` — **398 Zeilen**
   - Zweck: Hauptstore für Filmabende, lokale State-Änderungen, Queueing, Initial Load.
   - Risiko: breiter MainActor-State, viele Verantwortlichkeiten, schwierige Nebenwirkungsanalyse.

4. `filmfreaks/MovieStore/MovieStore+CloudSync.swift` — **396 Zeilen**
   - Zweck: Cloud-Refresh, Delta-Apply, Ratings-Merge, Initial Upload, Retry/Throttle.
   - Risiko: kritischer Datenpfad; hohe Fehlerkosten; MainActor contention; Datenverlustrisiko bei Refactors.

5. `filmfreaks/UserStore.swift` — **389 Zeilen**
   - Zweck: Gruppenmitglieder, Auswahl des aktiven Users, Cloud-Refresh, Sync-Status.
   - Risiko: UI-State + Persistenz + Cloud-Orchestrierung in einer Klasse.

6. `filmfreaks/ViewingCustomGoal.swift` — **369 Zeilen**
   - Zweck: Goal-Regelmodell inkl. Codable-Migration, Unique Keys, Rule-Enum.
   - Risiko: dichtes Modell mit Versionierungslogik; Änderungen wirken auf Persistenz und Cloud-Payloads.

7. `filmfreaks/Movie.swift` — **366 Zeilen**
   - Zweck: Kernmodell `Movie` + `Rating` + `CastMember` + Migrationslogik.
   - Risiko: sehr zentrales Modell; Änderungen berühren UI, Persistenz, CloudKit, Migrationen, Tests.

8. `filmfreaks/Stats/StatsSnapshotBuilder.swift` — **363 Zeilen**
   - Zweck: Snapshot-Aggregation für Stats.
   - Risiko: CPU-intensiver Hot Path; algorithmische Änderungen wirken breit auf Statistik-UI.

9. `filmfreaks/SettingsView.swift` — **363 Zeilen**
   - Zweck: Settings-UI für Sync, Cache, Appearance, Info.
   - Risiko: viele concerns in einer View; UI- und Infrastrukturkopplung.

10. `filmfreaks/GroupSettingsView.swift` — **360 Zeilen**
    - Zweck: Cloud-Gruppenverwaltung, Sharing, Delete/Leave, Aktivierung.
    - Risiko: hoher Geschäftslogikanteil in View; viele Async-Aktionen aus UI heraus.

11. `filmfreaks/Stats/StatsView+Cards.Leaderboards.swift` — **355 Zeilen**
    - Zweck: umfangreiche Card-UI für Leaderboards.
    - Risiko: UI-Komplexität, schwer testbar, potenziell hohe Renderkosten.

12. `filmfreaks/MovieDetail/MovieDetailView.swift` — **345 Zeilen**
    - Zweck: Hauptdetailansicht mit mehreren Untersektionen und Sheets.
    - Risiko: starke UI-Orchestrierung; anfällig für State-Leaks und Lifecycle-Bugs.

13. `filmfreaks/PersistenceManager.swift` — **343 Zeilen**
    - Zweck: lokale JSON-Persistenz, Migration von UserDefaults, Debounce-Write.
    - Risiko: globaler Persistenzknoten; Fehler betreffen Kern-Datenpfad.

14. `filmfreaks/CloudKitUserStore.swift` — **335 Zeilen**
    - Zweck: CloudKit-Persistenz für GroupMember.
    - Risiko: CloudKit-Fehlerbehandlung und Batch-Modifikation lokal konzentriert.

15. `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift` — **333 Zeilen**
    - Zweck: debounced/batched Cloud-Flush für mehrere Record-Typen.
    - Risiko: komplexes Pending-State-Management; hohe Race-Condition-Anfälligkeit.

## Hot Path Analyse

### Rendering / Scrolling

#### 1) `ContentView` invalidiert sehr breit
- Datei: `filmfreaks/Content/ContentView.swift`
- Grund:
  - viele `.onReceive(...)` und `.onChange(...)`
  - Trigger auf `movieStore.movies`, `movieStore.backlogMovies`, `movieNightStore.activityByGroup`, Suchtexte, Filter, Sortierung, Display Settings, Gruppenwechsel, Zähler
- Konkretes Risiko:
  - **exzessive View invalidation**
  - redundante Rebuilds von Listen- und Activity-Derivaten auf dem MainActor
- Bereits vorhandene Gegenmaßnahme:
  - `ContentMovieItemsModel`
  - `ContentActivityPreviewModel`
- Restproblem:
  - Orchestrierung liegt weiterhin in einer breiten View.

#### 2) `ContentMovieItemsModel` sortiert/filtert vollständige Arrays bei jedem Update
- Datei: `filmfreaks/Content/ContentMovieItemsModel.swift`
- Grund:
  - `buildIndexedItems(...)` arbeitet pro Update über vollständige Movie-Arrays
  - Sortierung hängt u. a. an Suchtext, Filter, Sort-Option, Rating-Display-Mode
- Konkretes Risiko:
  - **heavy sort**
  - **MainActor contention**
  - skaliert schlecht mit größerem Katalog

#### 3) Activity Preview baut Feed vollständig neu
- Dateien:
  - `filmfreaks/Content/ContentActivityPreviewModel.swift`
  - `filmfreaks/MovieStore/MovieStore+Activity.swift`
- Grund:
  - Movies + Ratings werden vollständig iteriert
  - MovieNight-Aktivität wird kombiniert und anschließend global sortiert
- Konkretes Risiko:
  - **heavy sort**
  - **derived feed rebuild** bei vielen eigentlich UI-fremden Änderungen

#### 4) Movie Search sortiert im Render-nahen Derived-Pfad
- Datei: `filmfreaks/MovieSearch/MovieSearchView+Derived.swift`
- Grund:
  - `sortedResults` ist eine berechnete Eigenschaft, die `results.sorted(...)` ausführt
- Konkretes Risiko:
  - **sort im Renderpfad**
  - unnötige CPU-Last bei Sortwechseln / Re-Rendern

#### 5) Timeline gruppiert/filtriert on demand
- Datei: `filmfreaks/Timeline/timelineview+data.swift`
- Grund:
  - `filteredMovies` filtert und sortiert direkt aus `movieStore.movies`
  - `monthGroups` gruppiert anschließend neu
- Konkretes Risiko:
  - **filter/sort/group im Renderpfad**
  - Wiederholung derselben Arbeit bei jeder Re-Evaluation

#### 6) Movie-Night-Kalender filtert pro Render neu
- Datei: `filmfreaks/MovieNights/Calendar/MovieNightCalendarView.swift`
- Grund:
  - `eventsInMonth` und `eventsForSelectedDay` sind berechnete Properties
  - filtern aus `movieNightStore.events(for: groupId)` bei jeder Evaluation
- Konkretes Risiko:
  - **repeated filter in render path**
  - moderat heute, aber wachsend mit Event-Menge

#### 7) Stats-Feature ist rechenintensiv, aber teilweise bereits entschärft
- Dateien:
  - `filmfreaks/Stats/StatsView.swift`
  - `filmfreaks/Stats/StatsViewModel.swift`
  - `filmfreaks/Stats/StatsSnapshotBuilder.swift`
- Grund:
  - viele `.onChange`-Trigger in `StatsView`
  - Snapshot-Building aggregiert große Mengen
- Konkretes Risiko:
  - **CPU heavy aggregation**
- Positiv:
  - Debounce + `Task.detached` in `StatsViewModel` reduzieren UI-Stalls
- Restproblem:
  - Triggerfläche bleibt breit, Mehrfachauslösungen sind möglich.

### Sync / Storage

#### 1) `MovieStore+CloudSync` ist der kritischste Datenpfad
- Datei: `filmfreaks/MovieStore/MovieStore+CloudSync.swift`
- Gründe:
  - mischt Full-Fetch, Zone-Changes, Initial Upload, Ratings-Merge, Gruppenwechsel-Schutz und Apply-Phase
  - arbeitet auf dem MainActor
- Konkrete Risiken:
  - **MainActor contention**
  - **oversized orchestration method**
  - **high blast radius** bei Änderungen
  - potentieller Datenverlust bei fehlerhafter Reihenfolge im Merge/Apply

#### 2) Cloud-Diffing bei lokalen Movie-Änderungen ist O(n)
- Dateien:
  - `filmfreaks/MovieStore/MovieStore+Persistence.swift`
  - `filmfreaks/MovieStore/MovieStore+CloudSync.swift`
- Grund:
  - didSet auf `movies`/`backlogMovies` triggert Persistenz und Queueing
  - Diffing erzeugt Dictionaries/Sets aus ganzen Listen
- Konkretes Risiko:
  - **full-array diff on mutation**
  - teurer bei häufigen kleinen Änderungen

#### 3) `UserStore` schreibt Nutzer einzeln und refresht danach
- Datei: `filmfreaks/UserStore.swift`
- Grund:
  - Add/Delete-Logik stößt pro User Cloud-Operationen an
  - danach erneuter Cloud-Fetch
- Konkretes Risiko:
  - **unbatched CloudKit writes**
  - **refresh fan-out**
  - unnötige Netzlast und längere MainActor-Blockade

#### 4) Movie Nights persistieren als kompletter Snapshot
- Dateien:
  - `filmfreaks/MovieNights/MovieNightStore+Persistence.swift`
  - `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`
- Grund:
  - jede Änderung serialisiert `eventsByGroup`, `responsesByGroup`, `activityByGroup` komplett
- Konkretes Risiko:
  - **whole-snapshot rewrite**
  - I/O wächst mit kompletter Feature-Nutzung

#### 5) Goals verwenden parallele lokale und Cloud-Pfade ohne gemeinsame Store-Abstraktion
- Dateien:
  - `filmfreaks/Goals/GoalsView+Persistence.swift`
  - `filmfreaks/CloudKitGoalStore.swift`
- Grund:
  - `GoalsView` enthält Persistenz- und Sync-Logik direkt in View-Extensions
  - lokale `UserDefaults`-Daten werden nicht durch leere Cloud ersetzt
- Konkretes Risiko:
  - **stale local state**
  - **view owns persistence**
  - erschwerte Testbarkeit

#### 6) `PersistenceManager` mischt Dateilayout, Migration und Debounce-Scheduler
- Datei: `filmfreaks/PersistenceManager.swift`
- Grund:
  - zentrale Verantwortung für Ordnerstruktur, File-Namen, Migrationslogik und Schreiben
- Konkretes Risiko:
  - **single point of failure**
  - schwierig isoliert zu ändern

#### 7) Secret Handling ist operativ riskant
- Dateien:
  - `filmfreaks/Secrets.xcconfig`
  - `filmfreaks/TMDbAPI/TMDbAPI.swift`
- Grund:
  - API-Key liegt aktuell im Repository-Stand in `Secrets.xcconfig`
- Konkretes Risiko:
  - **credential leakage**
- Kein Performance-Problem, aber klarer Architektur-/Betriebs-Hotspot.

### Concurrency

#### 1) Stores sind breit `@MainActor`
- Dateien:
  - `filmfreaks/MovieStore/MovieStore.swift`
  - `filmfreaks/UserStore.swift`
  - `filmfreaks/MovieNights/MovieNightStore.swift`
  - `filmfreaks/CloudKitGroupStore/CloudKitGroupStore.swift`
- Grund:
  - große Teile der Sync-Orchestrierung laufen im MainActor-Kontext
- Konkretes Risiko:
  - **MainActor contention**
  - schwer vorhersehbare UI-Stalls bei großen Datenmengen

#### 2) Lang lebende Tasks sind verteilt, aber nicht zentral sichtbar
- Beispiele:
  - `initialLoadTask` in `MovieNightStore`
  - Debounce-/Flush-Tasks in `MovieCloudSyncCoordinator` und `MovieNightCloudSyncCoordinator`
  - Refresh-Tasks in Views (`GroupSettingsView`, `MovieNightCalendarView`, `filmfreaksApp`)
- Konkretes Risiko:
  - **long-lived Task coordination complexity**
  - Cancellation-Verhalten nur teilweise explizit

#### 3) `StatsViewModel` macht es besser als viele andere Bereiche
- Datei: `filmfreaks/Stats/StatsViewModel.swift`
- Positiv:
  - Debounced Compute
  - Off-main Aggregation via `Task.detached`
  - Generationsschutz gegen veraltete Ergebnisse
- Architekturhebel:
  - dieses Pattern ist ein guter Kandidat für Wiederverwendung in Timeline, Search Sorting und Activity Preview.

#### 4) `MovieNightLocalPersistence` ist actor-basiert, `PersistenceManager` nicht
- Dateien:
  - `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`
  - `filmfreaks/PersistenceManager.swift`
- Konkretes Risiko:
  - unterschiedliche Nebenwirkungsmodelle
  - erschwerte Vereinheitlichung und Teststrategie

#### 5) Push-Fetch ist produktionsseitig fragwürdig
- Datei: `filmfreaks/CloudKit/CloudKitActivityPushFetchCoordinator.swift`
- Grund:
  - `fetchAndHandle(...)` ist innerhalb `#if DEBUG` implementiert, außerhalb gibt die Methode `false` zurück
- Konkretes Risiko:
  - **feature disabled in release**
  - Push-zu-Local-Notification-Pipeline möglicherweise nur im Debug effektiv
- Status: fachlich kritisch, Ursache/Absicht **UNKNOWN**.

## Refactor Map

### Konkrete Splits

#### 1) `ContentView.swift` weiter aufteilen
- Heute:
  - Routing
  - Onboarding
  - Push-Deep-Link
  - Toolbar
  - Refresh-Trigger
  - Derivation-Trigger
- Empfohlene Splits:
  - `ContentView+Lifecycle.swift`
  - `ContentView+DeepLink.swift`
  - `ContentView+ActivityPreview.swift`
  - `ContentView+Onboarding.swift`
- Ziel:
  - weniger Triggerlogik im Body-File
  - geringerer Merge-Konflikt-Radius

#### 2) `MovieStore+CloudSync.swift` nach Phasen trennen
- Empfohlene Splits:
  - `MovieStore+CloudLoad.swift`
  - `MovieStore+CloudApply.swift`
  - `MovieStore+CloudBootstrap.swift`
  - `MovieStore+CloudRatingsMerge.swift`
- Ziel:
  - klare Trennung zwischen Fetch, Merge, Apply, Initial Upload
  - bessere Testbarkeit ohne UI-State drumherum

#### 3) `UserStore.swift` in State vs. Cloud-Operationen trennen
- Empfohlene Splits:
  - `UserStore+Selection.swift`
  - `UserStore+CloudSync.swift`
  - `UserStore+SyncStatus.swift`
- Ziel:
  - weniger „eine Klasse macht alles“

#### 4) Goals aus View herauslösen
- Heute:
  - `GoalsView+Persistence.swift` enthält echte Datenlogik
- Empfohlene Struktur:
  - `GoalsStore.swift`
  - `GoalsStore+Cloud.swift`
  - `GoalsStore+Persistence.swift`
  - View bleibt auf Rendering, Editing und Intents fokussiert
- Ziel:
  - bessere Testbarkeit
  - weniger View-seitige Nebenwirkungen

#### 5) `PersistenceManager.swift` modularisieren
- Empfohlene Splits:
  - `PersistenceManager+Movies.swift`
  - `PersistenceManager+Users.swift`
  - `PersistenceManager+Migration.swift`
  - `PersistenceManager+Files.swift`
- Ziel:
  - klarere Verantwortlichkeiten
  - kleinere Review-Slices

### Cache- / Index-Ideen

#### 1) Timeline Snapshot Cache
- Dateien:
  - `filmfreaks/Timeline/timelineview+data.swift`
- Idee:
  - Cache-Key aus `movies hash + filterMode + selectedYear + selectedRange`
  - speichern von `filteredMovies` und `monthGroups`
- Invalidation:
  - Änderung an `movieStore.movies`
  - Änderung von Filter/Range/Year
- Nutzen:
  - weniger Filter-/Group-Last im Renderpfad

#### 2) Search Result Sort Cache
- Dateien:
  - `filmfreaks/MovieSearch/MovieSearchView+Derived.swift`
- Idee:
  - sortierte Resultlisten pro `selectedSort` memoizen
- Invalidation:
  - neue Suchergebnisse
  - Sort-Option-Wechsel
- Nutzen:
  - eliminiert wiederholtes `results.sorted(...)`

#### 3) Activity Preview Incremental Cache
- Dateien:
  - `filmfreaks/Content/ContentActivityPreviewModel.swift`
  - `filmfreaks/MovieStore/MovieStore+Activity.swift`
- Idee:
  - nicht bei jeder Änderung den gesamten Feed neu bauen
  - ggf. bereits normalisierte Activity-Events in `MovieStore` halten
- Invalidation:
  - relevante Felder (`addedAt`, `addedBy*`, `ratings.updatedAt`, MovieNightActivity)
- Nutzen:
  - weniger Vollscan über alle Movies/Ratings

#### 4) Diff-Index für Movie Cloud Sync
- Dateien:
  - `filmfreaks/MovieStore/MovieStore+CloudSync.swift`
  - `filmfreaks/MovieStore/MovieStore+Persistence.swift`
- Idee:
  - Dirty-ID-Tracking statt Array-Diff pro Mutation
- Invalidation:
  - bei lokaler Mutation Dirty-ID setzen
  - nach erfolgreichem Flush Dirty-ID entfernen
- Nutzen:
  - reduziert O(n)-Diffing im MainActor

### Vereinheitlichungen

#### 1) Gemeinsames Local-first + Cloud-sync Muster
- Kandidaten:
  - `MovieStore`
  - `UserStore`
  - `MovieNightStore`
  - Goals
- Vereinheitlichung:
  - gemeinsames Schema für
    - Load Local
    - Apply Cloud
    - Persist Sync Meta
    - Queue Pending
    - Retry on Network Reconnect
- Nutzen:
  - weniger Sonderfälle
  - konsistentere Fehlerbehandlung

#### 2) Gemeinsame Sync-Status-Struktur
- Heute:
  - `MovieStore`, `UserStore`, `MovieNightStore` haben je eigene Varianten
- Ziel:
  - standardisierte Sync-Meta mit
    - `lastAttemptAt`
    - `lastSuccessAt`
    - `lastError`
    - `pendingCount`
- Nutzen:
  - vereinfachte Settings-/Debug-UI

#### 3) Trigger-Management vereinheitlichen
- Heute:
  - `ContentView`, `StatsView`, `filmfreaksApp`, `GroupSettingsView` triggern eigenständig Refreshes/Updates
- Ziel:
  - weniger verstreute Trigger-Setups
  - zentrale refresh/update intents pro Feature

#### 4) Logging standardisieren
- Heute:
  - Mix aus `print(...)`, `Logger`, Stille bei best-effort-Fails
- Ziel:
  - einheitliche Logger-Kategorien (`sync`, `persistence`, `notifications`, `goals`, `movie-nights`)
- Nutzen:
  - bessere Reproduzierbarkeit

## Risiken & Edge Cases

### Datenverlust / Konsistenz

- `MovieStore+CloudSync` kombiniert lokale Ratings mit Cloud-Movies; Reihenfolgefehler oder fehlerhafte Merge-Regeln können Ratings verlieren (`filmfreaks/MovieStore/MovieStore+CloudSync.swift`).
- `MovieNightStore.persist()` speichert komplett, best-effort und ohne sichtbare Fehleroberfläche; stilles Scheitern ist möglich (`filmfreaks/MovieNights/MovieNightStore+Persistence.swift`).
- Goals überschreiben lokal nicht automatisch mit leerer Cloud; absichtlich robust, aber potenziell stale (`filmfreaks/Goals/GoalsView+Persistence.swift`).
- `deleteOwnedGroup(...)` löscht die gesamte Zone; fachlich korrekt, aber extrem destructive (`filmfreaks/CloudKitGroupStore/CloudKitGroupStore.swift`).

### Migrationen

- `PersistenceManager.migrateFromUserDefaultsIfNeeded()` ist kritisch für Altbestände (`filmfreaks/PersistenceManager.swift`).
- `Movie.cast`-Legacy-Migration muss kompatibel zu Fixtures bleiben (`filmfreaks/Movie.swift`).
- `ViewingCustomGoalsPayload` und `MovieNightLocalPersistence.Snapshot` sind versioniert; neue Felder müssen abwärtskompatibel eingeführt werden.

### Offline / Multi-Device

- Bei UUID-Gruppen ohne `GroupContext` bleiben Writes pending; gut gegen falsches Routing, aber UI kann längere Pending-Zustände zeigen (`filmfreaks/CloudKitRouting.swift`, `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift`).
- `UserStore` seeded Cloud, wenn Cloud leer und lokal nicht leer ist; in Mehrgeräte-Szenarien muss klar sein, welches Gerät zuerst seeded.
- Record-Sharing hängt davon ab, dass Children korrekt am Root hängen; deshalb der Reparenting-Repair (`filmfreaks/CloudKitGroupStore/CloudKitGroupStore+Sharing.swift`).

### Notifications / Push

- Remote Notification Background Mode ist aktiviert (`filmfreaks/Info.plist`), aber die aktive Fetch-Logik ist DEBUG-gated (`filmfreaks/CloudKit/CloudKitActivityPushFetchCoordinator.swift`).
- `NotificationsPermissionManager` registriert Remote Notifications auch dann, wenn Alert-Auth fehlschlägt; funktional okay, UX-/Telemetry-seitig aber erklärungsbedürftig (`filmfreaks/Notifications/NotificationsPermissionManager.swift`).

### Secrets / Betriebsrisiko

- `Secrets.xcconfig` ist im bereitgestellten Projekt enthalten. Das ist kein Architekturbruch, aber ein klarer operativer Schwachpunkt.

## Observability / Debuggability

### Vorhanden

- Sync-Transparenz im UI:
  - `movieStore.pendingCloudChangesCount`
  - `movieStore.lastCloudSyncAt`
  - `movieStore.lastCloudSyncError`
  - `UserStore`-Sync-Statusfelder
  - `MovieNightStore.pendingCloudChangesByGroup`
- Coalesced App-Resume-Refresh via `AppRefreshCoordinator` (`filmfreaks/AppRefreshCoordinator.swift`).
- Testabdeckung für:
  - `CloudKitRouting`
  - `GroupContextStore`
  - `CloudKitZoneChangeTokenStore`
  - `PersistenceManager`
  - `MovieNightLocalPersistence`
- Push-Debug-Logging in `CloudKitRemoteNotificationDebugger`.

### Fehlend / schwach

- Keine sichtbare strukturierte Metrik für Dauer von Cloud-Fetches / Merge-Phasen / Snapshot-Builds.
- Viele Best-effort-Fails sind nur `print(...)` oder komplett still.
- UI-Test-Suite deckt praktisch keine Fachflows ab (`filmfreaksUITests/*`).
- Keine zentrale Diagnoseansicht für Routing-/GroupContext-/ChangeToken-Status.

### Wie Probleme reproduzierbar gemacht werden könnten

1. Debug-Screen für:
   - aktive `groupId`
   - `GroupContext`
   - Route (public/private/shared)
   - letzte Change Tokens je Namespace
   - Pending Cloud Changes je Store
2. Messung von:
   - `loadFromCloud()` Dauer
   - `StatsSnapshotBuilder.computeSnapshot(...)` Dauer
   - Persistenzgrößen und Write-Dauer
3. Gezielte Tests für:
   - Gruppenwechsel während in-flight Fetch
   - leere Cloud + lokaler Seed
   - Release-Verhalten der Push-Pipeline

## Open Questions

- **UNKNOWN:** Ist der legacy/public-Fallback in `CloudKitRouting.route(...)` ein bewusst dauerhaft unterstütztes Modell oder nur Altlast-Migration? (`filmfreaks/CloudKitRouting.swift`)
- **UNKNOWN:** Soll `CloudKitActivityPushFetchCoordinator.fetchAndHandle(...)` im Release aktiv sein? Der aktuelle Code deaktiviert die Fetch-Logik außerhalb von DEBUG. (`filmfreaks/CloudKit/CloudKitActivityPushFetchCoordinator.swift`)
- **UNKNOWN:** Gibt es außerhalb dieses ZIPs eine CI-/Release-Pipeline, die Secrets, Signing und Push-/CloudKit-Umgebungen korrekt trennt?
- **UNKNOWN:** Gibt es eine beabsichtigte Datenbereinigung für lokale Caches (`SearchHistoryManager`, `RecommendationsCacheManager`, `PersonPopularityStore`, Image Cache) oder wachsen diese unbegrenzt/best-effort? (`filmfreaks/SearchHistoryManager.swift`, `filmfreaks/RecommendationsCacheManager.swift`, `filmfreaks/PersonPopularityStore.swift`, `filmfreaks/CachedAsyncImage.swift`)
- **UNKNOWN:** Ist die Public-DB-Nutzung für Default-/Legacy-Gruppen fachlich noch aktiv gewünscht, oder sollte mittelfristig alles über `GroupContext`/Zones laufen?

## First 3 Refactors I would do (P0)

### 1) Movie Cloud Load Pipeline zerlegen
- **Ziel**
  - `MovieStore+CloudSync.swift` in klar testbare Phasen aufteilen: Routing/Fetch, Delta Apply, Ratings Merge, Final Apply.
- **Betroffene Dateien**
  - `filmfreaks/MovieStore/MovieStore+CloudSync.swift`
  - neu: `MovieStore+CloudLoad.swift`
  - neu: `MovieStore+CloudApply.swift`
  - neu: `MovieStore+CloudRatingsMerge.swift`
- **Risiko**
  - hoch, weil zentraler Datenpfad; Reihenfolgefehler können zu inkonsistenten Movies/Ratings führen.
- **Erwarteter Nutzen**
  - deutlich bessere Testbarkeit
  - geringerer Review-Radius
  - weniger Angstschweiß bei CloudKit-Änderungen

### 2) Renderpfad-Entlastung in Content + Timeline + Search
- **Ziel**
  - alle großen `filter/sort/group`-Berechnungen aus rendernahen Computed Properties in gecachte ViewModels/Snapshots ziehen.
- **Betroffene Dateien**
  - `filmfreaks/Content/ContentView.swift`
  - `filmfreaks/Content/ContentMovieItemsModel.swift`
  - `filmfreaks/Content/ContentActivityPreviewModel.swift`
  - `filmfreaks/Timeline/timelineview+data.swift`
  - `filmfreaks/MovieSearch/MovieSearchView+Derived.swift`
- **Risiko**
  - mittel; Gefahr sind semantische Sort-/Filter-Abweichungen.
- **Erwarteter Nutzen**
  - bessere Scroll- und Tip-Responsiveness
  - weniger unnötige MainActor-Arbeit
  - klarere Trennung zwischen UI und Derived Data

### 3) Goals aus der View in einen Store verschieben
- **Ziel**
  - Persistenz, Cloud-Sync und Dedupe-Logik der Goals von `GoalsView` entkoppeln.
- **Betroffene Dateien**
  - `filmfreaks/Goals/GoalsView.swift`
  - `filmfreaks/Goals/GoalsView+Persistence.swift`
  - `filmfreaks/Goals/GoalsView+Matching.swift`
  - `filmfreaks/CloudKitGoalStore.swift`
  - neu: `filmfreaks/Goals/GoalsStore.swift`
- **Risiko**
  - mittel; Feature ist fachlich kleiner als Movies, aber hat Persistenz- und Migrationsabhängigkeiten.
- **Erwarteter Nutzen**
  - bessere Unit-Testbarkeit
  - konsistenteres Store-Muster im Projekt
  - weniger Side Effects direkt in der View
