# PROJECT_CONTEXT.md

_Last updated: 2026-02-15 (Europe/Berlin)_

(Paths are relative to the Xcode project root `filmfreaks/` unless stated otherwise.)

## TL;DR
- **App:** `filmfreaks` – a SwiftUI iOS/iPadOS app for group-based movie tracking (watched + backlog), ratings, stats, goals, timeline and movie nights.
- **Platforms:** iOS/iPadOS (single target) with **minimum iOS 26.0** (from `filmfreaks.xcodeproj/project.pbxproj`).
- **Storage/Sync:** local JSON files in Application Support (`PersistenceManager.swift`, `MovieNights/MovieNightLocalPersistence.swift`) + CloudKit (public DB legacy + private/shared DB with CloudKit Sharing via `GroupContext.swift`, `CloudKitGroupStore.swift`).

## Key Concepts / Domänenbegriffe
- **Group / Gruppe**: logical container for all data. Implemented via CloudKit Sharing; routing metadata is `GroupContext` (`GroupContext.swift`). Legacy behavior still exists for “no context” groups and routes to **public** CloudKit DB.
- **Watched** vs **Backlog**: two lists of `Movie` (`Movie.swift`) managed by `MovieStore` (`MovieStore.swift`). Backlog entries are flagged in CloudKit via `isBacklog` (`CloudKitMovieStore.swift`).
- **Rating**: per-user rating on a movie (`Rating` inside `Movie.swift`). Ratings are stored as CloudKit records (`CloudKitRatingStore.swift`, record type `MovieRating`) and embedded into movies for UI.
- **Active Member / aktiver Nutzer**: the “current” user used for attribution when adding movies/ratings; stored per group (`SelectedUserSelectionStore.swift`) and exposed via `UserStore.selectedUser` (`UserStore.swift`).
- **Activity Feed / Gruppenaktivität**: derived events shown in the app (`Content/GroupActivity*`, `MovieStore+Activity.swift`) + push notifications (subscriptions in `CloudKit/CloudKitActivitySubscriptionManager.swift`).
- **Movie Nights / Filmabende**: proposals + responses + calendar (`MovieNights/*`). Local persistence exists + CloudKit sync (`MovieNights/MovieNightStore.swift`, `CloudKitMovieNightStore.swift`).
- **Goals / Ziele**: yearly goals + custom goals (`Goals/*`, model: `ViewingCustomGoal.swift`, CloudKit: `CloudKitGoalStore.swift`).

## Architecture Map
Textual layer map (top → bottom):
- **SwiftUI Presentation**
  - Home/root: `Content/ContentView.swift` (NavigationStack) + extracted subviews in `Content/`.
  - Feature UIs: `MovieDetail/`, `MovieSearch/`, `Stats/`, `Goals/`, `MovieNights/`, `TimelineView.swift`, `UsersView.swift`, `SettingsView.swift`.
- **State / Stores (ObservableObject, mostly @MainActor)**
  - `MovieStore.swift` (movies + backlog + current group + sync meta)
  - `MovieNights/MovieNightStore.swift`
  - `UserStore.swift`
  - `CloudKitGroupStore.swift` (groups + sharing + subscriptions)
  - `DisplaySettings.swift` (appearance)
  - `NetworkMonitor.swift` (reachability)
- **Persistence (local, JSON on disk)**
  - `PersistenceManager.swift` (movies/backlog/users)
  - `MovieNights/MovieNightLocalPersistence.swift` (movie nights snapshot)
- **Cloud Sync + CloudKit Access**
  - CloudKit “repositories”: `CloudKitMovieStore.swift`, `CloudKitRatingStore.swift`, `CloudKitUserStore.swift`, `CloudKitGoalStore.swift`, `CloudKitMovieNightStore.swift`
  - Change tokens: `CloudKitZoneChangeTokenStore.swift` + helper ops in `CloudKitZoneChanges.swift`
  - Debounced upload coordinators: `MovieCloudSyncCoordinator.swift`, `MovieNights/MovieNightCloudSyncCoordinator.swift`
- **Notifications / Push**
  - Subscription bootstrap: `CloudKit/CloudKitActivitySubscriptionManager.swift`
  - Remote push entry: `CloudKitShareAppDelegate.swift` + permission bootstrap `Notifications/NotificationsPermissionManager.swift`
  - Deep-link routing: `Notifications/PushDeepLinkRouter.swift`
