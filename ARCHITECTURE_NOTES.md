# ARCHITECTURE_NOTES.md

## Scope / Method
- Basis: statischer Scan des hochgeladenen Projekts (Quellcode + Xcode-Projektdateien).
- **Keine Vermutungen als Fakten**: Alles, was ich aus dem Code nicht sicher ableiten kann, ist **UNKNOWN** und steht in „Open Questions“.

---

## Big Files List (Top 15 nach Zeilen)
1. `filmfreaks/MovieSearch/MovieSearchView.swift` — **434** Zeilen — struct MovieSearchView
2. `filmfreaks/Content/ContentView.swift` — **424** Zeilen — struct ContentView
3. `filmfreaks/MovieNights/MovieNightStore.swift` — **398** Zeilen — class MovieNightStore
4. `filmfreaks/MovieStore/MovieStore+CloudSync.swift` — **396** Zeilen — extension MovieStore, extension MovieStore
5. `filmfreaks/UserStore.swift` — **389** Zeilen — class UserStore
6. `filmfreaks/ViewingCustomGoal.swift` — **369** Zeilen — enum ViewingCustomGoalType, enum ViewingCustomGoalRule, extension ViewingCustomGoalRule, struct ViewingCustomGoal, extension ViewingCustomGoal
7. `filmfreaks/Movie.swift` — **366** Zeilen — enum RatingCriterion, struct Rating, struct CastMember, struct Movie, enum CodingKeys, extension Movie
8. `filmfreaks/SettingsView.swift` — **363** Zeilen — struct SettingsView
9. `filmfreaks/GroupSettingsView.swift` — **360** Zeilen — struct GroupSettingsView
10. `filmfreaks/Stats/StatsView+Cards.Leaderboards.swift` — **355** Zeilen — extension StatsView
11. `filmfreaks/Stats/StatsSnapshotBuilder.swift` — **348** Zeilen — enum StatsSnapshotBuilder
12. `filmfreaks/MovieDetail/MovieDetailView.swift` — **345** Zeilen — struct MovieDetailView
13. `filmfreaks/CloudKitUserStore.swift` — **335** Zeilen — struct CloudKitUserStore, struct CloudMember, enum StableID
14. `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift` — **333** Zeilen — class MovieNightCloudSyncCoordinator, struct PendingEventSave, struct PendingActivitySave, struct PendingResponseSave, struct PendingDelete, struct PendingResponseDelete
15. `filmfreaks/CloudKitMovieStore/CloudKitMovieStore+Modify.swift` — **332** Zeilen — extension CloudKitMovieStore, struct RouteKey

**Warum riskant (generisch):**
- Mehr Merge-Konflikte, schlechtere Orientierung, höhere Compile-Kosten.
- Höheres Risiko für „MainActor contention“, wenn große Daten- und Sync-Logik in einem File zusammenklebt.

---

## Hot Path Analyse

### Rendering / Scrolling (SwiftUI)
**Gute Nachrichten:** Es gibt bereits explizite Maßnahmen, um teure Ableitungen aus dem Render-Pfad zu halten.
- `ContentView` nutzt `@StateObject` Caches für Listen-Items & Activity Preview  
  (`filmfreaks/Content/ContentView.swift`, Zeile 31 + 34)

**Konkrete Hotspots (mit Grund):**
1. `filmfreaks/Content/GroupActivityListView.swift` (Zeile 35)
   - Grund: `(movies + nights).sorted(...)` im View-Compute → O(n log n) pro Invalidation.  
     Wenn Activity wächst (viele Events), kann das Scroll/Render „ruckeln“.
2. `filmfreaks/MovieNights/Calendar/MonthGridView.swift` (Zeile 36)
   - Grund: `Dictionary(grouping: events, ...)` im View-Compute → O(n) Gruppierung pro Invalidation.  
     Besonders spürbar bei Month-Grid + häufiger State-Änderung.
3. `filmfreaks/MovieNights/Calendar/MovieNightCalendarView.swift` (Zeile 66)
   - Grund: `.sorted(by:)` auf Events im View-Compute → O(n log n) pro Render.
4. `filmfreaks/Goals/GoalsView.swift` (Zeile 163)
   - Grund: `Array(Set(...)).sorted(...)` im View-Compute → unnötige Allokationen + Sort.

**Non-Hotspots (bewusst gut gelöst):**
- Stats Snapshot wird off-main und debounced berechnet (`filmfreaks/Stats/StatsViewModel.swift`, `DispatchQueue.global` bei Zeile 153).  
  → Sehr guter Pattern gegen UI-Stalls.

### Sync / Storage (CloudKit + Disk)
**Refresh-Cascade (App Resume):**
- In `filmfreaks/filmfreaksApp.swift` wird bei `scenePhase == .active` ein Refresh-Cascade getriggert (Zeile 69).
  - gut: `AppRefreshCoordinator` coalesced und verhindert parallele Cascades (`filmfreaks/AppRefreshCoordinator.swift`).
  - Risiko: Trotz Coalescing kann „häufiges Aktivieren“ (App Switch, Share Flow, etc.) CloudKit-Traffic erhöhen.
  - Test-Symptome: längere `isSyncing` Phasen, Battery/Network spikes.

