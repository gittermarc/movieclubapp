# PROJECT_CONTEXT — filmfreaks ("The Movie Club")

> Stand: 2026-02-24 (Europe/Berlin). Basis: Repository-Inhalt aus `filmfreaks/` + `filmfreaks.xcodeproj/`.

## TL;DR
- **App:** gemeinsames Film-Tracking für Gruppen (gesehen + Backlog) mit per-User Bewertungen, Stats, Timeline und „Movie Nights“.
- **Plattform:** iOS (iPhone + iPad). **Deployment Target:** iOS 26.0 (laut `filmfreaks.xcodeproj/project.pbxproj`).
- **Tech:** SwiftUI + Combine. **Storage:** lokale JSON-Persistenz in Application Support + CloudKit (Public/Private/Shared DB + optional Record Zones je Gruppe).
- **Wichtig:** Es gibt **kein SwiftData/CoreData** im Projekt (kein `import SwiftData`, kein CoreData-Stack). Alles ist Codable + CloudKit.

## Key Concepts / Domänenbegriffe
- **Group / groupId**
  - „Gruppen“-Trennung in der App (Filter/Scope für Daten).
  - groupId ist **entweder** ein „legacy“ String (Public DB) **oder** UUID-ähnlich (Sharing/Zone-Gruppe).
  - Routing-Regel: UUID-ähnliche groupIds **dürfen nie** auf Public DB zurückfallen → siehe `CloudKitRouting.swift`.
- **GroupContext**
  - Persistierte Routing-Metadaten (DB-Scope + ZoneName + OwnerName) pro Gruppe.
  - Quelle: `CloudKitGroupStore.swift` (List/Create/Share) + Speicherung in `GroupContext.swift`.
- **Owned vs Shared Groups**
  - CloudKit Sharing: Owned Groups in Private DB, Shared Groups in Shared DB. Siehe `CloudKitGroupStore.swift`.
- **Movies**
  - Domain-Model `Movie` (`Movie.swift`): u.a. `id`, `title`, `year`, `tmdbId`, `watchedDate`, `watchedLocation`, `groupId`, `addedAt`, `addedBy*`, `cast`, `directors`.
  - Zwei Listen: **gesehen** (`MovieStore.movies`) und **Backlog** (`MovieStore.backlogMovies`) → `MovieStore/MovieStore.swift`.
- **Ratings**
  - Domain-Model `Rating` (`Movie.swift`): pro Reviewer (stabil über `reviewerId`) + Kriterien-Scores + optional `fazitScore`.
  - Cloud-Sync getrennt: Ratings werden als eigene CloudKit Records gespeichert (`CloudKitRatingStore/*`), nicht als Bestandteil des Movie-Payloads (siehe Kommentar in `MovieStore/MovieStore.swift`).
- **Movie Nights**
  - Vorschläge/Termine pro Gruppe (`MovieNightEvent`, `MovieNightResponse`, `MovieNightActivityEvent`) in `MovieNights/*`.
  - Lokal: JSON-Snapshot (`MovieNightLocalPersistence.swift`). Cloud: eigener Store (`CloudKitMovieNightStore/*`) + Coordinator (`MovieNights/MovieNightCloudSyncCoordinator.swift`).
- **Routing / Sheets**
  - Zentrales Sheet-Routing über `Content/ContentRouting.swift` (Enum `ContentRoute` + `.sheet(item:)`).
- **Push / Activity**
  - Subscriptions für Aktivität werden best-effort erstellt (`CloudKit/CloudKitActivitySubscriptionManager.swift`).
  - Push-Debug + Best-effort Fetch: `CloudKit/CloudKitActivityPushFetchCoordinator.swift`.
  - Tap auf Push → DeepLink via NotificationCenter: `Notifications/PushDeepLinkRouter.swift`.

## Architecture Map (Layer, Verantwortlichkeiten, Abhängigkeiten)
**UI (SwiftUI Views)**
- Root: `Content/ContentView.swift` (Hauptscreen, Toolbar, Listen/Grids, Routing).
- Feature-Screens: `MovieDetail/*`, `MovieSearch/*`, `Stats/*`, `Timeline/*`, `MovieNights/*`, `Goals/*`, `SettingsView.swift`, `GroupSettingsView.swift`, `UsersView.swift`.

