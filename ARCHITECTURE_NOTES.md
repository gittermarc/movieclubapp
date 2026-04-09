# ARCHITECTURE_NOTES.md

## Scope
Diese Notizen basieren auf dem aktuellen Projektstand im gelieferten ZIP. Aussagen sind nur dort faktisch, wo sie durch Quellcode oder Projektdateien belegbar sind. Unklare Punkte sind als **UNKNOWN** markiert und unten gesammelt.

---

## Big Files List (Top 15 nach Zeilen)

1. **399** — `filmfreaks/MovieNights/MovieNightStore.swift`  
   Zweck: zentraler Store für Event-/Response-/Activity-State, lokale Persistenz, Retry-Handling, Sync-Status, Network-Reconnect, GroupContext-Retry.  
   Risiko: zu viele Verantwortungen in einer MainActor-Klasse; hoher Kopplungsgrad zwischen UI-State, Persistenz und Cloud-Flush.

2. **397** — `filmfreaks/MovieStore/MovieStore+CloudSync.swift`  
   Zweck: Cloud-Refresh, Deltas, Throttling, Network-Reconnect, GroupContext-Retry, Meta-Status.  
   Risiko: geschäftskritischer Sync-Pfad; Fehler führen direkt zu Datenstaleness, Dubletten oder falschem Group-Routing.

3. **370** — `filmfreaks/ViewingCustomGoal.swift`  
   Zweck: Goal-Domänenmodell, Codable-Migration, Regeln, Labels, Dedupe-Key.  
   Risiko: viel Domänenwissen in einer Datei; jede Änderung kann Persistenz, UI-Texte und Matching beeinflussen.

4. **367** — `filmfreaks/Movie.swift`  
   Zweck: Kernmodell Film/Rating/Cast + Migration + Berechnungshilfen.  
   Risiko: Änderung trifft nahezu jede App-Funktion; Modell ist lokal und in CloudKit serialisiert.

5. **366** — `filmfreaks/Stats/StatsSnapshotBuilder.swift`  
   Zweck: komplette Statistikaggregation inklusive Filter, Coverage, Critic-Gaps, Genres, Actors, Trends.  
   Risiko: rechenintensiver Hot Path; sehr leicht regressionsanfällig bei Actor-Isolation und Performance.

6. **356** — `filmfreaks/Stats/StatsView+Cards.Leaderboards.swift`  
   Zweck: mehrere leaderboardartige Statistik-Cards.  
   Risiko: UI ist breit verteilt und stark von Snapshot-Form abhängig; Card-Änderungen können schnell Inkonsistenzen erzeugen.

7. **346** — `filmfreaks/MovieDetail/MovieDetailView.swift`  
   Zweck: Orchestrator für Film-Detailscreen mit lokalen und TMDb-Daten.  
   Risiko: hoher UI-State-Anteil, viele Teilbereiche, mehrere externe Datenabhängigkeiten.

8. **344** — `filmfreaks/PersistenceManager.swift`  
   Zweck: zentrale Dateipersistenz für Movies/Backlog/Users inklusive Migration und Debounce.  
   Risiko: Single Point of Failure für lokale Datenhaltung; Fehler können Datenverlust oder Inkonsistenzen verursachen.

9. **343** — `filmfreaks/MovieSearch/MovieSearchView/MovieSearchView.swift`  
   Zweck: Suchscreen mit Query-State, Pagination, Empfehlungen, Scanner, Detail-Sheet, Toaster.  
   Risiko: sehr viel UI-State in einer View; Task-Lebenszyklen und Ergebnis-Reihenfolge sind heikel.

10. **336** — `filmfreaks/CloudKitUserStore.swift`  
    Zweck: CloudKit CRUD und Query für Gruppenmitglieder.  
    Risiko: Konfliktbehandlung, Legacy-Migration und Record-ID-Logik liegen in einem File.

11. **334** — `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift`  
    Zweck: debounced/batched Upload-Logik für Movie Nights.  
    Risiko: Queueing, Flush-Timing und Fehlerbehandlung sind synchronisationskritisch.

12. **333** — `filmfreaks/CloudKitMovieStore/CloudKitMovieStore+Modify.swift`  
    Zweck: Upsert/Delete/Batch-Write für Movie-Records.  
    Risiko: zentraler Schreibpfad für CloudKit-Filmobjekte; Konflikte und Routingfehler sind teuer.

