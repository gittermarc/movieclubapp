# PROJECT_CONTEXT.md

_Last updated: 2026-02-24. Generated from `Archiv.zip`._

## TL;DR
**filmfreaks** ist eine iOS-App (iPhone/iPad) für gemeinsames Film-Tracking in **Gruppen**: Watched/Backlog, Ratings pro Person, Stats/Timeline, Movie Nights und Custom Goals.
- **Minimum iOS:** 26.0 (`filmfreaks.xcodeproj/project.pbxproj`).
- **Storage:** Offline-first über JSON-Dateien (Application Support) + UserDefaults für kleine Keys (`filmfreaks/PersistenceManager.swift`).
- **Sync:** CloudKit (Public DB für Legacy-Gruppen; Private/Shared DB + Zones für Sharing-Gruppen; inkrementell via Zone Changes).
- **Dependencies:** keine SPM Packages im Projekt gefunden (`project.pbxproj`: keine SwiftPackage References).

## Key Concepts / Domänenbegriffe
- **Group / groupId**: String-ID der aktuellen Gruppe.
  - *Legacy/Public group*: groupId ist **nicht** UUID-like → CloudKit **Public DB** (kein ZoneID).
  - *Sharing/Zone group*: groupId ist UUID-like → CloudKit **Private/Shared DB + ZoneID**; ohne `GroupContext` wird Routing abgebrochen (kein Public-Fallback).
  - Routing-Regeln: `filmfreaks/CloudKitRouting.swift`.
- **GroupContext**: Persistiertes Routing-Metadata pro groupId: `scope` (private/shared), `zoneName`, `ownerName` (`filmfreaks/GroupContext.swift`).
- **Watched / Backlog**: getrennte Listen im `MovieStore` (2 Arrays; separate CloudKit Kennzeichnung `isBacklog`) (`filmfreaks/MovieStore/MovieStore.swift`, `filmfreaks/CloudKitMovieStore/CloudKitMovieStore.swift`).
- **Rating**: UI-/Statistik-Modell im `Movie`, aber CloudKit Sync als **eigene** Records `MovieRating` (pro movie+reviewer) (`filmfreaks/Movie.swift`, `filmfreaks/CloudKitRatingStore/*`).
- **Activity**: Group Activity Feed/Preview (UI im Content-Bereich; Push-Subscriptions für Änderungen) (`filmfreaks/Content/*`, `filmfreaks/CloudKit/*`).
- **Movie Night**: Termin + Responses + Activity (lokal + CloudKit Store) (`filmfreaks/MovieNights/*`, `filmfreaks/CloudKitMovieNightStore/*`).
- **Custom Goals**: Ziele auf Basis decade/person/director/genre/keyword + Jahr/Duration; als versioniertes Payload pro Gruppe (`filmfreaks/ViewingCustomGoal.swift`, `filmfreaks/ViewingCustomGoalsPayload.swift`).
- **DisplaySettings**: zentrale Darstellung (tint, font, UI density, presets) (`filmfreaks/DisplaySettings/*`).

## Architecture Map
### Layer/Module (Text-Map + Verantwortlichkeiten)
- **App Shell / Composition Root** → `filmfreaks/filmfreaksApp.swift`
  - init: URLCache (100MB memory / 500MB disk) konfigurieren.
  - erstellt EnvironmentObjects: `MovieStore`, `MovieNightStore`, `UserStore`, `CloudKitGroupStore`, `NetworkMonitor.shared`, `DisplaySettings`, `AppRefreshCoordinator`.
  - `scenePhase == .active` triggert Refresh-Kaskade (coalesced).
- **Routing / Navigation (Sheets)** → `filmfreaks/Content/ContentRouting.swift`
  - `ContentRoute` enum + `ContentRoutingModifier` hängt `.sheet(item:)` an den Host.
