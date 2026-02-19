# PROJECT_CONTEXT

## TL;DR
filmfreaks ist eine **iOS SwiftUI-App** zum gemeinsamen Verwalten/Bewerten von Filmen in **Gruppen** (inkl. iCloud/CloudKit Sharing).  
**Plattform:** iOS (keine Mac Catalyst Ziele im Projekt sichtbar).  
**Minimum iOS:** **26.0** (Xcode-Projekteinstellung `IPHONEOS_DEPLOYMENT_TARGET = 26.0` in `filmfreaks.xcodeproj/project.pbxproj`).  

## Key Concepts / Domänenbegriffe
- **Watched**: Liste „gesehen“ (lokal + optional CloudKit), Datenquelle `MovieStore.movies` in `filmfreaks/MovieStore.swift`.
- **Backlog**: Liste „noch schauen“ (`MovieStore.backlogMovies` in `filmfreaks/MovieStore.swift`).
- **Movie**: Zentrales Model (Codable) inkl. TMDb-Metadaten und Ratings: `filmfreaks/Movie.swift`.
- **Rating**: Bewertung pro User; wird lokal im Movie gehalten, aber **CloudKit-Sync erfolgt separat** über RecordType `MovieRating` (siehe `filmfreaks/CloudKitRatingStore.swift` + `MovieStore.upsertRating(...)` in `filmfreaks/MovieStore.swift`).
- **Group**: „CloudKit Sharing“-basierte Gruppe (eigene private Zone + CKShare) mit Root-Record `FFGroup` (`filmfreaks/CloudKitGroupStore.swift`).
- **GroupContext**: Persistierte Routing-Metadaten (DB scope + Zone + ownerName) pro Gruppe, damit Stores korrekt in private/shared DB schreiben (`filmfreaks/GroupContext.swift`).
- **Activity Feed**: Abgeleitete Events (Film hinzugefügt / bewertet) aus Movie-Metadaten & Ratings (`filmfreaks/MovieStore+Activity.swift`, UI in `filmfreaks/Content/GroupActivityListView.swift`).
- **Movie Nights**: Filmabend-Events (lokal + CloudKit geplant), Models in `filmfreaks/MovieNights/*.swift`, Store `filmfreaks/MovieNights/MovieNightStore.swift`.
- **Goals**: Jahresziele + Custom Goals (Decade/Person/Director/Genre/Keyword) – UI in `filmfreaks/Goals/*`, CloudKit in `filmfreaks/CloudKitGoalStore.swift`.

## Architecture Map (Layer/Module → Verantwortlichkeiten → Abhängigkeiten)
**UI (SwiftUI Views)**
- Root UI: `filmfreaks/Content/ContentView.swift` (+ Routing in `filmfreaks/Content/ContentRouting.swift`)
- Feature UIs: `filmfreaks/MovieDetail/*`, `filmfreaks/MovieSearch/*`, `filmfreaks/Stats/*`, `filmfreaks/Timeline/*`, `filmfreaks/MovieNights/*`, `filmfreaks/Goals/*`
- Abhängigkeiten: `@EnvironmentObject` Stores (MovieStore, UserStore, MovieNightStore, CloudKitGroupStore, DisplaySettings) aus `filmfreaks/filmfreaksApp.swift`.

**State / Stores (ObservableObject, meist @MainActor)**
- `filmfreaks/MovieStore.swift`: zentrale Domänenlogik für Movies/Backlog, lokale Persistenz, CloudKit-Sync-Orchestration.
- `filmfreaks/UserStore.swift`: Mitgliederverwaltung + CloudKit Sync (RecordType `GroupMember` via `filmfreaks/CloudKitUserStore.swift`).
- `filmfreaks/MovieNights/MovieNightStore.swift`: MovieNight Events/Responses/Activity + Sync.
- `filmfreaks/CloudKitGroupStore.swift`: Gruppenliste (owned/shared), Create + Invite/Share + Routing-Metadaten persistieren.
- `filmfreaks/DisplaySettings.swift`: UI-/Theme-Settings, `@EnvironmentObject` in `filmfreaks/filmfreaksApp.swift`.
- Querschnitt: `filmfreaks/NetworkMonitor.swift`, Toast-System (`filmfreaks/ToastHost.swift`, `filmfreaks/ToastCenter.swift`).