13. **315** — `filmfreaks/Content/ContentMainAreaView.swift`  
    Zweck: Hauptlisten-/Grid-Bereich, Refresh, Empty State, Delete-Abläufe.  
    Risiko: große zentrale UI-Fläche; jede unnötige Invalidierung schlägt sofort auf Scroll/Responsiveness.

14. **298** — `filmfreaks/MovieNights/Calendar/MovieNightCalendarView.swift`  
    Zweck: Monatskalender für Movie Nights.  
    Risiko: mehrfach getriggerte Rebuilds, gruppenabhängige Refreshes, Kalenderberechnungen.

15. **294** — `filmfreaks/Goals/CustomGoals/CustomGoalEditorView.swift`  
    Zweck: Editor für mehrere Goal-Typen inkl. Person-/Keyword-Suche.  
    Risiko: UI-State + Remote-Search + Validierung in einer Datei; hoher Testaufwand bei Änderungen.

---

## Hot Path Analyse

### Rendering / Scrolling

#### 1) `filmfreaks/Content/ContentView+Lifecycle.swift`
**Grund:** breite Invalidierung über viele Trigger (`onReceive`/`onChange`) für Movies, Backlog, MovieNightActivity, Search-Texte, Filter, Sortierung, Rating-Mode, Group-Wechsel.

Bewertung:
- Positiv: teure Ableitungen wurden bereits aus `body` ausgelagert nach
  - `filmfreaks/Content/ContentMovieItemsModel.swift`
  - `filmfreaks/Content/ContentActivityPreviewModel.swift`
- Risiko bleibt:
  - ein einziges Event kann mehrere Updatepfade nacheinander feuern
  - bei größeren Datenmengen drohen doppelte Snapshot-Builds

#### 2) `filmfreaks/Content/ContentMainAreaView.swift`
**Grund:** zentrale Scroll-/List-/Grid-UI mit Pull-to-Refresh und potenziell großen Arrays.

Auffällig:
- `List`- und `ScrollView/LazyVGrid`-Pfade leben zusammen in einer Datei
- Grid/Delete-State und Empty-State sind im selben Orchestrator gebündelt
- Renderkosten hängen direkt von `watchedItems`/`backlogItems`-Größe ab

Positiv:
- Such-/Sortierlogik ist aus dem Renderpfad verlagert (`filmfreaks/Content/ContentMovieItemsSnapshotBuilder.swift`)
- `MovieSearchIndexCache` reduziert String-Normalisierung im Suchpfad (`filmfreaks/Content/MovieSearchIndexCache.swift`)

#### 3) `filmfreaks/Stats/StatsView.swift` + `filmfreaks/Stats/StatsViewModel.swift`
**Grund:** viele `onChange`-Trigger auf Movies, Users, Filter und Rating-Mode; Statistikaggregation ist potenziell teuer.

Positiv:
- `StatsViewModel` debounced Updates und rechnet große Teile off-main via `Task.detached`
- `StatsSnapshotBuilder` ist explizit pure/nonisolated ausgelegt

Risiken:
- Input-Änderungen können in kurzer Folge mehrere Build-Generationen erzeugen
- Actor-Isolation bleibt fragil, weil das Projekt `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` nutzt
- Popularity-Preload für Actors erzeugt Zusatzarbeit vor Snapshot-Publikation

#### 4) `filmfreaks/Timeline/TimelineView.swift`
**Grund:** Snapshot-Rebuild bei `movieStore.movies`, `filterMode`, `selectedRange`, `selectedYear`.

Risiko:
- anders als bei Stats existiert hier kein dediziertes ViewModel mit Debounce
- `updateSnapshot()` läuft viewnah; bei großen Film-Mengen skaliert das schlechter

#### 5) `filmfreaks/MovieSearch/MovieSearchView/MovieSearchView.swift`
**Grund:** sehr stateful Search-Screen mit Query, Pagination, Empfehlungen, Scanner, Toast, Detail-Sheet, Focus-State.

