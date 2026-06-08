# PROJECT_CONTEXT.md

## TL;DR

**TMC - The Movie Club** ist eine SwiftUI-App für iPhone und iPad zum Verwalten gemeinsamer Filmlisten, Backlog, Bewertungen, Filmabend-Planung, Ziele, Statistiken und TMDb-basierter Filmsuche. Das Xcode-Projekt setzt projektweit `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, nutzt `iphoneos` und `iphonesimulator` sowie `TARGETED_DEVICE_FAMILY = 1,2`. Es wurde kein SwiftData, CoreData, `@Model`, `ModelContainer` oder `NSPersistentContainer` gefunden. Persistenz läuft über Codable-JSON in Application Support, kleine Metadaten in UserDefaults und CloudKit für Sync, Sharing und Gruppen.

## Key Concepts / Domänenbegriffe

- **Group / Gruppe**: Arbeitskontext für Filme, Mitglieder, Filmabende und Ziele. Moderne Gruppen sind UUID-basierte CloudKit-Sharing-Gruppen mit eigener Record Zone.
- **GroupContext**: Persistierte Routing-Metadaten aus `filmfreaks/GroupContext.swift`: `id`, `name`, `scope`, `zoneName`, `ownerName`. Andere Stores nutzen das, um private oder shared CloudKit DB plus Zone zu wählen.
- **Local / Legacy Group**: Ohne Gruppe oder mit nicht UUID-artigem Invite-Code fällt CloudKit bewusst auf den Public-DB-Pfad zurück. UUID-Gruppen dürfen ohne `GroupContext` nicht in Public DB fallen.
- **Watched / Backlog**: Zwei `Movie`-Arrays in `filmfreaks/MovieStore/MovieStore.swift`, lokal getrennt als `movies_watched.json` und `movies_backlog.json`.
- **Movie**: Codable-Domain-Entity in `filmfreaks/Movie.swift`. Enthält TMDb-Metadaten, lokale eingebettete Ratings, Cast, Directors, Genres, Keywords und Gruppenfelder.
- **Rating**: Per-Reviewer-Bewertung in `filmfreaks/Movie.swift`. Lokal in `Movie.ratings`, in CloudKit aber separat als `MovieRating`-Record gespeichert.
- **Member / User**: Gruppenmitglied in `filmfreaks/Users+Store/User.swift`, CloudKit-RecordType `GroupMember`.
- **Movie Night**: Filmabend-Vorschlag mit Event, Responses, Activity und Roulette-Presets unter `filmfreaks/MovieNights`.
- **Goals**: Jahresziel und Custom Goals. Jahresziele sind `ViewingGoal`-Records, Custom Goals sind ein versioniertes Payload `ViewingCustomGoals` pro Gruppe.
- **Dirty Journal**: Dauerhaftes Retry-Log für noch nicht hochgeladene Movie- und MovieNight-Änderungen.
- **Zone Change Token**: In UserDefaults gespeicherter CloudKit-Token für inkrementelle Zone-Changes pro Namespace, Scope und Zone.
- **TMDb**: Externe Movie-Datenquelle unter `filmfreaks/TMDbAPI`. API-Key wird aus Environment oder Info.plist gelesen.

## Architecture Map

- **App Shell**
  - `filmfreaks/filmfreaksApp.swift`
  - Initialisiert Stores, CloudKit Share Delegate, URLCache, Splash, ScenePhase-Refresh.
  - Injiziert `MovieStore`, `MovieNightStore`, `UserStore`, `CloudKitGroupStore`, `NetworkMonitor`, `DisplaySettings` als EnvironmentObjects.
- **Root UI und Navigation**
  - `filmfreaks/Content/ContentView.swift`
  - Ein zentraler `NavigationStack`; Hauptnavigation über Sheets in `filmfreaks/Content/ContentRouting.swift`.
- **Domain Stores**
  - `MovieStore`, `MovieNightStore`, `UserStore`, `GoalsStore`, `DisplaySettings`.
  - Stores sind überwiegend `@MainActor ObservableObject` und publizieren UI-State.
- **Local Persistence**
  - `filmfreaks/PersistenceManager.swift`: Movies, Backlog und Users als group-scoped JSON in Application Support.
  - `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`: ein Snapshot für alle Filmabend-Daten.
  - `filmfreaks/GroupScopedStorage.swift`: Pfade und UserDefaults-Keys.
- **CloudKit Sync Layer**
  - Routing: `filmfreaks/CloudKitRouting.swift`.
  - Groups: `filmfreaks/CloudKitGroupStore`.
  - Movies: `filmfreaks/CloudKitMovieStore` plus `filmfreaks/MovieCloudSyncCoordinator.swift`.
  - Ratings: `filmfreaks/CloudKitRatingStore`.
  - Users: `filmfreaks/CloudKitUserStore.swift`.
  - Goals: `filmfreaks/CloudKitGoalStore.swift`.
  - Movie Nights: `filmfreaks/CloudKitMovieNightStore` plus `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift`.
- **External Services und Caches**
  - `filmfreaks/TMDbAPI` für TMDb HTTP API.
  - `filmfreaks/CachedAsyncImage.swift`, `URLCache.shared`, `RecommendationsCacheManager`, `SearchHistoryManager`, `PersonPopularityStore`.
- **Tests**
  - 55 Unit-Test-Dateien unter `filmfreaksTests` plus 2 UI-Test-Dateien unter `filmfreaksUITests`.

Dependency-Richtung in Textform:

`SwiftUI Views -> Stores/ViewModels -> Local Persistence + CloudKit Stores -> CloudKit/TMDb/FileManager/UserDefaults`

Views sollten nicht direkt CloudKit oder Dateisystem schreiben. Der aktuelle Code hält diese Trennung überwiegend ein.

## Folder Map

- `filmfreaks/` root files: Domain-Modelle, Shared Utilities, CloudKit-Fassaden, Caches, App Entry Point.
- `filmfreaks/CloudKit`: Subscriptions, Push-Fetch, Remote-Notification-Debugging.
- `filmfreaks/CloudKitGroupStore`: Owned und shared Groups, Zone-Fetch, Sharing, Subscriptions.
- `filmfreaks/CloudKitMovieStore`: Movie Record Schema, Query, Modify, Merge, Routing, Zone Changes.
- `filmfreaks/CloudKitRatingStore`: MovieRating Schema, Query, Modify, Zone Changes.
- `filmfreaks/CloudKitMovieNightStore`: MovieNight Record Types, Snapshot, Modify, Routing, Zone Changes.
- `filmfreaks/Content`: Root UI, Header, Main Area, routing, derived list/activity snapshots.
- `filmfreaks/MovieStore`: MovieStore Lifecycle, Persistence, Cloud Sync, Mutations, Selections.
- `filmfreaks/Users+Store`: UserStore, selection, Cloud refresh, sync status, mutations.
- `filmfreaks/MovieNights`: MovieNight domain, store, calendar, planning, roulette, sheets und UI.
- `filmfreaks/MovieSearch`: TMDb-Suche, Empfehlungen, Scanner, ViewModel, Result-Komponenten.
- `filmfreaks/SearchResultDetail`: Detailansicht für TMDb-Suchergebnis und Add-to-list Flow.
- `filmfreaks/MovieDetail`: Movie-Detail, Ratings-Sheet, Metadata Load Coordinator.
- `filmfreaks/Goals`: Ziele, Custom Goals, GoalsStore, Goal UI.
- `filmfreaks/Stats`: StatsView, SnapshotBuilder, Karten und Drilldowns.
- `filmfreaks/Timeline`: Timeline ViewModel und UI.
- `filmfreaks/Settings`: Settings, Gruppenverwaltung, Appearance und Display Settings.
- `filmfreaks/TMDbAPI`: API-Fassade, Networking, Search, Details, People und Models.
- `filmfreaks/Notifications`: Push Deep Links, Local Notification State, Permission und User Identity.

## Data Model Map

### Movie und Rating

- `filmfreaks/Movie.swift`
- `Movie`
  - Identity: `id: UUID`
  - Display: `title`, `year`, `posterPath`, `tmdbRating`
  - TMDb: `tmdbId`, `genres`, `genreIds`, `keywords`, `keywordIds`, `cast`, `directors`
  - List state: `watchedDate`, `watchedLocation`, `suggestedBy`, `addedAt`, `addedById`, `addedByName`
  - Group: `groupId`, `groupName`
  - Embedded local ratings: `ratings: [Rating]`
- `Rating`
  - Identity: `id: UUID`, `reviewerId: UUID?`, `reviewerName`
  - Scores: `[RatingCriterion: Int]`, `comment`, `fazitScore`, `updatedAt`
  - Computed: average stars and normalized 0 to 10 score
- `CastMember`
  - `personId`, `name`
  - Used for cast and directors.
- Codable migration exists for legacy `cast: [String]` to `[CastMember]` with temporary negative person IDs.

### Users and Groups

- `filmfreaks/Users+Store/User.swift`
  - `User`: `id`, `name`
- `filmfreaks/GroupContext.swift`
  - `GroupContext`: `id`, `name`, `scope`, `zoneName`, `ownerName`
  - Stored in UserDefaults key `GroupContextsById`
- `filmfreaks/MovieStore/MovieStore.swift`
  - `GroupInfo`: local list of known groups.

### Movie Nights

- `filmfreaks/MovieNights/MovieNightEvent.swift`
  - `MovieNightEvent`: group, start, created/updated date, proposer, optional movie ref, note, status.
- `filmfreaks/MovieNights/MovieNightResponse.swift`
  - `MovieNightResponse`: eventId, userId, userName, decision, respondedAt.
- `filmfreaks/MovieNights/MovieNightActivityEvent.swift`
  - Activity feed events: proposed, responded, statusChanged, deleted.
- `filmfreaks/MovieNights/MovieNightMovieRef.swift`
  - Snapshot of movieId, title, year, posterPath and tmdbId.
- `filmfreaks/MovieNights/Roulette/MovieRoulettePreset.swift`
  - Presets with selected movie refs for roulette.

### Goals

- `filmfreaks/ViewingCustomGoal.swift`
  - Types: decade, person, director, genre, keyword.
  - Rule plus target, createdAt, startYear, durationYears and semantic `uniqueKey`.
- `filmfreaks/ViewingCustomGoalsPayload.swift`
  - Versioned custom-goal payload.
- `filmfreaks/Goals/GoalsStore.swift`
  - Yearly goals as `[Int: Int]` and Custom Goals as `[ViewingCustomGoal]`.

### Settings and Caches

- `filmfreaks/Settings/DisplaySettings/DisplaySettings.swift`: appearance, layout, rating display mode and watch-provider settings.
- `filmfreaks/SearchHistoryManager.swift`: recent search queries in UserDefaults.
- `filmfreaks/RecommendationsCacheManager.swift`: recommendation cache in UserDefaults.
- `filmfreaks/PersonPopularityStore.swift`: popularity cache for person sorting.
- `filmfreaks/CachedAsyncImage.swift`: image cache helper.

## Sync/Storage

### Local Storage

- No SwiftData/CoreData stack was found.
- `filmfreaks/PersistenceManager.swift`
  - Base directory: Application Support via `GroupScopedStorage.applicationSupportRootURL()`.
  - Group directory: `FilmFreaks/groups/<safeGroupFolderName>`.
  - Files: `movies_watched.json`, `movies_backlog.json`, `users.json`.
  - Debounced writes: 0.55 seconds on serial queue `filmfreaks.persistence`.
  - Atomic writes are used.
  - Migration from older UserDefaults keys exists and old keys are intentionally kept for rollback.
- `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`
  - Stores all events, responses, activity and presets in one `movieNights.json` snapshot.
  - Schema version 3 with backwards-compatible decoding.
- UserDefaults stores small state: current group, known groups, group contexts, selected user, goals, sync metadata, zone tokens and caches.

### CloudKit Routing

- `filmfreaks/CloudKitRouting.swift`
  - No groupId: public database.
  - GroupContext exists: private or shared database plus zone.
  - UUID-like groupId without GroupContext: throws `groupContextNotReady` and prevents unsafe public fallback.
  - Non-UUID groupId: legacy public database.

### CloudKit Record Types

- Groups: `FFGroup` in `filmfreaks/CloudKitGroupStore/CloudKitGroupStore.swift`.
- Movies: `Movie` with encoded `Movie` payload, `isBacklog`, `updatedAt`, `groupId`.
- Ratings: `MovieRating` with encoded `Rating` payload, `movieId`, `groupId`, `reviewerId`, `reviewerName`, `updatedAt`.
- Members: `GroupMember` with `groupId`, `memberId`, `name`, `updatedAt`.
- Goals: `ViewingGoal` and `ViewingCustomGoals`.
- Movie Nights: `MovieNightEvent`, `MovieNightResponse`, `MovieNightActivity`, `MovieRoulettePreset`.

### Sync Flow

- `filmfreaks/filmfreaksApp.swift` refreshes on scene active through `AppRefreshCoordinator`.
- `filmfreaks/Content/ContentView+Refresh.swift` performs pull-to-refresh for movies, users and movie nights in parallel.
- Movie sync:
  - `filmfreaks/MovieStore/MovieStore+CloudSync.swift` loads movies and ratings.
  - Zone groups use incremental changes with `CloudKitZoneChanges` and `CloudKitZoneChangeTokenStore`.
  - Public/legacy groups use query snapshots.
  - Local ratings are preserved, then CloudKit ratings are merged.
  - Local Movie changes are journaled by `filmfreaks/MovieCloudDirtyJournal.swift` and flushed by `MovieCloudSyncCoordinator`.
- MovieNight sync:
  - `filmfreaks/MovieNights/MovieNightStore/MovieNightStore+CloudRefresh.swift` merges snapshots or zone changes.
  - Writes are queued and journaled through `MovieNightCloudSyncCoordinator` and `MovieNightCloudDirtyJournal`.
- User sync:
  - `filmfreaks/Users+Store/UserStore+CloudRefresh.swift` fetches `GroupMember` records.
  - Local users seed CloudKit if the remote group is empty.
- Goals sync:
  - `filmfreaks/Goals/GoalsStore.swift` persists to UserDefaults and writes to `CloudKitGoalStore`.

### Offline Behavior

- Movies and MovieNight writes are local-first and have durable dirty journals for later retry.
- Ratings, Users and Goals are local-first or locally cached, but no equivalent durable CloudKit retry journal was found for their failed writes. This is a sync reliability risk.
- `NetworkMonitor` reconnect triggers flush for pending movie and movie-night changes.

### CloudKit Sharing

- Sharing entry points: `filmfreaks/CloudKitShareAppDelegate.swift`, `CloudKitShareSceneDelegate.swift`, `CloudKitShareCoordinator.swift`, `CloudKitGroupStore+Sharing.swift`.
- `CloudKitGroupStore+Sharing.swift` creates a `CKShare` for the group root record.
- Group-related records should be children of the root record via `record.parent` for record sharing.
- One-time share hierarchy repair currently covers `Movie`, `MovieRating`, `GroupMember`, `ViewingGoal`, `ViewingCustomGoals`.

## UI Map

### Root

- `filmfreaks/filmfreaksApp.swift`
  - `WindowGroup` with `ContentView`, `ToastHost` and `SplashView` overlay.
- `filmfreaks/Content/ContentView.swift`
  - Main `NavigationStack`.
  - Header via `ContentHeaderView`.
  - Body via `ContentMainAreaView`.
  - No main `TabView` in the root. `TabView` appears only in `QuickStartView`.

### Main Screens and Sheets

- `filmfreaks/Content/ContentRouting.swift` centralizes sheet routes:
  - `.settings` -> `SettingsView`
  - `.quickStart` -> `QuickStartView`
  - `.movieSearch` -> `MovieSearchView`
  - `.users` -> `UsersView`
  - `.stats` -> `StatsView`
  - `.timeline` -> `TimelineView`
  - `.calendar` -> `MovieNightPlanningView`
  - `.activity` -> `GroupActivityListView`
  - `.goals` -> `GoalsView`
  - `.groupSettings` -> `NavigationStack { GroupSettingsView }`

### Primary Flows

- Main list and backlog:
  - `ContentView` uses `MovieListMode.watched` and `.backlog`.
  - View styles: cards, compact list, poster grid via `ContentView_ViewStyle` AppStorage.
  - Derived list/grid items are built outside body by `ContentMovieItemsModel`.
- Search and add:
  - `MovieSearchView` -> TMDb search -> `SearchResultDetailView` -> add to watched or backlog through closures in `ContentRouting`.
- Movie detail:
  - `MovieDetailView` loads extra metadata through `MovieDetailLoadCoordinator` and exposes ratings sheets.
- Group settings:
  - `GroupSettingsView` creates, activates, shares, deletes and leaves CloudKit groups.
- Movie nights:
  - `MovieNightPlanningView`, calendar views, proposal sheets and roulette flows under `filmfreaks/MovieNights`.
- Push deep links:
  - `PushDeepLinkRouter` posts `.pushDeepLinkRequested`.
  - `ContentView+DeepLink.swift` switches group context, refreshes stores and opens `.activity`.

## Build & Configuration

- Xcode project: `filmfreaks.xcodeproj/project.pbxproj`
- Targets:
  - `filmfreaks`
  - `filmfreaksTests`
  - `filmfreaksUITests`
- Bundle ID: `de.marcfechner.filmfreaks`
- Display name: `TMC - The Movie Club`
- Marketing version: `1.5`
- Current project version: `3`
- Swift version setting: `SWIFT_VERSION = 5.0`
- Concurrency-related build settings:
  - `SWIFT_APPROACHABLE_CONCURRENCY = YES`
  - `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
  - `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES`
