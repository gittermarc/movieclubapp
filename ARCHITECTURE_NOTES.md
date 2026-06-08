# ARCHITECTURE_NOTES.md

Stand: Scan des ZIP-Projekts `tmc_context.zip` am 2026-06-08. Diese Notizen priorisieren Sync/Storage/Model, Entry Points/Navigation und Wartbarkeit/Performance großer Views/Services.

## 1. Kernbefund

- Die App ist **SwiftUI + ObservableObject Stores + Codable JSON + manuelles CloudKit**.
- SwiftData/CoreData wurden im App-Code nicht gefunden: kein `import SwiftData`, kein `@Model`, kein CoreData-Stack.
- App-Code: 320 Swift-Dateien, ca. 39.384 Zeilen unter `filmfreaks/`.
- Tests: 48 Swift-Testdateien unter `filmfreaksTests/` und `filmfreaksUITests/`.
- Wichtigster Architektur-Hotspot: CloudKit-Sync ist funktionsreich, aber über mehrere Stores/Coordinators verteilt; einige kritische Queues sind nur in-memory und einige Routing-/Sharing-Regeln sind dupliziert.

## 2. Storage-/Sync-Architektur im Detail

### 2.1 Local Storage

- `filmfreaks/PersistenceManager.swift`
  - Zuständig für Movies, Backlog, Users.
  - Base dir: `Application Support/FilmFreaks/`.
  - Group-scoped Dateien: `groups/<group>/movies_watched.json`, `movies_backlog.json`, `users.json`.
  - Debounced writes mit `DispatchQueue(label: "filmfreaks.persistence")`, `debounceSeconds = 0.55`, atomic writes.
  - Migration aus alten UserDefaults-Keys: `FilmFreaks.movies.v1`, `FilmFreaks.backlogMovies.v1`, `FilmFreaks.users.v1`, `Users_*`, `KnownGroups`.
  - Risiko: `pendingWrites` speichert WorkItems, aber der WorkItem entfernt sich nach erfolgreichem Write nicht aus `pendingWrites`; dadurch können erledigte WorkItems im Dictionary bleiben, bis ein späteres Flush/Test oder erneuter Write stattfindet.
- `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`
  - `actor`-basierte lokale MovieNight-Persistenz.
  - Base dir: `Application Support/filmfreaks/`.
  - Eine Datei `movieNights.json` für alle Gruppen und MovieNight-Domänen.
  - Schema `Snapshot` Version 3 mit Events, Responses, Activity, Presets.
  - Risiko: Load-/Save-Fehler werden geschluckt; ein defektes JSON führt zu `.empty()` ohne sichtbare Recovery.
- UserDefaults
  - Kleine Konfigurationen, Selection, Sync-Meta, Change Tokens, Goals, Search/Recommendation Caches, Person Popularity.
  - Risiko: Group-scoping ist nicht überall konsistent, z.B. `GoalsStore.yearlyGoalsStorageKey = "ViewingGoalsByYear.v1"` ist nicht group-scoped.

### 2.2 CloudKit Routing

- Zentraler Router: `filmfreaks/CloudKitRouting.swift`.
- Regeln:
  - `nil`/leere Group-ID -> public database.
  - `GroupContext` vorhanden -> private/shared database + Record-Zone.
  - UUID-artige Group-ID ohne `GroupContext` -> `CloudKitRoutingError.groupContextNotReady`.
  - Nicht-UUID Legacy-Gruppe ohne Context -> public database.
- Bewertung:
  - Die UUID-Schutzregel ist korrekt und wichtig, weil sonst Records in der public DB landen könnten.
  - Duplikat: `filmfreaks/CloudKitMovieNightStore/CloudKitMovieNightStore+Routing.swift` implementiert eigene Routing-Logik statt `CloudKitRouting` zu nutzen.
  - Duplikat: `MovieNightCloudSyncCoordinator.swift` hat eigene `requiresGroupContext`/`isRoutingReady` Heuristik.

### 2.3 CloudKit Recordtypen

| Domain | Recordtyp(en) | Pfade | Schlüssel-Design |
|---|---|---|---|
| Gruppen | `FFGroup` + `CKShare` | `CloudKitGroupStore/*` | Zone `group.<UUID>`, Root recordName = group ID. |
| Filme | `Movie` | `CloudKitMovieStore/*` | recordName = `Movie.id`; fields `payload`, `isBacklog`, `updatedAt`, `groupId`. |
| Ratings | `MovieRating` | `CloudKitRatingStore/*` | recordName = base64url von `groupId|movieId|reviewerId`. |
| Mitglieder | `GroupMember` | `CloudKitUserStore.swift` | recordName = `<groupId>|<memberId>`, Legacy by canonical name. |
| Ziele | `ViewingGoal`, `ViewingCustomGoals` | `CloudKitGoalStore.swift` | Jahresziel pro Jahr, Custom Goals als Payload pro Gruppe. |
| Filmabende | `MovieNightEvent`, `MovieNightResponse`, `MovieNightActivity`, `MovieRoulettePreset` | `CloudKitMovieNightStore/*` | Events/Activity/Presets per UUID, Responses per Composite Key. |

### 2.4 Incremental Sync / Tokens

- `filmfreaks/CloudKitZoneChanges.swift` kapselt `CKFetchRecordZoneChangesOperation`.
- `filmfreaks/CloudKitZoneChangeTokenStore.swift` persistiert `CKServerChangeToken` pro Namespace, Scope, Zone, Owner.
- Namespaces:
  - Movies: `movies`.
  - Ratings: `ratings`.
  - Movie Nights: `movieNights`.
- Risiko: `CKError.changeTokenExpired` wird nicht zentral behandelt. Der Wrapper wirft Fehler, aber es gibt keinen sichtbaren Recovery-Pfad „Token löschen + Full Zone Fetch“.

