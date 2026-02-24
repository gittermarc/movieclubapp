# ARCHITECTURE_NOTES.md

_Last updated: 2026-02-24. Generated from `Archiv.zip`._

## Big Files List: Top 15 files by line count
- `filmfreaks/SearchResultDetail/SearchResultDetailView.swift` — **522** lines
- `filmfreaks/CloudKitGroupStore.swift` — **455** lines
- `filmfreaks/MovieSearch/MovieSearchView.swift` — **434** lines
- `filmfreaks/Content/ContentView.swift` — **412** lines
- `filmfreaks/MovieNights/Sheets/MovieNightDetailSheet.swift` — **410** lines
- `filmfreaks/MovieNights/MovieNightStore.swift` — **398** lines
- `filmfreaks/MovieStore/MovieStore+CloudSync.swift` — **396** lines
- `filmfreaks/UserStore.swift` — **389** lines
- `filmfreaks/ViewingCustomGoal.swift` — **369** lines
- `filmfreaks/Movie.swift` — **366** lines
- `filmfreaks/SettingsView.swift` — **363** lines
- `filmfreaks/GroupSettingsView.swift` — **360** lines
- `filmfreaks/Stats/StatsView+Cards.Leaderboards.swift` — **355** lines
- `filmfreaks/Stats/StatsSnapshotBuilder.swift` — **348** lines
- `filmfreaks/MovieDetail/MovieDetailView.swift` — **345** lines

### Notes
- Diese Liste ist rein nach Zeilen sortiert (Swift files). Große SwiftUI Views sind hier meist die Compile-Time-Hotspots.
- Häufig ist der beste ROI: „Host bleibt, Rest in `+*.swift` Extensions/Subviews auslagern“ (mechanisch, kaum Risiko).

## Hot Path Analyse
### 1) Rendering / Scrolling (SwiftUI invalidations, expensive computations)
- `filmfreaks/Content/ContentView.swift` (412 lines)
  - **Warum Hotspot-Kandidat:** sehr viele `@State` + mehrere `@EnvironmentObject` → bei häufigen Publishes (Sync, Network) kann die View oft invalidieren.
  - **Mitigation im Code:** Off-render-path Modelle:
    - `filmfreaks/Content/ContentMovieItemsModel.swift` (derived list/grid items)
    - `filmfreaks/Content/ContentActivityPreviewModel.swift` (activity preview items)
  - **Was testen:** Scroll Performance bei aktivem Sync / pending changes, Wechsel Watched↔Backlog, Filter/Sort.
- `filmfreaks/MovieSearch/MovieSearchView.swift` (434 lines)
  - **Warum Hotspot-Kandidat:** Live search + pagination tasks + große Result-Listen; Sheet Navigation.
  - **Konkreter Grund:** `Task`-gesteuerte Suche/Pagination → Gefahr von Stale Results/Overfetch ohne konsequente Cancellation.
- `filmfreaks/SearchResultDetail/SearchResultDetailView.swift` (522 lines)
  - **Warum Hotspot-Kandidat:** Mehrere unabhängige Loads (Details + Watch Providers) + viele UI Zustände.
  - **Konkreter Grund:** **Task lifetime**: Sheet dismissed, aber laufende Task könnte weiterlaufen (abhängig von Implementierung).
- `filmfreaks/MovieNights/Sheets/MovieNightDetailSheet.swift` (410 lines)
  - **Warum Hotspot-Kandidat:** Große Sheet-View, viele Sections + State; wird häufig geöffnet.

### 2) Sync / Storage (CloudKit ops, fetch strategies, caching)
#### App-level refresh orchestration
- `filmfreaks/filmfreaksApp.swift` + `filmfreaks/AppRefreshCoordinator.swift`
  - **Konkreter Grund:** On-active refresh cascade kann mehrere CloudKit fetches triggern; coalescing verhindert parallelism, aber Work bleibt real.
  - **Was testen:** App switching (active toggles), Share accept flows, offline/online transitions.

#### Movies (watched/backlog) sync pipeline
- `filmfreaks/MovieStore/MovieStore.swift` + `MovieStore+CloudSync.swift` + `MovieStore+Persistence.swift`
  - **Konkreter Grund:** `movies`/`backlogMovies` `didSet` enqueuen diff work und persistieren JSON.
  - Guards im Code:
    - `isApplyingCloudUpdate` verhindert noise bei initial load/remote apply.
    - `isApplyingRatingUpdate` verhindert movie-diff work bei rating-only edits.
