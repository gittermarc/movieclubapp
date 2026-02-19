# ARCHITECTURE_NOTES

## Big Files List (Top 15 nach Zeilen)
Die folgenden Dateien sind aktuell die größten Swift-Dateien im Repo (line count basiert auf einfachem Zeilenzählen im ZIP-Stand):

| Rank | File | Lines | Zweck (kurz) | Warum riskant |
|---:|---|---:|---|---|
| 1 | `filmfreaks/MovieStore.swift` | 916 | Zentraler Domain-Store: Movies/Backlog, Disk-Persistenz, Group-Switching, Cloud-Sync-Orchestrierung, Activity-Feed-Helfer. | Sehr viele Verantwortungen in einer Klasse; hohe Compile-Zeit; viele MainActor-Pfade + O(n)-Diffs in didSet → UI-Stalls möglich. |
| 2 | `filmfreaks/CloudKitMovieStore.swift` | 728 | CloudKit CRUD + Zone-Changes + Batch writes für RecordType `Movie` inkl. Routing/Parenting/Conflict Handling. | Enthält JSON encoding + große Operationen; wird aktuell aus `@MainActor`-Kontexten aufgerufen → Hitches möglich; komplexe Fehlerpfade/Partial failures. |
| 3 | `filmfreaks/MovieNights/MovieNightStore.swift` | 695 | Store für MovieNight Events/Responses/Activity; lokale Persistenz + pending cloud change queue + UI-Helpers. | Viele Zustände/Queues; edge cases bei group routing; möglicher Datenverlust bei Merge/Deletes, schwer testbar. |
| 4 | `filmfreaks/CloudKitMovieNightStore.swift` | 606 | CloudKit Read (Phase 3) + schema/keys + zone changes für MovieNight* RecordTypes. | Routing muss strikt sein (UUID groupId); token handling; komplexe Mapping-/Merge-Pfade. |
| 5 | `filmfreaks/DisplaySettings.swift` | 599 | Globale Appearance/Display Konfiguration (ColorScheme, Tint, Fonts, Layout toggles) + Persistenz. | Großes Settings-Objekt → häufige View invalidations; unklare Verantwortlichkeiten/Defaults; Risiko bei Erweiterungen. |
| 6 | `filmfreaks/TMDbAPI.swift` | 592 | HTTP Client für TMDb (search/details/credits/providers/keywords/etc), Key loading, request building, error mapping. | Viele Endpoints in einer Datei; keine zentrale cancellation/throttling; Fehlerhandling/Rate limits schwer nachzuvollziehen. |
| 7 | `filmfreaks/Goals/CustomGoalEditorView.swift` | 546 | UI für Custom Goals (Filter/Matching/Preview), viel UI-State/Validation. | SwiftUI mega-file → lange Compile-Zeit; viele @State; Risk für exzessive invalidations. |
| 8 | `filmfreaks/SearchResultDetail/SearchResultDetailView.swift` | 523 | UI für TMDb Detail + Add-to-watched/backlog + load details/cast/providers in einem Flow. | Netzwerk + UI + Mapping in einer View; Task-Lifetimes/Cancellation; Renderpfad kann groß werden. |
| 9 | `filmfreaks/CloudKitRatingStore.swift` | 503 | CloudKit Sync für Ratings (RecordType `MovieRating`) inkl. zone-changes und save/delete. | Partial failure & conflicts; Routing; häufige Writes möglich → Performance sensibel. |
| 10 | `filmfreaks/CloudKitGroupStore.swift` | 464 | Owned/shared Gruppen laden, Gruppen erstellen, Share-Hierarchy Repair, Subscription Setup. | @MainActor + viele CloudKit ops; `refresh()` startet mehrere Tasks; doppelte ensureSubscriptions → unnötige Arbeit. |
| 11 | `filmfreaks/Stats/StatsView+Calculations.swift` | 444 | Aggregationen/Derivations für Stats UI (Totals, per-year, top genres, etc.). | Viele O(n) Berechnungen als computed vars in View-Extension → wiederholt bei jedem body-Refresh. |
| 12 | `filmfreaks/MovieSearch/MovieSearchView.swift` | 442 | Suche/Scanner/Recommendations/Pagination/Sort/DetailSheet in einem Screen. | Viele State-Variablen; parallele Tasks; fehlende Cancellation kann Netz/CPU belasten; compile time. |
| 13 | `filmfreaks/MovieNights/Sheets/MovieNightDetailSheet.swift` | 417 | Detail-Sheet für einen Filmabend (Status, Responses, Actions). | Große UI-Datei; viel conditional UI; schwer zu testen; potentiell viele invalidations. |
| 14 | `filmfreaks/Content/ContentView.swift` | 413 | Root Screen: Header + Listen + Activity Preview + Actions; bindet MovieStore/UserStore/GroupStore. | Hot: derived lists + computed activity preview; viele onChange handlers; Gefahr für exzessive invalidation. |
| 15 | `filmfreaks/UserStore.swift` | 413 | Members store: lokale Persistenz + Cloud refresh + selection + helpers. | Kern-Sync Pfad; concurrency/merge logic kann Daten überschreiben; viel MainActor state. |