**Inkrementeller Sync (ZoneChanges + Tokens):**
- ChangeTokens werden pro Zone/Namespace in UserDefaults persistiert (`filmfreaks/CloudKitZoneChangeTokenStore.swift`).
  - Nutzen: skaliert besser als Full-Fetch.
  - Risiko: Token-Inkonsistenzen/Reset-Fälle (z.B. `CKError.changeTokenExpired`) müssen robust gehandhabt werden.  
    **UNKNOWN**: Ob Token-Expiry explizit abgefangen und auf Full-Resync zurückfällt (bitte prüfen).

**CloudKit Routing Guard:**
- `CloudKitRouting` behandelt UUID-like groupIds als Sharing/Zone-Gruppen und verlangt einen `GroupContext` (sonst Error) (`filmfreaks/CloudKitRouting.swift`).
  - Nutzen: verhindert gefährliche „Public DB fallback“ Bugs.
  - Risiko: UX/Fehlerpfade, wenn GroupContext noch nicht geladen ist.  
    **UNKNOWN**: Ob alle Call-Sites `CloudKitRoutingError.groupContextNotReady` konsequent UI-seitig behandeln (Toast/Hint).

**Disk-Persistenz (Movies/Users):**
- `PersistenceManager` schreibt debounced/async auf Utility Queue (`filmfreaks/PersistenceManager.swift`).
  - gut: entkoppelt JSON-Encoding vom MainActor.
  - Risiko: sehr große Arrays können trotzdem spürbar CPU ziehen (auch wenn nicht am Main Thread).

### Concurrency (MainActor, Task Lifetimes, Cancellation)
- Stores sind häufig `@MainActor` (z.B. `MovieStore`, `MovieNightStore`, `StatsViewModel`) → konsistent & einfach, aber:
  - Hotspot-Risiko: Wenn „heavy work“ (Diff/Merge/Decode) versehentlich am MainActor passiert, führt das zu UI-Stalls.
- Search:
  - `MovieSearchView` hat explizite Cancellation + Out-of-order Tokens (`searchTask`, `paginationTask`, Tokens) (`filmfreaks/MovieSearch/MovieSearchView.swift`).  
    → sehr gut, weil Suche/Pagination typischerweise Race-/Leak-anfällig ist.
- Refresh/Sync:
  - `AppRefreshCoordinator` verhindert parallele Refresh Cascades.  
  - Debounced Writers: `MovieCloudSyncCoordinator` und `MovieNightCloudSyncCoordinator` (Batching).

---

## Refactor Map

### Konkrete Splits (mechanisch, geringer Risikohebel)
1. `filmfreaks/MovieStore/MovieStore+CloudSync.swift`  
   **Cut-Vorschlag:**  
   - `MovieStore+CloudSync.Fetch.swift` (Fetch / ZoneChanges orchestration)  
   - `MovieStore+CloudSync.Merge.swift` (Merge/Apply Strategien, Konflikte)  
   - `MovieStore+CloudSync.Meta.swift` (sync meta: last sync, pending, errors)  
   **Warum:** Bessere Orientierung + geringere Merge-Konflikte; Cloud-Sync ist typischer Hotspot.
2. `filmfreaks/SettingsView.swift` + `filmfreaks/GroupSettingsView.swift`  
   **Cut-Vorschlag:** Section-Views pro Themenblock (Appearance, Cloud, Privacy, Debug, etc.).  
   **Warum:** große Form-Views → oft Merge-Konflikt-Magnet.
3. Calendar Rendering  
   - `MonthGridView` + `MovieNightCalendarView` → Vorberechnung im Store/Model (z.B. `@StateObject MonthGridModel`).  
   **Warum:** Sort/Group im body entfernen.

### Cache-/Index-Ideen (konkret)
- **Activity Feed**:  
  - Cache: `[UnifiedGroupActivityEvent]` sortiert + “revision” Counter (Pattern ist schon in `ContentActivityPreviewModel` angelegt).  
  - Invalidation: wenn Movies/Backlog/MovieNights Activity-Inputs ändern.
- **Movie Lookups**:  
  - Index: `[UUID: Int]` oder `[UUID: Movie]` für häufige “find by id” Pfade (z.B. Activity → Movie).  
    **UNKNOWN**: Ob das bereits existiert außerhalb der gescannten Files (bitte verifizieren).
- **Calendar**:
  - Precompute: `eventsByDay` Dictionary + `sortedEvents` nur bei Input-Change.

### Vereinheitlichungen (Patterns, Services, DI)
- **CloudKit Store API**: einheitliche Signaturen für:
  - `refreshFromCloud(force:)`, `applyZoneChanges`, `flushPendingChanges` (Movies/MovieNights/Users/Goals).  
  - Ein zentraler Error-Mapping Layer (CloudKit → UX).
- **Logging**:
  - `Logger(subsystem: "filmfreaks", category: "...")` als Standard (statt gemischtem `print`/silent).

---