- `filmfreaks/MovieCloudSyncCoordinator.swift`
  - **Konkreter Grund:** debounced in-memory queues (`pendingSaves`, `pendingDeletes`) → robust gegen burst edits.
  - **Edge case:** queues sind nicht persisted → App-Kill kann pending uploads verlieren.
- Low-level: `filmfreaks/CloudKitMovieStore/*`
  - **Konkreter Grund:** Merge policy server-wins (`CloudKitMovieStore+Merge.swift`) → Konflikte vermeiden, aber lokale Änderungen können verlieren.

#### Ratings (separate records)
- `filmfreaks/CloudKitRatingStore/CloudKitRatingStore+Schema.swift`
  - **Konkreter Grund:** stable recordName encoding/parsing; bei vielen Ratings kann die Anzahl Records hoch werden.
  - **Was testen:** rename user, reviewerId migration, sync correctness zwischen Geräten.

#### Groups / Sharing / Routing
- `filmfreaks/CloudKitGroupStore.swift`
  - **Konkreter Grund:** CloudKit account status + owned/shared fetch + share hierarchy repair + subscription ensure.
- `filmfreaks/CloudKitRouting.swift`
  - **Konkreter Grund:** UUID-like groupId ohne `GroupContext` → throw `groupContextNotReady` (kein Public fallback).
  - **Was testen:** Share accept → GroupContextStore upsert → danach MovieNight flush + movie/user refresh funktioniert.

#### Incremental zone changes
- `filmfreaks/CloudKitZoneChanges.swift` + `filmfreaks/CloudKitZoneChangeTokenStore.swift`
  - **Konkreter Grund:** token invalidation/reset führt zu „mehr Arbeit“ (ok), aber muss UX-seitig tolerierbar sein.

#### Movie Nights sync
- `filmfreaks/MovieNights/MovieNightStore.swift` + `MovieNightCloudSyncCoordinator.swift` + `filmfreaks/CloudKitMovieNightStore/*`
  - **Konkreter Grund:** group-scoped routing + pending flush Timing (`filmfreaksApp.swift` comment: flush erst nach GroupContexts).

### 3) Concurrency (MainActor contention, cancellation, thread safety)
- Viele Stores sind `@MainActor` (gut für correctness). Risiko ist **MainActor contention**, wenn große Arrays oft mutieren.
- Coalescing/Debounce existiert bereits (gut):
  - `AppRefreshCoordinator.triggerRefresh(...)` (`filmfreaks/AppRefreshCoordinator.swift`)
  - `MovieCloudSyncCoordinator` debounced flush (`filmfreaks/MovieCloudSyncCoordinator.swift`)
- Kandidaten, wo Cancellation relevant ist:
  - `filmfreaks/MovieSearch/MovieSearchView+Search.swift` (search + pagination tasks)
  - `filmfreaks/SearchResultDetail/SearchResultDetailView.swift` (details/watch providers)
  - `filmfreaks/GroupSettingsView.swift` (refresh/async actions)

## Refactor Map
### A) Konkrete Splits (mechanisch, low risk)
1) `SearchResultDetailView` (522) → Host bleibt, split per Extensions:
   - `SearchResultDetailView+Loading.swift` (Details/WatchProviders load + cancellation)
   - `SearchResultDetailView+Actions.swift` (Add actions, trailer)
   - optional `SearchResultDetailView+State.swift` (derived props, helper structs)
2) `CloudKitGroupStore` (455) → Facade + focused extensions:
   - `CloudKitGroupStore+Fetch.swift` (account status, fetchGroupContexts)
   - `CloudKitGroupStore+Sharing.swift` (shares, hierarchy repair)
   - `CloudKitGroupStore+Subscriptions.swift` (Activity subscriptions)
3) `MovieNightDetailSheet` (410) → UI sections in Subviews/Extensions:
   - `+Header`, `+Responses`, `+Actions`
4) `MovieSearchView` (434) → UI shell vs search/recommendations (teilweise schon split):
   - `MovieSearchView+UI.swift` für Header/Empty/Scanner/Sheet wiring.