## Hot Path Analyse

### Rendering / Scrolling (SwiftUI invalidations, expensive computations im Renderpfad)
**Hotspots (konkrete Gründe + Pfade):**
- `filmfreaks/Stats/StatsView+Calculations.swift`
  - **Grund:** Sehr viele Aggregationen über `movies`/`backlog` als computed properties (z.B. `reduce`, `filter`, `sorted`) – werden typischerweise mehrfach pro `body`-Pass ausgewertet, sobald irgendein `@State/@ObservedObject` in `StatsView` invalidiert.
  - **Symptom:** Stats-Screen wird bei großen Libraries „sticky“/ruckelig; CPU spikes beim Scrollen oder beim Wechsel von Filtern.
- `filmfreaks/Content/ContentView.swift`
  - **Grund:** `activityPreviewItems` baut eine Liste aus `movieStore.activityEvents(...)` (siehe `filmfreaks/MovieStore+Activity.swift`) und schneidet sie zu. `activityEvents` sortiert/aggregiert abgeleitet aus den Movies/Ratings.
  - **Risiko:** Jeder `MovieStore`-Change invalidiert `ContentView` → Preview recompute → O(n log n) Sort.
- `filmfreaks/MovieStore.swift`
  - **Grund:** `movies`/`backlogMovies` sind `@Published` Arrays; ihre `didSet`-Blöcke vergleichen `oldValue == movies` (O(n) deep equality) und bauen in `enqueueCloudSync(...)` zusätzlich Dictionaries/Sets aus der gesamten Liste (O(n)) um Deltas zu bestimmen.
  - **Risiko:** Häufige Updates (z.B. Rating ändern, Titel editieren) skalieren schlecht und laufen auf dem MainActor.

**Konkrete Hebel (Rendering):**
- Stats: Aggregationen aus `StatsView+Calculations.swift` rausziehen und **einmalig** bei Input-Änderungen berechnen (ViewModel/Actor).  
- Activity: `MovieStore.activityEvents(...)` sollte entweder:
  - (A) gecached werden (invalidate bei movie/rating/movienight changes), oder
  - (B) ein inkrementelles Event-Indexing nutzen (nur delta updates).
- Root-List: Für große Listen UI diffing minimieren (IDs stabil, keine neu aufgebauten Arrays im `body`), besonders bei `ContentView`.

### Sync / Storage (CloudKit ops, fetch strategies, caching, triggers)
**Architektur (beobachtbar):**
- Local first: Disk JSON in `filmfreaks/PersistenceManager.swift` wird initial geladen; Cloud refresh danach (Trigger: `scenePhase == .active` in `filmfreaks/filmfreaksApp.swift`).
- Group scoping: `GroupContextStore` (UserDefaults) ist entscheidend für korrektes Routing in private/shared DB/Zone (`filmfreaks/GroupContext.swift`, `filmfreaks/CloudKitRouting.swift`).
- Incremental sync: Zone-changes + Token store (`filmfreaks/CloudKitZoneChanges.swift`, `filmfreaks/CloudKitZoneChangeTokenStore.swift`).