- **External API (TMDb)**
  - `TMDbAPI.swift` + caches (`RecommendationsCacheManager.swift`, `SearchHistoryManager.swift`, `PersonPopularityStore.swift`).

Dependency direction: Views → Stores → (Persistence + CloudKit Stores + TMDbAPI). No SwiftData/CoreData layer is present (confirmed: no `import SwiftData` / `import CoreData`).

## Folder Map
- `(root)/` (60 Swift files) — Shared building blocks, app entry, stores, models, utilities.
- `CloudKit/` (3 Swift files) — CloudKit push/subscription helpers and debug utilities.
- `Content/` (27 Swift files) — Main/home screen + routing + group activity UI.
- `Goals/` (19 Swift files) — Viewing goals feature (UI + CloudKit storage).
- `MovieDetail/` (19 Swift files) — Movie detail screen + ratings input + providers + trailers.
- `MovieNights/` (18 Swift files) — Movie night proposals/events/calendar + CloudKit sync.
- `MovieSearch/` (20 Swift files) — TMDb search UI + discovery lists.
- `Notifications/` (6 Swift files) — Push permission, local notifications, deep link routing, suppression.
- `SearchResultDetail/` (10 Swift files) — Detail sheets for TMDb search results (movies/persons).
- `Stats/` (16 Swift files) — Stats dashboard + calculations + cards.

## Data Model Map
### Core models
- `Movie` (`Movie.swift`)
  - **Identity:** `id: UUID`
  - **Grouping:** `groupId: String?`, `groupName: String?`
  - **Metadata:** `title: String`, `year: Int`, `tmdbId: Int?`, `posterPath: String?`, `genres/keywords` (+ IDs)
  - **Watched fields:** `watchedDate: Date?`, `watchedLocation: String?`
  - **Ratings:** `[Rating]` (embedded, per reviewer)
  - **Backlog attribution:** `suggestedBy: String?`
  - **Activity attribution:** `addedAt: Date?`, `addedById: UUID?`, `addedByName: String?`
  - **People:** `cast: [CastMember]`, `directors: [CrewMember]` (file: `Movie.swift`)
- `User` (`User.swift`)
  - `id: UUID`, `name: String`
- `GroupContext` (`GroupContext.swift`)
  - `id: String`, `name: String`, `scope: GroupScope`, `zoneName: String`, `ownerName: String`
  - persisted via `GroupContextStore` (UserDefaults, keyed by groupId)
- Goals
  - `ViewingCustomGoal` (`ViewingCustomGoal.swift`): `type/rule/target`, timeframe (`startYear`, `durationYears`) and optional filters (person/genre/keyword).
  - `ViewingCustomGoalsPayload` (`ViewingCustomGoalsPayload.swift`): groups custom goals into a payload stored in CloudKit.
- Movie Nights (`MovieNights/*`)
  - `MovieNightEvent` (`MovieNights/MovieNightEvent.swift`): `groupId`, `proposedStart`, `proposerUserId/name`, optional `suggestedMovie`, `status`.
  - `MovieNightResponse` (`MovieNights/MovieNightResponse.swift`): per-user accept/decline with timestamps.
  - `MovieNightActivityEvent` (`MovieNights/MovieNightActivityEvent.swift`): minimal activity records.

### Relationships (logical)
- `Movie` ↔ `Rating` (embedded array)
- `Group` ↔ Movies/Users/Ratings/Goals/MovieNights (by `groupId` string, not object references)
- `User` ↔ Ratings/MovieNightResponse via `reviewerId` / `userId`.

## Sync/Storage
### Local persistence (offline-first baseline)
- `PersistenceManager.swift`
  - Stores JSON files in **Application Support** (see `baseDir` comment: `~/Library/Application Support/FilmFreaks/`).
  - Kinds: watched movies, backlog movies, users (per-group files; keying is by `groupId`).
  - **Debounced writes** (`debounceSeconds = 0.55`) using a background queue + cancellable `DispatchWorkItem`.
  - Has a migration path from legacy UserDefaults (`migrateFromUserDefaultsIfNeeded()`), guarded by flag `FilmFreaks.diskPersistence.v2.migrated`.
- `MovieNights/MovieNightLocalPersistence.swift`
  - Actor storing one snapshot JSON file containing `eventsByGroup`, `responsesByGroup`, `activityByGroup`.

### CloudKit
CloudKit capability is enabled (`filmfreaks/filmfreaks.entitlements`), with iCloud container `iCloud.de.marcfechner.filmfreaks`.