- Entitlements: `filmfreaks/filmfreaks.entitlements`
  - iCloud CloudKit container `iCloud.de.marcfechner.filmfreaks`
  - `aps-environment = development`
- Info.plist: `filmfreaks/Info.plist`
  - `CKSharingSupported = true`
  - `TMDB_API_KEY = $(TMDB_API_KEY)`
  - `UIBackgroundModes = remote-notification`
- Config files:
  - `filmfreaks/Debug.xcconfig` includes `Secrets.xcconfig`.
  - `filmfreaks/Release.xcconfig` includes `Secrets.xcconfig`.
  - `filmfreaks/Secrets.xcconfig` contains a concrete TMDb key in the uploaded project. Do not reproduce it. Rotate it and replace with local or CI-injected secrets.
- SPM:
  - No package product dependencies were found in the project file.

## Conventions

- Use SwiftUI Views plus `@MainActor ObservableObject` stores.
- Keep CloudKit access inside CloudKit store types or sync coordinators, not in Views.
- Use `GroupContext` and `CloudKitRouting` for every CloudKit route decision.
- For UUID-like groups, never fall back to public DB without `GroupContext`.
- Persist local state before or independently of CloudKit so the UI remains local-first.
- For large derived data, prefer snapshot/view models like `ContentMovieItemsModel`, `ContentActivityPreviewModel`, `StatsViewModel`.
- Store large arrays in Application Support JSON, not UserDefaults.
- Keep record sharing children attached to the group root record with `record.parent`.
- Prefer deterministic record names for idempotent CloudKit writes.
- Prefer tests around pure builders and merge logic. Existing tests already cover Content, Stats, Persistence, MovieNights, CloudRouting and UserStore.