**Hotspots / Risiken (konkrete Gründe + Pfade):**
- `filmfreaks/CloudKitMovieStore.swift` (`modifyBatch`)
  - **Grund:** Baut CKRecords und encoded `Movie` als `Data` via `JSONEncoder().encode(...)` im Sync-Pfad.
  - **Faktisch:** Der Writer (`filmfreaks/MovieCloudSyncCoordinator.swift`) ist explizit `@MainActor` und konstruiert die Records vor dem `await` → Encoder-Arbeit passiert auf dem MainActor.
  - **Risiko:** UI Hitches bei vielen queued updates (oder bei großen Movie payloads).
- `filmfreaks/CloudKitGroupStore.swift` (`refresh`)
  - **Grund:** `refresh()` startet mehrere Tasks (inkl. **doppelt** aufgerufenem subscription ensure).
  - **Risiko:** Unnötige CloudKit Calls → Quota/Latency, plus mehr Nebenläufigkeit als nötig (Debuggability sinkt).
- `filmfreaks/CloudKitZoneChangeTokenStore.swift`
  - **Grund:** Bei Token-Problemen wird Token gelöscht („reset“) und dann full resync gemacht.
  - **Risiko:** Full resync kann bei großen Datenmengen lange dauern; ohne UI/UX ist schwer zu verstehen, warum Daten „springen“.

### Concurrency (MainActor, Task lifetimes, cancellation, thread safety)
**Beobachtete Muster:**
- Viele Stores sind `@MainActor` und führen sowohl State-Mutationen als auch Teile der CloudKit/Encoding-Pipeline aus (z.B. `filmfreaks/MovieStore.swift`, `filmfreaks/CloudKitGroupStore.swift`).
- ScenePhase Trigger startet Tasks ohne Cancellation (`filmfreaks/filmfreaksApp.swift`).
- UI Screens starten `Task { ... }` auf Tap/Appear (z.B. Suche/Detail), häufig ohne Cancellation/Throttling (`filmfreaks/MovieSearch/MovieSearchView.swift`, `filmfreaks/SearchResultDetail/SearchResultDetailView.swift`).

**Hotspots (konkrete Gründe + Pfade):**
- **MainActor contention**: Encoding + Delta-Building auf MainActor (`filmfreaks/MovieStore.swift` + `filmfreaks/CloudKitMovieStore.swift`)
- **Task lifetime leak (soft)**: Tasks laufen evtl. weiter, wenn Sheet dismissed wird (z.B. detail sheet). Nicht zwingend crashy, aber Network/CPU waste.

**Hebel:**
- Heavy work in `nonisolated` helper/actor verschieben (Encoding, diff building, sorting).
- Task cancellation tokens speichern (z.B. `@State private var refreshTask: Task<Void, Never>?`).
- Concurrency caps für batch network work (max parallel requests) in TMDb flows.

## Refactor Map

### Konkrete Splits (Datei → neue Dateien)
> Ziel: kleinere Compile Units, klarere Verantwortlichkeiten, weniger MainActor „Hot Loops“.

**1) `filmfreaks/MovieStore.swift` (916 Zeilen)**
- Split-Vorschlag:
  - `filmfreaks/MovieStore.swift` → nur Public API + init + published state
  - `filmfreaks/MovieStore+Persistence.swift` → Disk load/save + migration hooks (`PersistenceManager`)
  - `filmfreaks/MovieStore+CloudSync.swift` → enqueue/flush, coordinator wiring (`MovieCloudSyncCoordinator`)
  - `filmfreaks/MovieStore+Mutations.swift` → alle „write“ APIs (add/remove/move between watched/backlog, update fields)
  - `filmfreaks/MovieStore+Selections.swift` → selected user / selected group / derived UI helpers
  - `filmfreaks/MovieStore+Activity.swift` existiert bereits (beibehalten; evtl. Cache ergänzen)