### 2.5 Upload Queues

- Movies: `filmfreaks/MovieCloudSyncCoordinator.swift`.
  - Debounced `0.8s`, pending saves/deletes in Dictionaries.
  - CloudKit-Batch wird über `CloudKitMovieStore.modifyBatch` geschrieben; dort gibt es Chunks à 200.
  - Läuft auf `@MainActor`.
- Movie Nights: `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift`.
  - Debounced `0.8s`, vier Record-Domänen plus Deletes.
  - Group-by-group Flush.
  - `CloudKitMovieNightStore.modifyBatch` schreibt alles in einer Operation, ohne Chunking.
  - `publishPendingCount` und `snapshotForGroup` filtern alle Pending-Dictionaries pro Gruppe; bei vielen Pending Items O(Gruppen × Pending × Recordtypen).
- Risiko für beide:
  - Pending Queues sind in-memory; kein persistentes Dirty Journal.
  - Nach App-Kill bleiben lokale JSON-Daten erhalten, aber die konkrete CloudKit-Upload-Absicht kann verloren gehen.
  - Beim nächsten Launch gibt es keine klare Startup-Diff-Reconciliation für „lokal geändert, Cloud noch nicht“.

### 2.6 Sharing / Parent Hierarchy

- `filmfreaks/CloudKitGroupStore/CloudKitGroupStore+Sharing.swift` setzt/repairt `record.parent` für:
  - `Movie`
  - `MovieRating`
  - `GroupMember`
  - `ViewingGoal`
  - `ViewingCustomGoals`
- Risiko: MovieNight-Recordtypen fehlen in der Repair-Liste:
  - `MovieNightEvent`
  - `MovieNightResponse`
  - `MovieNightActivity`
  - `MovieRoulettePreset`
- Neue Writes in `CloudKitMovieNightStore+Modify.swift` setzen zwar `record.parent`, aber vorhandene Records aus älteren Versionen könnten bei Share-Teilnehmern unsichtbar bleiben.

## 3. Entry Points + Navigation

### 3.1 App Entry

- `filmfreaks/filmfreaksApp.swift`
  - `@main struct filmfreaksApp: App`.
  - `@UIApplicationDelegateAdaptor(CloudKitShareAppDelegate.self)` für CloudKit Share Acceptance und Push Handling.
  - Konfiguriert `URLCache.shared` mit 100 MB Memory und 500 MB Disk.
  - Erzeugt zentrale EnvironmentObjects:
    - `MovieStore(useCloud: true)`
    - `MovieNightStore()`
    - `UserStore()`
    - `CloudKitGroupStore()`
    - `NetworkMonitor.shared`
    - `DisplaySettings()`
    - `AppRefreshCoordinator()`
  - `WindowGroup` rendert `ContentView`, `ToastHost`, `SplashView`.
  - Bei `scenePhase == .active` wird Refresh-Cascade getriggert:
    - `groupStore.refresh()`
    - `movieNightStore.flushPendingCloudChanges()`
    - `movieStore.refreshFromCloud(force: false)`
    - `userStore.refreshFromCloud(force: false)`
    - `movieNightStore.refreshFromCloud(groupId: movieStore.currentGroupId, force: false)`

### 3.2 Root View / Sheet Router

- `filmfreaks/Content/ContentView.swift`
  - Root mit `NavigationStack`.
  - State für Mode, ViewStyle, Search, Sort, Filter, Sheet Route, Onboarding.
  - `ContentHeaderView`, `ContentMainAreaView`, `ContentToolbar`.
- `filmfreaks/Content/ContentRouting.swift`
  - `ContentRoute`: `settings`, `quickStart`, `movieSearch`, `users`, `stats`, `timeline`, `calendar`, `activity`, `goals`, `groupSettings`.
  - Alle Hauptrouten werden per `.sheet(item:)` präsentiert.
  - `movieSearch` übergibt `existingWatched`, `existingBacklog` sowie Add-Callbacks.
  - Add-Callbacks reichern Movies mit `currentGroupId`, `currentGroupName`, `addedAt`, `addedById`, `addedByName` an.
- Navigation Pattern:
  - Haupt-App: Stack + Sheets, kein globales TabView.
  - Listen/Grid öffnen `MovieDetailView` via `NavigationLink`.
  - Featurebereiche nutzen eigene `NavigationStack`s in Sheets.

### 3.3 Deep Links / Shares / Push

- `filmfreaks/CloudKitShareAppDelegate.swift`
  - Notifications permission bootstrap.
  - Remote Notification Fetch an `CloudKitActivityPushFetchCoordinator.fetchAndLog`.
  - `UNUserNotificationCenterDelegate` tap -> `PushDeepLinkRouter.route`.
- `filmfreaks/CloudKitShareSceneDelegate.swift`
  - Cold/Warm CloudKit Share Acceptance.
  - Cold-start Push Deep Link.
- `filmfreaks/CloudKitShareCoordinator.swift`
  - `CKAcceptSharesOperation`, Toasts, `.cloudKitShareAccepted` notification.
- `filmfreaks/Content/ContentView+DeepLink.swift`
  - Erwartet `groupId` im `userInfo`.
  - Aktiviert `GroupContext`, lädt Gruppen/User/Movies/MovieNights und routet zu `.activity`.
- Risiko: `CloudKitActivityPushFetchCoordinator.fetchAndHandle` läuft nur in `#if DEBUG`; Release gibt `false` zurück. Ob das gewollt ist, ist **UNKNOWN**.

## 4. Big Files List: Top 15 Dateien nach Zeilen