### B) Cache-/Index-Ideen (performance, concrete)
- **Persisted pending upload retry (Movies/Movie Nights):**
  - Minimaler Persistenz-Ansatz: pro groupId ein Set aus `(movieId, isBacklog)` + timestamp in UserDefaults oder Application Support.
  - Reconcile on launch/active: queueSave für dirty items → clear bei `batchDidSucceed`.
  - Betroffene Files: `MovieCloudSyncCoordinator.swift`, `MovieStore+CloudSync.swift`, analog `MovieNightCloudSyncCoordinator.swift`.
- **Activity/Derived snapshots überall dort, wo Listen groß werden:**
  - Pattern existiert schon: `StatsSnapshotBuilder.swift` (pure compute) + off-main call-site.
  - Kandidaten: Goals progress snapshots, MovieNight calendar buckets.

### C) Vereinheitlichungen (Patterns, Services, DI)
- Singletons vs injected dependencies vereinheitlichen (z.B. `CloudKitGoalStore.shared` vs `CloudKitMovieStore()` in MovieStore init).
- Einheitliches Error Surfacing: Stores publishen teils `lastCloudSyncError` oder Toasts; konsolidieren in einem „SyncStatus“ Modell.

## Risiken & Edge Cases
- **Secrets:** `filmfreaks/Secrets.xcconfig` enthält echten TMDb Key (Snapshot) → sofortiges Risiko.
- **Upload queue persistence:** in-memory pending queues können nach App-Kill verloren gehen → Multi-device drift.
- **Routing readiness:** UUID-like groupId ohne GroupContext → throw → muss UX-seitig klar sein.
- **Merge policy:** server-wins kann lokale Änderungen verwerfen (sicherer, aber UX/Transparency wichtig).
- **CloudKit account state:** `CloudKitGroupStore.refresh()` leert Listen bei noAccount/restricted (Toast best-effort).

## Observability / Debuggability
- Logging ist punktuell vorhanden (z.B. `os.Logger` in `PersistenceManager`).
- Push debugging: `filmfreaks/CloudKit/CloudKitRemoteNotificationDebugger.swift`.
- Empfehlung: Einen „Sync Diagnostics“ Screen in Settings (GroupContext + last sync + pending + last error).

## Open Questions (UNKNOWN)
- CloudKit Dashboard (Indices, subscriptions in production) ist aus Repo nicht belegbar → **UNKNOWN**.
- Production vs Development deployment von Push/CloudKit: Entitlements haben `aps-environment=development` → **UNKNOWN** ob Production configured ist.
- Unit tests: Zustand/Abdeckung von `filmfreaksTests` → **UNKNOWN**.
- Zentrales Error-Surfacing (RoutingError + Cloud errors) → **UNKNOWN** (gesehen: mix aus Toast + published strings).
- End-to-end Payload Versionierung/Changelog (Movie/Goals/MovieNights) → **UNKNOWN** über alle Domains.

## First 3 Refactors I would do (P0)
### P0.1 — Secrets hygiene (immediate risk reduction)
- **Ziel:** Keine Secrets im Repo; Key Rotation möglich.
- **Betroffene Dateien:** `filmfreaks/Secrets.xcconfig`, `filmfreaks/Debug.xcconfig`, `filmfreaks/Release.xcconfig`.
- **Risiko:** niedrig (config-only), aber Builds brechen, wenn lokale Datei fehlt.
- **Erwarteter Nutzen:** Security + sauberer CI/Sharing Flow.

### P0.2 — Persisted pending upload retry (robust offline sync)
- **Ziel:** Offline edits überleben App-Kill und werden später hochgeladen.
- **Betroffene Dateien:** `filmfreaks/MovieCloudSyncCoordinator.swift`, `filmfreaks/MovieStore/MovieStore+CloudSync.swift` (analog `MovieNightCloudSyncCoordinator.swift`).
- **Risiko:** medium (Reconcile/De-dup muss sauber sein).
- **Erwarteter Nutzen:** Weniger “Warum fehlt das auf Gerät B?” und weniger Support-Aufwand.

### P0.3 — Split `SearchResultDetailView` (compile-time + maintainability)
- **Ziel:** Große Datei in 2–3 kleine Dateien splitten; Verantwortlichkeiten klar.
- **Betroffene Dateien:** `filmfreaks/SearchResultDetail/SearchResultDetailView.swift` + neue `SearchResultDetailView+*.swift`.
- **Risiko:** niedrig (mechanisch).
- **Erwarteter Nutzen:** Schnellere Iteration + weniger Regressionen in Trailer/WatchProviders/Add flows.
