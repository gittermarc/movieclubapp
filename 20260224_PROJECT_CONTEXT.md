# PROJECT_CONTEXT.md — filmfreaks / “The Movie Club”

## TL;DR
**filmfreaks** ist eine iOS‑App (SwiftUI), die Filme in einer Gruppe organisiert: **Gesehen** vs **Backlog**, **Bewertungen** pro Mitglied, plus **Stats**, **Goals**, **Timeline** und **Movie Nights**. Persistenz ist **lokal (JSON auf Disk)** plus **CloudKit Sync** (inkl. CloudKit Sharing für Gruppen). Mindest‑iOS laut Xcode‑Projekt: **26.0** (`filmfreaks.xcodeproj/project.pbxproj` → `IPHONEOS_DEPLOYMENT_TARGET = 26.0;`).

> Hinweis: **SwiftData/CoreData wird nicht verwendet** (im Codebase kein `import SwiftData` / `import CoreData` gefunden).

---

## Key Concepts / Domänenbegriffe
- **Watched / Backlog**: Zwei Listen je Gruppe (`MovieStore.movies` vs `MovieStore.backlogMovies`).
- **Group / groupId**:
  - “Legacy/public” Gruppen via Invite‑Code (String) → Public DB Query‑Pfad.
  - “Sharing/Zone” Gruppen via UUID‑ähnlicher `groupId` (CloudKit Sharing) → Private/Shared DB + Zone (`CloudKitRouting.requiresGroupContext`).
  - Routing‑Metadaten werden als **GroupContext** persistiert.
- **GroupContext**: Minimaler Routing‑Datensatz (scope/private|shared, zoneName, ownerName) in `UserDefaults` (`filmfreaks/GroupContext.swift`).
- **Ratings**: Bewertungen sind **separate CloudKit Records** (RecordType `MovieRating`) und werden beim Movie‑Fetch bewusst nicht mitgeladen (`CloudKitMovieStore+Schema.swift` setzt `decoded.ratings = []`). Merge passiert im `MovieStore`.
- **Zone Changes (Phase 2)**: In Sharing‑Gruppen wird inkrementell synchronisiert über `CKFetchRecordZoneChangesOperation` (`filmfreaks/CloudKitZoneChanges.swift` + `CloudKitZoneChangeTokenStore.swift`).
- **Pending Cloud Changes**: Lokale Änderungen werden debounced + gebatcht hochgeladen (Movie: `MovieCloudSyncCoordinator.swift`; MovieNight: `MovieNightCloudSyncCoordinator.swift`).
- **Group Activity**:
  - UI‑Feed ist **derived** aus Movie/Ratings (kein eigener Cloud RecordType) (`filmfreaks/Content/GroupActivityEvent.swift`).
  - Pushes werden (Debug‑only) gefetched und in Local Notifications übersetzt (`filmfreaks/CloudKit/CloudKitActivityPushFetchCoordinator.swift`, `filmfreaks/Notifications/GroupActivityLocalNotifier.swift`).

---

## Architecture Map
Text‑Map (Layer → Verantwortung → Abhängigkeiten):

1) **UI (SwiftUI Views)**
- Hauptscreen: `filmfreaks/Content/ContentView.swift` + Subviews/Extensions (`filmfreaks/Content/*`).
- Feature‑Screens: `MovieSearch/*`, `MovieDetail/*`, `SearchResultDetail/*`, `Stats/*`, `Goals/*`, `Timeline/*`, `MovieNights/*`, `SettingsView.swift`, `GroupSettingsView.swift`.
- Abhängig von: Stores (`MovieStore`, `UserStore`, …), Models (`Movie`, `User`, …), DisplaySettings.

2) **State/Stores (ObservableObject / MainActor)**
- `MovieStore` (Core state + sync orchestration): `filmfreaks/MovieStore/*`.
- `UserStore`: `filmfreaks/UserStore.swift`.
- `MovieNightStore`: `filmfreaks/MovieNights/MovieNightStore.swift`.
- `CloudKitGroupStore`: `filmfreaks/CloudKitGroupStore.swift` (Groups + sharing + subscriptions + repairs).
- `DisplaySettings`: `filmfreaks/DisplaySettings/*`.
- Abhängig von: Persistenz (`PersistenceManager`), CloudKit Stores, Routing, NetworkMonitor.