**State / Stores (ObservableObject, meist @MainActor)**
- `MovieStore/MovieStore.swift` (+ `MovieStore/MovieStore+CloudSync.swift`): lokale Listen + Sync-Transparenz + Cloud Flush/Refresh.
- `UserStore.swift`: Mitgliederverwaltung + per-Group Sync Status.
- `MovieNights/MovieNightStore.swift` (+ Extensions): MovieNight Domain + Persistenz + Cloud Sync.
- `CloudKitGroupStore.swift`: Gruppenliste + Sharing + GroupContexts.
- `DisplaySettings/DisplaySettings.swift` (u.a. `.tint`, Layout-Metriken) + weitere Display-Views in `DisplaySettings/*`.
- `NetworkMonitor.swift`: Connectivity (NWPathMonitor).

**Storage (local)**
- `PersistenceManager.swift`: JSON-Dateien pro Gruppe für Movies/Backlog/Users (Application Support, debounced, atomic).
- `MovieNights/MovieNightLocalPersistence.swift`: eigener JSON-Snapshot für MovieNights (actor).

**Cloud Sync (CloudKit)**
- Routing/Safety: `CloudKitRouting.swift` + `GroupContext.swift`.
- Stores (CloudKit API):
  - Movies: `CloudKitMovieStore/*` (Payload `Movie` als Data + Flags).
  - Ratings: `CloudKitRatingStore/*` (RecordType `MovieRating`, Payload `Rating` als Data).
  - Users: `CloudKitUserStore.swift` (RecordType `GroupMember`, 1 Record pro Mitglied).
  - Goals: `CloudKitGoalStore.swift` (RecordTypes `ViewingGoal` + `ViewingCustomGoals` Payload).
  - MovieNights: `CloudKitMovieNightStore/*` (separate RecordTypes pro Event/Response/Activity).
- Incremental Scaling für Zone-Gruppen: `CloudKitZoneChanges.swift` + `CloudKitZoneChangeTokenStore.swift` (Tokens) + Store-spezifische `*+ZoneChanges.swift`.

**Networking / External API**
- TMDb API: `TMDbAPI/*` (Facade `TMDbAPI.swift`, Details/Search/Networking gesplittet).
- API Key-Injection über Build Setting: `Info.plist` nutzt `$(TMDB_API_KEY)`.

## Folder Map (Ordner → Zweck)
- `(root)` — Shared UI-Komponenten, Domain-Models, Stores, Routing/Infra  
  - z.B. `filmfreaksApp.swift`, `PersistenceManager.swift`, `CloudKitRouting.swift`, `NetworkMonitor.swift`
- `Content/` — Hauptscreen, Toolbar, Routing, Activity Feed, derived-list Models  
  - z.B. `ContentView.swift`, `ContentRouting.swift`, `ContentMovieItemsModel.swift`
- `MovieStore/` — MovieStore Kern + Cloud-Sync Extensions  
  - z.B. `MovieStore.swift`, `MovieStore+CloudSync.swift`
- `MovieSearch/` — TMDb Suche + Recommendations UI/Logik  
  - z.B. `MovieSearchView.swift`, `MovieSearchView+Search.swift`, `MovieSearchView+Recommendations.swift`
- `SearchResultDetail/` — Detail-Screens für TMDb Search Results (Movie/Person)  
  - z.B. `SearchResultDetailView.swift`, `SearchResultPersonDetailSheet.swift`
- `MovieDetail/` — Detailansicht für lokale Movies + Ratings/WatchProviders  
  - z.B. `MovieDetailView.swift`, `MovieRatingsSheetView.swift`
- `Stats/` — Aggregationen + Stats UI  
  - z.B. `StatsViewModel.swift`, `StatsSnapshotBuilder.swift`, `StatsView+Cards.*.swift`
- `Timeline/` — Timeline-UI für watched Movies  
  - z.B. `TimelineView.swift`
- `Goals/` — Zielsystem (Yearly Goals + Custom Goals) + UI  
  - z.B. `ViewingCustomGoal.swift`, `GoalsView.swift`
- `MovieNights/` — MovieNight Domain + UI + Cloud-Sync  
  - z.B. `MovieNightStore.swift`, `MovieNightCalendarView.swift`, `Sheets/*`
- `CloudKit/` — Push/Subscription/Debug Infrastruktur  
  - z.B. `CloudKitActivitySubscriptionManager.swift`
