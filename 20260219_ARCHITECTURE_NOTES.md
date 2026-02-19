# ARCHITECTURE_NOTES — filmfreaks

_Last updated: 2026-02-19 (Europe/Berlin)_

> Fokus dieser Notes: Wartbarkeit + Performance + Sync-Risiken. Kein Marketing, nur Technik.

---

## 0) Snapshot: Was dieses Projekt *wirklich* ist
- Persistenz/Sync ist **custom**: lokale JSON-Dateien + CloudKit (Public + Private/Shared mit Sharing).
- **Kein SwiftData/CoreData** im Code gefunden (Suche nach `import SwiftData`/`import CoreData` ohne Treffer).
- App ist **store-driven** (ObservableObjects, meist `@MainActor`) und UI ist SwiftUI.

---

## 1) Big Files List (Top 15 nach Zeilen)
_Quelle: `wc -l` über `filmfreaks/**/*.swift`._

1. `filmfreaks/MovieStore.swift` — **863**
   - Zweck: zentrale State-Maschine für Movies+Backlog, lokales Speichern, Cloud Refresh, Merge/Apply.
   - Risiko: „God Store“ → schwer testbar, hohe Compile-Zeit, viele Responsibilities.
2. `filmfreaks/CloudKitMovieStore.swift` — **719**
   - Zweck: CloudKit Fetch/Modify/Migration für Movies (public + zones).
   - Risiko: viel CloudKit-Detailcode, schwer zu ändern ohne Edge Cases zu brechen.
3. `filmfreaks/MovieNights/MovieNightStore.swift` — **647**
   - Zweck: Movie night Domain + UI-helpers + local snapshot + cloud sync + activity.
   - Risiko: hohe Kopplung (Domain+Persistence+Sync) + viele States.
4. `filmfreaks/DisplaySettings.swift` — **598**
   - Zweck: globales Appearance/Layout/Feature-Toggles.
   - Risiko: „Settings-Sammelbecken“; viele `@AppStorage`/Computed → View invalidations.
5. `filmfreaks/TMDbAPI.swift` — **591**
   - Zweck: Netzwerk-Layer zu TMDb inkl. Endpoints, models, decoding.
   - Risiko: ein File für alles (Requests + Models + Helpers) → unübersichtlich.
6. `filmfreaks/CloudKitMovieNightStore.swift` — **580**
   - Zweck: CloudKit Sync für Movie nights.
   - Risiko: CloudKit Operation Code + Change Tokens + conflict handling.
7. `filmfreaks/Goals/CustomGoalEditorView.swift` — **545**
   - Zweck: UI+Form-Logik für Custom Goals.
   - Risiko: SwiftUI compile-time + schwer zu testen.
8. `filmfreaks/SearchResultDetail/SearchResultDetailView.swift` — **522**
   - Zweck: Detail-Sheet für TMDb Suchergebnis (Metadaten, Cast/Directors, Add-to-List).
   - Risiko: sehr viel UI+Loading in einem View.
9. `filmfreaks/CloudKitRatingStore.swift` — **508**
   - Zweck: Ratings in CloudKit (stable recordName, fetch changes, modify).
   - Risiko: stabile IDs + Migration/Parsing → potenziell daten-kritisch.
10. `filmfreaks/CloudKitGroupStore.swift` — **463**
    - Zweck: Gruppen erstellen/listen/teilen/leave/delete + share hierarchy repair + subscriptions.
    - Risiko: Sharing Edge Cases + Nebenläufigkeit + „Repair“-Tasks.
11. `filmfreaks/Stats/StatsView+Calculations.swift` — **429**
    - Zweck: Aggregationen/Statistiken.
    - Risiko: potenziell teuer im Renderpfad (viele Iterationen/Sorts).
12. `filmfreaks/MovieSearch/MovieSearchView.swift` — **420**
    - Zweck: Search UI + Networking + Pagination.
    - Risiko: View besitzt zu viele Verantwortungen.