**2) `filmfreaks/CloudKitMovieStore.swift` (728 Zeilen)**
- Split-Vorschlag:
  - `CloudKitMovieStore+Schema.swift` (Record types/keys)
  - `CloudKitMovieStore+Routing.swift`
  - `CloudKitMovieStore+Modify.swift` (modifyBatch / delete / record construction)
  - `CloudKitMovieStore+ZoneChanges.swift` (incremental fetch)
  - `CloudKitMovieStore+Merge.swift` (apply changes to local models)

**3) `filmfreaks/Stats/StatsView+Calculations.swift` (444 Zeilen)**
- Split/Verschiebung:
  - `StatsEngine` (pure functions, testbar)
  - `StatsViewModel` (caching + invalidation)
  - `StatsView` konsumiert nur „fertige“ Values.

**4) `filmfreaks/MovieSearch/MovieSearchView.swift` (442 Zeilen)**
- Split:
  - `MovieSearchViewModel` (query, pagination, loadRecommendations, scanner pipeline)
  - UI in Subviews: `MovieSearchHeader`, `MovieSearchResults`, `MovieSearchRecommendationsSection` (einige existieren bereits als *View Dateien – Ziel: weiter konsequentieren)

### Cache-/Index-Ideen (was cachen, Keys, Invalidations)
- **Movie Index**
  - Cache: `Dictionary<UUID, Movie>` bzw. `Dictionary<String, Movie>` (Key = `MovieSearchMapper.key(for:)`).
  - Nutzen: O(1) Lookup statt `first(where:)` in UI/Actions.
  - Invalidation: bei jeder Mutation eines Movies (ID bleibt stabil).
- **Activity Index**
  - Cache: `[GroupActivityEvent]` pro `(groupId, displayMode)` in `MovieStore`.
  - Invalidation Trigger: Movie added/removed, rating upsert, movie night activity changes.
- **Stats Cache**
  - Cache: Aggregates (counts per year/genre/director) in `StatsViewModel`.
  - Invalidation: movies/backlog arrays changed, selectedUser changed, filters changed.
- **CloudKit Token Reset + Sync State**
  - Persist: lastSuccessfulSyncAt pro groupId (UserDefaults) und in UI sichtbar machen.
  - Invalidation: nach erfolgreichem refresh.

### Vereinheitlichungen (Patterns, Services, DI)
- **Logging**: konsequent `os.Logger` statt `print` (z.B. `CloudKitGroupStore.refresh`).
- **Group scoping**: ein gemeinsames `GroupScopedStore`-Protokoll:
  - `setActiveGroup(groupId:)`
  - `refreshFromCloud()`
  - `clearLocalCacheForGroup()`
- **Dependency Injection**: `filmfreaksApp` erstellt Stores; mittelfristig `AppEnvironment` struct (injizierbar in Previews/Tests).

## Risiken & Edge Cases
- **Datenverlust durch Merge-Reihenfolge**: Wenn lokal + Cloud parallel geändert, muss klar sein, wer gewinnt (Movie payload vs Rating records vs Goals). Merge-Priorität ist über mehrere Dateien verteilt (`MovieStore`, `CloudKitMovieStore`, `CloudKitRatingStore`) → Risiko „last writer wins“ unbeabsichtigt.
- **Share/Parenting Bugs**: `repairShareHierarchyIfNeeded` in `filmfreaks/CloudKitGroupStore.swift` verändert Parent-Beziehungen. Fehler kann Teilnehmer-Sichtbarkeit brechen.
- **Offline + queued writes**: Bei offline Änderung viele deltas → beim reconnect großer Flush (MainActor load) möglich.
- **UUID groupId ohne GroupContext**: Code schützt an mehreren Stellen (z.B. `CloudKitMovieNightStore.requiresGroupContext`). Trotzdem muss sichergestellt sein, dass `GroupContextStore` zuverlässig upserted wird (passiert in `CloudKitGroupStore.refresh`).