| Rang | Zeilen | Pfad | Grober Zweck | Warum riskant |
|---:|---:|---|---|---|
| 1 | 446 | `filmfreaks/MovieNights/Roulette/MovieRouletteView.swift` | Roulette-Screen, Sheets, Store-Sync, Kandidatenanzeige | Große View; `currentGroupBacklogMovies` nutzt Map + `first(where:)` je ID => O(n²); viele onReceive/onChange. |
| 2 | 432 | `filmfreaks/Settings/GroupSettingsSections.swift` | Group-Settings Cards/Sections/Subviews | Viele UI-Komponenten und Actions in einem File; hoher Änderungs-/Merge-Konflikt-Radius. |
| 3 | 413 | `filmfreaks/Stats/StatsSnapshotBuilder+TasteDynamics.swift` | Taste-/Reviewer-Dynamik-Aggregationen | Algorithmisch komplex; potenziell viele Paar-/Rating-Auswertungen; Korrektheitsrisiko. |
| 4 | 405 | `filmfreaks/Stats/StatsSnapshotBuilder.swift` | Zentrale Stats-Aggregation | Viele Full-Array-Passes und Sorts; Änderungen können mehrere Karten beeinflussen. |
| 5 | 396 | `filmfreaks/MovieStore/MovieStore+CloudSync.swift` | Movie/Ratings Cloud Refresh, Merge, Initial Upload | Kritischer Datenpfad; Change-Token, lokale Ratings, Deletes, Group-Switch und Initial Upload in einer Datei. |
| 6 | 387 | `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift` | Debounced Upload Queue für 4 MovieNight-Recordtypen | MainActor, in-memory Queue, kein Chunking im Store, dupliziert Routing-Heuristik, O(n)-Scans. |
| 7 | 369 | `filmfreaks/ViewingCustomGoal.swift` | Custom Goal Types, Rules, Codable Migration | Persistenz-/Migrationsmodell; kleine Änderungen können alte Payloads brechen. |
| 8 | 366 | `filmfreaks/Movie.swift` | Core Movie, Rating, CastMember, Codable Migration | Zentrale Entity; Cloud payload, UI, Stats und Persistence hängen daran. |
| 9 | 355 | `filmfreaks/Stats/StatsView+Cards.Leaderboards.swift` | Leaderboard-Karten im Stats-UI | Große UI-Datei; Risiko für View invalidation und schwer testbare Präsentationslogik. |
| 10 | 350 | `filmfreaks/Settings/GroupSettingsView.swift` | Gruppenverwaltung, Share/Delete/Switch/Refresh | Viel State/Actions; `activeCardSnapshot` wird direkt im Renderpfad berechnet. |
| 11 | 343 | `filmfreaks/PersistenceManager.swift` | JSON-Persistenz, Migration, Debounced Writes | Storage-Kern; Migration + Writer + Pfadlogik gekoppelt; erledigte WorkItems bleiben potenziell referenziert. |
| 12 | 341 | `filmfreaks/MovieDetail/MovieDetailView.swift` | Filmdetail, Sheets, Rating/Provider/Person-Flows | Hoher State-Surface; `onAppear` startet TMDb Task statt `.task(id:)`; Duplicate Loads möglich. |
| 13 | 335 | `filmfreaks/CloudKitUserStore.swift` | GroupMember CloudKit CRUD, Legacy-Migration | Identity-/Dedupe-kritisch; Fehler wirken auf Ratings/Notifications/User-Auswahl. |
| 14 | 332 | `filmfreaks/CloudKitMovieStore/CloudKitMovieStore+Modify.swift` | Movie CloudKit Save/Batch/Delete/Conflict | Kritischer Write-Pfad; Merge-/Conflict-Regeln müssen sehr stabil bleiben. |
| 15 | 327 | `filmfreaks/Stats/StatsSnapshotBuilder+RatingDimensions.swift` | Rating-Dimension-Aggregationen | Komplexe fachliche Sort-/Aggregationslogik; Performance/Korrektheitsrisiko bei großen Daten. |

## 5. Hot Path Analyse

### 5.1 Rendering / Scrolling

#### Home Liste/Grid

- Pfade:
  - `filmfreaks/Content/ContentMainAreaView.swift`
  - `filmfreaks/Content/ContentMovieItemsModel.swift`
  - `filmfreaks/Content/ContentMovieItemsSnapshotBuilder.swift`
  - `filmfreaks/Content/ContentView+Lifecycle.swift`
- Gute Entscheidung:
  - Filter/Sort/Search werden über `ContentMovieItemsModel` in `Task.detached` berechnet, nicht im `body`.
  - `MovieSearchIndexCache` reduziert Normalisierungskosten.
- Hotspot:
  - `ContentView+Lifecycle.scheduleMovieItemsRefresh()` setzt `debounceSeconds: 0` und kopiert komplette `movieStore.movies`/`backlogMovies` bei jeder Änderung in den Task.
  - Bei schnellen Batch-Mutationen kann das viele Snapshot-Builds auslösen.
- Hotspot:
  - `IndexedMovie` speichert Array-Index. In `ContentMainAreaView.posterGrid` wird gegen stale indices geguarded, weil SwiftUI beim Gruppenwechsel kurz alte Items rendern kann.
  - Grund: Index-basierte Binding-Navigation ist anfällig gegen Reorder/Delete/Group-Switch.
  - Refactor: ID-basierte Detailroute + Binding-Lookup nach UUID.

#### Group Settings Hero / Active Card

- Pfade:
  - `filmfreaks/Settings/GroupSettingsView.swift`
  - `filmfreaks/Settings/GroupSettingsActiveCardSnapshot.swift`
- Hotspot:
  - `activeCardSnapshot` ist eine computed property in der View.
  - Sie ruft `movieStore.activityEvents(...)`, `movieNightStore.activityEvents(...)` und `GroupSettingsActiveCardSnapshotBuilder.build(...)` direkt im Renderpfad.
  - `GroupSettingsActiveCardSnapshotBuilder` kombiniert Movie/Backlog und Activity-Vorschau.