- **Feature UIs** → Ordner `Content/`, `MovieSearch/`, `SearchResultDetail/`, `MovieDetail/`, `Stats/`, `Timeline/`, `MovieNights/`, `Goals/`.
- **Stores (State + Mutationen + Sync)** → `MovieStore/*`, `UserStore.swift`, `MovieNights/MovieNightStore*.swift`, `CloudKitGroupStore.swift`, `DisplaySettings/*`.
- **CloudKit Low-Level Stores** → `CloudKitMovieStore/*`, `CloudKitRatingStore/*`, `CloudKitUserStore.swift`, `CloudKitGoalStore.swift`, `CloudKitMovieNightStore/*`.
- **Persistence** → `PersistenceManager.swift` (JSON), UserDefaults (`GroupContextStore`, AppStorage).

### Abhängigkeiten (intended direction)
- Views → Stores → (CloudKit*Store / PersistenceManager / TMDbAPI / helpers)
- CloudKit*Store → (CloudKitRouting / ZoneChanges / TokenStore)
- PersistenceManager ist „leaf“ (keine View-Abhängigkeiten).

## Folder Map (Ordner → Zweck)
- `filmfreaks/Content/` — Home, Header, List/Grid, Routing, Group Activity UI, off-render-path models.
- `filmfreaks/MovieStore/` — MovieStore facade + extensions: persistence, mutations, sync, selections, activity.
- `filmfreaks/MovieSearch/` — Search UI, Search tasks, recommendations, scanner sheet, detail sheet routing.
- `filmfreaks/SearchResultDetail/` — Detail-Sheet für TMDb Search Result (Details, Watch Providers, Trailer, Add actions).
- `filmfreaks/MovieDetail/` — Detail UI für gespeicherten Film inkl. Rating Editing und TMDb-Enrichment.
- `filmfreaks/Stats/` — Stats UI + Snapshot computation (`StatsSnapshotBuilder`).
- `filmfreaks/Timeline/` — Timeline UI + Data helpers.
- `filmfreaks/Goals/` — Goals UI + Custom Goal Editor + derived computations + persistence wiring.
- `filmfreaks/MovieNights/` — Movie Night models, store, calendar UI, sheets, cloud coordinator, local persistence.
- `filmfreaks/CloudKitMovieStore/` — CloudKit Movie schema, routing, modify, merge, zone changes.
- `filmfreaks/CloudKitRatingStore/` — CloudKit Rating schema, queries, modify, zone changes.
- `filmfreaks/CloudKitMovieNightStore/` — CloudKit schema & snapshot/zone changes für Movie Nights.
- `filmfreaks/CloudKit/` — Activity subscriptions + push fetch coordination + debugger.
- `filmfreaks/DisplaySettings/` — DisplaySettings facade + defaults/persistence/presets/metrics.

## Data Model Map (Entities, Relationships, wichtige Felder)
### App-level entities (Codable structs, **kein** SwiftData/CoreData)
- SwiftData/CoreData usage: NOT FOUND (Project scan: keine `import SwiftData` / `import CoreData`).
- `filmfreaks/Movie.swift`
  - `Movie`:
    - identity: `id: UUID`
    - content: `title`, `year`, `tmdbId`, `posterPath`, `tmdbRating`
    - tracking: `watchedDate`, `watchedLocation`, `suggestedBy`
    - taxonomy: `genres`/`genreIds`, `keywords`/`keywordIds`
    - people: `cast`, `directors` (TMDb person refs)
    - group: `groupId`, `groupName`
    - social meta: `addedAt`, `addedById`, `addedByName`
    - ratings: `ratings: [Rating]` (UI-only; CloudKit separat)
  - `Rating`: reviewer identity (`reviewerId`), display (`reviewerName`), `scores` (criteria), `fazitScore`, `updatedAt`.
- `filmfreaks/User.swift` — `User` (UUID, name).
- `filmfreaks/GroupContext.swift` — `GroupContext` (id, name, scope private/shared, zoneName, ownerName).
- Movie Nights:
  - `filmfreaks/MovieNights/MovieNightEvent.swift` — (id UUID, groupId, proposedStart, proposerUserId/name, status, optional suggestedMovie, timestamps).
  - `filmfreaks/MovieNights/MovieNightResponse.swift` — links to Event via `eventId` + user decision.
  - `filmfreaks/MovieNights/MovieNightMovieRef.swift` — points to a backlog movie by UUID + title/year/poster/tmdbId.
