# ARCHITECTURE_NOTES.md

## Scope and Ground Rules

- Analysis target: uploaded iOS project root with `filmfreaks.xcodeproj`, app sources under `filmfreaks`, tests under `filmfreaksTests` and `filmfreaksUITests`.
- Priorities used: Sync, Storage, Model first; Entry Points and Navigation second; large Views and Services third; conventions and workflows fourth.
- No SwiftData, CoreData or `@Model` usage was found.
- Any item marked **UNKNOWN** is not asserted as fact and is collected in Open Questions.

## Big Files List: Top 15 by Lines

| Rank | Lines | Path | Grober Zweck | Warum riskant |
|---:|---:|---|---|---|
| 1 | 648 | `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift` | Debounced CloudKit writer for MovieNight events, responses, activity and presets | One MainActor class owns queue state, journal restore, batching, routing readiness, pending counts and retry. High change risk and hard to reason about partial failures. |
| 2 | 432 | `filmfreaks/Settings/GroupSettingsSections.swift` | UI sections for group settings | Large SwiftUI surface with many conditional sections. Risk is maintenance and view invalidation when EnvironmentObjects change. |
| 3 | 414 | `filmfreaks/MovieStore/MovieStore+CloudSync.swift` | Movie and rating CloudKit refresh, initial upload, diff enqueue, group context retry | Central sync path. Mixes routing guards, fetch modes, rating merge, local persistence, cast migration trigger and UI sync state. |
| 4 | 413 | `filmfreaks/Stats/StatsSnapshotBuilder+TasteDynamics.swift` | Taste and dynamics aggregation for stats | CPU-heavy aggregation and sorting. Pure builder is testable, but still likely expensive on large libraries. |
| 5 | 405 | `filmfreaks/Stats/StatsSnapshotBuilder.swift` | Base stats snapshot aggregation | Many passes over movies, users and ratings. Off-main through `StatsViewModel`, but invalidation currently compares full inputs. |
| 6 | 375 | `filmfreaks/Settings/GroupSettingsView.swift` | Create, select, share, delete and leave CloudKit groups | Multiple Tasks and CloudKit calls directly triggered from a large View. Hard to test, cancellation and error presentation are scattered. |
| 7 | 372 | `filmfreaks/MovieNights/MovieNightCloudDirtyJournal.swift` | Durable journal for MovieNight cloud writes | Broad payload surface for four record types. Restore scans group dirs and is tightly coupled to coordinator shape. |
| 8 | 369 | `filmfreaks/ViewingCustomGoal.swift` | Custom goal types, rules, Codable migration, presentation helpers | Domain, persistence compatibility and UI labels in one file. High accidental-breakage risk during schema evolution. |
| 9 | 366 | `filmfreaks/Movie.swift` | Movie, Rating, CastMember, sample data and Codable migration | Core model with embedded migration and sample data. Any change affects persistence, CloudKit payloads, stats and tests. |
| 10 | 355 | `filmfreaks/Stats/StatsView+Cards.Leaderboards.swift` | SwiftUI leaderboard cards | Large card file. Risk is maintainability and expensive body recomputation if input is not already precomputed. |
| 11 | 341 | `filmfreaks/MovieDetail/MovieDetailView.swift` | Movie detail UI and sheet orchestration | Large stateful View with metadata loading and ratings flows. Risk is view invalidation and task lifecycle coupling. |
| 12 | 335 | `filmfreaks/CloudKitUserStore.swift` | CloudKit GroupMember fetch, migration, upsert and delete | Querying, legacy migration, record name policy and batch APIs are combined. Easy to diverge from UserStore behavior. |
| 13 | 332 | `filmfreaks/CloudKitMovieStore/CloudKitMovieStore+Modify.swift` | Movie CloudKit save, batch modify, delete and conflicts | Complex route bucketing and conflict fallback. Partial failure can degrade to individual saves. |
| 14 | 327 | `filmfreaks/Stats/StatsSnapshotBuilder+RatingDimensions.swift` | Rating dimension stats | CPU-heavy rating aggregation. Risk grows with number of ratings per movie and users. |
| 15 | 326 | `filmfreaks/MovieNights/Roulette/MovieRouletteViewModel.swift` | Roulette state, candidate selection and spin animation state | MainActor view model with multiple published properties and tasks. Animation tasks need careful cancellation. |

