# PROJECT_CONTEXT

## TL;DR
**filmfreaks / The Movie Club** ist eine SwiftUI iOS-App (Targets: iPhone+iPad) zum gemeinsamen Tracken von Filmen pro Gruppe: *Gesehen*, *Backlog*, *Bewertungen (Kriterien + Fazit)*, *Ziele*, *Filmabende (Kalender)*, *Timeline* und *Gruppen-Aktivität*. Persistenz ist hybrid: lokale JSON-Dateien (Application Support) + CloudKit (Public DB für Legacy, Private/Shared DB + Zone pro Sharing-Gruppe). **SwiftData/CoreData wird nicht verwendet** (Storage ist JSON/UserDefaults + CloudKit). Mindest-iOS: **26.0**.

## Key Concepts / Domänenbegriffe
- **Gruppe / GroupId**: Kontext, in dem Filme/Members/Ziele/Filmabende isoliert sind.
  - **UUID-like groupId** → CloudKit Sharing (Zone pro Gruppe), Routing via `GroupContext`.
  - **nicht-UUID / leer** → Legacy/Public-DB Gruppe (Routing fällt auf Public DB zurück).
  - Routing-Guard: UUID-like groupIds dürfen **nie** in Public DB „zurückfallen“: `filmfreaks/CloudKitRouting.swift`.
- **Watched vs Backlog**: zwei Listen; CloudKit speichert beide über dasselbe RecordType (`Movie`) mit Feld `isBacklog`: `filmfreaks/CloudKitMovieStore/CloudKitMovieStore.swift`.
- **Rating**: pro User ein Rating-Record (Creator = Reviewer) in CloudKit: `MovieRating` (`CloudKitRatingStore`). Lokal im `Movie.ratings` Array.
- **Group Members**: Members als `GroupMember` Records (`CloudKitUserStore.swift`), zusätzlich lokal in JSON.
- **Goals**: yearly goals (`ViewingGoal`) + versioniertes Custom-Goals Payload (`ViewingCustomGoals`): `filmfreaks/CloudKitGoalStore.swift`.
- **Movie Nights**: Termine + Responses + Activity: RecordTypes `MovieNightEvent`, `MovieNightResponse`, `MovieNightActivity`.
- **Group Activity**: Feed aus Movie/Rating/MovieNight-Events, unterstützt durch CloudKit Subscriptions + Push Fetch.

## Architecture Map
**UI (SwiftUI Views)**
- Feature-Views (Home/Content, MovieSearch, MovieDetail, Stats, Timeline, Goals, MovieNights, Settings)
- Routing primär über `.sheet(item:)` in `filmfreaks/Content/ContentRouting.swift`

**State / Stores (ObservableObject, überwiegend @MainActor)**
- `filmfreaks/MovieStore/MovieStore.swift` (+ Extensions)
- `filmfreaks/UserStore.swift`
- `filmfreaks/MovieNights/MovieNightStore.swift`
- `filmfreaks/CloudKitGroupStore.swift`
- `filmfreaks/DisplaySettings.swift`

**Persistence (lokal)**
- JSON in Application Support (debounced atomic writes): `filmfreaks/PersistenceManager.swift`
- Zusätzliche kleine Meta-Daten in UserDefaults (GroupContexts, Tokens, Sync-Status, SelectedUser etc.)

**Sync (CloudKit)**
- Routing DB/Zone: `filmfreaks/CloudKitRouting.swift`
- Zone-Changes + Tokens: `filmfreaks/CloudKitZoneChanges.swift`, `filmfreaks/CloudKitZoneChangeTokenStore.swift`
- Feature-Stores:
  - Movies: `filmfreaks/CloudKitMovieStore/*`
  - Ratings: `filmfreaks/CloudKitRatingStore.swift`
  - Members: `filmfreaks/CloudKitUserStore.swift`
  - Goals: `filmfreaks/CloudKitGoalStore.swift`
  - Movie Nights: `filmfreaks/CloudKitMovieNightStore/*`
  - Groups/Sharing: `filmfreaks/CloudKitGroupStore.swift`, `filmfreaks/CloudKitShareCoordinator.swift`

**Networking (TMDb)**
- `filmfreaks/TMDbAPI/*` (Facade `TMDbAPI.shared`)