- Goals:
  - `filmfreaks/ViewingCustomGoal.swift` — Goal type + rule matcher (decade/person/director/genre/keyword) + validity scope.
  - `filmfreaks/ViewingCustomGoalsPayload.swift` — versioniertes payload pro Gruppe.

## Sync/Storage
### Local Storage
- **Disk JSON** via `PersistenceManager` (`filmfreaks/PersistenceManager.swift`)
  - pro Gruppe eigene Dateien (watched/backlog/users).
  - debounced writes (`debounceSeconds = 0.55`) auf Utility queue.
  - Migration-Flag in UserDefaults: `FilmFreaks.diskPersistence.v2.migrated`.
- **UserDefaults/AppStorage** für:
  - GroupContexts (`filmfreaks/GroupContext.swift`) und diverse UI flags (z.B. Onboarding, WatchProvider Region).
  - Sync meta per group (pendingCount/lastSyncAt/lastError) (`filmfreaks/MovieStore/MovieStore+Persistence.swift`).

### CloudKit
- Routing (DB + optional ZoneID): `filmfreaks/CloudKitRouting.swift`
- Change tokens pro Zone + Namespace: `filmfreaks/CloudKitZoneChangeTokenStore.swift`
- Inkrementeller Fetch: `filmfreaks/CloudKitZoneChanges.swift` (Wrapper um `CKFetchRecordZoneChangesOperation`).
- Record types (source of truth in code):
- Movies: `Movie` (`filmfreaks/CloudKitMovieStore/CloudKitMovieStore.swift`)
- Ratings: `MovieRating` (`filmfreaks/CloudKitRatingStore/CloudKitRatingStore+Schema.swift`)
- Members: `GroupMember` (`filmfreaks/CloudKitUserStore.swift`)
- Groups: `FFGroup` (`filmfreaks/CloudKitGroupStore.swift`)
- Goals: `ViewingGoal`, `ViewingCustomGoals` (`filmfreaks/CloudKitGoalStore.swift`)
- Movie Nights: `MovieNightEvent`, `MovieNightResponse`, `MovieNightActivity` (`filmfreaks/CloudKitMovieNightStore/CloudKitMovieNightStore.swift`)

### Refresh triggers (app lifecycle)
- `filmfreaks/filmfreaksApp.swift`
  - `.onChange(of: scenePhase)` when `.active` → `appRefresh.triggerRefresh { ... }`
  - cascade: group refresh → flush pending movie nights → movie/user refresh → movie nights refresh.
- `filmfreaks/AppRefreshCoordinator.swift` coalesced repeated triggers (debounce + no parallel refresh).

## UI Map (Hauptscreens + Navigation + wichtige Sheets/Flows)
### Root composition
- Root view: `ContentView()` in `filmfreaks/filmfreaksApp.swift`.
- Global overlays: `ToastHost()` + optional `SplashView`.

### Home (ContentView)
- `filmfreaks/Content/ContentView.swift`
  - `NavigationStack` + `ContentHeaderView` + `ContentMainAreaView`.
  - Sheet routing state: `@State private var route: ContentRoute?`.
  - Render path optimizations: `@StateObject ContentMovieItemsModel`, `@StateObject ContentActivityPreviewModel`.

### Central sheet routing (ContentRoute)
- Enum cases: `settings`, `quickStart`, `movieSearch`, `users`, `stats`, `timeline`, `calendar`, `activity`, `goals`, `groupSettings` (`filmfreaks/Content/ContentRouting.swift`).
- Presentation: `.sheet(item: $route)` in `ContentRoutingModifier`.

### Notable feature flows
- Search:
  - `MovieSearchView` zeigt Results und öffnet `SearchResultDetailView` als Sheet (`filmfreaks/MovieSearch/MovieSearchView.swift`).
- Movie detail:
  - `MovieDetailView` für gespeicherte Filme (`filmfreaks/MovieDetail/MovieDetailView.swift`).
- Movie nights:
  - Calendar UI → `MovieNightDetailSheet` (`filmfreaks/MovieNights/Sheets/MovieNightDetailSheet.swift`).