Near-misses worth watching: `filmfreaks/Content/ContentMainAreaView.swift` with 319 lines, `filmfreaks/MovieStore/MovieStore+Mutations.swift` with 318 lines, `filmfreaks/PersistenceManager.swift` with 314 lines, and `filmfreaks/MovieSearch/MovieSearchView/MovieSearchView.swift` with 314 lines.

## Hot Path Analyse

### Rendering and Scrolling

#### Content list and grid

Files:

- `filmfreaks/Content/ContentView.swift`
- `filmfreaks/Content/ContentView+Lifecycle.swift`
- `filmfreaks/Content/ContentMovieItemsModel.swift`
- `filmfreaks/Content/ContentMainAreaView.swift`
- `filmfreaks/Content/MovieSearchIndexCache.swift`

Positive:

- Filtering, searching, sorting and item building are not done directly in `ContentView.body`.
- `ContentMovieItemsModel` cancels stale work and builds snapshots in a detached task.
- `MovieSearchIndexCache` avoids rebuilding normalized haystack strings on every search.

Hotspot reason:

- `ContentMovieItemsInputSignature` maps full watched and backlog arrays on the MainActor and includes fields such as ratings, cast, directors, genres and keywords. This is O(n) per input refresh before detached computation begins.
- `ContentView+Lifecycle.swift` schedules refreshes on many triggers: movies, backlog, search text, filter, sort, rating mode, TMDb display setting and group change. The computation is off render path, but the trigger/signature work still scales with library size.
- `ContentActivityPreviewModel.Inputs.isEquivalent` compares entire movie arrays and activity arrays before scheduling. This avoids unnecessary detached work but can still be O(n) on the MainActor.

Refactor lever:

- Introduce store-level revisions, for example `moviesRevision`, `backlogRevision`, `ratingsRevision`, `activityRevision`.
- Make input signatures revision-based plus search/filter/sort settings.
- Keep `MovieSearchIndexCache`, but invalidate by per-movie revision rather than recomputing a full fingerprint from many fields each time.

#### Stats

Files:

- `filmfreaks/Stats/StatsViewModel.swift`
- `filmfreaks/Stats/StatsSnapshotBuilder.swift`
- `filmfreaks/Stats/StatsSnapshotBuilder+TasteDynamics.swift`
- `filmfreaks/Stats/StatsSnapshotBuilder+RatingDimensions.swift`
- `filmfreaks/Stats/StatsSnapshotBuilder+SuggestionQuality.swift`

Positive:

- `StatsViewModel` debounces updates by 200 ms.
- Snapshot building runs in a detached task.
- Actor popularity is preloaded outside the snapshot builder, then actor sorting runs detached.

Hotspot reason:

- `StatsViewModel.Inputs` is `Equatable` and contains full `[Movie]` and `[User]`. `shouldScheduleUpdate` compares entire arrays on the MainActor.
- Snapshot builders perform many aggregations and sorts. This is fine for small libraries, but stats is the largest pure computation area.
- `PersonPopularityStore.shared.preloadPopularity` plus actor sorting can add secondary work after the base snapshot.

Refactor lever:

- Use revision-based invalidation.
- Split stats into smaller snapshots by tab/card group and compute only visible sections.
- Cache stable sub-aggregates keyed by groupId, selected range, location filter and movie revision.

#### Movie detail

Files:

- `filmfreaks/MovieDetail/MovieDetailView.swift`
- `filmfreaks/MovieDetail/MovieDetailLoadCoordinator.swift`
- `filmfreaks/SearchResultDetail/SearchResultDetailView.swift`

Hotspot reason:

- `MovieDetailView.swift` is a large stateful View that coordinates metadata loading and ratings UI.
- The detail loader can trigger TMDb network fetches and then patch `MovieStore` via `applyLoadedMoviePatch` in `MovieStore+Mutations.swift`.
- **UNKNOWN**: Exact body recomputation profile was not measured. Risk is based on file size, stateful View orchestration and metadata tasks.

Refactor lever:

- Move detail state orchestration into a small `MovieDetailViewModel` if not already fully covered by `MovieDetailLoadCoordinator`.
- Keep subviews stateless and pass precomputed presentation models.

#### Movie roulette

Files:

- `filmfreaks/MovieNights/Roulette/MovieRouletteViewModel.swift`
- `filmfreaks/MovieNights/Roulette/MovieRouletteBacklogIndex.swift`
- `filmfreaks/MovieNights/Roulette/MovieRouletteSpinStripView.swift`

Positive:

- `MovieRouletteBacklogIndex` builds a group-filtered snapshot and dictionary once per update.
- `MovieRouletteViewModel` cancels spin tasks when resetting.

Hotspot reason:

- Spin state is represented by several `@Published` properties: candidates, displayCandidates, active index, winner and spinning state. Each change can invalidate dependent views.
- Animation uses delayed tasks in `spin()` and is sensitive to cancellation.

Refactor lever:

- Collapse spin state into one published `State` struct to reduce multiple invalidations.
- Keep candidate indexing separate from animation state.

### Sync and Storage

#### Local persistence

Files:

- `filmfreaks/PersistenceManager.swift`
- `filmfreaks/GroupScopedStorage.swift`
- `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`

Positive:

- Large arrays moved out of UserDefaults into Application Support JSON.
- Writes are atomic and debounced.
- Group-scoped file paths are centralized.

Hotspot reason:

- `MovieStore+Persistence.swift` does `oldValue == movies` and diff enqueue on MainActor in `didSet`.
- For big arrays, equality, dictionary construction and filtering are MainActor CPU work.
- MovieNight local persistence writes an all-groups snapshot. A change in one group writes the whole MovieNight snapshot.

Refactor lever:

- Use explicit mutation APIs that know the changed item and avoid full-array old/new diffs.
- Move persistence encoding to actors or services with immutable payload snapshots.
- Consider per-group MovieNight files instead of one global snapshot.

#### CloudKit routing

Files:

- `filmfreaks/CloudKitRouting.swift`
- `filmfreaks/GroupContext.swift`
- `filmfreaks/CloudKitGroupStore/CloudKitGroupStore.swift`

Positive:

- UUID-like group IDs are protected from unsafe public DB fallback.
- `GroupContextStore` decouples route lookup from group list UI.

Hotspot reason:

- Many stores independently need GroupContext readiness and retry behavior.
- GroupContext arrival triggers flush and refresh in MovieStore and MovieNightStore.

Refactor lever:

- Add a small `CloudRouteResolver` service with typed route result and readiness status.
- Centralize retry/backoff for `groupContextNotReady`.

#### Movie sync

Files:

- `filmfreaks/MovieStore/MovieStore+CloudSync.swift`
- `filmfreaks/MovieCloudSyncCoordinator.swift`
- `filmfreaks/MovieCloudDirtyJournal.swift`
- `filmfreaks/CloudKitMovieStore/CloudKitMovieStore+Modify.swift`
- `filmfreaks/CloudKitMovieStore/CloudKitMovieStore+ZoneChanges.swift`
- `filmfreaks/CloudKitRatingStore/CloudKitRatingStore+ZoneChanges.swift`

Positive:

- Dirty journal preserves pending movie changes across launches.
- Batched movie modifications use 200-record chunks.
- Zone groups use `CKFetchRecordZoneChangesOperation` with token recovery.
- Ratings are separated from Movie payloads in CloudKit.

Hotspot reason:

- Zone-change apply loops through changed movies and calls `removeAll` on watched and backlog for each entry. This is O(k*n) when many changed records arrive.
- `enqueueCloudSync` builds dictionaries and filters full arrays on MainActor for each list mutation.
- `MovieStore+CloudSync.swift` combines sync, merge, local persistence, rating merge and migration trigger in one file.
- `CloudKitMovieStore+Modify.swift` has complex partial-failure and conflict behavior. Some conflicts fall back to individual `save(movie:isBacklog:)` calls.

Refactor lever:

- Apply changes through dictionaries keyed by movie ID, then rebuild sorted arrays once.
- Introduce `MovieCloudDiffEngine` and `MovieCloudMergeEngine` as pure, testable helpers.
- Keep CloudKit operations in service types and have `MovieStore` apply final snapshots only.

#### Rating sync

Files:

- `filmfreaks/MovieStore/MovieStore+Mutations.swift`
- `filmfreaks/CloudKitRatingStore/CloudKitRatingStore+Modify.swift`
- `filmfreaks/CloudKitRatingStore/CloudKitRatingStore+Query.swift`

Positive:

- Rating records are keyed by stable reviewer identity.
- Rating deletes can be reconstructed from encoded record names during zone changes.
- Local UI updates happen before CloudKit writes.

Hotspot reason:

- `upsertRating` and `deleteRating` do not use a durable dirty journal. If CloudKit write fails, local data remains, but no explicit retry queue was found.
- `saveRatingsBatch` builds zone-aware record IDs, but unlike `saveRating`, it does not set `record.parent` for shared-zone records. This may matter for batch migration or initial uploads into shared zones.
- `CloudKitRatingStore+Query.swift` chunks by 100 movie IDs and queries all pages into memory. This is acceptable for moderate libraries but should be watched.

Refactor lever:

- Add a `RatingCloudDirtyJournal` or fold ratings into the existing movie journal with distinct record type.
- Set parent root in `saveRatingsBatch` for zone routes.
- Add tests around batch rating parent assignment.

#### User sync

Files:

- `filmfreaks/Users+Store/UserStore+CloudRefresh.swift`
- `filmfreaks/Users+Store/UserStore+Mutations.swift`
- `filmfreaks/CloudKitUserStore.swift`

Positive:

- `CloudKitUserStore` has batch upsert support and legacy memberId migration.
- Local users are persisted to group-scoped JSON.

Hotspot reason:

- Initial seeding in `UserStore+CloudRefresh.swift` loops over local users and calls `upsertMember` once per user, although `upsertMembersBatch` exists.
- User mutations use direct Task writes to CloudKit and no durable retry journal was found.

Refactor lever:

- Use `upsertMembersBatch` for bootstrap.
- Introduce a small member mutation queue for add, rename and delete.
- Split `CloudKitUserStore.swift` into schema, query, modify and legacy migration files.

#### Goals sync

Files:

- `filmfreaks/Goals/GoalsStore.swift`
- `filmfreaks/CloudKitGoalStore.swift`
- `filmfreaks/ViewingCustomGoal.swift`

Positive:

- Custom Goals use a versioned payload, which allows new goal types without CloudKit schema churn.
- Legacy yearly goal migration exists.

Hotspot reason:

- Custom Goals are one payload record per group. Concurrent edits from two devices can overwrite each other unless merge is added above the payload level.
- `syncFromCloud` overwrites local goals with remote values.
- Goal writes are direct Tasks with no durable retry journal found.

Refactor lever:

- Add `updatedAt` or per-goal logical clocks inside `ViewingCustomGoalsPayload` and merge per goal.
- Add sync conflict tests for concurrent custom-goal edits.

#### MovieNight sync

Files:

- `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift`
- `filmfreaks/MovieNights/MovieNightCloudDirtyJournal.swift`
- `filmfreaks/MovieNights/MovieNightStore/MovieNightStore+CloudRefresh.swift`
- `filmfreaks/CloudKitMovieNightStore/CloudKitMovieNightStore+Modify.swift`

Positive:

- Local writes are journaled and debounced.
- Multiple record types are batched through `MovieNightCloudKitModificationBatcher`.
- Routing readiness prevents UUID groups from falling back to Public DB.
- Activity is capped to 200 entries in merge.

Hotspot reason:

- The coordinator is 648 lines and handles eight pending dictionaries plus restore, batching, routing, retries and pending counts.
- `publishPendingCount` filters all pending dictionaries by group each time. This is fine for small queues, but grows with offline usage.
- `MovieNightLocalPersistence` writes a single all-groups snapshot.
- `CloudKitGroupStore+Sharing.swift` share hierarchy repair does not include `MovieNightEvent`, `MovieNightResponse`, `MovieNightActivity` or `MovieRoulettePreset`, although current modify code sets parent for new records.

Refactor lever:

- Split queue state, journal restore, flush planning and CloudKit execution.
- Maintain pending counts incrementally by group.
- Add MovieNight record types to one-time share hierarchy repair if existing records may lack parents.

#### Push and subscriptions

Files:

- `filmfreaks/CloudKit/CloudKitActivitySubscriptionManager.swift`
- `filmfreaks/CloudKit/CloudKitActivityPushFetchCoordinator.swift`
- `filmfreaks/CloudKitShareAppDelegate.swift`
- `filmfreaks/Notifications/PushDeepLinkRouter.swift`

Positive:

- Subscriptions are deterministic per group and record kind.
- Push taps route to `ContentView+DeepLink.swift`, switch group and open activity.

Hotspot reason:

- `CloudKitActivityPushFetchCoordinator.fetchAndHandle` is guarded by `#if DEBUG`; in non-debug builds it returns false. Production local notification enrichment and fetch handling may not run.
- Entitlement has `aps-environment = development`. Production push readiness is **UNKNOWN**.

Refactor lever:

- Decide production push behavior explicitly.
- Move only verbose debug logging behind `#if DEBUG`, not the entire fetch-and-handle path, if the feature should ship.

### Concurrency

#### MainActor isolation

Files:

- `filmfreaks.xcodeproj/project.pbxproj`
- `filmfreaks/MovieStore/MovieStore.swift`
- `filmfreaks/MovieNights/MovieNightStore/MovieNightStore.swift`
- `filmfreaks/Users+Store/UserStore.swift`
- `filmfreaks/Goals/GoalsStore.swift`

Hotspot reason:

- Project default actor isolation is `MainActor`.
- Most stores are `@MainActor`, which simplifies UI state but can concentrate CPU work on the UI actor.
- Equality checks, diffing, signature creation and some sorting happen before detached tasks.

Refactor lever:

- Keep UI state mutation on MainActor.
- Move pure diffing, merging and snapshot preparation into nonisolated structs or actors.
- Apply only final result arrays on MainActor.

#### Task lifetimes

Files:

- `filmfreaks/AppRefreshCoordinator.swift`
- `filmfreaks/MovieSearch/MovieSearchView/MovieSearchViewModel+Search.swift`
- `filmfreaks/MovieNights/Roulette/MovieRouletteViewModel.swift`
- `filmfreaks/MovieStore/MovieStore+Mutations.swift`
- `filmfreaks/Settings/GroupSettingsView.swift`

Positive:

- `AppRefreshCoordinator` coalesces app-active refreshes and prevents parallel cascades.
- Movie search cancels search and pagination tasks with tokens.
- Roulette cancels spin tasks on reset.

Hotspot reason:

- `MovieStore+Mutations.migrateCastDataIfNeeded` uses an unbounded `withTaskGroup` over all target movies. This can create many concurrent TMDb requests.
- Several UI actions in `GroupSettingsView.swift` start `Task` directly from the View. Long CloudKit tasks may outlive the visible UI if the sheet is dismissed.
- Store initializers start Tasks, for example MovieStore cast migration and cloud load, UserStore initial refresh and MovieNight initial local load.

Refactor lever:

- Add bounded concurrency helpers.
- Centralize view-launched async actions in ViewModels or stores with explicit cancellation.
- Track long-running Task handles where the lifetime matters.

## Refactor Map

### Concrete Splits

#### `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift`

Split into:

- `MovieNightPendingQueue.swift`
  - Owns pending saves/deletes by record type.
  - Maintains counts by group incrementally.
- `MovieNightJournalRestorer.swift`
  - Converts `MovieNightCloudDirtyJournal.Entry` to pending queue operations.
- `MovieNightFlushPlanner.swift`
  - Produces per-group flush snapshots and batches.
- `MovieNightCloudFlushExecutor.swift`
  - Calls `CloudKitMovieNightStore.modifyBatch` and handles batch result.
- `MovieNightSyncCoordinator.swift`
  - Keeps debounce, network check, routing readiness and callbacks.

Expected benefit:

- Easier tests for each failure mode.
- Less chance of corrupting pending state during partial failure.
- Smaller MainActor surface.

#### `filmfreaks/MovieStore/MovieStore+CloudSync.swift`

Split into:

- `MovieCloudRefreshService.swift`
  - Chooses zone changes versus public snapshot.
- `MovieCloudMergeEngine.swift`
  - Applies changed and deleted movies using dictionaries.
- `MovieRatingMergeEngine.swift`
  - Preserves local ratings, applies changed and deleted rating records.
- `MovieInitialUploadService.swift`
  - Handles empty cloud bootstrap.
- `MovieCloudDiffEngine.swift`
  - Calculates save and delete intents from old and new snapshots.

Expected benefit:

- Smaller store extension.
- Pure functions for merge and diff tests.
- Less MainActor CPU work.

#### `filmfreaks/MovieStore/MovieStore+Mutations.swift`

Split into:

- `MovieRatingMutations.swift`
- `MoviePatchMutations.swift`
- `MovieCastMigrationService.swift`

Expected benefit:

- Rating sync reliability can be changed without touching cast migration.
- Cast migration can get bounded concurrency and retry policy.

#### `filmfreaks/CloudKitUserStore.swift`

Split into:

- `CloudKitUserStore+Schema.swift`
- `CloudKitUserStore+Query.swift`
- `CloudKitUserStore+Modify.swift`
- `CloudKitUserStore+LegacyMigration.swift`

Expected benefit:

- Mirrors existing Movie and Rating store style.
- Easier to add batch bootstrap and tests.

#### `filmfreaks/Movie.swift`

Split into:

- `Movie.swift`
- `Rating.swift`
- `CastMember.swift`
- `MovieCodableMigration.swift`
- `SampleMovies.swift`

Expected benefit:

- Model evolution is safer.
- Test fixtures and sample data stop bloating the core model file.

#### `filmfreaks/ViewingCustomGoal.swift`

Split into:

- `ViewingCustomGoalType.swift`
- `ViewingCustomGoalRule.swift`
- `ViewingCustomGoal.swift`
- `ViewingCustomGoal+Codable.swift`
- `ViewingCustomGoal+Presentation.swift`
- `ViewingCustomGoal+LegacyCompatibility.swift`

Expected benefit:

- Custom goal schema changes are less risky.
- Presentation text changes do not touch persistence code.

#### Stats files

Split and standardize:

- Keep `StatsSnapshotBuilder.swift` as coordinator.
- Move each domain into small builders: ratings, genres, people, timeline, suggestions, taste dynamics.
- Ensure each builder has narrow tests and uses immutable input snapshots.

#### Settings group UI

Files:

- `filmfreaks/Settings/GroupSettingsView.swift`
- `filmfreaks/Settings/GroupSettingsSections.swift`

Split into:

- `GroupSettingsViewModel.swift`
- `GroupSettingsOwnedSection.swift`
- `GroupSettingsSharedSection.swift`
- `GroupSettingsActiveGroupCard.swift`
- `GroupSettingsDangerZone.swift`

Expected benefit:

- Fewer Tasks directly inside the View.
- Better error and loading-state testing.

### Cache and Index Ideas

- **Movie revision keys**
  - Store `moviesRevision`, `backlogRevision`, `ratingsRevision`, `metadataRevision` in `MovieStore`.
  - Key Content and Stats invalidation by revisions instead of full arrays.
- **Movie dictionaries**
  - Maintain transient `[UUID: Movie]` for watched and backlog during sync merge.
  - Use this for zone-change apply and detail patching.
- **Rating index**
  - Maintain `[movieId: [reviewerKey: Rating]]` during rating merges to avoid repeated linear scans.
- **MovieNight response index**
  - Add `[eventId: [userId: MovieNightResponse]]` inside merge helpers or snapshots.
- **Stats sub-cache**
  - Key by groupId, selected range, location filter, moviesRevision and ratingDisplayMode.
  - Cache people, genre and rating-dimension sub-aggregates separately.
- **CloudKit route cache**
  - Cache successful route resolution per groupId and invalidate on `groupContextDidUpsert` and `groupContextDidRemove`.
- **Actor popularity cache TTL**
  - `PersonPopularityStore` already acts as a cache. Document TTL and invalidation policy.
- **Recommendations cache key**
  - Include groupId and watched/backlog revision. Current cache is max-age based.
- **Search index cache**
  - Keep `MovieSearchIndexCache`, but feed it a per-movie search revision instead of hashing many fields each time.

### Vereinheitlichungen

- Define a common `SyncStatus` model across MovieStore, MovieNightStore, UserStore and GoalsStore.
- Define a `CloudWriteQueue` protocol for queue, flush, pending count and journal restore.
- Use one `CloudKitOperationBatcher` pattern for Movie, Rating, User, Goal and MovieNight writes.
- Standardize CloudKit error presentation through a small formatter, similar to existing UserStore sync status tests.
- Replace scattered `print` with `Logger(subsystem: "filmfreaks", category: ...)`.
- Use dependency injection for CloudKit stores in production stores where tests need to simulate errors.
- Keep all group-routing checks in `CloudKitRouting` or a resolver. Avoid local duplicate heuristics like separate UUID checks in multiple stores.