**Notifications**
- Push fetch + subscription mgmt: `filmfreaks/CloudKit/*`
- Local notifier + deep link routing: `filmfreaks/Notifications/*`

## Folder Map
- `filmfreaks/Assets.xcassets/` — App icons, colors, assets.
- `filmfreaks/CloudKit/` — CloudKit utilities (subscriptions, push fetch, debugging).
- `filmfreaks/CloudKitMovieNightStore/` — CloudKit store for MovieNight* records (zone changes + modify queue).
- `filmfreaks/CloudKitMovieStore/` — CloudKit store implementation for Movie records (split via extensions).
- `filmfreaks/Content/` — Home screen composition + routing + list/grid UI.
- `filmfreaks/Goals/` — Goals UI and goal domain helpers (yearly + custom goals).
- `filmfreaks/MovieDetail/` — Movie detail screen + rating UI/editor.
- `filmfreaks/MovieNights/` — Movie night feature (calendar, sheets, local persistence, cloud flush).
- `filmfreaks/MovieSearch/` — TMDb search UI + recommendation flows.
- `filmfreaks/MovieStore/` — MovieStore core + extensions (persistence, mutations, cloud sync, activity).
- `filmfreaks/Notifications/` — Local notifications + push deep link routing and state stores.
- `filmfreaks/SearchResultDetail/` — Detail screen for TMDb search results (pre-add-to-list).
- `filmfreaks/Stats/` — Stats UI + aggregation model.
- `filmfreaks/TMDbAPI/` — TMDb networking facade + models.
- `filmfreaks/Timeline/` — Timeline feature (movie history / activity timeline).

## Data Model Map
### Core Domain (lokal, Codable)
- `filmfreaks/Movie.swift`
  - `Movie`: `id`, `title`, `year`, `tmdbId`, `posterPath`, `watchedDate`, `watchedLocation`, `suggestedBy`, `addedAt`, `addedById/Name`, `genres/genreIds`, `keywords/keywordIds`, `cast`, `directors`, `groupId/groupName`, `ratings`.
  - `Rating`: `reviewerId` (stabil), `reviewerName` (Display), `scores` (Kriterium→Sterne), `comment`, `fazitScore`, `updatedAt`.
  - `CastMember`: `personId`, `name` (TMDb Person IDs).
- `filmfreaks/User.swift`: `User { id, name }`.
- `filmfreaks/GroupContext.swift`: `GroupContext { id, name, scope, zoneName, ownerName }` + `GroupContextStore` (UserDefaults).
- `filmfreaks/MovieNights/*`:
  - `MovieNightEvent`: `groupId`, `proposedStart`, `status`, `proposerUserId/Name`, optional `suggestedMovie`, `createdAt/updatedAt`.
  - `MovieNightResponse`: Event-Response pro User (Decision + Timestamp).
  - `MovieNightActivityEvent`: Feed/Activity pro Änderung.
- `filmfreaks/ViewingCustomGoal.swift`, `filmfreaks/ViewingCustomGoalsPayload.swift`: versionierte Custom Goals.

### CloudKit Schema (aus Code abgeleitet)
Record Types (best effort):
- `FFGroup`
- `GroupMember`
- `Movie`
- `MovieNightActivity`
- `MovieNightEvent`
- `MovieNightResponse`
- `MovieRating`
- `ViewingCustomGoals`
- `ViewingGoal`

**Wichtiges Sharing-Modell**
- Zone pro Gruppe: ZoneName `group.<groupId>` (`CloudKitGroupStore.createGroup`).
- Root Record: `FFGroup` mit recordName = `<groupId>` in dieser Zone.
- Descendants (Movies, Ratings, Goals, Members, MovieNights) werden via `record.parent = CKRecord.Reference(rootID, .none)` an die Share-Hierarchie angehaengt (siehe z.B. `CloudKitRatingStore.saveRating`, `CloudKitGoalStore.saveGoal`).

## Sync/Storage
### Lokal
- **Große Arrays** (Movies/Backlog/Users) werden als JSON pro Gruppe gespeichert:
  - `filmfreaks/PersistenceManager.swift`
  - Pfad: `~/Library/Application Support/FilmFreaks/groups/<group>/movies_watched.json` etc.
  - Writes sind debounced (`0.55s`) und atomar.