Risiken:
- viele UI-Zustände in einer View erhöhen Re-Render-Fläche
- Task-Cancellation/Out-of-order-Schutz ist vorhanden, aber Logik verteilt sich über mehrere Extensions
- Empfehlungen und Suchergebnisse leben parallel im gleichen State-Space

#### 6) `filmfreaks/MovieDetail/MovieDetailView.swift` und `filmfreaks/SearchResultDetail/SearchResultDetailView.swift`
**Grund:** beide Views laden externe TMDb-Details und Watch-Provider asynchron, teils parallel (`async let`).

Risiken:
- Wiederholte Loads bei ID-/Region-Änderungen
- UI-State, Netzwerk-Status und lokale Mutationen sind eng gekoppelt

---

### Sync / Storage

#### 1) `filmfreaks/PersistenceManager.swift`
**Grund:** zentraler lokaler Schreib-/Leseweg für Movies, Backlog, Users.

Wichtige Eigenschaften:
- gruppenspezifische Dateipfade
- debounced writes auf eigener Queue
- atomische Writes
- Migration von Legacy-UserDefaults

Risiken:
- Fehler werden geloggt, aber nicht zentral beobachtbar gemacht
- ein defekter Pfad oder Serialisierungsfehler kann still zu leerem Fallback führen
- als Singleton schwer isoliert testbar außerhalb vorhandener Tests

#### 2) `filmfreaks/MovieStore/MovieStore+CloudSync.swift`
**Grund:** Cloud-Read-Pfad der wichtigsten Domäne.

Wichtige Eigenschaften:
- minRefreshInterval = 8 Sekunden
- Schutz vor falschem Public-Fallback via `CloudKitRouting`
- Delta-Lesen via Zone-Changes
- Mid-flight-Group-Switch-Schutz

Risiken:
- hoher Verzweigungsgrad: local/public/shared/zone-change/full snapshot
- Fehler hier schlagen direkt auf Kernfunktion der App
- `beginSync`/`endSync` und mehrere Statusfelder sind leicht inkonsistent zu halten

#### 3) `filmfreaks/MovieNights/MovieNightStore.swift` + `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift`
**Grund:** eigener kompletter Persistenz-/Sync-Stack parallel zum MovieStore.

Risiken:
- ähnliche Mechanik wie MovieStore, aber eigene Implementierung statt geteilter abstrakter Sync-Infrastruktur
- Gefahr von Pattern-Drift zwischen MovieSync und MovieNightSync
- Retry/Flush/Refresh/Network-Reconnect/GroupContext-Retry mehrfach gelöst

#### 4) `filmfreaks/CloudKitGroupStore/*`
**Grund:** Gruppen sind Routing-Grundlage für alles Weitere.

Besonders heikel:
- `CloudKitGroupStore+Fetch.swift` setzt auf Zonenliste + Direktfetch des Root-Records statt Query
- `CloudKitGroupStore+Sharing.swift` repariert Share-Hierarchien best effort durch Reparenting mehrerer Record-Typen

Risiken:
- Share-Hierarchy-Repair kann bei großen Datenmengen teuer werden
- jede Inkonsequenz hier schlägt auf Sichtbarkeit/Schreibbarkeit geteilter Records durch

#### 5) `filmfreaks/Goals/GoalsStore.swift`
**Grund:** Goals mischen `UserDefaults`-Persistenz und CloudKit-Sync.

Risiken:
- `syncFromCloud` überschreibt lokale State-Container direkt
- kein Konfliktmodell außer „remote wins if non-empty“
- `UserDefaults` statt Datei bedeutet bei größeren Goal-Payloads weniger Transparenz

---

### Concurrency