## Risiken & Edge Cases

### Data Loss and Sync Conflicts

- Ratings:
  - Local rating changes persist in embedded movie JSON, but CloudKit rating write failures have no durable retry queue found.
  - A user may believe a rating synced while it is local only.
- Custom Goals:
  - One payload record per group can lose concurrent edits. Last writer wins at record level.
- Users:
  - Add/delete operations write directly to CloudKit through Tasks. No durable retry queue found.
- Movie changes:
  - Dirty journal protects offline writes, but MainActor diffing could be expensive during bulk changes.
- MovieNight changes:
  - Durable journal exists, but coordinator complexity increases partial-failure risk.
- Group switch mid-flight:
  - MovieStore guards against applying fetched movies to the wrong active group.
  - Equivalent guards in every store and every view-launched Task should be audited.

### CloudKit Sharing

- `CloudKitGroupStore+Sharing.swift` repair list excludes MovieNight record types.
- `CloudKitRatingStore+Modify.swift` `saveRatingsBatch` does not attach parent root, while `saveRating` does.
- Shared database write permissions can fail for participants, especially for migration or repair operations.
- Existing records without parent may be invisible to CKShare participants.

### Legacy and Migration

- `PersistenceManager` migrates legacy UserDefaults to files and intentionally leaves old keys.
- `Movie` decodes legacy cast strings to negative person IDs and later migrates through TMDb credits.
- `CloudKitUserStore` migrates legacy member records missing `memberId` best-effort.
- `MovieNightLocalPersistence` decodes old snapshot shapes and multiple date formats.
- `CloudKitTokenRecovery` handles stale zone tokens, but token corruption and partial state should remain covered by tests.

### Offline and Multi-Device

- Movies and MovieNights have queued retry.
- Ratings, Users and Goals need an explicit policy: durable retry, manual retry, or clear local-only status.
- Goals and ratings need clear conflict semantics on multi-device edits.
- Public legacy groups and zone-based groups behave differently. Bugs can hide if only one route is tested.

### Secrets and Configuration

- `filmfreaks/Secrets.xcconfig` in the uploaded project contains a concrete TMDb key.
- Client-side API keys are extractable from the app bundle. The immediate risk is source/archive leakage, not absolute secrecy.
- Production push readiness is **UNKNOWN** because entitlements show development APNs.

### Push and Notifications

- `CloudKitActivityPushFetchCoordinator.swift` only fetches and handles records under `#if DEBUG`.
- CloudKit visible notifications may still appear due to subscription notificationInfo, but local notification enrichment and background result will not run in non-debug.
- Tapping CloudKit notification can still parse subscriptionID through `PushDeepLinkRouter`, but payload shape should be tested in production.

### Performance at Scale

- Full-array equality in `StatsViewModel`, `ContentActivityPreviewModel` and `MovieStore+Persistence` is the main MainActor CPU risk.
- Zone-change apply using repeated `removeAll` is inefficient for many changes.
- Unbounded cast migration can create too many TMDb requests.
- Stats builders are pure and off-main but still heavy.

## Observability and Debuggability

### Existing

- `PersistenceManager` uses `os.Logger` with subsystem `filmfreaks`, category `Persistence`.
- Many CloudKit paths use `print`.
- Sync state is exposed in stores, for example pending counts, last sync date and last error.
- `CloudKitRemoteNotificationDebugger` exists for push logs.
- Tests cover routing, token recovery, dirty journals, local persistence, content builders, stats builders, movie-night merge and user-store error formatting.

### Recommended

- Add `Logger` categories:
  - `Sync.Movie`
  - `Sync.Rating`
  - `Sync.User`
  - `Sync.Goals`
  - `Sync.MovieNight`
  - `CloudKit.Routing`
  - `CloudKit.Push`
- Log sync events with groupId, route scope, zone name, operation count, changed count, deleted count, token reset and elapsed time.
- Add a hidden debug screen for:
  - Current group context.
  - Database scope and zone.
  - Pending journal counts by record type.
  - Last CloudKit error by store.
  - Zone token presence by namespace.
- Add reproducible sync fixtures:
  - Empty cloud bootstrap.
  - Offline movie edit then reconnect.
  - Rating write failure then app restart.
  - Shared group record without parent.
  - Stale zone token recovery.
  - Concurrent custom-goal edits.