- `CloudKitMovieStore/`, `CloudKitRatingStore/`, `CloudKitMovieNightStore/` — CloudKit Store Implementierungen (gesplittet nach Verantwortung)
- `Notifications/` — Notification Permissions, DeepLink Routing, lokale Notifs  
  - z.B. `NotificationsPermissionManager.swift`, `PushDeepLinkRouter.swift`
- `DisplaySettings/` — Darstellung/Theme/Layouts + Preview Cards
- `Assets.xcassets/` — App Assets

## Data Model Map (Entities, Relationships, wichtige Felder)
> Hinweis: Alle Models sind **Codable structs**, keine SwiftData/CoreData-Entities.

### Movie (`Movie.swift`)
- Identität: `id: UUID`
- Metadaten: `title`, `year`, `tmdbId`, `posterPath`
- Watch-Info: `watchedDate`, `watchedLocation`
- Gruppen-Scoping: `groupId`, `groupName`
- Social/Activity: `addedAt`, `addedById`, `addedByName`, `suggestedBy`
- Credits: `cast: [CastMember]?`, `directors: [CastMember]?`
- Beziehung:
  - `ratings: [Rating]` existiert im Domain-Model, wird aber **Cloud-seitig** über separate Rating-Records gepflegt (`CloudKitRatingStore/*`).

### Rating (`Movie.swift`)
- `id: UUID`
- Reviewer: `reviewerId: UUID?` (stabil), `reviewerName: String` (display)
- Bewertung: `scores: [RatingCriterion: Int]` (0–3), `comment`, `fazitScore (1–10)`
- Sync: `updatedAt: Date?` (aus CloudKit Record)

### User (`User.swift`)
- `id: UUID`, `name: String`
- Verwendung: Auswahl des aktiven Reviewers in `UserStore.swift`.

### GroupContext (`GroupContext.swift`)
- Identität: `id: String` (groupId)
- Routing: `scope: GroupScope (private/shared)`, `zoneName`, `ownerName`
- UI: `name`, `isShared`

### MovieNights (`MovieNights/*`)
- `MovieNightEvent`: `id`, `groupId`, `proposedStart`, `status`, proposer + optional `suggestedMovie`
- `MovieNightResponse`: Antwort je User pro Event (accept/decline/etc.)
- `MovieNightActivityEvent`: Activity-Feed-Events (z.B. status changes)
- **Lokal** als Snapshot gespeichert (`MovieNightLocalPersistence.swift`), **Cloud** als separate RecordTypes (`CloudKitMovieNightStore.swift`).

### Goals (`Goals/*`)
- Yearly Viewing Goal: year → target (Cloud record `ViewingGoal` via `CloudKitGoalStore.swift`)
- Custom Goals: versioniertes Payload pro Gruppe (`ViewingCustomGoal.swift` + `CloudKitGoalStore.swift`)

## Sync/Storage
### Local (Offline-First Baseline)
- Movies/Backlog/Users: `PersistenceManager.swift`
  - Speicherort: `~/Library/Application Support/filmfreaks/` (konkret: siehe `PersistenceManager.makeBaseDir()`).
  - Pro Gruppe getrennte Dateien (group-scoped Naming über `groupId`).
  - Debounced Writes über DispatchQueue (qos `.utility`) + `DispatchWorkItem` Cancellations.
- MovieNights: `MovieNights/MovieNightLocalPersistence.swift`
  - Actor kapselt IO und Snapshot-Schema-Version (`Snapshot.schemaVersion`).

### CloudKit (Online Sync)
- Container: iCloud Container ID `iCloud.de.marcfechner.filmfreaks` (siehe `filmfreaks.entitlements`).
- Background Push: `UIBackgroundModes` enthält `remote-notification` (siehe `Info.plist`).
- DB/Zone Routing:
  - `CloudKitRouting.swift` entscheidet Public vs Zone (Private/Shared).
  - UUID-ähnliche groupIds erfordern `GroupContext`; sonst wird **geworfen** (kein Public-Fallback).
- Sharing:
  - `CloudKitGroupStore.swift` liest Owned/Shared Groups und sorgt für Subscription-Setup.
  - Share Acceptance: `CloudKitShareSceneDelegate.swift` + `CloudKitShareCoordinator.swift` + Toasts.