- Konkreter Grund:
  - Expensive derived data im `body`-Pfad; potenziell exzessive View invalidation bei jeder Published-Änderung in Movie/User/MovieNight/DisplaySettings.
- Refactor:
  - `GroupSettingsViewModel` mit debounced Snapshot und Input-Fingerprint.

#### Movie Roulette

- Pfad: `filmfreaks/MovieNights/Roulette/MovieRouletteView.swift`.
- Hotspot:
  - `currentGroupBacklogMovies` baut Kandidaten und sucht danach für jede Movie-ID mit `movieStore.backlogMovies.first(where:)` das Movie.
  - Konkreter Grund: O(n²) Lookup bei großer Backlogliste; wird bei Preset-Manager-Sheet-Auswertung relevant.
- Refactor:
  - Einmal `[UUID: Movie]` aus `backlogMovies` bilden oder `MovieRouletteCandidate` direkt mit vollständigem `Movie`/Ref liefern.

#### Stats

- Pfade:
  - `filmfreaks/Stats/StatsViewModel.swift`
  - `filmfreaks/Stats/StatsSnapshotBuilder*.swift`
- Gute Entscheidung:
  - 200ms Debounce.
  - Snapshot wird detached auf `.userInitiated` berechnet.
  - Generation Guard verhindert stale Apply.
- Hotspot:
  - Builder-Dateien machen viele Full-Array-Passes, Sorts und Reviewer-/Taste-Auswertungen.
  - Bei sehr großen Movie-/Rating-Daten kann CPU steigen, auch wenn nicht auf dem MainActor.
- Hotspot:
  - `PersonPopularityStore` ist `@MainActor` und `preloadPopularity` macht Batches mit TaskGroup. Das ist netzwerkfreundlich, aber Actor-State und SaveToDisk laufen über MainActor.
  - `isExpired(_:)` existiert, wird aber nicht genutzt; TTL-Refresh-Verhalten ist **UNKNOWN**.

#### Movie Detail / TMDb

- Pfade:
  - `filmfreaks/MovieDetail/MovieDetailView.swift`
  - `filmfreaks/MovieDetail/MovieDetailView+Lifecycle.swift`
  - `filmfreaks/MovieDetail/MovieDetailLoadCoordinator.swift`
  - `filmfreaks/TMDbAPI/*`
- Hotspot:
  - `handleOnAppear()` startet `Task { await loadDetails() }`.
  - Konkreter Grund: Unstrukturierte Task-Lifetime; bei mehrfachen Appears kann derselbe TMDb-Fetch erneut starten. `.task(id: movie.tmdbId)` wäre besser cancellable/gebunden.
- Hotspot:
  - `MovieStore.migrateCastDataIfNeeded()` in `MovieStore+Mutations.swift` nutzt `withTaskGroup` über alle Zielmovies ohne sichtbares Parallelitätslimit.
  - Konkreter Grund: Viele Legacy-Movies könnten sehr viele TMDb Credits Requests parallel starten.

#### Images

- Pfad: `filmfreaks/CachedAsyncImage.swift`.
- Gute Entscheidung:
  - Memory `NSCache`, Disk Cache, in-flight Dedupe pro URL.
- Risiko:
  - **UNKNOWN:** Ob Bilddaten vor UI-Nutzung downsampled werden. Bei großen Poster-Grids kann Full-Decode Memory/CPU belasten.

### 5.2 Sync / Storage

#### Movies + Ratings

- Pfade:
  - `filmfreaks/MovieStore/MovieStore+CloudSync.swift`
  - `filmfreaks/MovieStore/MovieStore+Mutations.swift`
  - `filmfreaks/CloudKitMovieStore/*`
  - `filmfreaks/CloudKitRatingStore/*`
- Positiv:
  - Movie-Payload trennt Ratings; `MovieRating` separat skaliert besser für Multi-User-Konflikte.
  - Local ratings werden vor Cloud Reload konserviert und mit Remote Ratings gemerged.
  - Group-Switch mid-flight wird geprüft; falsches Apply wird verworfen.
- Hotspot:
  - Rating delete merge filtert pro Movie `changes.deletedKeys.filter { $0.movieId == copy.id }`.
  - Konkreter Grund: O(MovieCount × DeletedRatingKeys), wenn viele Rating-Deletes eintreffen.
  - Refactor: `Dictionary<UUID, Set<String>>` für deleted reviewer keys vor dem Map bilden.
- Hotspot:
  - `enqueueCloudSync(newList:oldList:isBacklog:)` baut Dictionaries/Sets und filtert bei jedem Array-`didSet`.
  - Konkreter Grund: O(n) pro UI-Mutation; bei Bulk-Updates potenziell MainActor-Last.
- Risiko:
  - Pending Uploads nicht persistent. Lokaler Add/Edit kann nach App-Kill lokal sichtbar bleiben, aber nicht zwingend automatisch in Cloud hochgeladen werden.

#### Movie Nights

- Pfade:
  - `filmfreaks/MovieNights/MovieNightStore/*`
  - `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift`
  - `filmfreaks/CloudKitMovieNightStore/*`
- Positiv:
  - Local-first Writes mit Cloud queue.
  - Zone Changes für shared/zone groups.
  - Merge nach `updatedAt`/`respondedAt`, Activity capped auf 200.
- Hotspot:
  - `CloudKitMovieNightStore+Modify.swift` schreibt alle Saves/Deletes in einer `CKModifyRecordsOperation`.
  - Konkreter Grund: kein Chunking; große Presets/Activity-Backlogs/Batch-Änderungen können CloudKit-Limits oder partial failures härter treffen.
- Hotspot:
  - `MovieNightCloudSyncCoordinator.publishPendingCount` und `snapshotForGroup` scannen alle Pending-Dictionaries.
  - Konkreter Grund: O(n)-Scans auf MainActor bei jedem Queue/Flush.