- **UserDefaults**
  - Group routing metadata: `filmfreaks/GroupContext.swift`
  - Zone change tokens: `filmfreaks/CloudKitZoneChangeTokenStore.swift`
  - Sync meta (pending count, last sync, error) für Movies: `filmfreaks/MovieStore/MovieStore+Persistence.swift`
  - Sync status per group für Members: `filmfreaks/UserStore.swift`

### CloudKit
- **App-Resume Refresh-Coalescing**: `filmfreaks/AppRefreshCoordinator.swift` wird in `filmfreaks/filmfreaksApp.swift` auf `.active` getriggert (debounce + single in-flight refresh).
- **HTTP Image Cache**: `filmfreaks/filmfreaksApp.swift` setzt `URLCache.shared` (100MB memory / 500MB disk) für effektivere Poster/Backdrop-Loads.
- **Routing** (Public vs Private/Shared + Zone): `filmfreaks/CloudKitRouting.swift`.
- **Incremental sync** für Sharing-Gruppen via Zone Changes:
  - `filmfreaks/CloudKitZoneChanges.swift`
  - Tokens persistent: `filmfreaks/CloudKitZoneChangeTokenStore.swift`
- **Upload/Flush**
  - Movies: `filmfreaks/MovieStore/MovieStore+CloudSync.swift` + `filmfreaks/MovieCloudSyncCoordinator.swift`.
  - Movie Nights: `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift` + `filmfreaks/MovieNights/MovieNightStore+CloudFlush.swift`.
- **Offline-Verhalten (best effort)**
  - UI arbeitet immer auf lokaler JSON-Cache-Basis; Cloud-Fetches sind „eventually consistent“.
  - Reconnect handling für Movies: `filmfreaks/MovieStore/MovieStore.swift` (NetworkMonitor + Flush auf online).
  - GroupContext-Guard: bei UUID-like groupIds wird Upload/Fetch blockiert bis Context vorhanden ist: `CloudKitRoutingError.groupContextNotReady`.

## UI Map
### Entry Points
- App entry:
  - `filmfreaks/filmfreaksApp.swift` (`@main`)
  - `filmfreaks/CloudKitShareAppDelegate.swift` (`UIApplicationDelegate`: Share-Accept + Remote Notifications)
  - `filmfreaks/CloudKitShareSceneDelegate.swift` (`UISceneDelegate`: Share delivery path)
- Root View: `filmfreaks/Content/ContentView.swift`

### Hauptnavigation
- `ContentView` nutzt `NavigationStack` + Routing State `ContentRoute`.
- Modale Screens als Sheets: `filmfreaks/Content/ContentRouting.swift`.
  - Settings: `filmfreaks/SettingsView.swift`
  - QuickStart: `filmfreaks/QuickStartView.swift`
  - Movie Search: `filmfreaks/MovieSearch/MovieSearchView.swift`
  - Users: `filmfreaks/UsersView.swift`
  - Stats: `filmfreaks/Stats/StatsView.swift`
  - Timeline: `filmfreaks/Timeline/TimelineView.swift`
  - Calendar: `filmfreaks/MovieNights/Calendar/MovieNightCalendarView.swift`
  - Activity: `filmfreaks/GroupActivityListView.swift`
  - Goals: `filmfreaks/Goals/GoalsView.swift`
  - Group Settings: `filmfreaks/GroupSettingsView.swift`

### In-Screen Navigation
- Movie Detail via `NavigationLink` aus Content-Liste/Grid: `filmfreaks/Content/ContentMainAreaView.swift` → `filmfreaks/MovieDetail/MovieDetailView.swift`.
- Search Result Detail via Navigation in MovieSearch: `filmfreaks/SearchResultDetail/SearchResultDetailView.swift`.

## Build & Configuration
- Xcode project: `filmfreaks.xcodeproj`
- Targets: filmfreaks, filmfreaksTests, filmfreaksUITests
- Deployment target: iOS 26.0
- Device family: 1,2 ("1"=iPhone, "2"=iPad)
- Info.plist: `filmfreaks/Info.plist`
  - `CKSharingSupported` = True
  - `UIBackgroundModes` = ['remote-notification']
  - `TMDB_API_KEY` via build setting: `$(TMDB_API_KEY)`
- Entitlements: `filmfreaks/filmfreaks.entitlements`
  - iCloud containers: ['iCloud.de.marcfechner.filmfreaks']
  - aps-environment: development