## Observability/Debuggability
- **Logging Kategorien** (Vorschlag):
  - `CloudKit.Groups`, `CloudKit.Movies`, `CloudKit.Ratings`, `CloudKit.Goals`, `CloudKit.MovieNights`, `Persistence`, `UI.Navigation`
- **Sync Debug Panel** (Settings):
  - pro Gruppe: last refresh, pending upload counts, token present?, last error.
  - Aktionen: „Reset zone token“, „Clear local cache“, „Force refresh“.
  - Dateien: UI ist in `filmfreaks/SettingsView.swift` (Erweiterungspunkt).
- **Repro Leitfaden (minimal)**
  - Sync Issues: zwei Geräte, gleiche Gruppe; offline auf Gerät A → Änderungen; online → prüfen ob B nach push/active refresh aktualisiert.
  - Share Issues: Invite-Link über `UIActivityViewController` (siehe `CloudKitShareCoordinator`) → accept → check `CloudKitGroupStore.refresh`.

## Open Questions
- **CloudKit Schema & Security**: Record type indices, parent/CKShare configuration, server-side validation (**UNKNOWN**)
- **Test Coverage**: Existieren Unit/UI Tests? Targets sind im `project.pbxproj` vorhanden, aber Quellen fehlen im ZIP (**UNKNOWN**).
- **Performance Baseline**: Gibt es Messwerte (FPS, sync durations, list sizes)? (**UNKNOWN** – keine Metrics im Repo sichtbar)

## First 3 Refactors I would do (P0)

### P0.1 — MainActor entlasten: CloudKit Movie payload encoding + MovieStore diffing
- **Ziel**
  - UI-Hitches vermeiden, wenn viele Movies/Ratings geändert werden (Encoding + O(n) diffs nicht auf MainActor).
- **Betroffene Dateien**
  - `filmfreaks/MovieStore.swift` (didSet + `enqueueCloudSync`)
  - `filmfreaks/MovieCloudSyncCoordinator.swift` (Flush scheduling)
  - `filmfreaks/CloudKitMovieStore.swift` (`modifyBatch` JSON encoding)
- **Risiko**
  - Mittel: Änderungen betreffen Sync-Pipeline. Fehler können zu „Sync stuck“ oder doppelten Uploads führen.
- **Erwarteter Nutzen**
  - Spürbar weniger UI Stalls bei großen Libraries; bessere Battery/CPU; saubere Trennung „State vs Work“.

### P0.2 — Stats entkoppeln: StatsEngine + Caching statt computed Aggregates im View
- **Ziel**
  - Stats Screen reaktiv, aber berechenbar: O(n) Work nur bei Input-Änderung, nicht bei jedem Render.
- **Betroffene Dateien**
  - `filmfreaks/Stats/StatsView.swift`
  - `filmfreaks/Stats/StatsView+Calculations.swift`
  - (neu) `filmfreaks/Stats/StatsEngine.swift`, `filmfreaks/Stats/StatsViewModel.swift`
- **Risiko**
  - Niedrig–Mittel: hauptsächlich Refactor, solange Outputs identisch bleiben.
- **Erwarteter Nutzen**
  - Deutlich weniger CPU beim Scrollen; bessere Responsiveness; bessere Testbarkeit der Berechnungen.

### P0.3 — CloudKitGroupStore refresh stabilisieren (Subscription-Dedupe + Task-Struktur)
- **Ziel**
  - Weniger unnötige CloudKit Calls, klarer Refresh-Ablauf, besser debugbar.
- **Betroffene Dateien**
  - `filmfreaks/CloudKitGroupStore.swift` (doppelte subscription ensure, Task-Struktur)
  - `filmfreaks/CloudKit/CloudKitActivitySubscriptionManager.swift` (falls needed für idempotency)
- **Risiko**
  - Niedrig: hauptsächlich Cleanup/Struktur.
- **Erwarteter Nutzen**
  - Weniger Quota/Latency; deterministischer Refresh; weniger „mystery“ background work.