- Risiko:
  - Ein Fehler bei einer Gruppe `break`t den Flush-Loop; spätere Gruppen werden bis zum nächsten Trigger blockiert.
- Risiko:
  - Kommentare in `MovieNightActivityEvent.swift` und `MovieNightStore+CloudRefresh.swift` sind veraltet bzw. widersprechen existierendem Cloud-Write-Pfad.

#### Goals

- Pfade:
  - `filmfreaks/Goals/GoalsStore.swift`
  - `filmfreaks/CloudKitGoalStore.swift`
  - `filmfreaks/ViewingCustomGoal.swift`
- Hotspot/Risiko:
  - Jahresziele sind lokal nicht group-scoped (`ViewingGoalsByYear.v1`), CloudKit aber group-scoped.
  - Konkreter Grund: Gruppenwechsel kann lokal falsche Jahresziele anzeigen/persistieren.
- Risiko:
  - `syncFromCloud` übernimmt Remote nur, wenn `remoteYearly` bzw. `remoteCustom.goals` nicht leer sind.
  - Konkreter Grund: Remote-Löschung/leer kann lokal stale Daten nicht entfernen.
- Tradeoff:
  - Custom Goals als ein versionierter Payload sind schemaflexibel, aber last-writer-wins Konflikte können parallele Änderungen verlieren.

#### Users

- Pfade:
  - `filmfreaks/Users+Store/UserStore.swift`
  - `filmfreaks/Users+Store/UserStore+CloudRefresh.swift`
  - `filmfreaks/CloudKitUserStore.swift`
- Positiv:
  - Stable `memberId` Migration für Legacy Records.
  - Per-group selected user via `SelectedUserSelectionStore`.
- Risiko:
  - Initial Bootstrap lädt leere Cloud und lädt lokale User sequenziell hoch.
  - Nutzerzahl ist vermutlich klein; trotzdem wäre Batch-Upload konsistenter.
- Risiko:
  - Konfliktpolitik bei Rename/Delete auf mehreren Geräten ist **UNKNOWN**.

#### CloudKit Subscriptions / Push

- Pfade:
  - `filmfreaks/CloudKit/CloudKitActivitySubscriptionManager.swift`
  - `filmfreaks/CloudKit/CloudKitActivityPushFetchCoordinator.swift`
  - `filmfreaks/Notifications/*`
- Positiv:
  - Deterministische Subscription IDs pro Gruppe/Kind.
  - Subscriptions für `Movie`, `MovieRating`, `MovieNightActivity`.
- Risiko:
  - Release-Push-Fetch unklar, weil FetchCoordinator außerhalb DEBUG `false` zurückgibt.
- Risiko:
  - Subscriptions feuern visible alert + content-available; UX/Rate-Limits bei hoher Aktivität sind **UNKNOWN**.

### 5.3 Concurrency

- MainActor Stores:
  - `MovieStore`, `MovieNightStore`, `UserStore`, `GoalsStore`, `CloudKitGroupStore`, `PersonPopularityStore`.
- Positive Pattern:
  - `AppRefreshCoordinator` coalesced Resume-Refreshs.
  - `ContentMovieItemsModel` und `StatsViewModel` nutzen detached Tasks + Generation Guard.
- Risk Pattern:
  - `Task { ... }` in `onAppear`, init, network reconnect und mutations ohne zentrale Cancellation.
  - Sync Coordinators liegen auf MainActor; Dictionary-Snapshot und Pending-Zählung passieren dort.
  - `MovieStore.migrateCastDataIfNeeded()` startet potenziell viele TMDb Requests parallel.
  - `CloudKit` async completions sind nicht unbedingt MainActor-bound, aber Store-Anwendung schon; große Merges blockieren UI potenziell.

## 6. Refactor Map

### 6.1 Konkrete Splits

#### `filmfreaks/MovieStore/MovieStore+CloudSync.swift`

Aufteilen in:

- `MovieCloudRefreshService`
  - Fetch movies, fetch ratings, apply zone/public strategy.
- `MovieRatingMergeService`
  - `mergeRatings`, delete-key indexing, reviewer key normalization.
- `MovieInitialUploadService`
  - Initial upload policy, startup reconciliation.
- `MovieCastMigrationService`
  - Cast migration mit bounded concurrency und retry/backoff.
- `MovieSyncStateStore`
  - Sync meta, last attempt/success/error, pending counts.

Ziel: Kritische Datenlogik testbarer machen und MainActor-Arbeit reduzieren.

#### `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift`

Aufteilen in:

- `MovieNightPendingSyncQueue`
  - Pending Dictionaries, count per group, snapshot by group.
- `MovieNightSyncRouter`
  - Nutzung von `CloudKitRouting` statt eigener Heuristik.
- `MovieNightSyncFlusher`
  - Group-by-group Flush, Retry Policy, Fehlerisolierung.
- `MovieNightSyncMetrics`
  - Pending counts, last success/error, debug events.

Ziel: O(n)-Scans verringern, Routing dupliziert entfernen, Fehler einer Gruppe isolieren.

#### `filmfreaks/CloudKitMovieNightStore/CloudKitMovieNightStore+Modify.swift`

Aufteilen in:

- `MovieNightRecordBuilder+Event.swift`
- `MovieNightRecordBuilder+Response.swift`
- `MovieNightRecordBuilder+Activity.swift`
- `MovieNightRecordBuilder+Preset.swift`
- `CloudKitBatchModifyWriter.swift` als generischer Chunked Writer.

Ziel: Record-Feldmapping separat testbar machen und Batch-Limits einheitlich behandeln.

#### `filmfreaks/Settings/GroupSettingsView.swift`

Aufteilen in:

- `GroupSettingsViewModel`
  - active context, summaries, active card snapshot, refresh state.
- `GroupSettingsActions`
  - create/switch/share/delete/leave workflows.