#### Projektweite Ausgangslage
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` im Projektfile
- viele Stores/Views sind `@MainActor`
- pure Helper müssen explizit nonisolated/actor-safe gebaut werden

#### Konkrete Hotspots

##### `filmfreaks/Stats/StatsViewModel.swift`
- nutzt `Task.detached` korrekt für teure reine Berechnung
- nutzt Generation-Counter gegen Out-of-order-Publish
- Risiko: sobald `StatsSnapshotBuilder` versehentlich wieder MainActor-isolierte APIs referenziert, kommen Swift-6-Warnungen/Fehler zurück

##### `filmfreaks/MovieSearch/MovieSearchView/MovieSearchView.swift` + `MovieSearchView+Search.swift`
- parallele Search-/Pagination-Tasks
- manuelle Tokens für Ergebnisreihenfolge
- Risiko: Task-Lifetime verteilt sich über View-State; schwerer zu testen als ein dediziertes SearchViewModel

##### `filmfreaks/AppRefreshCoordinator.swift`
- coalesced app-resume refresh ist sauber gedacht
- Risiko: Refresh-Kaskade ist closure-basiert und nicht domänenspezifisch instrumentiert

##### `filmfreaks/MovieStore/*` und `filmfreaks/MovieNights/*`
- viel Logik bleibt auf MainActor
- Diffing, Array-Vergleiche und Statusupdates finden teilweise im Store-Layer statt
- Risiko: MainActor contention bei großen Listen oder häufigen Sync-Events

##### `filmfreaks/Notifications/*`
- Local Notification Flow ist klein und nachvollziehbar
- Risiko gering, aber Debugbarkeit beschränkt sich weitgehend auf `print`

---

## Refactor Map

### A) Konkrete Splits

#### 1) `filmfreaks/MovieNights/MovieNightStore.swift`
Empfohlene Splits:
- `MovieNightStore+ReadModel.swift`
- `MovieNightStore+Writes.swift`
- `MovieNightStore+CloudRefresh.swift`
- `MovieNightStore+RetryHandling.swift`
- `MovieNightStore+SyncMeta.swift`

Nutzen:
- geringere kognitive Last
- weniger Konflikte in PRs
- besser testbare Verantwortlichkeiten

#### 2) `filmfreaks/MovieSearch/MovieSearchView/MovieSearchView.swift`
Empfohlene Splits:
- `MovieSearchViewState.swift` für ViewState-Ableitungen
- `MovieSearchRecommendationsController.swift`
- `MovieSearchScannerCoordinator.swift`
- optional `MovieSearchViewModel.swift`

Nutzen:
- weniger `@State`-Explosion in der View
- klarere Task-Lebenszyklen

#### 3) `filmfreaks/MovieDetail/MovieDetailView.swift`
Empfohlene Splits:
- `MovieDetailView+Sections.swift` nur Orchestrierung
- `MovieDetailLoadCoordinator.swift`
- `MovieDetailWatchProvidersLoader.swift`
- `MovieDetailRatingsCoordinator.swift`

Nutzen:
- externe Loads und lokale Mutationen entkoppeln
- leichterer Testzugang

#### 4) `filmfreaks/Stats/StatsView.swift`
Empfohlene Splits:
- `StatsInputState.swift`
- `StatsRouteState.swift`
- `StatsView+Observers.swift`

Nutzen:
- Beobachtungslogik separierbar
- weniger Chancen für redundante Refresh-Kaskaden

### B) Cache-/Index-Ideen

#### 1) Stats
- vorhandenes Actor-Popularity-Preload beibehalten, aber Snapshot-Keying ergänzen
- möglicher Cache-Key:
  - movie IDs + updatedAt fingerprint
  - selectedRange
  - selectedLocationFilter
  - ratingDisplayMode
- Invalidation:
  - bei `movieStore.movies`, `userStore.users`, `displaySettings.ratingDisplayMode`

#### 2) Timeline
- Snapshot-Cache analog Stats einführen
- Key:
  - movie IDs + watchedDate fingerprint
  - filterMode / selectedRange / selectedYear

#### 3) Movie Detail / Search Detail
- Watch-Provider-Cache nach `(tmdbId, regionCode)`
- Person-Detail-Cache nach `personId`
- Invalidation über TTL oder manuelle Refresh-Aktion

#### 4) Cloud Sync Meta
- konsolidierter Sync-Meta-Typ für MovieStore + MovieNightStore + UserStore
- heute mehrfach ähnlich gelöst, aber nicht vereinheitlicht

### C) Vereinheitlichungen

#### 1) Sync Coordinator Pattern
Heute existieren parallele Muster:
- `filmfreaks/MovieCloudSyncCoordinator.swift`
- `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift`

Empfehlung:
- gemeinsames internes Pattern oder generische Hilfsschicht für
  - debounce
  - pending count
  - immediate flush
  - network reconnect
  - success/failure hooks

#### 2) Routing / Current Group Access
- Current-group-Zugriff ist verteilt über `MovieStore.currentGroupId`, `UserStore.currentGroupId`, `GroupContextStore`
- Empfehlung: kleiner `GroupSession`-Typ oder zumindest klarere Read-Only-Fassade

#### 3) Read-Model Builder Pattern
Bereits vorhanden in Content/Stats/Timeline, aber inkonsistent.
Empfehlung:
- einheitlicher Stil für:
  - Input-Typ
  - Snapshot-Typ
  - Builder
  - optionales ViewModel mit Debounce

#### 4) Observability Pattern
- aktuell: `print`, vereinzelt `Logger`, sonst wenig gemeinsame Diagnoseoberfläche
- Empfehlung:
  - ein kleines Logging-/Metrics-Interface
  - Sync-Phase, Dauer, Record-Anzahl, Fehlerklasse standardisiert erfassen

---

## Risiken & Edge Cases

### Datenverlust / Persistenz
- `PersistenceManager.read(...)` und `MovieNightLocalPersistence.load()` fallen bei Fehlern auf leere Daten zurück. Das ist robust gegen Crashes, aber gefährlich für stille Datenprobleme.
- `GroupSettingsView` löscht lokale Gruppendaten beim Delete/Leave explizit über `PersistenceManager.shared.deleteGroupData(groupId:)`.
- Goal-Daten liegen in `UserDefaults`; bei künftigen großen Payloads ist das weniger transparent als dateibasierte Persistenz.

### Migration
- Legacy-Migrationen sind verteilt über mehrere Typen und nicht zentral dokumentiert.
- Share-Hierarchy-Repair ist best effort; unklar, wie oft reale Altbestände das noch benötigen.

### Offline / Multi-Device
- Offline ist lokal gut abgedeckt.
- Multi-Device-Konsistenz hängt stark an CloudKit-Routing und Change-Token-Korrektheit.
- Für UUID-artige Gruppen ist falsches Public-Fallback sauber verhindert; das ist wichtig und sollte nicht aufgeweicht werden.

### Notifications / Push
- Push-Flow ist vorhanden, aber stark auf Debug-Logging gestützt.
- `aps-environment` steht hier auf `development`; Produktivverhalten muss separat geprüft werden.

### Security / Secrets
- `filmfreaks/Secrets.xcconfig` enthält in dieser Kopie einen konkreten API-Key.
- `TMDbAPI` ist im Code als „nicht wirklich geheim“ kommentiert, trotzdem sollte die committed Datei bereinigt werden.

---

## Observability / Debuggability

### Vorhanden
- `os.Logger` in `filmfreaks/PersistenceManager.swift`
- viele `print`-Statements in CloudKit- und Sync-Pfaden
- dedizierter Remote-Notification-Debugger in `filmfreaks/CloudKit/CloudKitRemoteNotificationDebugger.swift`
- Notification-Dedupe-State in `filmfreaks/Notifications/ActivityNotificationStateStore.swift`
- Sync-Präsentation für Settings in `filmfreaks/Settings/SettingsSyncStatusPresentation.swift`

### Lücken
- keine zentrale Metrik für Dauer/Größe von Sync-Vorgängen
- kein einheitliches Error-Domain-Mapping für alle Stores
- keine sichtbare Diagnoseoberfläche für lokale Persistenzfehler
- keine Performance-Telemetrie für Stats/Timeline/Search-Builder

### Repro-Ansätze
- **Sync-Probleme**: Gruppe wechseln, Offline/Online toggeln, Pull-to-refresh, App in Hintergrund/Vordergrund
- **Push-Probleme**: Remote notification logs prüfen, `CloudKitActivityPushFetchCoordinator`-Pfad verfolgen
- **Render-Probleme**: große Filmlisten, schnelle Filter-/Suchwechsel, Stats Range/Location mehrfach ändern
- **Share-Probleme**: Group create → share → accept on second device → refresh → hierarchy repair beobachten

---

## Open Questions

1. **UNKNOWN**: Ist das Deployment Target iOS 26.0 bewusst final oder temporär projektbedingt? Im Projektfile ist es faktisch 26.0.
2. **UNKNOWN**: Ist `filmfreaks/Secrets.xcconfig` absichtlich committed oder nur versehentlich im ZIP enthalten?
3. **UNKNOWN**: Gibt es außerhalb des Repos CI, Fastlane oder Release-Automation? Im ZIP wurde nichts dazu gefunden.
4. **UNKNOWN**: Ist die CloudKit-Schema-Migration in Produktion bereits ausgerollt oder nur lokal/dev getestet?
5. **UNKNOWN**: Wie groß werden reale Filmbestände pro Gruppe erwartet? Im Code gibt es keine Benchmarks oder Limits.
6. **UNKNOWN**: Sind `Goals` absichtlich in `UserDefaults` statt dateibasiert, oder ist das nur historisch gewachsen?
7. **UNKNOWN**: Gibt es bekannte Produktivprobleme bei Share-Hierarchy-Repair oder Zone-Changes? Im Code sind nur best-effort-Pfade sichtbar.
8. **UNKNOWN**: Ist Push-Handling nur für Debug aktiv oder wird `CloudKitActivityPushFetchCoordinator` auch in Release produktiv genutzt? Der Code selbst ist unter `#if DEBUG` gated.
9. **UNKNOWN**: Gibt es zusätzliche nicht eingecheckte CloudKit-Dashboard-Indizes/Constraints, von denen die Queries abhängen?
10. **UNKNOWN**: Gibt es manuelle QA-Checklisten für Multi-Device/Sharing/Offline? Im Projekt selbst nicht gefunden.

---

## First 3 Refactors I would do (P0)

### 1) MovieNightStore in klare Verantwortungsblöcke zerlegen
- **Ziel**  
  `filmfreaks/MovieNights/MovieNightStore.swift` in Read API, Write API, Sync-Refresh, Retry/Connectivity und Sync-Meta aufteilen.
- **Betroffene Dateien**  
  `filmfreaks/MovieNights/MovieNightStore.swift`  
  neu: `MovieNightStore+Writes.swift`, `MovieNightStore+CloudRefresh.swift`, `MovieNightStore+RetryHandling.swift`, `MovieNightStore+SyncMeta.swift`, `MovieNightStore+ReadModel.swift`
- **Risiko**  
  niedrig bis mittel; hauptsächlich organisatorisch, solange Public API und Published Properties unverändert bleiben.
- **Erwarteter Nutzen**  
  weniger PR-Konflikte, kleinere Testflächen, deutlich niedrigere Komplexität im kritischsten Movie-Night-Typ.

### 2) Timeline auf Snapshot-Model mit Debounce umstellen
- **Ziel**  
  `filmfreaks/Timeline/TimelineView.swift` analog zu Stats/Content aus dem direkten Rebuild-Pfad lösen.
- **Betroffene Dateien**  
  `filmfreaks/Timeline/TimelineView.swift`  
  `filmfreaks/Timeline/TimelineSnapshotBuilder.swift`  
  neu: `filmfreaks/Timeline/TimelineViewModel.swift`
- **Risiko**  
  niedrig; fachliche Logik kann fast 1:1 übernommen werden.
- **Erwarteter Nutzen**  
  geringere Renderlast, klarere Verantwortlichkeiten, weniger Rebuilds bei schnellen Filterwechseln.

### 3) Search-Screen-State aus MovieSearchView herausziehen
- **Ziel**  
  `filmfreaks/MovieSearch/MovieSearchView/MovieSearchView.swift` von UI-Orchestrator zu schlanker View umbauen; Search/Recommendations/Scanner-State separat kapseln.
- **Betroffene Dateien**  
  `filmfreaks/MovieSearch/MovieSearchView/MovieSearchView.swift`  
  `filmfreaks/MovieSearch/MovieSearchView/MovieSearchView+Search.swift`  
  `filmfreaks/MovieSearch/MovieSearchView/MovieSearchView+Recommendations.swift`  
  neu: `MovieSearchViewModel.swift`, `MovieSearchRecommendationsController.swift`, optional `MovieSearchScannerCoordinator.swift`
- **Risiko**  
  mittel; der Screen hat viele Zustände und mehrere Seiteneffekte.
- **Erwarteter Nutzen**  
  stabilere Task-Lebenszyklen, bessere Testbarkeit, weniger View-State-Kopplung und leichteres Weiterentwickeln.