3) **Sync Layer (CloudKit “Stores”)**
- Movies: `filmfreaks/CloudKitMovieStore/*`.
- Ratings: `filmfreaks/CloudKitRatingStore/*`.
- Group Members: `filmfreaks/CloudKitUserStore.swift`.
- Goals: `filmfreaks/CloudKitGoalStore.swift`.
- Movie Nights: `filmfreaks/CloudKitMovieNightStore/*`.
- Shared plumbing: `CloudKitRouting.swift`, `CloudKitZoneChanges.swift`, `CloudKitZoneChangeTokenStore.swift`.

4) **Local Persistence + Caches**
- Große Arrays (Movies/Backlog/Users): JSON auf Disk (Application Support): `filmfreaks/PersistenceManager.swift`.
- Small state + tokens: `UserDefaults` (z.B. currentGroupId, GroupContexts, ZoneChangeTokens).
- Image caching:
  - Global HTTP cache: `URLCache.shared` wird im App‑Init konfiguriert (`filmfreaks/filmfreaksApp.swift`).
  - App‑eigener Disk+Memory Cache: `ImageCacheStore` Actor (`filmfreaks/CachedAsyncImage.swift`).

5) **External Integrations**
- TMDb: `filmfreaks/TMDbAPI/*`.
- YouTube Embed: `filmfreaks/YouTubePlayerView.swift`.
- Network reachability: `filmfreaks/NetworkMonitor.swift`.

6) **System glue / App lifecycle**
- App entry: `filmfreaks/filmfreaksApp.swift`.
- Share acceptance + notifications: `CloudKitShareAppDelegate.swift`, `CloudKitShareSceneDelegate.swift`, `CloudKitShareCoordinator.swift`.
- Resume refresh coalescing: `AppRefreshCoordinator.swift`.

---

## Folder Map (Ordner → Zweck)
Top‑Level unter `filmfreaks/`:
- `Content/` — Root UI (Header/MainArea/Activity Preview, Routing, Onboarding, Index Cache).
- `MovieStore/` — zentraler Store (State, Persistence, CloudSync, Mutations, Selections, Activity).
- `CloudKitMovieStore/` — CloudKit CRUD + ZoneChanges für Movies.
- `CloudKitRatingStore/` — CloudKit CRUD + ZoneChanges für Ratings.
- `CloudKitMovieNightStore/` — CloudKit CRUD + ZoneChanges + Snapshot/Routing für MovieNight.
- `CloudKit/` — Activity Push Fetch, Subscription Manager, Remote Notification Debugger.
- `MovieNights/` — Domain + UI (Calendar, Sheets) + lokale Persistenz + Sync Coordinator.
- `MovieSearch/` — TMDb Suche, Scanner, Recommendations, Ergebnislisten.
- `SearchResultDetail/` — Detailansicht eines Suchtreffers (Hero, Info, WatchProviders, Trailer, Add‑to‑List).
- `MovieDetail/` — Detailansicht eines gespeicherten Movies inkl. Ratings.
- `Stats/` — Stats UI + `StatsViewModel` Aggregation.
- `Goals/` — Goals UI + CustomGoals + TMDb Anreicherung.
- `Timeline/` — Timeline Screen.
- `Notifications/` — Local notification plumbing + deep links + dedupe state.
- `DisplaySettings/` — UI‑Preferences (Tint, LayoutMetrics, Presets, Persistence).
- `Assets.xcassets/` — Icons, AccentColor.

---

## Data Model Map

### Core
- `Movie` (`filmfreaks/Movie.swift`)
  - Identität: `id: UUID`
  - Metadaten: `title`, `year`, `tmdbId`, `posterPath`, `tmdbRating`
  - Gruppenkontext: `groupId`, `groupName`
  - Activity: `addedAt`, `addedById`, `addedByName`
  - Watch state: `watchedDate`, `watchedLocation`, `suggestedBy`
  - Enrichment: `genres/genreIds`, `keywords/keywordIds`, `cast`, `directors`
  - Beziehung: `ratings: [Rating]`