**Services / Persistence / Backend**
- Lokale Persistenz: `filmfreaks/PersistenceManager.swift` (Application Support, JSON, Debounce).
- CloudKit Backend:
  - Movies: `filmfreaks/CloudKitMovieStore.swift`
  - Ratings: `filmfreaks/CloudKitRatingStore.swift`
  - Members: `filmfreaks/CloudKitUserStore.swift`
  - Groups/Sharing: `filmfreaks/CloudKitGroupStore.swift`, Share handling: `filmfreaks/CloudKitShareCoordinator.swift`, `filmfreaks/CloudKitShareSceneDelegate.swift`, `filmfreaks/CloudKitShareAppDelegate.swift`
  - MovieNights: `filmfreaks/CloudKitMovieNightStore.swift`
  - Goals: `filmfreaks/CloudKitGoalStore.swift`
  - Zone-changes + Token persistence: `filmfreaks/CloudKitZoneChanges.swift`, `filmfreaks/CloudKitZoneChangeTokenStore.swift`
  - Routing: `filmfreaks/CloudKitRouting.swift` + `filmfreaks/GroupContext.swift`
- TMDb Networking: `filmfreaks/TMDbAPI.swift` (+ mapping helpers in `filmfreaks/MovieSearch/*`).

**Abhängigkeitsrichtung (vereinfacht)**
UI → Stores → (PersistenceManager, CloudKit*Store, TMDbAPI, NetworkMonitor) → System (CloudKit/Network/File IO)

## Folder Map (Ordner → Zweck)
- `filmfreaks/` (root): Stores, CloudKit Stores, Persistence, Routing, Models, UI-Querschnitt (Toast, Settings, Utilities).
- `filmfreaks/Content/`: Root-Screen + group activity feed + routing (`ContentRouting.swift`).
- `filmfreaks/MovieSearch/`: Suche, Scanner, Empfehlungen, Result Cards (größter UI-Flow neben Detail).
- `filmfreaks/SearchResultDetail/`: Detailansicht für TMDb-Suchergebnis + „Hinzufügen“.
- `filmfreaks/MovieDetail/`: Detail für bereits gespeicherte Movies inkl. Rating UI.
- `filmfreaks/Stats/`: Stats Screen + Berechnungen.
- `filmfreaks/Timeline/`: Timeline Screen (Historie/Events).
- `filmfreaks/Goals/`: Goals UI + Matching/Derived/Enrichment (siehe `GoalsView+*.swift`).
- `filmfreaks/MovieNights/`: Filmabend Feature (Model + UI + Calendar + Sheets).
- `filmfreaks/Notifications/`: Local notification layer + deep link routing.
- `filmfreaks/CloudKit/`: Push-coordinators & subscription tooling (zusätzlich zu CloudKit Stores im root).

## Data Model Map (Entities, Relationships, wichtige Felder)
> Hinweis: Keine SwiftData/CoreData Entities im Projekt gefunden. Models sind überwiegend `Codable` structs.

### Movie (`filmfreaks/Movie.swift`)
- Identität: `id: UUID`, optional `tmdbId: Int?`
- Metadaten: `title`, `year`, `posterPath`, `overview`, `tagline`, `runtimeMinutes`, `genres`, `keywords`, `watchProviders`, …
- Gruppierung: `groupId: String?` (wichtig für CloudKit Routing)
- Status: `addedAt`, `addedByName`, `addedById`, `isBacklog` wird separat gespeichert (CloudKit field `isBacklog` in `filmfreaks/CloudKitMovieStore.swift`)
- Beziehungen:
  - `ratings: [Rating]` (lokal im Movie; CloudKit separat)
  - `cast: [CastMember]?` (Migration/Enrichment via TMDb IDs; siehe `MovieStore.migrateCastDataIfNeeded()` in `filmfreaks/MovieStore.swift`)