- View bleibt rein deklarativ.

Ziel: Render-Hotspot entfernen und CloudKit-Actions isoliert testen.

#### `filmfreaks/MovieNights/Roulette/MovieRouletteView.swift`

Aufteilen/ändern:

- `MovieRouletteScreenChrome`
- `MovieRoulettePresetSheetRouter`
- `MovieRouletteBacklogIndex`
- O(n²)-Lookup in `currentGroupBacklogMovies` ersetzen.

Ziel: Wartbarkeit und bessere Performance für große Backlogs.

#### `filmfreaks/Stats/StatsSnapshotBuilder*.swift`

Weiter splitten nach fachlichen Aggregaten:

- `StatsRatingAggregateBuilder`
- `StatsTasteDynamicsBuilder`
- `StatsSuggestionQualityBuilder`
- `StatsPickInsightsBuilder`
- `StatsPeopleAggregateBuilder`

Ziel: kleinere Testtargets und klarere Input/Output-Verträge.

#### `filmfreaks/Movie.swift`

Nicht zwingend in viele Dateien fragmentieren, aber Verantwortlichkeiten trennen:

- `Rating.swift`
- `RatingCriterion.swift`
- `CastMember.swift`
- `Movie+CodableMigration.swift`
- `Movie+RatingAverages.swift`

Ziel: Core Entity kleiner, Migration bewusst isoliert.

#### `filmfreaks/PersistenceManager.swift`

Aufteilen in:

- `PersistencePaths`
- `DebouncedFileWriter`
- `LegacyUserDefaultsMigration`
- `GroupLocalDataCleaner`

Ziel: Pfad-/Migration-/Write-Risiken getrennt testbar machen.

### 6.2 Cache-/Index-Ideen

- `MovieByIdIndex`
  - Key: `groupId + watchedVersion + backlogVersion`.
  - Nutzbar für Detail-Bindings, Roulette, rating deletes, activity joins.
- `DeletedRatingKeyIndex`
  - Key: `movieId -> Set<reviewerKey>`.
  - Ersetzt O(MovieCount × DeletedKeys) in `MovieStore+CloudSync.swift`.
- `GroupSettingsActiveCardSnapshotCache`
  - Key: `groupId`, `users.count`, `movies.count`, `backlog.count`, `activity max date`, `ratingDisplayMode`.
  - Invalidierung über Published Store-Versionen, nicht über komplette Array-Equatable.
- `ContentSnapshotDebounce`
  - 50–150ms Debounce statt `0` bei Such-/Sort-/Movie-Änderungen.
  - Bei Suchtext kann `0` gewünscht sein; bei Store-Batchmutationen nicht.
- `MovieSearchIndexCache.prune(activeMovieIds:)`
  - Aktueller Cache hat keine sichtbare Prune-Strategie; entfernte Movies können bis App-Neustart im Cache bleiben.
- `PersonPopularityStore` TTL anwenden
  - `isExpired(_:)` existiert, wird aber nicht genutzt; fehlende/stale Einträge sollten gezielt neu geladen werden.
- `CloudKitDirtyJournal`
  - Persistente Liste lokaler Dirty Records pro Domain/Gruppe.
  - Key: `domain + groupId + recordId + operation + localVersion`.
  - Invalidation: nach erfolgreichem CloudKit Save/Delete oder Remote-Delete-Konflikt.
- `CloudKitTokenRecovery`
  - Bei `CKError.changeTokenExpired`: Token löschen, Full Zone Fetch erzwingen, Dirty Journal danach re-applien.
- `MovieNightPendingCountIndex`
  - Count pro Gruppe inkrementell pflegen statt bei jedem Queue alle Pending-Dictionaries zu filtern.
- `TMDbRequestLimiter`
  - Bounded concurrency und optional Retry/Backoff für Cast-Migration, Popularity Preload, Detail Reloads.

### 6.3 Vereinheitlichungen

- **CloudKitRouting überall verwenden**
  - Ersetzen in `CloudKitMovieNightStore+Routing.swift` und `MovieNightCloudSyncCoordinator.swift`.
- **CloudKit Batch Writer abstrahieren**
  - Gemeinsame Behandlung für chunks, partial failure, serverRecordChanged, rate limit, zone busy.
- **Sync Meta Pattern vereinheitlichen**
  - MovieStore, UserStore, MovieNightStore haben ähnliche Statusfelder. Gemeinsames `SyncStatusByGroup`-Modell reduziert UI-/Logik-Duplikate.
- **Local Persistence Namespace vereinheitlichen**
  - Ein `AppSupportPaths` für `FilmFreaks` statt parallele Groß-/Kleinschreibung.
- **DI-Protokolle ausbauen**
  - `GoalsCloudSyncing` ist gutes Beispiel. Ähnliches für Movie/Rating/MovieNight Cloud Stores erleichtert Tests.
- **Activity Feed Modell klären**
  - Movie/Rating Activity ist derived; MovieNight Activity ist persistiert. Dokumentation/Benennung sollte das explizit machen.
- **Error Presentation zentralisieren**
  - `print` -> `Logger` + user-visible status where relevant.

## 7. Risiken & Edge Cases

### 7.1 Datenverlust / Divergenz

- In-memory Pending Queues können nach App-Kill verloren gehen.
  - Betroffen: `MovieCloudSyncCoordinator.swift`, `MovieNightCloudSyncCoordinator.swift`, direkte `Task`-Writes in `UserStore+Mutations.swift`, `GoalsStore.swift`.
  - Folge: lokale JSON-Daten können CloudKit nicht erreichen, wenn keine spätere Mutation sie erneut queued.
- Public/Legacy Full Fetch kann lokale unsynced Änderungen eher überschreiben als Zone-Delta-Pfad.
  - Betroffen: `MovieStore+CloudSync.swift`, `CloudKitMovieStore+Query.swift`.