- `Rating` (`filmfreaks/Movie.swift`)
  - Reviewer: `reviewerId: UUID?` + `reviewerName`
  - Inhalt: `scores`, optional `comment`, optional `fazitScore`
  - Meta: `updatedAt` (best‑effort)

- `User` (`filmfreaks/User.swift`)
  - `id: UUID`, `name: String`

### Gruppen/Routing
- `GroupContext` + `GroupContextStore` (`filmfreaks/GroupContext.swift`)
  - `id` (= groupId), `name`, `scope: private|shared`, `zoneName`, `ownerName`

### Activity / Notifications
- `GroupActivityEvent` (`filmfreaks/Content/GroupActivityEvent.swift`)
  - UI‑Event, derived aus Movies/Ratings (kein Cloud storage “yet”).
- Push deep link routing:
  - `PushDeepLinkRouter` (`filmfreaks/Notifications/PushDeepLinkRouter.swift`) postet `.pushDeepLinkRequested`.
  - `ContentView` konsumiert das und schaltet Gruppe + öffnet Activity (`ContentView.handlePushDeepLink`).

### Movie Nights
- `MovieNightEvent` (`filmfreaks/MovieNights/MovieNightEvent.swift`)
- `MovieNightResponse` (`filmfreaks/MovieNights/MovieNightResponse.swift`)
- `MovieNightActivityEvent` (`filmfreaks/MovieNights/MovieNightActivityEvent.swift`)

### Goals
- `ViewingCustomGoal` + `ViewingCustomGoalRule` (`filmfreaks/ViewingCustomGoal.swift`)

### UI Settings
- `DisplaySettings` (`filmfreaks/DisplaySettings/DisplaySettings.swift` + Extensions)
  - Enthält Presets, Tint‑Style, LayoutMetrics, Persistence.

**UNKNOWN**
- Ob es zusätzliche persistierte Goal‑Modelle gibt (z.B. yearly goals), die nicht als eigene Types auftreten.

---

## Sync/Storage

### Local Storage
- **Movies/Backlog/Users** werden als JSON in `Application Support/FilmFreaks/groups/<groupId>/...json` gespeichert.
  - Implementierung: `filmfreaks/PersistenceManager.swift`.
  - Debounced writes (0.55s) auf Utility‑Queue.
  - Migration v1 UserDefaults → Files (Flag `FilmFreaks.diskPersistence.v2.migrated`).

### CloudKit

#### Routing
- Zentral: `filmfreaks/CloudKitRouting.swift`.
- Regeln:
  - Keine groupId → Public DB.
  - GroupContext vorhanden → Private/Shared DB + Zone.
  - GroupContext fehlt:
    - groupId UUID‑like → **throw** `groupContextNotReady`.
    - sonst → legacy/public group → Public DB.

#### Groups / Sharing
- Gruppen sind **Record Zones** mit Naming `group.<groupId>`; Root‑Record `FFGroup` trägt Name/createdAt.
  - Listing: via Zone‑Listing + Root‑Fetch (nicht per Query) (`filmfreaks/CloudKitGroupStore.swift`).
  - Sharing: CKShare auf Root‑Record (`CloudKitGroupStore.fetchOrCreateShare`).
  - Share acceptance: `CloudKitShareCoordinator.accept` + Notification `.cloudKitShareAccepted`.

#### Movies
- RecordType: `Movie` (`filmfreaks/CloudKitMovieStore/CloudKitMovieStore.swift`).
- Feldschema: `payload(Data)`, `isBacklog(Bool)`, `updatedAt(Date)`, `groupId(String)`.
- Sharing: `record.parent` auf Root‑Record (`CloudKitMovieStore+Modify.swift`).
- Fetch:
  - Sharing/Zone: `fetchMovieChanges` (`CloudKitMovieStore+ZoneChanges.swift`) → inkrementell.
  - Legacy/Public: Query fetch + legacy migration (`CloudKitMovieStore+Routing.swift`).