13. `filmfreaks/UserStore.swift` — **389**
    - Zweck: Users/Members State + persistence + cloud sync.
    - Risiko: ähnliches Muster wie MovieStore (kleiner).
14. `filmfreaks/ViewingCustomGoal.swift` — **369**
    - Zweck: Modell + Codable Migration + Rule Encoding.
    - Risiko: relativ ok; „riskant“ nur wegen Größe/Komplexität der Codable.
15. `filmfreaks/Movie.swift` — **366**
    - Zweck: Movie + embedded Rating Modell + viele Helpers.
    - Risiko: Modell enthält Logik, die UI/Sort/Display beeinflusst.

---

## 2) Hot Path Analyse

### 2.1 Rendering / Scrolling

#### Hotspot A — List/Grid: Filter + Sort pro Render
- **Datei:** `filmfreaks/Content/ContentView+MovieItems.swift`
- **Was passiert:**
  - Bei jedem Render werden aus `movieStore.movies`/`backlogMovies` neue Arrays gebaut:
    - `Array(enumerated())` → `filter` → `sorted` → `map` zu `IndexedMovie`.
  - Zusätzlich werden pro Vergleich im Sort teils Scores berechnet (`displayScore(for:)`).
- **Warum Hot Path:**
  - O(n log n) pro Render + zusätzlicher String/Score-Compute.
  - Render-Invaldiation kann durch viele Quellen passieren (SearchText, Filter, Settings, Network-Badge, PendingChanges, etc.).
- **Risiko-Symptom:** „Scroll stutter“ bei größeren Listen, spürbar beim Tippen im Searchfeld.

#### Hotspot B — In-List Search: String Normalisierung pro Movie
- **Datei:** `filmfreaks/Content/ContentView+Filtering.swift`
- **Was passiert:**
  - `passesListSearch` baut pro Movie `fields` Array, joint + normalized, dann `contains` für Tokens.
- **Warum Hot Path:**
  - String folding/lowercasing/joining ist teuer und läuft im Filter-Loop.
  - Besonders schlimm beim Tippen (jede Textänderung invalidiert View).

#### Hotspot C — Activity Feed wird „on demand“ komplett neu gebaut
- **Datei:** `filmfreaks/MovieStore+Activity.swift`
- **Was passiert:**
  - `activityEvents(...)` iteriert über `movies + backlogMovies`, erzeugt Events + sortiert.
  - Wird u.a. in `filmfreaks/Content/ContentView.swift` (Header Preview) und `filmfreaks/Content/GroupActivityListView.swift` genutzt.
- **Warum Hot Path:**
  - Allokiert viele Event-Objekte + `sort` bei jeder Abfrage.

#### Hotspot D — Stats: viele Aggregationen als Computed Properties
- **Datei:** `filmfreaks/Stats/StatsView+Calculations.swift`
- **Was passiert:**
  - Viele `var`-Aggregationen laufen auf gefilterten Movie-Listen.
  - Je nach UI werden mehrere dieser Computeds in einem Render gebraucht → mehrfaches Iterieren.
- **Warum Hot Path:**
  - SwiftUI fragt Computeds potentiell mehrfach ab (body/Subviews), besonders bei Conditional UI.

#### Hotspot E — Bilder in Listen/Grid: viele `.task`-Starts beim Scroll
- **Datei:** `filmfreaks/CachedAsyncImage.swift`
- **Was passiert:**
  - Pro Zelle startet `.task(id: url)` und lädt/cacht.
- **Warum Hot Path:**
  - Viele kurzlebige Tasks beim schnellen Scroll.
  - Wird durch `URLCache.shared` (gesetzt in `filmfreaksApp.swift`) und `ImageCacheStore` abgefedert, aber Task-Churn bleibt.

---

### 2.2 Sync / Storage

#### Hotspot F — Disk writes gekoppelt an Store-Mutationen
- **Datei:** `filmfreaks/MovieStore.swift`
- **Was passiert:**
  - `movies`/`backlogMovies` haben `didSet` und rufen `persist()` (debounced) + Cloud Queue.
  - Zusätzlich gibt es `oldValue == movies` Checks (Array-Equality) als „No-Op Guard“.