- MovieNight local decode Fehler -> `.empty()`.
  - Folge: lokale Filmabenddaten wirken verschwunden, ohne Repair UI.
- Goals remote empty wird nicht als leer angewendet.
  - Folge: gelöschte oder leere Ziele bleiben lokal stale.

### 7.2 Migrationen

- `Movie.swift` hat Legacy-Cast-Decoding von `[String]` zu `[CastMember]` mit Legacy-IDs.
- `ViewingCustomGoalsPayload` migriert Legacy-Versionen zu Version 3.
- `CloudKitUserStore.swift` migriert `GroupMember` von name-basiertem RecordName zu `memberId`.
- Risiken:
  - Neue non-optional Felder in Codable-Modellen ohne Default brechen alte JSON-Dateien.
  - CloudKit Schema kann Felder/Indexes erfordern; Dashboard-State ist **UNKNOWN**.
  - `PersistenceManager` lässt alte UserDefaults-Keys bewusst stehen; Rollback-freundlich, aber stale Quellen bleiben.

### 7.3 Multi-Device / Offline

- Ratings pro Reviewer als eigener Record sind gut für Multi-User.
- Movie payload conflict merge existiert in `CloudKitMovieStore+Merge.swift`.
- Custom Goals als Einzelpayload pro Gruppe riskieren last-writer-wins-Verlust bei parallelen Änderungen.
- MovieNight Merge basiert auf Timestamps; Clock skew zwischen Geräten kann Konflikte falsch entscheiden.
- Activity capped auf 200; alte Aktivitäten verschwinden lokal/remote-semantisch je nach Merge. Erwartetes Retention-Verhalten ist **UNKNOWN**.

### 7.4 CloudKit Share / Collaboration

- Records in shared zones müssen Parent Root setzen.
- Neue MovieNight writes tun das, aber Share-Hierarchy-Repair lässt MovieNight-Typen aus.
- `CloudKitGroupStore.refresh()` repairt owned groups einmal per UserDefaults-Flag.
- Wenn Repair-Liste später erweitert wird, alte `ff.ck.shareHierarchyRepair.v1.<group>` Flags könnten verhindern, dass neue Typen repariert werden.
  - Refactor: Repair-Version erhöhen oder per record type eigene Repair-Flags.

### 7.5 Security / Secrets

- `filmfreaks/Secrets.xcconfig` enthält im ZIP einen Klartext-`TMDB_API_KEY`.
- `TMDbAPI.swift` kommentiert korrekt, dass ein Client API Key nie wirklich geheim ist.
- Trotzdem sollte der gefundene Key rotiert und `Secrets.xcconfig` aus getrackten Artefakten entfernt werden.
- CloudKit Container/Bundle IDs sind keine Secrets.

### 7.6 Build / Release

- `IPHONEOS_DEPLOYMENT_TARGET = 26.0`; Absicht **UNKNOWN**.
- Entitlements enthalten `aps-environment = development`; Release-Handling **UNKNOWN**.
- `CloudKitActivityPushFetchCoordinator` ist DEBUG-only; Release-Verhalten **UNKNOWN**.
- Kein SPM gefunden; externe Dependencies **UNKNOWN**, aber aus Projektstruktur nicht sichtbar.

## 8. Observability / Debuggability

### Ist-Zustand

- `PersistenceManager.swift` nutzt `os.Logger` mit Subsystem `filmfreaks`, Category `Persistence`.
- Viele CloudKit-Pfade nutzen `print`, z.B. `MovieStore+CloudSync.swift`, `CloudKitActivityPushFetchCoordinator.swift`, `UserStore+CloudRefresh.swift`.
- User-visible Feedback:
  - Toasts über `ToastCenter` / `ToastHost`.
  - Sync status in Stores (`lastCloudSyncAt`, `lastCloudSyncError`, pending counts).
- Tests existieren für:
  - Cloud Routing und Token Store.
  - Persistence und Fixtures.
  - Content Snapshot Models.
  - MovieNight Store/Merge/Retry/Roulette.
  - Stats Snapshot/ViewModel.
  - GoalsStore.

### Lücken

- Kein zentraler Sync Event Log sichtbar.
- Keine strukturierte CloudKit Error-Kategorisierung pro Domain.
- Keine Metric/Signpost für Snapshot-Build-Zeiten, CloudKit Batch-Größen, Queue-Laufzeiten.
- Keine sichtbare Recovery-UI für corrupt local JSON oder token expired.
- Push Debugging ist DEBUG-lastig; Release-Diagnose **UNKNOWN**.

### Vorschläge

- `SyncLogger` mit Kategorien:
  - `sync.movie.refresh`
  - `sync.movie.flush`
  - `sync.rating.refresh`
  - `sync.movienight.flush`
  - `sync.group.share`
  - `sync.token`
- Pro Sync-Lauf strukturierte Felder:
  - `groupIdHash`, `scope`, `zoneName`, `namespace`, `changedCount`, `deletedCount`, `pendingBefore`, `pendingAfter`, `durationMs`, `errorCode`.
- Debug Screen unter Settings:
  - aktive GroupContext-Daten
  - pending counts pro Domain
  - letzte Token-Zeit pro Namespace
  - letzte CloudKit Errors
  - lokale Datei-URLs/Größen ohne personenbezogene Payloads
- Performance Signposts:
  - `StatsSnapshotBuilder.computeSnapshot`
  - `ContentMovieItemsSnapshotBuilder.build`
  - `MovieStore.loadFromCloud apply`
  - `MovieNightCloudSyncCoordinator.flushNow`
- Repro Playbooks dokumentieren:
  - Offline Add Movie -> App Kill -> Relaunch -> Cloud Check.
  - Share Owner creates MovieNight before/after sharing -> Participant visibility.
  - Token expired simulation -> recovery.
  - Group switch during Cloud fetch -> no wrong apply.