#### Ratings
- RecordType: `MovieRating` (`filmfreaks/CloudKitRatingStore/CloudKitRatingStore+Schema.swift`).
- Stabile RecordIDs (base64‑url) pro `(groupId, movieId, reviewerId)`.
- Merge:
  - Movies kommen “rating‑leer” aus Cloud (`CloudKitMovieStore+Schema.swift`).
  - `MovieStore+CloudSync.swift` konserviert lokale Ratings und merged Cloud‑Ratings.

#### Members (Users)
- RecordType: `GroupMember` (`filmfreaks/CloudKitUserStore.swift`).
- Migration legacy recordName → `memberId` Feld (best effort).

#### Movie Nights
- Cloud store: `filmfreaks/CloudKitMovieNightStore/*`.
- Local state + sync coordinator: `filmfreaks/MovieNights/MovieNightStore.swift` + `MovieNightCloudSyncCoordinator.swift`.

#### Goals
- Cloud store: `filmfreaks/CloudKitGoalStore.swift`.

#### Zone Change Tokens
- Persistenz: `filmfreaks/CloudKitZoneChangeTokenStore.swift`.
- Namespaces: z.B. `movies`, `ratings`, `movieNights` (siehe jeweilige `+ZoneChanges.swift`).

### Offline Verhalten
- App ist **lokal‑first**: beim Group‑Switch wird zuerst Disk‑Cache geladen (`MovieStore+Selections.loadLocalCache`).
- Cloud Writes werden queued/debounced; bei Offline wird Flush geskipped (`MovieCloudSyncCoordinator.flushNow` → `networkIsAvailable()`).
- Reconnect flush: `MovieStore.setupNetworkReconnectHandling` (`MovieStore+CloudSync.swift`).

### Migration
- Local: UserDefaults → Files (`PersistenceManager.swift`).
- Movie payload: legacy `cast: [String]` → `[CastMember]` Migration im Decoder (`Movie.swift`).
- Cloud: legacy groupId Feld in Movie Records wird best‑effort nachgetragen (`CloudKitMovieStore+Routing.migrateLegacyGroupIdFieldAndFetch`).

**UNKNOWN**
- Server‑seitige CloudKit Index‑Konfiguration / Deployment‑Status der RecordTypes.

---

## UI Map (Hauptscreens + Navigation)

### Entry / Root
- `filmfreaks/filmfreaksApp.swift`
  - `WindowGroup` zeigt `ContentView`.
  - EnvironmentObjects: `MovieStore`, `MovieNightStore`, `UserStore`, `CloudKitGroupStore`, `NetworkMonitor`, `DisplaySettings`.
  - App‑Resume Refresh via `AppRefreshCoordinator` (coalesced).

### ContentView (Home)
- `filmfreaks/Content/ContentView.swift`
  - `NavigationStack` + eigener `ContentRoute`.
  - Header: `ContentHeaderView`.
  - Main Area: `ContentMainAreaView` (List/Grid + Pull‑to‑Refresh).
  - Derived Models (off render path):
    - `ContentMovieItemsModel` (`filmfreaks/Content/ContentMovieItemsModel.swift`).
    - `ContentActivityPreviewModel` (`filmfreaks/Content/ContentActivityPreviewModel.swift`).
  - Sheet routing: `filmfreaks/Content/ContentRouting.swift` (`.sheet(item:)`).
  - Push deep link: `.onReceive(.pushDeepLinkRequested)` → `handlePushDeepLink`.

### Sheets (ContentRoute)
Definiert in `filmfreaks/Content/ContentRouting.swift`:
- Settings: `SettingsView.swift`
- Quick Start: `QuickStartView.swift`
- Movie Search: `MovieSearch/MovieSearchView.swift`
- Users: `UsersView.swift`
- Stats: `Stats/StatsView.swift`
- Timeline: `Timeline/TimelineView.swift`
- Calendar: `MovieNights/Calendar/MovieNightCalendarView.swift`
- Activity: `Content/GroupActivityListView.swift`
- Goals: `Goals/GoalsView.swift`
- Group Settings: `GroupSettingsView.swift`