- Incremental Fetch:
  - Zone-Gruppen nutzen `CloudKitZoneChanges.fetchAllChanges(...)` (`CloudKitZoneChanges.swift`) + Token Store (`CloudKitZoneChangeTokenStore.swift`).
  - Public/Legacy Gruppen nutzen CKQuery-Pfade (siehe z.B. `CloudKitMovieStore/CloudKitMovieStore+Routing.swift`).

### Caches
- HTTP/Images: `filmfreaksApp.swift` setzt `URLCache.shared` (100MB RAM / 500MB Disk).
- Derived Lists: `Content/ContentMovieItemsModel.swift` baut filter/sort/search Listen **außerhalb** von `ContentView.body`.

### Migration
- Local: `PersistenceManager.swift` migriert best-effort von UserDefaults auf Disk (`migrateFromUserDefaultsIfNeeded()`).
- Cloud:
  - Movies: Legacy groupId im Payload → Migration in `CloudKitMovieStore/CloudKitMovieStore+Routing.swift` (scan + upsert).
  - Users: Legacy RecordName-Format wird best-effort migriert beim Fetch (`CloudKitUserStore.swift`).

## UI Map (Screens + Navigation)
### Entry Point
- `filmfreaksApp.swift`
  - injectiert EnvironmentObjects: `MovieStore`, `MovieNightStore`, `UserStore`, `CloudKitGroupStore`, `NetworkMonitor`, `DisplaySettings`.
  - `.onChange(of: scenePhase)` → App-Resume Refresh Cascade über `AppRefreshCoordinator.swift`.

### Main Screen
- `Content/ContentView.swift`
  - Listen/Grids für „gesehen“ und „Backlog“ (Mode via `selectedMode`).
  - Routing über `ContentRoute?` + `contentRouting(...)` Modifier (`Content/ContentRouting.swift`).
  - Toolbar: `ContentToolbar` (in `Content/`), öffnet Sheets.

### Sheet-Routes (aus `Content/ContentRouting.swift`)
- `.settings` → `SettingsView.swift`
- `.quickStart` → `QuickStartView.swift`
- `.movieSearch` → `MovieSearch/MovieSearchView.swift`
- `.users` → `UsersView.swift`
- `.stats` → `Stats/StatsView.swift`
- `.timeline` → `Timeline/TimelineView.swift`
- `.calendar` → `MovieNights/Calendar/MovieNightCalendarView.swift`
- `.activity` → `Content/GroupActivityListView.swift`
- `.goals` → `Goals/GoalsView.swift`
- `.groupSettings` → `GroupSettingsView.swift`

### Detail-Flows
- Movie Detail: `MovieDetail/MovieDetailView.swift` (z.B. Ratings Sheet, WatchProviders Sheet).
- Search Result Detail: `SearchResultDetail/SearchResultDetailView.swift` + Person Sheet.

## Build & Configuration
- Xcode Project: `filmfreaks.xcodeproj/`
  - Targets: `filmfreaks`, `filmfreaksTests`, `filmfreaksUITests` (aus `project.pbxproj`).
  - Bundle ID: `de.marcfechner.filmfreaks` (aus `project.pbxproj`).
  - Team: `HPJKAPZ8A3` (aus `project.pbxproj`).
- Plists/Entitlements:
  - `filmfreaks/Info.plist`:
    - `CKSharingSupported = true`
    - `TMDB_API_KEY = $(TMDB_API_KEY)`
    - `UIBackgroundModes = remote-notification`
  - `filmfreaks/filmfreaks.entitlements`:
    - iCloud Container: `iCloud.de.marcfechner.filmfreaks`
    - iCloud Service: CloudKit
    - `aps-environment = development` (**Production muss separat signiert werden**).
- Build Config:
  - `Debug.xcconfig`, `Release.xcconfig` includen `Secrets.xcconfig`
  - `Secrets.xcconfig` enthält `TMDB_API_KEY = ...`
  - `.gitignore` ignoriert `Secrets.xcconfig` (siehe `filmfreaks/.gitignore`)

## Conventions (Naming, Patterns, Do/Don't)
- **Datei-Splitting per Extensions** ist Standard:
  - `TMDbAPI.swift` + `TMDbAPI+*.swift`
  - `MovieStore.swift` + `MovieStore+CloudSync.swift`
  - `CloudKit*Store.swift` + `CloudKit*Store+{Routing,Schema,Query,Modify,ZoneChanges}.swift`
