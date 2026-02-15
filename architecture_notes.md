# ARCHITECTURE_NOTES.md

_Last updated: 2026-02-15 (Europe/Berlin)_

(Paths are relative to the Xcode project root `filmfreaks/` unless stated otherwise.)

## Big Files List (Top 15 by lines)
High line count is not inherently bad, but here it correlates with mixed responsibilities and higher regression risk.

- `MovieStore.swift` — **863 lines**
  - Purpose: In-memory canonical source of watched/backlog movie lists + per-group selection + local persistence + CloudKit sync queueing.
  - Why risky: Many responsibilities in one file; didSet triggers persistence + cloud sync and can run often; correctness/perf risk when lists grow.

- `CloudKitMovieStore.swift` — **719 lines**
  - Purpose: CloudKit access layer for Movie records (query path + zone-changes incremental fetch + save/delete).
  - Why risky: High complexity + multiple code paths (legacy public DB vs shared/private zones, incremental changes); easy to regress edge cases.

- `MovieNights/MovieNightStore.swift` — **647 lines**
  - Purpose: Group-scoped store for MovieNightEvent/Response/Activity, local persistence + CloudKit sync + derived views.
  - Why risky: Mixes persistence, sync meta, and business rules; lots of state dictionaries keyed by group; risk of subtle inconsistencies.

- `DisplaySettings.swift` — **598 lines**
  - Purpose: User appearance settings (theme, tint, layout metrics) + persistence + derived metrics used across UI.
  - Why risky: Large surface area affecting most UI; changes can cause wide invalidations and hard-to-trace layout regressions.

- `TMDbAPI.swift` — **591 lines**
  - Purpose: Networking layer for TMDb (search, details, providers, images), plus caching helpers and attribution.
  - Why risky: Many endpoints + request building + decoding; network error handling/caching behavior can affect UX broadly.

- `CloudKitMovieNightStore.swift` — **580 lines**
  - Purpose: CloudKit access layer for movie night records (event/response/activity) with routing for shared zones.
  - Why risky: CloudKit schema mapping + routing; concurrency and conflict resolution can be tricky.

- `Goals/CustomGoalEditorView.swift` — **545 lines**
  - Purpose: Large SwiftUI editor for custom viewing goals (validation, UI state, saving).
  - Why risky: Big SwiftUI view with many bindings/validation; prone to invalidation storms and preview/debug friction.

- `SearchResultDetail/SearchResultDetailView.swift` — **522 lines**
  - Purpose: Large SwiftUI sheet for a TMDb search result with sections, fetches, actions.
  - Why risky: Large SwiftUI view likely doing async fetches; risk of multiple tasks and state races.

- `CloudKitRatingStore.swift` — **508 lines**
  - Purpose: CloudKit access for MovieRating records (save/fetch, zone changes tokens, mapping into Movie.Rating).
  - Why risky: CloudKit writes/reads + mapping into movies; race conditions with movie updates; token invalidation complexity.

- `TimelineView.swift` — **501 lines**
  - Purpose: Timeline UI aggregating watched/backlog events; likely sorts/filters and builds sections.
  - Why risky: Aggregations/sorts likely recomputed on invalidation; can become sluggish with large movie lists.

- `SearchResultDetail/SearchResultDetailView.swift`
  - Starts async loading with `Task { await loadDetails() }` in `.onAppear` and also triggers reloads in `.onChange(of: result.id)`.
  - Reason: tasks are not explicitly cancelled on disappear; if the sheet is dismissed quickly, late responses may still mutate state (racey UI updates).
- `MovieSearch/MovieSearchView.swift`
  - Uses multiple `Task { ... }` blocks for search/pagination and one `.task { ... }`.
  - Reason: without careful cancellation/debounce, it can generate overlapping network requests and stale state updates.


- `CloudKitGroupStore.swift` — **463 lines**
  - Purpose: Group creation/listing + CloudKit sharing + context persistence + subscription bootstrap.
  - Why risky: Touches account status, shares, zones, subscriptions; failure modes involve user-visible data access issues.

- `Stats/StatsView+Calculations.swift` — **429 lines**
  - Purpose: Computed properties and aggregation helpers powering StatsView cards (counts, leaderboards, charts).
  - Why risky: Heavy computations likely run in render path if used as computed vars in body; can impact scrolling/interaction.

- `MovieSearch/MovieSearchView.swift` — **421 lines**
  - Purpose: Main search/discovery screen with TMDb querying, pagination, results list/grid.
  - Why risky: Pagination and request cancellation; risk of duplicated calls or stale results.

- `UserStore.swift` — **389 lines**
  - Purpose: Members store + active user selection + local persistence + CloudKit sync + per-group sync status.
  - Why risky: Selection persistence + sync status; mis-sync can break onboarding and user attribution in ratings/activity.

- `ViewingCustomGoal.swift` — **369 lines**
  - Purpose: Custom goal model + evaluation logic and helpers; used in goals feature.
  - Why risky: Non-trivial evaluation logic; bugs are correctness issues that are hard to spot.


## Hot Path Analyse