## Risiken & Edge Cases
- **Datenverlust / Merge**:
  - Movies und Ratings sind getrennte Records (Movie payload ohne Ratings; Ratings separat) → Merge muss “rating-only edits” sauber behandeln (`filmfreaks/MovieStore/MovieStore+Persistence.swift` kommentiert das explizit).
- **Migration / Legacy IDs**:
  - `CloudKitUserStore` hat Legacy RecordName-Formate (alt: groupId|canonicalName) → best-effort Migration beim Fetch (`filmfreaks/CloudKitUserStore.swift`).
  - `Rating.reviewerId` kann für Legacy nil sein → wird stabilisiert (siehe `CloudKitRatingStore` Schema/Helpers).
- **Offline + Pending Changes**:
  - Pending queues existieren (Movies/MovieNights).  
  - **UNKNOWN**: Wie Konflikte aufgelöst werden, wenn zwei Geräte offline denselben Datensatz bearbeiten.
- **Sharing / DB Routing**:
  - `GroupContext` ist kritisch, um shared zones korrekt anzusprechen (`filmfreaks/GroupContext.swift`, `filmfreaks/CloudKitRouting.swift`).  
  - Edge Case: GroupContext nicht geladen → RoutingError → muss UX-seitig behandelt werden.

---

## Observability / Debuggability
- Existierend:
  - `PersistenceManager` nutzt `os.Logger` (`filmfreaks/PersistenceManager.swift`).
  - Remote Notification Debug: `CloudKitRemoteNotificationDebugger` (`filmfreaks/CloudKit/CloudKitRemoteNotificationDebugger.swift`).
- Empfohlen:
  - Konsistente CloudKit-Logs (Start/Ende + Dauer + record counts) in:
    - `MovieStore+CloudSync`, `MovieNightStore+CloudFlush`, `CloudKit*Store+ZoneChanges`
  - Ein Debug-Screen/Section in Settings (falls nicht vorhanden) mit:
    - lastCloudSyncAt, pending counts, last errors pro Gruppe.

---

## Open Questions (UNKNOWN)
1. CloudKit Dashboard:
   - Sind die RecordTypes/Zones exakt so eingerichtet wie im Code (z.B. `"Movie"`, `"MovieRating"`, `"FFGroup"`, `"ViewingGoal"`, `"ViewingCustomGoals"`, `"MovieNightEvent"` etc.)? (**UNKNOWN**)
2. Token Expiry Handling:
   - Gibt es einen robusten Fallback bei `CKError.changeTokenExpired`/Token-Invalidation? (**UNKNOWN**)
3. UX bei RoutingError:
   - Wo werden `CloudKitRoutingError.groupContextNotReady` und ähnliche Fehler dem User angezeigt? (**UNKNOWN**)
4. Offline Conflicts:
   - Welche Konfliktstrategie gilt bei gleichzeitigen Offline-Edits auf mehreren Geräten? (**UNKNOWN**)
5. Secrets Hygiene:
   - Ist `Secrets.xcconfig` bewusst committed oder nur im lokalen Zip? (**UNKNOWN**)

---

## First 3 Refactors I would do (P0)

### P0.1 — Calendar/Activity: Sort/Group aus dem Render-Pfad raus
- **Ziel:** weniger UI-Stalls beim Scrollen/Monatswechsel, stabilere FPS.
- **Betroffene Dateien:**
  - `filmfreaks/Content/GroupActivityListView.swift`
  - `filmfreaks/MovieNights/Calendar/MonthGridView.swift`
  - `filmfreaks/MovieNights/Calendar/MovieNightCalendarView.swift`
- **Risiko:** niedrig (rein mechanisch: Vorberechnung + Cache; UI bleibt gleich).
- **Erwarteter Nutzen:** spürbar bei großen Event-Listen; weniger unnötige Recomputations.

### P0.2 — MovieStore CloudSync: Split + “heavy work” audit
- **Ziel:** Orientierung + Compile-Time; gleichzeitig gezielt prüfen, ob Merge/Decode/Diff am MainActor passiert.
- **Betroffene Dateien:**
  - `filmfreaks/MovieStore/MovieStore+CloudSync.swift`
  - optional: `filmfreaks/CloudKitMovieStore/*` (Merge/ZoneChanges) als Referenz
- **Risiko:** niedrig–mittel (bei reinem Split niedrig; wenn Work off-main verlagert wird, mittel).
- **Erwarteter Nutzen:** weniger Merge-Konflikte, bessere Wartbarkeit; potenziell weniger MainActor contention bei großen Gruppen.

### P0.3 — Secrets/Config hardening (kein Feature, aber verhindert “Oh no”-Momente)
- **Ziel:** API Keys nicht im Repo; Build bleibt reproduzierbar.
- **Betroffene Dateien:**
  - `filmfreaks/Secrets.xcconfig`
  - `filmfreaks/Debug.xcconfig`, `filmfreaks/Release.xcconfig`
  - `filmfreaks/Info.plist` (TMDB_API_KEY Key)
- **Risiko:** niedrig (Build-Konfig; kein Runtime-Behavior, wenn korrekt umgesetzt).
- **Erwarteter Nutzen:** Security + leichteres Onboarding (new dev → key eintragen, ohne zu leaken).