## Build & Configuration
- Targets: `filmfreaks`, `filmfreaksTests`, `filmfreaksUITests` (`project.pbxproj`).
- Bundle ID: `de.marcfechner.filmfreaks`
- Marketing version: 1.4, Build: 2
- `filmfreaks/Info.plist` enthält nur wenige, gezielte Keys:
  - `CKSharingSupported = true`
  - `UIBackgroundModes = remote-notification`
  - `TMDB_API_KEY = $(TMDB_API_KEY)` (Build setting via xcconfig)
- Entitlements: `filmfreaks/filmfreaks.entitlements`
  - iCloud container(s): iCloud.de.marcfechner.filmfreaks
  - aps-environment: development
- Build configurations:
  - `filmfreaks/Debug.xcconfig`, `filmfreaks/Release.xcconfig` includen `Secrets.xcconfig`.
  - `filmfreaks/Secrets.xcconfig` enthält **TMDb API Key im Klartext** (siehe Quick Wins / Risiken).

## Conventions
- File splits per extensions/Subviews: `Type+Feature.swift` (bei Stores, Settings, Stats, CloudKit Stores).
- `internal import SwiftUI` wird häufig genutzt (konsistentes Module scoping).
- Stores sind meist `@MainActor` und publishen via `@Published` (ObservableObject).
- CloudKit stores sind oft `struct` + `async` APIs; schema keys liegen in der jeweiligen Store-Datei/Schema-Extension.

## How to work on this project
### Setup Steps (lokal)
1) Xcode öffnen: `filmfreaks.xcodeproj`.
2) Signing/iCloud prüfen (CloudKit capability; Container: siehe Entitlements).
3) TMDb Key konfigurieren:
   - empfohlen: `Secrets.xcconfig` lokal (nicht committed) + `Secrets.xcconfig.example` committed.
4) Run & Test:
   - CloudKit Sharing/Push am besten auf Device mit iCloud Login (Development vs Production beachten).

### Wo anfangen für neue Devs
- App composition + refresh: `filmfreaks/filmfreaksApp.swift`, `filmfreaks/AppRefreshCoordinator.swift`
- Routing + Home: `filmfreaks/Content/ContentView.swift`, `filmfreaks/Content/ContentRouting.swift`
- Sync core:
  - Movies: `filmfreaks/MovieStore/*` + `filmfreaks/CloudKitMovieStore/*`
  - Ratings: `filmfreaks/CloudKitRatingStore/*`
  - Groups: `filmfreaks/CloudKitGroupStore.swift` + `filmfreaks/CloudKitRouting.swift`
  - Local persistence: `filmfreaks/PersistenceManager.swift`

## Quick Wins (max. 10)
1) **Secrets hygiene:** `filmfreaks/Secrets.xcconfig` ist committed und enthält echten Key → raus aus Git + Rotation.
2) **Persisted retry for uploads:** Pending upload queues sind in-memory → minimal dirty-set persistieren und beim Launch reconciliieren.
3) **Surfacing routing readiness:** `CloudKitRoutingError.groupContextNotReady` UX-seitig sichtbar machen (Toast/Settings hint).
4) **Task cancellation in sheets:** SearchResultDetail/MovieSearch Tasks sauber canceln bei Dismiss/Disappear.
5) **CloudKit schema doc:** aus Code generieren (RecordTypes + Keys + recordName rules) → reduziert Dashboard/Code drift.
6) **Coalesced refresh in more stores:** pattern wie `AppRefreshCoordinator` auch für Group/User/Movie refresh tasks (falls parallel möglich).
7) **Split biggest views:** `SearchResultDetailView.swift`, `MovieNightDetailSheet.swift`, `MovieSearchView.swift` (mechanisch, low risk).
8) **MainActor workload audit:** teure O(n) diffing/sorts in Stores auf background snapshot verschieben, wenn Datensätze wachsen (pattern: `StatsSnapshotBuilder`).
9) **Improve sync transparency:** pending count/last sync sind da; UI-Hook zentralisieren (z.B. `ContentSyncStatusLineView.swift`).
10) **Add unit tests for pure helpers:** recordName parsing, stable ID helpers (Tests status derzeit **UNKNOWN**).