## How to work on this project

### Setup Steps

1. Open `filmfreaks.xcodeproj`.
2. Ensure signing team and iCloud container match your Apple Developer account.
3. Replace `filmfreaks/Secrets.xcconfig` with a local untracked file or CI-provided config.
4. Set `TMDB_API_KEY` via xcconfig or environment. The app reads Environment first, then Info.plist.
5. Run unit tests under `filmfreaksTests`, especially Persistence, CloudRouting, MovieNights, Content and Stats after sync changes.
6. Test CloudKit on real devices for private/shared database behavior. Simulator is not enough for all sharing and push flows.

### Where to start as a new dev

- Entry point: `filmfreaks/filmfreaksApp.swift`.
- Root UI and sheet routing: `filmfreaks/Content/ContentView.swift` and `filmfreaks/Content/ContentRouting.swift`.
- Movie domain and sync: `filmfreaks/Movie.swift`, `filmfreaks/MovieStore`, `filmfreaks/CloudKitMovieStore`, `filmfreaks/CloudKitRatingStore`.
- Group and sharing: `filmfreaks/GroupContext.swift`, `filmfreaks/CloudKitRouting.swift`, `filmfreaks/CloudKitGroupStore`.
- MovieNight sync: `filmfreaks/MovieNights/MovieNightStore`, `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift`, `filmfreaks/CloudKitMovieNightStore`.
- Stats performance: `filmfreaks/Stats/StatsViewModel.swift`, `filmfreaks/Stats/StatsSnapshotBuilder.swift` and extensions.