- **Stores sind @MainActor** (UI-konsistent), aber schwere Arbeit wird oft ausgelagert:
  - Stats: Snapshot in `StatsSnapshotBuilder.swift`, Debounce in `StatsViewModel.swift`.
  - Content: Derivation in `ContentMovieItemsModel.swift`.
- **Do**
  - groupId stets normalisieren (`CloudKitRouting.normalizedGroupId`)
  - bei UUID-like groupId: nie public fallback (Fehler bewusst behandeln)
  - I/O nicht im Renderpfad (kein JSON load/save im `View.body`)
- **Don't**
  - `.onChange`/`.onAppear` Tasks ohne Cancellation, wenn sie Netzwerk/Cloud anstoßen (Race & wasted work; siehe `SearchResultDetail/SearchResultDetailView.swift`)
  - neue CloudKit-RecordTypes ohne dokumentierte Keys + Routing-Check (Public vs Zone)

## How to work on this project (Setup + Einstieg)
### Setup Checklist
- [ ] `filmfreaks.xcodeproj` öffnen
- [ ] Signing überprüfen (Team `HPJKAPZ8A3`, Bundle `de.marcfechner.filmfreaks`)
- [ ] iCloud Capability + Container `iCloud.de.marcfechner.filmfreaks` aktiv
- [ ] Push Notifications aktiv + korrektes `aps-environment` für Debug/Release
- [ ] `TMDB_API_KEY` setzen (lokal über `Secrets.xcconfig`; Datei ist via `.gitignore` ausgeschlossen)
- [ ] Auf echtem Device testen, eingeloggt in iCloud (Sharing + Private/Shared DB können im Simulator eingeschränkt sein)

### Wo anfangen für neue Devs
1. Bootstrapping: `filmfreaksApp.swift` (EnvironmentObjects, Refresh-Cascade).
2. Main UX: `Content/ContentView.swift` + `Content/ContentRouting.swift`.
3. Storage/Sync:
   - Local: `PersistenceManager.swift`
   - Cloud Routing: `CloudKitRouting.swift` + `GroupContext.swift`
   - Movie Cloud: `CloudKitMovieStore/*` + `MovieCloudSyncCoordinator.swift`
4. External API: `TMDbAPI/*`


## CloudKit Schema (Quick Map)
> Ziel: schnelle Orientierung, wo welche RecordTypes/Felder definiert sind. Keys sind Code-Quelle der Wahrheit.

### Groups (Sharing)
- Group Record: RecordType `"FFGroup"` (siehe `CloudKitGroupStore.swift`)
  - Keys: `name`, `createdAt` (siehe Konstanten `nameKey/createdAtKey`)
- GroupContext Persistence: `GroupContext.swift`
  - `GroupContextStore` speichert pro `groupId` ein JSON-Blob in UserDefaults (`GroupContextsById`)

### Movies
- RecordType `"Movie"` (siehe `CloudKitMovieStore/CloudKitMovieStore.swift`)
  - Keys:
    - `payload` (Data, codierter `Movie`)
    - `isBacklog` (Bool)
    - `updatedAt` (Date)
    - `groupId` (String)
- Fetch-Pfade (siehe `CloudKitMovieStore/CloudKitMovieStore+Routing.swift`)
  - Zone-Gruppe: Query im Zone-Kontext (ZoneID != nil) + optional Zone-Changes (`CloudKitMovieStore+ZoneChanges.swift`)
  - Public/Legacy: Query im Public DB; optional Legacy-Migration, wenn `groupId` im Record fehlt

### Ratings
- RecordType `"MovieRating"` (siehe `CloudKitRatingStore/CloudKitRatingStore+Schema.swift`)
  - Keys:
    - `payload` (Data, codierter `Rating`)
    - `movieId` (String UUID)
    - `groupId` (String)
    - `reviewerId` (String UUID)
    - `updatedAt` (Date)

### Users (Group Members)
- RecordType `"GroupMember"` (siehe `CloudKitUserStore.swift`)
  - Keys: `groupId`, `memberId`, `name`, `updatedAt`
  - RecordName: `"<groupId>|<memberId>"` (Legacy: `"<groupId>|<canonicalName>"`, wird best-effort migriert)

### Goals
- Yearly Goal: RecordType `"ViewingGoal"` (siehe `CloudKitGoalStore.swift`)
  - Keys: `groupId`, `year`, `target`, `updatedAt`