- **Warum Hot Path:**
  - Array-Equality ist O(n) und läuft auf `@MainActor` (Store ist `@MainActor`).
  - Viele kleine Änderungen (Rating ändern, Location tippen, reorder etc.) triggern Writes.

#### Hotspot G — App lifecycle: Refresh-Kaskade beim Aktivwerden
- **Datei:** `filmfreaks/filmfreaksApp.swift` (`.onChange(of: scenePhase)`)
- **Was passiert:**
  - Bei `active`: `groupStore.refresh()` + `movieStore.refreshFromCloud()` + `userStore.refreshFromCloud()` + `movieNightStore.refreshFromCloud(...)`.
- **Warum Hot Path:**
  - Ohne globale Throttles kann das bei häufigem Background/Foreground (oder beim Wechsel zwischen Apps) spürbar netz-/CPU-lastig sein.

#### Hotspot H — Gruppenliste/Sharing: Repair Tasks + Subscription Tasks
- **Datei:** `filmfreaks/CloudKitGroupStore.swift`
- **Konkrete Gründe:**
  - `refresh()` startet mehrere `Task { ... }`:
    - `ensureSubscriptions(...)` wird **doppelt** gestartet (identischer Block zweimal).
    - Pro Owned group: `Task { await repairShareHierarchyIfNeeded(for:) }`.
- **Risiko:**
  - Unbounded concurrency bei vielen Gruppen.
  - Sharing-Hierarchy Repair ist daten-kritisch (Parent-Refs beeinflussen Sichtbarkeit in Shares).

#### Hotspot I — CloudKit Query Helper ist dupliziert
- **Dateien:** mehrere `CloudKit*Store.swift` (z.B. `CloudKitMovieStore.swift`, `CloudKitRatingStore.swift`, `CloudKitMovieNightStore.swift`)
- **Warum relevant:**
  - Gleiche Pagination/Query/Operation Patterns mehrfach implementiert → Bugfix muss an mehreren Stellen passieren.

---

### 2.3 Concurrency / MainActor contention

#### Hotspot J — Stores sind `@MainActor` und machen „viel“
- **Dateien:** `filmfreaks/MovieStore.swift`, `filmfreaks/UserStore.swift`, `filmfreaks/MovieNights/MovieNightStore.swift`, `filmfreaks/CloudKitGroupStore.swift`
- **Konkrete Gründe:**
  - Viele Methoden laufen vollständig auf MainActor (inkl. Sorting/Merging/Encoding/Map).
  - Mehrere `Task`-Starts in Views/Lifecycle ohne zentralen Cancellation-Owner.

#### Good Practice (bereits vorhanden)
- `MovieCloudSyncCoordinator` (`filmfreaks/MovieCloudSyncCoordinator.swift`) cancelt scheduled flushes.
- `MovieStore.loadFromCloud` prüft `requestedGroupId` gegen aktuellen State (Race-Guard).

---

## 3) Refactor Map

### 3.1 Konkrete Splits (Datei → neue Dateien)

#### Split 1 — `MovieStore.swift` (863 Zeilen) entknoten
**Ziel:** Responsibilities trennen (State, Persistence, Cloud, Merge, Activity) und Compile-Time senken.

- **Ist:** `filmfreaks/MovieStore.swift` (State + Persistence + Cloud Refresh + Migration + Merge + error UI state).
- **Vorschlag Cut (low risk, „Split-only“ zuerst):**
  - `filmfreaks/MovieStore.swift` → nur: Public API + Published state + init + High-level orchestration.
  - NEU:
    - `filmfreaks/MovieStore+Persistence.swift` — calls zu `PersistenceManager` + group-scoped load/save.
    - `filmfreaks/MovieStore+CloudRefresh.swift` — `refreshFromCloud`, `loadFromCloud`, throttling.
    - `filmfreaks/MovieStore+Merge.swift` — Apply Cloud changes, merge Ratings, backlog/watched transitions.
    - `filmfreaks/MovieStore+Network.swift` — Network gating, pending changes meta.