**Routing model:**
- If a `GroupContext` exists for `groupId` (`GroupContextStore.context(forGroupId:)`), CloudKit stores route into a **record zone** in either:
  - `container.privateCloudDatabase` (owned groups)
  - `container.sharedCloudDatabase` (shared groups)
- If no `GroupContext` exists, code falls back to `container.publicCloudDatabase` (legacy path) – see e.g. `CloudKitMovieStore.routedDatabase(forGroupId:)`.

**Record types used in code:**
- `FFGroup` (groups; `CloudKitGroupStore.swift`)
- `Movie` (`CloudKitMovieStore.swift`) — fields: `payload: Data`, `isBacklog: Bool`, `updatedAt: Date`, `groupId: String`
- `MovieRating` (`CloudKitRatingStore.swift`) — fields: `payload: Data`, plus indices: `movieId`, `groupId`, `reviewerId`, `reviewerName`, `updatedAt`
- `GroupMember` (`CloudKitUserStore.swift`) — fields: `groupId`, `memberId`, `name`, `updatedAt`
- `ViewingGoal` + `ViewingCustomGoals` (`CloudKitGoalStore.swift`) — fields include `groupId`, `year/target/updatedAt`, and `payload: Data` for custom goals.
- `MovieNightEvent` / `MovieNightResponse` / `MovieNightActivity` (`CloudKitMovieNightStore.swift`) — explicit fields (not a blob payload) for key attributes.

**Fetch strategy:**
- For sharing groups (zone-based), movies and ratings implement **incremental sync** using `CKFetchRecordZoneChangesOperation` with persisted change tokens (`CloudKitZoneChangeTokenStore.swift`). Example: `CloudKitMovieStore.fetchMovieChanges(forGroupId:)`.
- For legacy (public DB, no zone), code uses `CKQuery` based fetches (see `CloudKitMovieStore` / `CloudKitUserStore`).

**Upload strategy:**
- `MovieStore.swift` enqueues changes into `MovieCloudSyncCoordinator.swift` (debounced + batched saves/deletes).
- `MovieNights/MovieNightStore.swift` uses `MovieNights/MovieNightCloudSyncCoordinator.swift`.

**Offline behavior:**
- Stores read from local disk on startup and work offline.
- Cloud upload coordinators gate uploads on network availability (`NetworkMonitor.shared`, e.g. `MovieCloudSyncCoordinator.flushNow()` checks `networkIsAvailable()`). Pending changes remain queued.

**Sync triggers (important):**
- Global refresh on app activation in `filmfreaksApp.swift` (`scenePhase` `.active`):
  - `groupStore.refresh()`
  - `movieStore.refreshFromCloud(force: false)`
  - `userStore.refreshFromCloud(force: false)`
  - `movieNightStore.refreshFromCloud(groupId: movieStore.currentGroupId, force: false)`
- Additional refresh flows exist in `Content/ContentView+Refresh.swift` (**UNKNOWN** whether all of them debounce/cancel properly).

## UI Map
### Entry points
- `filmfreaksApp.swift` → `Content/ContentView.swift` (wrapped in a `NavigationStack`).
- App-level environment objects are injected in `filmfreaksApp.swift`:
  - `MovieStore(useCloud: true)`
  - `MovieNightStore()`
  - `UserStore()`
  - `CloudKitGroupStore()`
  - `NetworkMonitor.shared`
  - `DisplaySettings()`

### Primary navigation
- `Content/ContentView.swift` is the hub.
  - Detail navigation uses `NavigationLink` into `MovieDetail/MovieDetailView.swift` (see `Content/ContentMainAreaView.swift`).
  - Feature screens open mostly as **sheets** via central routing enum `ContentRoute` (`Content/ContentRouting.swift`).

### Sheets / Flows (via `ContentRoute`)
- `.settings` → `SettingsView.swift`
- `.quickStart` → `QuickStartView.swift` (onboarding)
- `.movieSearch` → `MovieSearch/MovieSearchView.swift`
- `.users` → `UsersView.swift`
- `.stats` → `Stats/StatsView.swift`
- `.timeline` → `TimelineView.swift`
- `.calendar` → `MovieNights/Calendar/MovieNightCalendarView.swift`
- `.activity` → `Content/GroupActivityListView.swift`
- `.goals` → `Goals/GoalsView.swift`
- `.groupSettings` → `GroupSettingsView.swift`

### Notification deep links
- Tapping a push notification posts `.pushDeepLinkRequested` (`Notifications/PushDeepLinkRouter.swift`).
- `Content/ContentView.swift` listens and routes accordingly (`handlePushDeepLink`).