- Custom Goals Payload: RecordType `"ViewingCustomGoals"` (siehe `CloudKitGoalStore.swift`)
  - Keys: `payload` (Data)

### Movie Nights
- Event: RecordType `"MovieNightEvent"` (siehe `CloudKitMovieNightStore/CloudKitMovieNightStore.swift`)
- Response: RecordType `"MovieNightResponse"`
- Activity: RecordType `"MovieNightActivity"`
- Common Key: `groupId`  
  (weitere Keys: `proposedStart/createdAt/updatedAt/...` direkt im Store definiert)

## How-to: typischer Workflow für neue Features (kurz)
### 1) Neuer Screen / Flow
- View in passendem Feature-Ordner anlegen (z.B. `MovieNights/Sheets/...`).
- Routing:
  - wenn Sheet von Content aus: `Content/ContentRouting.swift` erweitern (neuer `ContentRoute` Case + Switch-Case).
  - wenn innerhalb eines Screens: lokale `.sheet`/`NavigationStack` wie in `MovieDetail/MovieDetailView.swift`.

### 2) Neues persisted Feld im Domain-Model
- `Codable`-Model erweitern (z.B. `Movie.swift` oder `MovieNights/*`).
- Backwards Compatibility:
  - `decodeIfPresent` nutzen, wenn alte Payloads weiterhin dekodieren sollen (Beispiele: `Movie.swift`, `MovieNightLocalPersistence.swift`).
- Local Persistenz:
  - Movies/Users: passiert automatisch via `PersistenceManager` in `didSet`/Store-Handlern (`MovieStore`, `UserStore`).
  - MovieNights: Snapshot speichern über `MovieNightStore+Persistence.swift` (writes laufen über `MovieNightLocalPersistence`).

### 3) Cloud Sync Änderung (Record Keys / Payload)
- Keys/Schema **zentral** in Store definieren:
  - z.B. `CloudKitMovieStore.swift`, `CloudKitMovieNightStore.swift`, `CloudKitRatingStore+Schema.swift`
- Routing immer über `CloudKitRouting.route(...)` (kein Copy-Paste Routing).
- Bei Zone-Gruppen: überlegen, ob Zone-Changes Token (`CloudKitZoneChangeTokenStore`) betroffen ist.

## Quick Wins (max 10, konkret)
1. `SearchResultDetail/SearchResultDetailView.swift`: Task-Cancellation einbauen (z.B. `@State var loadTask: Task<Void, Never>?`) für `loadDetails()` und `reloadWatchProvidersOnly()` → weniger Race/duplizierte Requests.
2. `Secrets.xcconfig`: sicherstellen, dass im Release-Build wirklich ein CI/Local Override existiert (aktuell per include aktiv). Dokumentation in README/Context ergänzen.
3. `CloudKitGroupStore.swift`: Refresh/Subscription Ensure Logging erweitern (z.B. Logger) um Push/Subscription Issues leichter zu debuggen.
4. `CloudKitMovieStore/CloudKitMovieStore+Routing.swift`: Migration-Pfad (legacy groupId) mit „one-shot“ Flag absichern, damit nicht wiederholt teure Scans passieren.
5. `Content/ContentView.swift`: weitere UI-Teilbereiche auslagern (Toolbar-Header, Filter-Leiste) um Merge-Konflikte zu reduzieren.
6. `MovieStore/MovieStore+CloudSync.swift`: SyncMeta + PendingCount Handling in eigene Extensions aufsplitten (rein organisatorisch, keine Logik-Änderung).
7. `Stats/StatsSnapshotBuilder.swift`: bei Set/Sort auf großen Datenmengen optional „pre-index“ pro Movie (z.B. cached reviewerKey) nutzen, wenn UI bei sehr vielen Ratings ruckelt.
8. `Notifications/NotificationsPermissionManager.swift`: User-Facing Diagnostics (Settings Screen) anbieten, ob Remote-Notifications registriert sind (**nur Anzeige**, keine neue Feature-Logik).
9. `PersistenceManager.swift`: optional „flush now“ API für App-Background (scenePhase) damit weniger Debounce-Work beim Terminate verloren geht (**nur wenn ihr Datenverlust beobachtet**).
10. `CloudKitZoneChangeTokenStore.swift`: Debug-Export der Tokens (per Settings) um Sync-Drift reproduzierbar zu machen.