**Risiko:** niedrig (bei Split-only) bis mittel (wenn Logik umgebaut wird).

#### Split 2 — `CloudKitMovieStore.swift` in „Transport“ + „Codec“ + „Queries“
- **Ist:** ein File enthält routing, schema, decode/encode, migrations, query pagination.
- **Vorschlag:**
  - `filmfreaks/CloudKit/CloudKitRouting.swift` — `routedDatabase(forGroupId:)` Pattern (für alle Stores).
  - `filmfreaks/CloudKit/CloudKitQueryPaging.swift` — `queryAllRecords` + generic pagination.
  - `filmfreaks/CloudKit/CloudKitMovieCodec.swift` — encode/decode Movie-Record (payload keys, fallback).

**Nutzen:** weniger Copy/Paste, bessere Testbarkeit (Codec separat), weniger Risiko bei Schema-Änderungen.

#### Split 3 — Stats: `StatsView+Calculations.swift` → Calculator Service
- **Ist:** Aggregationen als Computed Properties in View-Extension.
- **Vorschlag:**
  - `filmfreaks/Stats/StatsCalculator.swift` (Actor oder struct) mit Input: `[Movie]` + DisplaySettings + Filter.
  - In `StatsView`: einmal rechnen (z.B. `.task(id: filterKey)` oder `@State var snapshot`).

**Risiko:** niedrig (wenn API klein gehalten wird) und bringt oft sofort messbare UI-Glättung.

#### Split 4 — SearchResultDetailView (522) und MovieSearchView (420)
- **Vorschlag:**
  - `SearchResultDetailView+Sections.swift` (Overview/Cast/Crew/Keywords)
  - `SearchResultDetailView+Actions.swift` (Add to watched/backlog)
  - `MovieSearchView+Networking.swift` (Search/pagination) + `MovieSearchView+UI.swift`.

---

### 3.2 Cache-/Index-Ideen

#### Cache 1 — Search Index pro Movie
- **Motivation:** `passesListSearch` baut Strings pro Movie pro Render.
- **Idee:**
  - `MovieSearchIndexCache`: `[UUID: String]` (movieId → normalized haystack).
  - Invalidieren wenn Movie relevante Felder ändern (title/year/location/suggestedBy/cast/directors/genres/keywords).

#### Cache 2 — Sorted/Filtered Movie Items Snapshot
- **Motivation:** `ContentView+MovieItems` sortiert/filtered im Renderpfad.
- **Idee:**
  - `ContentMovieItemsModel` als Observable/State:
    - Inputs: `movies`, `backlogMovies`, `selectedSort`, `filterByUser`, `watchedSearchText`, `backlogSearchText`, `displaySettings.ratingDisplayMode`, `displaySettings.showTMDbRatingsInLists`
    - Output: `watchedItems`, `backlogItems`.
  - Recompute nur bei Input-Änderung (nicht bei jedem render).

#### Cache 3 — Activity Feed Snapshot
- **Motivation:** `MovieStore.activityEvents(...)` erzeugt Events immer neu.
- **Idee:**
  - Store hält `@Published private(set) var activitySnapshot: [GroupActivityEvent]`.
  - Update inkrementell bei Movie add / Rating updated.

#### Cache 4 — CloudKit Change Tokens + Backpressure
- Tokens existieren schon (`CloudKitZoneChangeTokenStore`).
- Ergänzen:
  - per-store `minRefreshInterval` (MovieStore/UserStore haben das schon; GroupStore nicht konsequent).
  - „Backpressure“: keine parallel laufenden Refreshes pro Store (Mutex/flag).

---

### 3.3 Vereinheitlichungen (Patterns, Services, DI)