## 9. Open Questions

- **UNKNOWN:** Ist iOS `26.0` als Deployment Target absichtlich?
- **UNKNOWN:** Welche Rolle hat `TMC - The Movie Club.xcodeproj` neben `filmfreaks.xcodeproj`?
- **UNKNOWN:** Ist `Secrets.xcconfig` im echten Repo getrackt oder nur im ZIP enthalten?
- **UNKNOWN:** Welche CloudKit Schema-Felder und Query Indexes sind im Dashboard deployed?
- **UNKNOWN:** Sind Legacy/public Gruppen noch aktiv unterstütztes Feature oder nur Migrationspfad?
- **UNKNOWN:** Soll CloudKit Push-Fetch in Release aktiv sein?
- **UNKNOWN:** Wie wird `aps-environment = development` beim Release-Export überschrieben?
- **UNKNOWN:** Gewünschtes Konfliktmodell für Custom Goals bei paralleler Bearbeitung.
- **UNKNOWN:** Gewünschtes Konfliktmodell für MovieNight Status/Response bei Clock Skew.
- **UNKNOWN:** Soll Activity Retention fest 200 sein, oder CloudKit-/lokal unterschiedlich?
- **UNKNOWN:** Soll `PersonPopularityStore` TTL wirklich ignorieren, sobald ein Record existiert?
- **UNKNOWN:** Sind TMDb Rate Limits/Retry-Anforderungen produktseitig definiert?
- **UNKNOWN:** Gibt es Datenschutzvorgaben für Logs, actor names, movie titles in Notifications?
- **UNKNOWN:** Gibt es ein manuelles CloudKit Schema Migration/Deployment-Dokument?

## 10. First 3 Refactors I would do (P0)

### P0.1 Sync Safety Baseline: Routing, Dirty Journal, Token Recovery, Chunking

- Ziel
  - CloudKit-Sync gegen Datenverlust und falsches Routing absichern.
  - Alle Domains sollen dieselben Regeln für Routing, Token-Recovery, Chunking und Pending-Durability nutzen.
- Betroffene Dateien
  - `filmfreaks/CloudKitRouting.swift`
  - `filmfreaks/CloudKitZoneChanges.swift`
  - `filmfreaks/CloudKitZoneChangeTokenStore.swift`
  - `filmfreaks/MovieCloudSyncCoordinator.swift`
  - `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift`
  - `filmfreaks/CloudKitMovieNightStore/CloudKitMovieNightStore+Modify.swift`
  - `filmfreaks/CloudKitMovieNightStore/CloudKitMovieNightStore+Routing.swift`
  - `filmfreaks/CloudKitGroupStore/CloudKitGroupStore+Sharing.swift`
- Risiko
  - Mittel bis hoch: Core-Sync-Pfad, CloudKit edge cases, Migration vorhandener pending/local Daten.
  - Muss mit Multi-Device, Offline, Share-Participant und Token-Expired-Szenarien getestet werden.
- Erwarteter Effekt
  - Weniger Risiko für Records im falschen Scope.
  - Recovery bei `changeTokenExpired`.
  - Keine verlorenen Upload-Absichten nach App-Kill.
  - Stabilere MovieNight-Batches bei großen Änderungen.

### P0.2 Group-Scoped Local Storage Cleanup

- Ziel
  - Lokale Daten strikt und konsistent pro Gruppe speichern und löschen.
  - Cross-group Leakage und stale Goals verhindern.
- Betroffene Dateien
  - `filmfreaks/PersistenceManager.swift`
  - `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`
  - `filmfreaks/Goals/GoalsStore.swift`
  - `filmfreaks/CloudKitGoalStore.swift`
  - `filmfreaks/MovieStore/MovieStore+Selections.swift`
  - `filmfreaks/Users+Store/UserStore+Selection.swift`
- Risiko
  - Mittel: Pfad-/Key-Migration, alte UserDefaults und bestehende lokale JSON-Dateien müssen sauber übernommen werden.
  - Besonderes Risiko bei Usern mit mehreren bestehenden Gruppen.
- Erwarteter Effekt
  - Keine falschen Jahresziele nach Gruppenwechsel.
  - Einheitliche App-Support-Struktur.
  - Gruppenlöschung/Leave kann lokale Caches vollständig und vorhersehbar entfernen.
  - Bessere Grundlage für Backup/Debug Screen.

### P0.3 Render-Hotpaths entkoppeln: GroupSettings, Roulette, ID-basierte Navigation

- Ziel
  - Teure Ableitungen und indexbasierte Bindings aus SwiftUI-Renderpfaden entfernen.
  - Große Views in testbare ViewModels/Subviews splitten.
- Betroffene Dateien
  - `filmfreaks/Settings/GroupSettingsView.swift`
  - `filmfreaks/Settings/GroupSettingsActiveCardSnapshot.swift`
  - `filmfreaks/MovieNights/Roulette/MovieRouletteView.swift`
  - `filmfreaks/MovieNights/Roulette/MovieRouletteViewModel.swift`
  - `filmfreaks/Content/ContentMainAreaView.swift`
  - `filmfreaks/Content/ContentMovieItemsModel.swift`
  - `filmfreaks/Content/ContentMovieItemsSnapshotBuilder.swift`
- Risiko
  - Niedrig bis mittel: UI-Verhalten muss gleich bleiben; Snapshot-Timing und Navigation-Bindings brauchen Tests.
  - Achtung bei Delete/Reorder/Group-Switch, weil aktuelle Guard-Logik stale indices abfängt.
- Erwarteter Effekt
  - Weniger exzessive View invalidation.
  - Bessere Scroll-/Sheet-Performance bei großen Backlogs.
  - Weniger Crash-/Wrong-Binding-Risiko durch ID-basierte Navigation.
  - Kleinere, wartbarere Feature-Dateien.