### Detail Flows
- Search Result Detail: `SearchResultDetail/SearchResultDetailView.swift`.
- Movie Detail: `MovieDetail/MovieDetailView.swift` + Ratings Sheet `MovieRatingsSheetView.swift`.
- Movie Nights:
  - Calendar list/day: `MovieNights/Calendar/*`.
  - Propose sheet: `MovieNights/Sheets/ProposeMovieNightSheet.swift`.
  - Detail sheet: `MovieNights/Sheets/MovieNightDetailSheet.swift`.

---

## Build & Configuration

### Xcode Project
- Projekt: `filmfreaks.xcodeproj`
- Targets:
  - App: `de.marcfechner.filmfreaks` (`project.pbxproj` → `PRODUCT_BUNDLE_IDENTIFIER`).
  - Tests: `de.marcfechner.filmfreaksTests`, `de.marcfechner.filmfreaksUITests` (Targets vorhanden; **keine** Test‑Sources im Repo gefunden).
- Supported platforms: iPhoneOS + iPhoneSimulator (`SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"`).

### Entitlements / Capabilities
- `filmfreaks/filmfreaks.entitlements`
  - iCloud container: `iCloud.de.marcfechner.filmfreaks`
  - iCloud service: CloudKit
  - APS env: `development`

### Info.plist
- `filmfreaks/Info.plist`
  - `CKSharingSupported = true`
  - `UIBackgroundModes = [remote-notification]`
  - `TMDB_API_KEY = $(TMDB_API_KEY)`

### xcconfig / Secrets
- `filmfreaks/Debug.xcconfig` und `filmfreaks/Release.xcconfig` inkludieren `Secrets.xcconfig`.
- `.gitignore` ignoriert `filmfreaks/Secrets.xcconfig`.

**Quick sanity checklist (Build)**
- [ ] `Secrets.xcconfig` existiert lokal und enthält `TMDB_API_KEY`.
- [ ] Signing/Team passt (Projekt hat `DEVELOPMENT_TEAM = HPJKAPZ8A3;`).
- [ ] iCloud Capability aktiv + Container ID stimmt mit Entitlements.
- [ ] Push/remote notification background mode passt (real device required).

---

## Conventions (Naming, Patterns, Do/Don’t)

### File Splits
- Pattern: `Type+Feature.swift` (z.B. `MovieStore+CloudSync.swift`, `CloudKitMovieStore+ZoneChanges.swift`).
- Ziel: klarer “Surface” Typ + fokussierte Implementations‑Extensions.

### `internal import SwiftUI`
- Viele Dateien nutzen `internal import SwiftUI` statt `import SwiftUI`.
- Das wirkt wie ein Stil‑Entscheid (Visibility) — beim Refactor beibehalten, um Diff‑Noise zu vermeiden.

### Actor/MainActor
- Stores mutieren überwiegend auf `@MainActor` (`MovieStore`, `StatsViewModel`, `NetworkMonitor`).
- Für echte Parallelität: `actor` selektiv nutzen (z.B. `ImageCacheStore` in `CachedAsyncImage.swift`).

### UI
- “Compute outside render path”: abgekapselte Models (`ContentMovieItemsModel`, `ContentActivityPreviewModel`).

### Do/Don’t
- ✅ Do: schwere Filter/Sort/Map in Models/Services (nicht in `body`).
- ✅ Do: groupId snapshotten, bevor async calls starten (siehe `MovieStore+CloudSync.loadFromCloud`).
- ❌ Don’t: CloudKit routing bei UUID‑groupId ohne `GroupContext` in Public DB fallen lassen (`CloudKitRouting` schützt).

---

## How to work on this project

### Setup Steps
1) Xcode öffnen: `filmfreaks.xcodeproj`.
2) Secrets setzen:
   - Lege `filmfreaks/Secrets.xcconfig` an.
   - Stelle sicher, dass `TMDB_API_KEY` gesetzt ist.
3) Signing:
   - Team & Bundle ID prüfen (`de.marcfechner.filmfreaks`).