#### Vereinheitlichung A — CloudKit Routing & Query Code
- Zentralisiere:
  - Routing public vs private/shared+zone.
  - Pagination/`queryAllRecords`.
  - `modifyRecords` wrapper inkl. retryable CKError handling.
- Effekt:
  - weniger divergente Implementierungen zwischen Movie/Rating/User/Goal/Night.

#### Vereinheitlichung B — Local persistence base dir + encoding strategy
- Aktuell:
  - Movies/Users: Application Support `FilmFreaks/` + `JSONEncoder.dateEncodingStrategy = .deferredToDate`.
  - Movie nights: Application Support `filmfreaks/` + ISO8601.
- Entscheidung treffen:
  - **entweder** ISO8601 überall (human-readable) **oder** deferredToDate überall (stabil, compact).
  - BaseDir vereinheitlichen (Case-Sensitivity vermeiden).

#### Vereinheitlichung C — „Session“/Context Objekt statt verstreuter UserDefaults Keys
- `GroupContextStore`, `CurrentUserIdentityStore`, SelectedGroupId/Name Keys verteilen sich.
- Vorschlag:
  - `GroupSession` (ObservableObject) als Source of Truth: `currentGroupId/name`, `selectedUser`.
  - Stores nehmen `GroupSession` injected (Testbarkeit, weniger Key-Drift).

---

## 4) Risiken & Edge Cases

### Daten-/Sync-Risiken
- **Sharing Parent Hierarchy**
  - Wenn Records (Movies/Ratings/Goals/Users/Nights) keinen `parent` auf die Group-Root haben, sind sie in Shares unsichtbar.
  - `CloudKitGroupStore.repairShareHierarchyIfNeeded` versucht das zu reparieren — daten-kritisch.
- **Legacy/public Gruppen**
  - `CloudKitMovieStore.fetchMovies` nutzt für no-group ein OR-Predicate (`groupId == NULL OR ''`) und filtert zusätzlich in-memory.
  - Risiko: Query kann viele Records ziehen (Public DB wächst).
- **Konflikte / Merge**
  - Movies/Ratings werden lokal + Cloud kombiniert. Strategie ist teilweise im Code ersichtlich (z.B. `updatedAt`), aber es gibt keine zentrale „Conflict Policy“.
  - **UNKNOWN:** definitive Konfliktregel je Modell (server wins? last-write-wins? field-level merge?).

### Offline / Multi-device
- Offline: lokale Speicherung ist stabil.
- Multi-device: CloudKit eventual consistency + Race-Guards existieren (`requestedGroupId` Checks).
- Edge Case: Group switch während laufender Cloud fetches → teilweise abgefangen (MovieStore), aber nicht überall verifiziert (**UNKNOWN** für UserStore/MovieNightStore).

### Push / Background
- `Info.plist` hat `remote-notification` background mode.
- CloudKit subscriptions existieren (`CloudKitActivitySubscriptionManager`), plus lokale Notification Pipeline in `filmfreaks/Notifications/*`.
- **UNKNOWN:** ob push pipeline im Release vollständig aktiviert ist (abhängig von iCloud entitlements + subscription creation + APS environment).

---

## 5) Observability / Debuggability

### Logging (ist da)
- `filmfreaks/PersistenceManager.swift` nutzt `os.Logger` (subsystem `filmfreaks`, category `Persistence`).
- Viele CloudKit Stores loggen via `print(...)` (Debug-only teils). Beispiele:
  - `filmfreaks/CloudKitGroupStore.swift`
  - `filmfreaks/Notifications/GroupActivityLocalNotifier.swift`

### Empfohlen (kleiner Aufwand, großer Nutzen)
- Einheitlicher `Logger` pro Domäne:
  - `Logger(subsystem: "filmfreaks", category: "CloudKit.Movies")` etc.
- Optional: `os_signpost` für:
  - Cloud fetch duration (Movies/Ratings/Groups)
  - Apply/Merge duration
  - Content list item build duration (bei großen Listen)