### Rating (`filmfreaks/Movie.swift`)
- Identität: `reviewerId: UUID?` (stabile Identität), `reviewerName: String`
- Inhalt: `fazit`, `fazitScore`, `criteria: [RatingCriterion]`
- Sync-Metadaten: `updatedAt: Date?` (für Activity Feed + Merge), wird in CloudKit gesetzt (`updatedAt` Feld in `filmfreaks/CloudKitRatingStore.swift`)

### User (`filmfreaks/User.swift`)
- `id: UUID`, `name: String`
- CloudKit RecordType: `GroupMember` in `filmfreaks/CloudKitUserStore.swift` mit Feldern `groupId`, `memberId`, `name`, `updatedAt`

### GroupContext (`filmfreaks/GroupContext.swift`)
- `id` (groupId), `name`, `scope: private|shared`, `zoneName`, `ownerName`
- Persistenz: `UserDefaults` Key `GroupContextsById` (siehe `GroupContextStore`)

### MovieNight (Models in `filmfreaks/MovieNights/`)
- `MovieNightEvent` (`MovieNights/MovieNightEvent.swift`): `groupId`, `proposedStart`, `status`, proposer, optional suggested movie
- `MovieNightResponse` (`MovieNights/MovieNightResponse.swift`): Entscheidung pro User zu Event
- `MovieNightActivityEvent` (`MovieNights/MovieNightActivityEvent.swift`): Activity timeline (cloud record type `MovieNightActivity` in `filmfreaks/CloudKitMovieNightStore.swift`)

### Goals
- Yearly goals in CloudKit: RecordType `ViewingGoal` (fields: `groupId`, `year`, `target`, `updatedAt`) in `filmfreaks/CloudKitGoalStore.swift`
- Custom goals payload: RecordType `ViewingCustomGoals` (field `payload`), models `ViewingCustomGoal` + `ViewingCustomGoalsPayload` in `filmfreaks/ViewingCustomGoal.swift` / `filmfreaks/ViewingCustomGoalsPayload.swift`

## Sync/Storage (SwiftData/CoreData? CloudKit? Caches? Migration? Offline)
### Lokale Persistenz (Primary cache, immer verfügbar)
- Implementierung: `filmfreaks/PersistenceManager.swift`
- Ort: `~/Library/Application Support/FilmFreaks/groups/<group>/` (per `baseDir` + `groups/<gid>` in `fileURL(kind:groupId:)`)
- Dateien (pro Gruppe):
  - `movies_watched.json` (Key `.watchedMovies`)
  - `movies_backlog.json` (Key `.backlogMovies`)
  - `users.json` (Key `.users`)
- Write-Strategie: Debounced writes (`debounceSeconds = 0.55`), DispatchQueue `.utility`, cancelable WorkItems (siehe `pendingWrites` + `scheduleWrite`).
- Migration: von UserDefaults nach Disk (`migrateFromUserDefaultsIfNeeded()`; Flag `FilmFreaks.diskPersistence.v2.migrated`).

### CloudKit (Sync + Sharing)
- Container: `iCloud.de.marcfechner.filmfreaks` (`filmfreaks/filmfreaks.entitlements`)
- Hintergrund: Remote notifications aktiviert (`UIBackgroundModes: remote-notification` in `filmfreaks/Info.plist`)
- Group Sharing:
  - Root record: `FFGroup` (`filmfreaks/CloudKitGroupStore.swift`)
  - Pro Gruppe eigene Zone: `zoneName = "group.<UUID>"` in `CloudKitGroupStore.createGroup(...)`
  - Invitation acceptance: `filmfreaks/CloudKitShareSceneDelegate.swift` + `filmfreaks/CloudKitShareCoordinator.swift`
  - Routing-Metadaten werden in `GroupContextStore` persistiert (UserDefaults), dann nutzen alle Stores `CloudKitRouting.route(...)` bzw. `GroupContextStore.context(...)`.