### Feature Workflow

- Add or update the Codable domain model first.
- Decide storage scope: file JSON, UserDefaults, CloudKit record, or cache.
- Add local persistence and migration before CloudKit sync.
- Route CloudKit through `CloudKitRouting` and set parent root for shared zones.
- Add store mutation API, then UI route or ViewModel.
- Add tests for model decoding, merge behavior, sync routing, and derived snapshots.
- Check large derived work is not in a SwiftUI body.

## Quick Wins

1. Rotate the TMDb key and remove `filmfreaks/Secrets.xcconfig` from versioned artifacts or replace it with a template plus local override.
2. Use `CloudKitUserStore.upsertMembersBatch` in `UserStore+CloudRefresh.swift` initial seeding instead of one CloudKit save per user.
3. Add a concurrency limit to `MovieStore+Mutations.swift` cast migration. The current `withTaskGroup` creates one child task per target movie.
4. Move MovieStore diffing and zone-change apply to dictionary-based merge helpers to reduce MainActor O(n) work.
5. Include MovieNight record types in `CloudKitGroupStore+Sharing.swift` share hierarchy repair if older movie-night records need to become visible in existing shares.
6. Add durable retry or explicit sync-failed UX for ratings, users and goals.
7. Replace broad `print` calls in CloudKit paths with `Logger` categories and structured sync events.
8. Replace full-array equality/signature checks in Content and Stats with revision-based invalidation.
9. Add a small CloudKit schema note or fixture documenting queryable fields and required indexes.
10. Review `CloudKitActivityPushFetchCoordinator.swift` because its record fetch and local notification handling are gated behind `#if DEBUG`.

## Open Questions

- **UNKNOWN**: Is `IPHONEOS_DEPLOYMENT_TARGET = 26.0` intentional for production, or a local Xcode 26 default?
- **UNKNOWN**: Should legacy public DB groups remain supported long-term?
- **UNKNOWN**: What is the expected offline guarantee for ratings, users and goals?
- **UNKNOWN**: Are CloudKit Dashboard indexes deployed for every queried field such as `groupId`, `movieId`, `memberId`, `updatedAt`, `year`?
- **UNKNOWN**: Is production APNs configured separately from the uploaded development entitlement?
- **UNKNOWN**: Are MovieNight records already shared in production data, or do old records need hierarchy repair?