### „Wie reproduziere ich Sync-Probleme?“ (praktisch)
- iCloud Logout/Restricted simulieren: `CloudKitGroupStore.refresh()` zeigt Toast.
- Share Flow testen:
  - Owned group erstellen → Share Sheet öffnen → Einladung an zweites Device → Accept → `cloudKitShareAccepted` Notification.
- Multi-device Race testen:
  - Device A: Movie hinzufügen
  - Device B: sofort im Hintergrund/Foreground → prüfen ob `scenePhase.active` Refresh reicht.

---

## 6) Open Questions (UNKNOWNs gesammelt)

1. **Konfliktauflösung (per Model) — formale Policy:**
   - Movies: last-write-wins via `updatedAt`? field-level merge? (**UNKNOWN**)
   - Ratings: pro-user record reduziert Konflikte, aber Merge von `reviewerName` vs `reviewerId`? (**UNKNOWN**)
2. **CloudKit Schema/Indexes im Dashboard:**
   - Welche Felder sind query-indexed (z.B. `groupId`, `updatedAt`)? (**UNKNOWN**)
3. **Public DB Wachstum / Cleanup:**
   - Gibt es TTL/cleanup für Legacy public records? (**UNKNOWN**)
4. **Push Pipeline in Production:**
   - Welche SubscriptionIDs werden erstellt? Werden remote notifications im Release zuverlässig zugestellt? (**UNKNOWN**)
5. **Group switch race coverage:**
   - MovieStore ist guarded; UserStore/MovieNightStore: gibt es ähnliche guards? (**UNKNOWN**)
6. **Secrets Hygiene / CI:**
   - Wird `Secrets.xcconfig` in CI/Release builds korrekt injected ohne im Repo zu landen? (**UNKNOWN**)

---

## 7) First 3 Refactors I would do (P0)

### P0.1 — Content List/Grid aus dem Renderpfad holen
- **Ziel:** Scroll & Search smooth machen, CPU reduzieren.
- **Betroffene Dateien:**
  - `filmfreaks/Content/ContentView+MovieItems.swift`
  - `filmfreaks/Content/ContentView+Filtering.swift`
  - (optional) `filmfreaks/Content/ContentView.swift`
- **Risiko:** niedrig–mittel (UI-Behavior muss exakt gleich bleiben).
- **Erwarteter Nutzen:**
  - weniger Recomputes, weniger String-Arbeit, bessere Responsiveness bei großen Listen.

### P0.2 — CloudKit helper deduplizieren + GroupStore doppelte Subscriptions fixen
- **Ziel:** Wartbarkeit, weniger Sync-Bugs, weniger unnötige CloudKit Calls.
- **Betroffene Dateien:**
  - `filmfreaks/CloudKitGroupStore.swift` (doppeltes `ensureSubscriptions` entfernen)
  - `filmfreaks/CloudKitMovieStore.swift`
  - `filmfreaks/CloudKitRatingStore.swift`
  - `filmfreaks/CloudKitMovieNightStore.swift`
  - (optional) `filmfreaks/CloudKitGoalStore.swift`, `filmfreaks/CloudKitUserStore.swift`
- **Risiko:** niedrig (bei reinem Helper-Extract) bis mittel (wenn Signaturen sich ändern).
- **Erwarteter Nutzen:**
  - weniger Copy/Paste, zentraler Bugfix-Ort, geringere Battery/Network Peaks.

### P0.3 — StatsCalculator Snapshot (einmal rechnen, mehrfach anzeigen)
- **Ziel:** Stats-Tab flüssig, weniger wiederholte Iterationen.
- **Betroffene Dateien:**
  - `filmfreaks/Stats/StatsView+Calculations.swift`
  - `filmfreaks/Stats/StatsView.swift`
  - NEU: `filmfreaks/Stats/StatsCalculator.swift`
- **Risiko:** niedrig.
- **Erwarteter Nutzen:**
  - deutlich weniger CPU bei Stats, klarere Trennung (UI vs Compute), besser testbar.