- Record Types (aus Code abgeleitet):
  - Movies: `Movie` (payload Data + isBacklog + updatedAt + groupId) in `filmfreaks/CloudKitMovieStore.swift`
  - Ratings: `MovieRating` in `filmfreaks/CloudKitRatingStore.swift`
  - Members: `GroupMember` in `filmfreaks/CloudKitUserStore.swift`
  - Goals: `ViewingGoal`, `ViewingCustomGoals` in `filmfreaks/CloudKitGoalStore.swift`
  - MovieNights: `MovieNightEvent`, `MovieNightResponse`, `MovieNightActivity` in `filmfreaks/CloudKitMovieNightStore.swift`
- Inkrementeller Sync: Zone changes + Token store (`filmfreaks/CloudKitZoneChanges.swift`, `filmfreaks/CloudKitZoneChangeTokenStore.swift`).

### Offline-Verhalten (beobachtbar aus Code)
- UI arbeitet primär auf lokal geladenen JSON-Caches (`MovieStore.init` lädt zuerst Disk; `UserStore.init` lädt Disk).
- Cloud refresh wird bei `scenePhase == .active` getriggert (`filmfreaks/filmfreaksApp.swift`).
- Cloud writes sind queued/batched (`MovieCloudSyncCoordinator` + `MovieStore.enqueueCloudSync(...)` in `filmfreaks/MovieStore.swift`).
- Reconnect handling: `MovieStore.setupNetworkReconnectHandling()` (Combine subscription auf `NetworkMonitor.shared.isConnected`).

**UNKNOWN (wichtig):**
- CloudKit Dashboard Schema/Indexes/CKShare permissions sind nicht aus dem Repo verifizierbar → siehe „Open Questions“.

## UI Map (Hauptscreens + Navigation + wichtige Sheets/Flows)
### Entry Points
- App entry: `filmfreaks/filmfreaksApp.swift` (`@main`), setzt EnvironmentObjects + ScenePhase refresh.
- UIApplicationDelegate: `filmfreaks/CloudKitShareAppDelegate.swift` (Push registration + share acceptance)
- Scene delegate: `filmfreaks/CloudKitShareSceneDelegate.swift` (cold/warm share acceptance + push deep link route)

### Root Navigation (Content)
- Root view: `filmfreaks/Content/ContentView.swift` in einem `NavigationStack`.
- Routing state: `ContentRoute` (`filmfreaks/Content/ContentRouting.swift`) + `.sheet(item:)` für:
  - Settings: `filmfreaks/SettingsView.swift`
  - Stats: `filmfreaks/Stats/StatsView.swift`
  - Timeline: `filmfreaks/Timeline/TimelineView.swift`
  - Activity: `filmfreaks/Content/GroupActivityListView.swift`
  - Movie Search: `filmfreaks/MovieSearch/MovieSearchView.swift`
  - Movie Nights Calendar: `filmfreaks/MovieNights/Calendar/MovieNightCalendarView.swift`
  - Goals: `filmfreaks/Goals/GoalsView.swift`
- Weitere Sheets/Flows:
  - Search Result Detail Sheet: `filmfreaks/SearchResultDetail/SearchResultDetailView.swift` (öffnet Detail aus Suche)
  - Movie Detail Screen: `filmfreaks/MovieDetail/MovieDetailView.swift` (NavigationLink, Pfad in `ContentRouting.destination(for:)`)