- Add performance signposts around:
  - Content item snapshot build.
  - Stats snapshot build.
  - MovieStore diff enqueue.
  - Zone-change apply.
  - MovieNight journal restore and flush.

## Open Questions

- **UNKNOWN**: Is iOS 26.0 the intended minimum deployment target for users?
- **UNKNOWN**: Are public legacy groups still a supported product feature, or only migration compatibility?
- **UNKNOWN**: What exact offline guarantee is expected for ratings, users and goals?
- **UNKNOWN**: Are CloudKit Dashboard indexes configured for all queried fields?
- **UNKNOWN**: Does production use APNs production entitlement, and should push fetch handling run outside DEBUG?
- **UNKNOWN**: Should MovieNight records created before parent-root assignment be repaired for existing shared groups?
- **UNKNOWN**: What is the expected maximum library size, rating count and group count?
- **UNKNOWN**: Should custom goals merge per goal or remain last-writer-wins by payload?
- **UNKNOWN**: Should CloudKit conflicts prefer server, client, timestamp or field-level merge for every record type?
- **UNKNOWN**: How are CloudKit schema migrations managed between development and production containers?
- **UNKNOWN**: Are TMDb rate limits a practical concern for cast migration on large local libraries?

## First 3 Refactors I would do

### P0.1: Move Movie diff and merge off the MainActor

- Ziel:
  - Reduce UI stalls from full-array diffing and zone-change apply.
  - Make Movie/Ratings merge behavior testable as pure logic.
- Betroffene Dateien:
  - `filmfreaks/MovieStore/MovieStore+CloudSync.swift`
  - `filmfreaks/MovieStore/MovieStore+Persistence.swift`
  - `filmfreaks/MovieStore/MovieStore+Mutations.swift`
  - New: `MovieCloudDiffEngine.swift`, `MovieCloudMergeEngine.swift`, `MovieRatingMergeEngine.swift`
- Risiko:
  - Medium. This touches core sync and persistence behavior. Needs tests for watched to backlog moves, deletes, rating preservation, group switch mid-flight and initial upload.
- Erwarteter Nutzen:
  - Less MainActor contention.
  - Faster large-library sync.
  - Smaller `MovieStore+CloudSync.swift`.
  - Safer future changes to rating and movie merge rules.

### P0.2: Split MovieNightCloudSyncCoordinator into queue, journal restore and flush executor

- Ziel:
  - Make MovieNight offline sync reliable and maintainable before more record types or conflict rules are added.
- Betroffene Dateien:
  - `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift`
  - `filmfreaks/MovieNights/MovieNightCloudDirtyJournal.swift`
  - `filmfreaks/MovieNights/MovieNightStore/MovieNightStore+CloudFlush.swift`
  - New: `MovieNightPendingQueue.swift`, `MovieNightJournalRestorer.swift`, `MovieNightFlushPlanner.swift`, `MovieNightCloudFlushExecutor.swift`
- Risiko:
  - Medium to high. The code is central to offline MovieNight writes. Migration must keep existing journal files readable.
- Erwarteter Nutzen:
  - Easier partial-failure testing.
  - Cleaner retry behavior.
  - Lower chance of pending-count drift.
  - Smaller files and more targeted responsibilities.

### P0.3: Close CloudKit reliability gaps for ratings, users, goals and sharing parents

- Ziel:
  - Make sync guarantees explicit and prevent records from being local-only or invisible in shared zones.
- Betroffene Dateien:
  - `filmfreaks/MovieStore/MovieStore+Mutations.swift`
  - `filmfreaks/CloudKitRatingStore/CloudKitRatingStore+Modify.swift`
  - `filmfreaks/Users+Store/UserStore+CloudRefresh.swift`
  - `filmfreaks/Users+Store/UserStore+Mutations.swift`
  - `filmfreaks/Goals/GoalsStore.swift`
  - `filmfreaks/CloudKitGroupStore/CloudKitGroupStore+Sharing.swift`
- Risiko:
  - Medium. Adding retry queues changes user-visible sync status and can duplicate writes if record IDs are not deterministic. Parent repair needs careful CloudKit testing.
- Erwarteter Nutzen:
  - Fewer silent sync failures.
  - Better multi-device consistency.
  - Clear offline semantics.
  - Existing shared groups have a path to repair invisible records.