### Rendering / Scrolling
Hot paths are code that runs frequently during scrolling or view invalidations.

**Candidates (with concrete reasons):**
- `Content/ContentView+MovieItems.swift`
  - Rebuilds filtered+sorted arrays via `.filter` + `.sorted` in computed properties (`watchedItems` / `backlogItems`).
  - Reason: called from `ContentView.body` (via parameters into `ContentMainAreaView`), so it can rerun on many unrelated state changes → O(n log n) + allocations.
- `Content/ContentView+Filtering.swift`
  - `passesListSearch(...)` normalizes strings (`folding` + `lowercased`) and tokenizes search text; used per movie inside list building.
  - Reason: per-item string normalization can dominate CPU for large lists.
- `MovieStore+Activity.swift`
  - Builds activity events by iterating **all movies + all ratings** each call.
  - Reason: if the activity teaser/list is derived in a view’s render path, cost scales with dataset size.
- `Stats/StatsView+Calculations.swift`
  - Contains many computed properties with loops/reduces and sorting.
  - Reason: if these are read from `StatsView.body`, every invalidation recomputes aggregations.
- `TimelineView.swift`
  - Likely builds sorted/sectioned timelines from `movieStore.movies` and/or backlog.
  - Reason: timeline is typically aggregation-heavy; verify it doesn’t recompute everything on minor state changes.

**Concrete mitigation levers:**
- Move expensive list building into a dedicated view model with memoization keyed by:
  - `movies` version / `backlogMovies` version (or change counters)
  - filter state (`selectedSort`, `filterByUser`, search text)
- Precompute and cache normalized search tokens once per search string.
- Use stable IDs for bindings (bind by `Movie.id`, not array index) to avoid invalidations and index drift.

### Sync / Storage
**CloudKit fetch/write complexity hotspots:**
- `CloudKitMovieStore.swift`
  - Two fetch modes: legacy query vs zone-change delta.
  - Reason: multiple backends and token logic increase edge cases (token reset, partial failures, deletes).
- `CloudKitRatingStore.swift`
  - Ratings are separate records; they must be merged back into the correct `Movie`.
  - Reason: ordering/races when movies are modified while ratings sync is in flight.
- `CloudKitGroupStore.swift`
  - Creates/list groups, writes `GroupContext`, and bootstraps subscriptions.
  - Reason: failures here can strand users without access to shared data.
- `PersistenceManager.swift`
  - Disk writes are debounced but still triggered by `MovieStore` didSet.
  - Reason: frequent small edits can cause repeated encode/write churn if debounce is bypassed.

**Where sync starts / is triggered:**
- `filmfreaksApp.swift` on `scenePhase == .active` runs refresh for groups/movies/users/movie nights.
- Remote-notification background mode is enabled (`Info.plist`), and CloudKit query subscriptions are installed (`CloudKit/CloudKitActivitySubscriptionManager.swift`).

### Concurrency
- Stores are `@MainActor` (`MovieStore.swift`, `UserStore.swift`, `MovieNights/MovieNightStore.swift`).
  - Pro: avoids Sendable headaches with SwiftUI.
  - Con: risk of MainActor contention if heavy work happens in store methods.
- Debounced flush tasks (`MovieCloudSyncCoordinator.swift`, `MovieNights/MovieNightCloudSyncCoordinator.swift`).
  - Verify cancellation behavior: `scheduledFlush` tasks are replaced, but long-running flush calls should also be cancellation-aware (**UNKNOWN**: not fully audited).
- Remote push handling:
  - Entry point: `CloudKitShareAppDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`.
  - Fetch logic is currently **debug-only** (`#if DEBUG` in `CloudKit/CloudKitActivityPushFetchCoordinator.swift`).


## Refactor Map
### Konkrete Splits (low-risk, mechanical)
- `MovieStore.swift` → split by responsibility:
  - `MovieStore+Persistence.swift` (load/save + sync meta)
  - `MovieStore+CloudSync.swift` (enqueue logic + coordinator hooks)
  - `MovieStore+Groups.swift` (group selection + known groups)
- `CloudKitMovieStore.swift` → split by data type / mode:
  - `CloudKitMovieStore+Routing.swift`
  - `CloudKitMovieStore+QueryFetch.swift` (legacy public DB)
  - `CloudKitMovieStore+ZoneChanges.swift` (delta fetch)
  - `CloudKitMovieStore+Write.swift`
- `Stats/StatsView+Calculations.swift` → move aggregation into a memoized `StatsEngine` object:
  - keep view layer as formatting only.
- `TMDbAPI.swift` → split by endpoint families:
  - `TMDbAPI+Search.swift`, `TMDbAPI+Details.swift`, `TMDbAPI+Providers.swift`, `TMDbAPI+People.swift`.

### Cache-/Index-Ideen
- **Movie list indexing:** build an index structure once per movie list version:
  - e.g. `[UUID: Int]` (movieId → index in array) to replace fragile `indices.contains(item.index)` patterns.
- **Search normalization cache:** store `normalizedTitle` / `normalizedTokens` per movie in an in-memory cache keyed by `Movie.id`.
  - Invalidate when title/year/keywords change.