## Build & Configuration
- Xcode Project: `filmfreaks.xcodeproj`
- Bundle ID: `de.marcfechner.filmfreaks` (`PRODUCT_BUNDLE_IDENTIFIER` in `filmfreaks.xcodeproj/project.pbxproj`)
- iCloud Entitlements: `filmfreaks/filmfreaks.entitlements` (CloudKit + container id)
- Build Configs:
  - `filmfreaks/Debug.xcconfig` includes `filmfreaks/Secrets.xcconfig`
  - `filmfreaks/Release.xcconfig` includes `filmfreaks/Secrets.xcconfig`
- Secrets handling:
  - `TMDB_API_KEY` wird aus `Info.plist` gelesen (`filmfreaks/TMDbAPI.swift`).
  - `Info.plist` Key `TMDB_API_KEY` wird via Build Setting `$(TMDB_API_KEY)` gesetzt (`filmfreaks/Info.plist`).
  - `Secrets.xcconfig` definiert `TMDB_API_KEY = ...` (`filmfreaks/Secrets.xcconfig`).
  - `.gitignore` ignoriert `Secrets.xcconfig` (`filmfreaks/.gitignore`).  
    **Achtung:** Im gelieferten ZIP ist `Secrets.xcconfig` trotzdem enthalten → für echte Repos: sicherstellen, dass es nicht committed ist.
- SPM: Keine `Package.swift` / keine `XCRemoteSwiftPackageReference` Einträge im `project.pbxproj` gefunden.

**Targets**
- App target: `filmfreaks`
- Test targets referenziert in `project.pbxproj`: `filmfreaksTests`, `filmfreaksUITests` (Bundle IDs vorhanden), aber im ZIP fehlen die entsprechenden Quellordner → **UNKNOWN**, ob Tests existieren/leer sind.

## Conventions (Naming, Patterns, Do/Don’t)
- Stores sind überwiegend `@MainActor` + `ObservableObject` (z.B. `MovieStore`, `UserStore`, `CloudKitGroupStore`).
- CloudKit Access ist in dedizierten Stores kapselt (`CloudKit*Store.swift`) und wird über `CloudKitRouting` + `GroupContextStore` gescoped.
- Persistenz: Große Arrays **nicht** in UserDefaults, sondern Disk via `PersistenceManager`.
- UI: Navigation primär via `ContentRoute` + `.sheet(item:)` (Root) und `NavigationStack` innerhalb von Feature-Screens.
- Do:
  - Heavy Work (JSON encode, sorting, mapping) aus Renderpfaden rausziehen (siehe Hotspots in `ARCHITECTURE_NOTES.md`).
  - GroupId normalisieren (trim/empty) über `CloudKitRouting.normalizedGroupId(...)` (z.B. in `MovieStore.handleGroupContextUpsert(...)`).
- Don’t:
  - UUID-like groupIds ohne `GroupContext` in Public DB schreiben (code already enforces this in `CloudKitRouting`/stores; weiter so).

## How to work on this project (Setup Steps + wo anfangen)
### Setup (lokal)
1. Öffnen: `filmfreaks.xcodeproj`
2. Signing: Team + Bundle ID konfigurieren (Target `filmfreaks`)
3. iCloud Capability:
   - iCloud/CloudKit aktivieren (sollte via `filmfreaks.entitlements` vorbereitet sein)
   - Container `iCloud.de.marcfechner.filmfreaks` muss in Apple Developer Account existieren und dem App ID zugeordnet sein (**UNKNOWN**, ob bereits so konfiguriert)
4. TMDb Key:
   - Lokal: `Secrets.xcconfig` mit `TMDB_API_KEY` setzen (oder Env var `TMDB_API_KEY`, siehe `TMDbAPI.loadAPIKey()`).
5. Push/Sharing:
   - CloudKit sharing + remote notifications: sinnvollerweise auf **echtem Gerät** testen (Sim kann Einschränkungen haben).
6. Erster Run:
   - App startet in `ContentView` (splash overlay in `filmfreaks/filmfreaksApp.swift`)