## Common Workflows (high-level)
- **Add movie to watched/backlog**
  - UI entry: `Content` toolbar → `.movieSearch` sheet (`Content/ContentRouting.swift`).
  - Add action enriches group + activity attribution (see `Content/ContentRouting.swift` methods `addMovieToWatched` / `addMovieToBacklog`).
  - Mutation writes to disk (`PersistenceManager.saveMovies/saveBacklogMovies`) and queues CloudKit sync (`MovieStore.swift` didSet + `MovieCloudSyncCoordinator.swift`).
- **Rate a movie**
  - UI: `MovieDetail/MovieDetailView.swift` + rating UI (`MovieDetail/MovieDetailRatingInputSection.swift`).
  - Ratings are stored as separate CloudKit records (`CloudKitRatingStore.swift`) and are embedded back into `Movie.ratings` for UI.
- **Switch group**
  - UI: group selector in header (`Content/ContentHeaderView.swift`).
  - State: `MovieStore.currentGroupId/currentGroupName` persisted in UserDefaults; also updates `knownGroups` (`MovieStore.swift`).
  - Group routing metadata: `GroupContextStore` (`GroupContext.swift`) determines CloudKit DB/zone.
- **Accept a group share**
  - Entry: `CloudKitShareAppDelegate` scene handling (`CloudKitShareAppDelegate.swift`, `CloudKitShareSceneDelegate.swift`).
  - Coordinator: `CloudKitShareCoordinator.accept(_:)` shows toasts and triggers refresh (`CloudKitShareCoordinator.swift`).
- **Push notifications → deep link**
  - Subscriptions created in `CloudKit/CloudKitActivitySubscriptionManager.swift` by `CloudKitGroupStore.refresh()`.
  - Tap push: `Notifications/PushDeepLinkRouter.swift` posts `.pushDeepLinkRequested` → `Content/ContentView.swift` handles routing.

## Sync Transparency (UI)
- Movies: `MovieStore` exposes `isSyncing`, `pendingCloudChangesCount`, `lastCloudSyncAt`, `lastCloudSyncError` (`MovieStore.swift`).
- Movie nights: `MovieNightStore` exposes per-group sync state (`MovieNights/MovieNightStore.swift`).
- Users: `UserStore` keeps per-group last success/attempt/error (`UserStore.swift`).
- UI surfaces (examples):
  - `Content/ContentSyncStatusLineView.swift` (status line)
  - Settings / group settings may also show sync hints (**UNKNOWN**: not exhaustively traced).

## Caching
- HTTP image caching is configured globally in `filmfreaksApp.init()` (`URLCache.shared` memory 100MB / disk 500MB).
- `CachedAsyncImage.swift` is the main UI wrapper for image loading and should benefit from `URLCache`.
- Additional app-level caches:
  - `RecommendationsCacheManager.swift`
  - `SearchHistoryManager.swift`
  - `PersonPopularityStore.swift`

## Build & Configuration
- Xcode project: `filmfreaks.xcodeproj`
- Targets (from `project.pbxproj`): `filmfreaks`, `filmfreaksTests`, `filmfreaksUITests`
- Deployment target: **iOS 26.0** (project setting `IPHONEOS_DEPLOYMENT_TARGET = 26.0`).

### Info.plist / Entitlements
- `filmfreaks/Info.plist`
  - `CKSharingSupported = true`
  - `UIBackgroundModes = [remote-notification]` (needed for CloudKit pushes)
  - `TMDB_API_KEY = $(TMDB_API_KEY)`
- `filmfreaks/filmfreaks.entitlements`
  - `com.apple.developer.icloud-container-identifiers = [iCloud.de.marcfechner.filmfreaks]`
  - `com.apple.developer.icloud-services = [CloudKit]`
  - `aps-environment = development`

### Build configs / secrets
- `filmfreaks/Debug.xcconfig` and `filmfreaks/Release.xcconfig` both `#include "Secrets.xcconfig"`.
- `filmfreaks/Secrets.xcconfig` currently contains a **real TMDb key** in plaintext. This file is excluded from git via `filmfreaks/.gitignore`.
  - **Risk:** the zip you shared includes it; treat it as compromised if the archive was shared beyond trusted devices.
- No Swift Package Manager dependencies detected (no `XCRemoteSwiftPackageReference` in `project.pbxproj`).