4) iCloud/CloudKit:
   - Capability aktivieren, Container `iCloud.de.marcfechner.filmfreaks`.
   - Für Sharing/Push idealerweise auf **real device** testen.
5) Run.

### Wo anfangen (für neue Devs)
- Entry: `filmfreaks/filmfreaksApp.swift`
- Root UI + Navigation: `filmfreaks/Content/ContentView.swift` + `Content/ContentRouting.swift`
- Core state: `filmfreaks/MovieStore/MovieStore.swift`
- Sync/Routing: `filmfreaks/CloudKitRouting.swift` + `CloudKitMovieStore/*` + `CloudKitRatingStore/*`

### Typischer Workflow: neues Feature hinzufügen
- UI Entry:
  - “Hauptscreen”: Route in `Content/ContentRouting.swift` ergänzen.
  - Quick access: Toolbar Entry in `filmfreaks/Content/ContentView+Toolbar.swift` (falls genutzt).
- State:
  - Neuen Store als `ObservableObject` anlegen (idealerweise `@MainActor`).
  - In `filmfreaksApp.swift` als `.environmentObject` injecten.
- Persistenz:
  - Große Daten: `PersistenceManager` (Disk JSON).
  - Kleine Flags/Meta: `UserDefaults` (eigene keys, Namespacing).
- CloudKit:
  - Neuen RecordType/Schema in dedizierter CloudKitStore‑Struktur + Extension‑Files.
  - Routing immer via `CloudKitRouting.route(...)`.
  - Sharing‑Gruppen: `record.parent` auf Group Root setzen.
  - Skalierung: ZoneChanges + `CloudKitZoneChangeTokenStore`.

---

## Quick Wins (max 10)
1) **Secrets handling härten**: `filmfreaks/Secrets.xcconfig` enthält in diesem ZIP einen echten Key. Sicherstellen, dass Secrets **nie** in Artefakten/Backups landen (z.B. `Secrets.xcconfig.example` + CI secrets). (`Secrets.xcconfig`, `.gitignore`).
2) **MovieSearch concurrency säubern**: `MovieSearchView+Search.swift` setzt View‑States teils außerhalb `MainActor` (`isLoading = true`) und hat keine Cancellation/Task‑Debounce.
3) **Stats Snapshot off‑main**: `StatsViewModel.computeSnapshot` läuft auf `@MainActor` und macht mehrere vollständige Passes + Sorts über `movies`. In `StatsView.swift` wird das auf vielen `.onChange` Triggern aufgerufen.
4) **MovieStore didSet Equality**: `MovieStore+Persistence.handleMoviesDidSet` nutzt `oldValue == movies` (O(n) Deep‑Equality). Bei großen Listen + häufigen Mutations kann das messbar werden.
5) **CloudKitGroupStore.refresh parallelisieren**: Root‑Record Fetch wird pro Zone sequenziell gemacht (`CloudKitGroupStore.fetchGroupContexts`). Für viele Gruppen langsam.
6) **Zone Token Hygiene**: beim “Leave group” (z.B. `MovieStore.leaveCurrentGroup`, `CloudKitGroupStore.leaveSharedGroup`) werden ZoneChangeTokens nicht explizit gecleared → potenziell stale Tokens (`CloudKitZoneChangeTokenStore`).
7) **Push handling in Release**: `CloudKitActivityPushFetchCoordinator.fetchAndHandle` ist `#if DEBUG` gated → in Release passiert bei Pushes effektiv nichts. Entscheiden, ob das beabsichtigt ist.
8) **Tests bootstrappen**: Targets existieren, aber keine Test‑Sources. Minimal: Smoke tests für `CloudKitRouting`, `MovieSearchIndexCache`, `StableID`.
9) **Logging vereinheitlichen**: Mischung aus `print` und `Logger` (`PersistenceManager` nutzt `os.Logger`). Ein einheitliches Logging‑Konzept erleichtert Debugging.
10) **UI invalidation reduzieren**: `ContentView` hat viele `.onReceive/.onChange` Trigger; prüfen, ob einige zusammengeführt werden können (z.B. in einem “inputs” struct wie bei `StatsViewModel`).