### Wo anfangen (neue Entwickler)
- Datenfluss verstehen: `MovieStore.swift` + `PersistenceManager.swift` + `CloudKitRouting.swift`
- Navigation verstehen: `ContentView.swift` + `ContentRouting.swift`
- Sync/Sharing verstehen: `CloudKitGroupStore.swift` + `GroupContext.swift` + `CloudKitZoneChanges.swift`

## Quick Wins (max 10, konkret & umsetzbar)
1. **Doppelte Subscription-Setup Tasks entfernen** in `filmfreaks/CloudKitGroupStore.swift` (`refresh()` enthält zwei identische `Task { ... }`-Blöcke mit `ensureSubscriptions(...)`).
2. **Activity Feed cachen**: `MovieStore.activityEvents(...)` (in `filmfreaks/MovieStore+Activity.swift`) sortiert jedes Mal neu → ViewModel/Cache pro Group + DisplayMode.
3. **Stats Berechnungen memoizen**: `filmfreaks/Stats/StatsView+Calculations.swift` enthält viele O(n) Aggregationen als computed vars → in `StatsViewModel` vorberechnen (Trigger: movies/backlog/filter).
4. **Off-main JSON encoding** bei CloudKit batch writes: `JSONEncoder().encode(...)` in `filmfreaks/CloudKitMovieStore.swift` (`modifyBatch`) kann UI blocken, wenn auf MainActor aufgerufen.
5. **MovieStore didSet Kosten reduzieren**: `oldValue == movies` und `enqueueCloudSync` erzeugen Dictionaries/Sets O(n) pro Update (`filmfreaks/MovieStore.swift`) → gezielte Mutations + ChangeTracker.
6. **ScenePhase refresh deduplizieren/canceln**: `filmfreaks/filmfreaksApp.swift` startet bei jeder Aktivierung ein neues `Task` ohne Cancellation → Task handle speichern und bei erneutem `.active` canceln.
7. **Secrets Hygiene prüfen**: sicherstellen, dass `Secrets.xcconfig` niemals committed wird (Repo) und ggf. CI-Mechanismus (Env var) nutzen (`filmfreaks/TMDbAPI.swift` unterstützt das).
8. **Tests Ziel klären**: `filmfreaksTests`/`UITests` Targets existieren im Projektfile, aber Quellen fehlen im ZIP → entweder hinzufügen oder aus Projekt entfernen, damit CI nicht rot ist.
9. **Logging vereinheitlichen**: CloudKit Stores nutzen gemischt `print(...)` (z.B. `CloudKitGroupStore.refresh`) und `Logger` (Persistence) → standardisieren, plus log categories.
10. **CloudKit Token Reset UX**: Bei Token-Korruption löscht `CloudKitZoneChangeTokenStore` den Token still → optional UI-Aktion in Settings: "Sync zurücksetzen" (nur Token löschen), debugbar.

## Open Questions (alles, was als UNKNOWN markiert wurde)
- **CloudKit Dashboard Setup**: Sind Record Types/Indexes/Permissions/Share settings im iCloud Container `iCloud.de.marcfechner.filmfreaks` konsistent mit dem Code? (**UNKNOWN**; nicht aus Repo verifizierbar)
- **Test Targets**: Existieren `filmfreaksTests` / `filmfreaksUITests` Quellen, oder sind sie absichtlich leer? (`project.pbxproj` referenziert sie, ZIP enthält keine Ordner) (**UNKNOWN**)
- **Migration/Backward Compatibility**: Welche App-Versionen müssen noch gelesen werden (UserDefaults v1, Disk v2, Cloud schema versions)? Es gibt Migrationen, aber keine dokumentierte Support-Matrix. (**UNKNOWN**)
- **CloudKit Quotas/Batching**: Erwartete Max-Größe pro Movie payload + worst-case backlog Größe? (relevant für `JSONEncoder` payload size + CK limits) (**UNKNOWN**)