## Conventions (Naming, Patterns, Do/Don’t)
- **Stores are `ObservableObject` and mostly `@MainActor`** (e.g. `MovieStore.swift`, `UserStore.swift`, `MovieNights/MovieNightStore.swift`).
  - Do: keep UI mutations on MainActor.
  - Don’t: do heavy aggregation in computed properties used from `body` (see Hot Path notes in `ARCHITECTURE_NOTES.md`).
- **Routing:** one enum + one sheet modifier (`ContentRoute` + `contentRouting(...)` in `Content/ContentRouting.swift`).
- **Group-scoped data:** prefer explicit `groupId` fields on models and storage functions.
- **Persistence:** large arrays go to disk JSON (`PersistenceManager.swift`), not UserDefaults.
- **CloudKit schema:** mixed approach
  - Movies/Ratings: store a `payload: Data` blob + a few indexed fields.
  - Movie Nights: store explicit typed fields.

## How to work on this project
### Setup steps (new dev)
- Open `filmfreaks.xcodeproj` in Xcode.
- Set a valid Development Team and ensure capabilities:
  - iCloud → CloudKit
  - Push Notifications
  - Background Modes → Remote notifications
- Provide `TMDB_API_KEY` in `Secrets.xcconfig` (or replace with your own). (`Info.plist` expects `$(TMDB_API_KEY)`.)
- CloudKit:
  - Ensure the iCloud container `iCloud.de.marcfechner.filmfreaks` exists and the CloudKit schema contains record types listed above.
  - **UNKNOWN:** required CloudKit indexes (e.g., on `groupId`, `movieId`, `updatedAt`) are not derivable from code. Verify in CloudKit Dashboard.

### Where to start for a new feature
1) Add domain model (if needed) in a dedicated file (e.g. `MovieNights/MovieNightEvent.swift`).
2) Add a store / service (ObservableObject or actor) for state + persistence.
3) Add a view in the relevant feature folder.
4) Wire navigation:
   - New sheet route: add case to `ContentRoute` (`Content/ContentRouting.swift`) + add toolbar entry in `Content/ContentView+Toolbar.swift`.
   - New detail push: add `NavigationLink` in list/grid (see `Content/ContentMainAreaView.swift`).
5) Add CloudKit integration last (keep a local-only P0 first) – project already follows this pattern for Movie Nights.

## Quick Wins (max 10)
1) **Cache filtered/sorted movie lists** to avoid recomputing on every SwiftUI invalidation (`Content/ContentView+MovieItems.swift`).
2) **Precompute search tokens once per search string** and reuse for each movie; current implementation normalizes per movie (`Content/ContentView+Filtering.swift`).
3) **Extract `MovieStore` responsibilities** into `MovieStore+Persistence`, `MovieStore+CloudSync`, `MovieStore+Groups` (see `MovieStore.swift`).
4) **Unify disk persistence strategy** (currently `PersistenceManager` vs `MovieNightLocalPersistence` have different patterns and locations).
5) **Remove duplicate subscription bootstrap Tasks** in `CloudKitGroupStore.refresh()` (there are two similar `Task { ensureSubscriptions... }` blocks).
6) **Move heavy stats aggregation off the render path** by caching results in a view model (see `Stats/StatsView+Calculations.swift`).
7) **Add cancellation to long-running TMDb tasks** in views that fetch in `onAppear` (hotspot candidates: `MovieSearch/MovieSearchView.swift`, `SearchResultDetail/SearchResultDetailView.swift`).
8) **Harden NavigationLink bindings** that rely on array indices (`Content/ContentMainAreaView.swift`) – consider stable binding by `Movie.id`.
9) **Treat `Secrets.xcconfig` as sensitive**: do not ship it in support zips; load from local `.xcconfig` not shared.
10) **Add a lightweight logging facade** (os.Logger categories) for CloudKit and sync status to simplify debugging.

## Open Questions (UNKNOWN)
- CloudKit schema details beyond what’s in code: record indexes, query performance characteristics, and server-side validation rules.
- Exact file names/paths used by `PersistenceManager` for each group and kind (code exists, but the full mapping wasn’t verified end-to-end).
- Whether `CloudKitActivityPushFetchCoordinator.fetchAndHandle` is intentionally debug-only (`#if DEBUG` in `CloudKit/CloudKitActivityPushFetchCoordinator.swift`). If not, release builds currently skip fetch+local notification translation.
- How conflicts are resolved when multiple devices edit the same movie/ratings concurrently (some best-effort logic exists, but end-to-end policy is not explicitly documented in code).