- Build configs: `filmfreaks/Debug.xcconfig`, `filmfreaks/Release.xcconfig`, `filmfreaks/Secrets.xcconfig`
  - Secrets handling: `Secrets.xcconfig` enthält aktuell einen **literal** `TMDB_API_KEY` Wert: True. (Security/Repo-Risiko, siehe Quick Wins)
- SPM: keine `XCRemoteSwiftPackageReference` Einträge im `.pbxproj` gefunden → **keine externen Packages** (best effort).

## Conventions
- **File Splits via Extensions**: Stores/Services sind bereits in `+Feature.swift` Extensions gesplittet (z.B. `MovieStore+CloudSync.swift`).
- **Group scoping**: alle cloud-relevanten Operationen sollten `groupId` führen und via `CloudKitRouting.route(...)` laufen.
- **Avoid heavy work in SwiftUI body**: Der Code versucht Derived-Lists out-of-body zu berechnen (`ContentMovieItemsModel`).
- **Persistenz**: große Datenmengen nicht in UserDefaults, sondern `PersistenceManager`.
- **UNKNOWN**: Es gibt keine zentral dokumentierte DI-Schicht; EnvironmentObjects werden direkt im App Root injiziert.

## How to work on this project
### Setup Steps
- Öffnen: `filmfreaks.xcodeproj`.
- Signing & Capabilities: iCloud/CloudKit aktiv (siehe Entitlements).
- TMDb Key setzen:
  - aktuell via `filmfreaks/Secrets.xcconfig` (besser: aus Repo entfernen + lokal via xcconfig/CI Secret).
- Testgerät: iCloud-Login erforderlich für Cloud-Gruppen/Sharing.

### Wo anfangen (für neue Devs)
1) `filmfreaks/filmfreaksApp.swift` → App Composition, EnvironmentObjects, Refresh-Verhalten.
2) `filmfreaks/Content/ContentView.swift` + `Content/ContentRouting.swift` → UI Entry + Navigation.
3) `filmfreaks/MovieStore/MovieStore.swift` + `MovieStore+CloudSync.swift` → Datenfluss Movies.
4) `filmfreaks/CloudKitRouting.swift` + `CloudKitGroupStore.swift` → Group/Sharing Architektur.

## Quick Wins (max 10)
1) **Secrets hardening**: `filmfreaks/Secrets.xcconfig` aus VCS entfernen, `.gitignore`, Key via user-defined build setting oder CI Secret injizieren.
2) **Doppelte Subscription-Tasks entfernen**: `filmfreaks/CloudKitGroupStore.swift` enthält zwei nahezu identische `Task { ensureSubscriptions... }` Blöcke in `refresh()`.
3) **Task cancellation**: Search/Detail Views nutzen `Task { ... }` in `.onAppear`/`.onChange` ohne Cancel (z.B. `SearchResultDetailView`, `MovieSearchView`). Umstellen auf `.task(id:)` oder gespeicherte `Task` + `cancel()`.
4) **Main-thread Aggregationen**: `filmfreaks/Stats/StatsViewModel.swift` Snapshot-Berechnung in background Task (mit Cancellation) verschieben.
5) **Main-thread Sort/Filter**: `filmfreaks/Content/ContentMovieItemsModel.swift` bei großen Listen: sort/filter debounced + background.
6) **Sync-Observability**: Einheitliches Logging (os.Logger) für CloudKit Ops in Stores (teilweise `print`/teilweise `Logger`).
7) **Cloud error UX**: `MovieStore` Sync Errors sind String; standardisieren (CKError mapping wie `UserStore.humanReadableCloudError`).
8) **Reduce equality checks on big arrays**: `StatsViewModel.Inputs` ist `Equatable` mit `[Movie]`/`[User]` → kann bei großen Listen teuer sein; stattdessen Fingerprints (counts + lastUpdatedAt).
9) **Group scoped disk cleanup UI**: `PersistenceManager.deleteGroupData(groupId:)` existiert; in Settings als „Reset local cache“ anbieten (falls noch nicht vorhanden) oder zumindest dokumentieren.
10) **Spot-check remote-notification path**: Background mode ist aktiv; sicherstellen, dass Push Fetch nicht unbounded parallel läuft (`CloudKitActivityPushFetchCoordinator`).