- **Activity feed cache:** store derived `GroupActivityEvent` list with a `sourceRevision` counter.
  - Increment counter when movies/backlog or ratings change.

### Vereinheitlichungen (Patterns/DI)
- Introduce a small protocol-based boundary for CloudKit access:
  - e.g. `MovieCloudBackingStore` with methods used by `MovieCloudSyncCoordinator`.
  - Benefit: easier unit testing and reduced coupling.
- Standardize per-group sync meta storage:
  - Movies use `MovieStore` properties; users store in `UserStore` custom dict; movie nights store in `MovieNightStore` dict.
  - Consider a shared `PerGroupSyncStatusStore` utility.

## Risiken & Edge Cases
- **Index-based bindings in NavigationLinks**
  - Files: `Content/ContentMainAreaView.swift` and other places binding `movieStore.movies[item.index]`.
  - Risk: if the underlying array changes while a detail view is on screen, indices can drift.
- **CloudKit conflict policy**
  - Multiple devices can edit the same movie/ratings.
  - Code uses `updatedAt` fields and some best-effort merging, but an explicit documented policy is missing (**UNKNOWN**: authoritative resolution rule).
- **Public DB legacy path**
  - Many CloudKit stores have fallback to `publicCloudDatabase` when no `GroupContext` exists.
  - Risk: behavior divergence (sharing groups vs legacy) and migration complexity.
- **Push notification behavior**
  - Subscriptions create visible notifications (alert/sound/badge) in `CloudKit/CloudKitActivitySubscriptionManager.swift`.
  - Deep link parsing relies on subscriptionID parsing (`Notifications/PushDeepLinkRouter.swift`). If subscription IDs change, routing breaks.
- **Secrets exposure**
  - `Secrets.xcconfig` contains a plaintext API key; exclude from any shared archives.

## Observability / Debuggability
- Push debugging:
  - `CloudKit/CloudKitRemoteNotificationDebugger.swift` logs the raw push payload.
- Sync transparency in UI:
  - `Content/ContentSyncStatusLineView.swift` + store-exposed fields (`MovieStore.swift`, `UserStore.swift`, `MovieNights/MovieNightStore.swift`).
- Logging:
  - `PersistenceManager.swift` uses `os.Logger` (subsystem `filmfreaks`, category `Persistence`).
  - CloudKit layers mostly use `print` / best-effort toasts (search for `print("[Push]` etc).
- Repro tips:
  - For CloudKit zone-change issues, wipe local tokens in `UserDefaults` keys prefixed with `CKZoneToken.` (see `CloudKitZoneChangeTokenStore.swift`).
  - For share issues, verify `GroupContextStore` entries exist for group IDs (key `GroupContextsById` in UserDefaults).

## Open Questions (UNKNOWN)
- CloudKit Dashboard schema: indexes and query performance characteristics for `groupId`, `updatedAt`, `movieId`, etc.
- Release behavior for push record-fetching: `CloudKit/CloudKitActivityPushFetchCoordinator.swift` wraps `fetchAndHandle` in `#if DEBUG`.
- Whether activity feed should be derived-only forever, or later moved into a dedicated record type for server-side queries.
- Exact migration plan from legacy public DB groups to sharing zones (code supports both, but a one-way migration flow is not explicit).

## First 3 Refactors I would do (P0)

### P0.1 Cache movie list building (filter/sort/search)
- **Ziel:** Make scrolling and state changes cheaper by avoiding repeated O(n log n) work in render path.
- **Betroffene Dateien:**
  - `Content/ContentView+MovieItems.swift`
  - `Content/ContentView+Filtering.swift`
  - (consumer) `Content/ContentView.swift`, `Content/ContentMainAreaView.swift`
- **Risiko:** Low–medium. Risk of subtle behavior changes in filtering/sorting and focus/search UI.
- **Erwarteter Nutzen:** Big performance win as lists grow; fewer allocations; less MainActor CPU.

### P0.2 Split `MovieStore` by responsibility + add stable movie indexing
- **Ziel:** Reduce coupling and regression risk; eliminate index drift patterns.
- **Betroffene Dateien:**
  - `MovieStore.swift`
  - `MovieCloudSyncCoordinator.swift`
  - `PersistenceManager.swift`
  - `Content/ContentMainAreaView.swift`
- **Risiko:** Medium. Store refactor touches persistence and sync triggers.
- **Erwarteter Nutzen:** Better testability, simpler diffs, fewer crashes from array index drift.

### P0.3 Normalize CloudKit push handling and make release behavior explicit
- **Ziel:** Make notification behavior predictable and easier to debug.
- **Betroffene Dateien:**
  - `CloudKit/CloudKitActivityPushFetchCoordinator.swift`
  - `CloudKitShareAppDelegate.swift`
  - `Notifications/PushDeepLinkRouter.swift`
  - `CloudKit/CloudKitActivitySubscriptionManager.swift`
- **Risiko:** Medium. Notification changes are hard to test and can affect deliverability.
- **Erwarteter Nutzen:** Clear separation: system push (always) vs local-enriched notifications (optional), consistent deep links.