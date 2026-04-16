# ARCHITECTURE_NOTES.md

## Scope dieser Notizen

Diese Notizen basieren auf dem gelieferten Projektstand im ZIP und orientieren sich ausschließlich am vorhandenen Code. Unklare Punkte sind als **UNKNOWN** markiert und unten gesammelt.

---

## Big Files List — Top 15 nach Zeilen

1. `filmfreaks/MovieNights/Roulette/MovieRouletteView.swift` — **446 Zeilen**
   - Zweck: komplette Roulette-UI inklusive Flows, Listen, Controls, Modals.
   - Risiko: UI-State, Routing und Präsentationslogik in einer großen Datei; hohe Änderungsfläche.

2. `filmfreaks/Stats/StatsSnapshotBuilder+TasteDynamics.swift` — **413 Zeilen**
   - Zweck: Ableitung komplexer Geschmacks-/Bias-/Hot-Take-Insights.
   - Risiko: rechenintensiv, fachlich dicht, fehleranfällig bei Erweiterungen.

3. `filmfreaks/Stats/StatsSnapshotBuilder.swift` — **405 Zeilen**
   - Zweck: zentrales Stats-Snapshot-Building.
   - Risiko: zentraler Analytics-Hub; Änderungen haben breite Seiteneffekte.

4. `filmfreaks/MovieStore/MovieStore+CloudSync.swift` — **396 Zeilen**
   - Zweck: Laden, Mergen, Initial-Upload, Rating-Merge, Group-Switch-Schutz.
   - Risiko: höchst kritischer Datenkonsistenzpfad.

5. `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift` — **387 Zeilen**
   - Zweck: debounced Batch-Writes für Events/Responses/Activity/Presets.
   - Risiko: Nebenläufigkeit, Retry, Pending-State, gruppenspezifische Flush-Logik.

6. `filmfreaks/ViewingCustomGoal.swift` — **369 Zeilen**
   - Zweck: Goal-Domainmodell, Regeln, Codable-/Equatable-Semantik.
   - Risiko: tragendes Domainmodell mit Migrationsimplikationen.

7. `filmfreaks/Movie.swift` — **366 Zeilen**
   - Zweck: Kernmodell für Filme und Ratings inklusive Legacy-Migration.
   - Risiko: jede Modelländerung betrifft Persistenz, Cloud, UI und Stats.

8. `filmfreaks/Stats/StatsView+Cards.Leaderboards.swift` — **355 Zeilen**
   - Zweck: großer UI-Block für Stats-Cards/Leaderboards.
   - Risiko: UI-Verantwortung stark konzentriert; schwer reviewbar.

9. `filmfreaks/PersistenceManager.swift` — **343 Zeilen**
   - Zweck: lokale JSON-Persistenz, Debounce, Dateipfade, Migration.
   - Risiko: foundation layer; Fehler schlagen in mehreren Stores durch.

10. `filmfreaks/MovieDetail/MovieDetailView.swift` — **339 Zeilen**
    - Zweck: Haupt-Detailscreen für gespeicherte Filme.
    - Risiko: großer UI-Knoten mit mehreren Sheets/Zuständen.

11. `filmfreaks/CloudKitUserStore.swift` — **335 Zeilen**
    - Zweck: CloudKit-Mitgliederverwaltung.
    - Risiko: Sharing-/Parent-/Sync-Logik nahe am Kernfluss der Gruppen.

12. `filmfreaks/CloudKitMovieStore/CloudKitMovieStore+Modify.swift` — **332 Zeilen**
    - Zweck: Movie-Upsert, Batch-Modify, Konfliktlösung.
    - Risiko: Write-Konflikte und Parent-/Routing-Semantik.

13. `filmfreaks/Stats/StatsSnapshotBuilder+RatingDimensions.swift` — **327 Zeilen**
    - Zweck: Rating-Dimensionen/Statistikableitungen.
    - Risiko: rechenintensiver Snapshot-Unterbau.

14. `filmfreaks/Settings/GroupSettingsView.swift` — **326 Zeilen**
    - Zweck: Gruppenverwaltung, Sharing, Wechsel, Löschen/Verlassen.
    - Risiko: UI und Orchestrierung von Seiteneffekten gemischt.

15. `filmfreaks/MovieNights/Roulette/MovieRouletteViewModel.swift` — **325 Zeilen**
    - Zweck: Roulette-Session, Kandidatenwahl, Presets, Spin-State.
    - Risiko: Feature-Logik + UI-Anforderungen eng gekoppelt.

### Einordnung

- Die größte technische Risikokonzentration liegt **nicht** nur in großen Views, sondern vor allem in:
  - `MovieStore/MovieStore+CloudSync.swift`
  - `MovieNightCloudSyncCoordinator.swift`
  - `PersistenceManager.swift`
  - `CloudKitMovieStore/CloudKitMovieStore+Modify.swift`
  - `StatsSnapshotBuilder*`

---

## Hot Path Analyse

### 1) Rendering / Scrolling / Derived State

#### A. Content-Hauptlisten

- Betroffene Dateien:
  - `Content/ContentView+Lifecycle.swift`
  - `Content/ContentMovieItemsModel.swift`
  - `Content/ContentMovieItemsSnapshotBuilder.swift`
  - `Content/ContentMainAreaView.swift`

- Beobachtung:
  - `ContentView` triggert bei vielen Änderungen `updateMovieItemsModel()`.
  - `ContentMovieItemsModel.update(...)` baut das Snapshot synchron auf dem MainActor.
  - `ContentMovieItemsSnapshotBuilder.build(...)` macht `filter` + `searchIndex.matches` + `sorted` + `map` auf kompletten Arrays.

- Hotspot-Grund:
  - **heavy sort/filter auf MainActor**
  - **häufige Invalidierung** durch Search, Sort, Filter, Rating-Mode, Movie-/Backlog-Änderungen

- Bewertung:
  - Gut: die Logik ist bereits aus dem `body` gezogen.
  - Nicht gut genug: die Ableitung ist noch nicht off-main.

#### B. Activity Preview im Root-Screen

- Betroffene Dateien:
  - `Content/ContentActivityPreviewModel.swift`
  - `Content/ContentActivityPreviewSnapshotBuilder.swift`
  - `MovieStore/MovieStore+Activity.swift`

- Beobachtung:
  - Bei Movie-/Backlog-/MovieNight-Änderungen wird die Preview neu gebaut.
  - `update(...)` läuft auf MainActor.

- Hotspot-Grund:
  - **iterative Aggregation + Sortierung auf MainActor**
  - **wiederholte Ableitung aus mehreren Datenquellen**

#### C. Timeline-Snapshot

- Betroffene Dateien:
  - `Timeline/TimelineViewModel.swift`
  - `Timeline/TimelineSnapshotBuilder.swift`

- Beobachtung:
  - `rebuildSnapshotIfNeeded()` baut das Snapshot synchron auf MainActor.
  - Trigger kommen aus Filter-/Range-/Year-Wechseln und Movie-Updates.

- Hotspot-Grund:
  - **synchrones Snapshot-Building auf MainActor**
  - **potenziell teures Gruppieren/Sortieren über vollständige Movie-Liste**

#### D. Stats

- Betroffene Dateien:
  - `Stats/StatsViewModel.swift`
  - `Stats/StatsSnapshotBuilder.swift`
  - `Stats/StatsSnapshotBuilder+*.swift`

- Beobachtung:
  - Stats sind bereits besser aufgestellt als Content/Timeline.
  - `StatsViewModel` debounced Updates und rechnet per `Task.detached` off-main.

- Hotspot-Grund:
  - **große Input-Snapshots**, aber die teuerste Arbeit ist schon sinnvoll ausgelagert.

- Bewertung:
  - Eher Positivbeispiel als Problemfall.

#### E. Search Result Detail / Movie Detail

- Betroffene Dateien:
  - `MovieDetail/MovieDetailLoadCoordinator.swift`
  - `SearchResultDetail/SearchResultDetailView+Loading.swift`
  - `SearchResultDetail/SearchResultDetailView.swift`

- Beobachtung:
  - Zwei ähnliche Detail-Ladepfade existieren parallel.
  - `SearchResultDetailView` startet eigene Tasks auf `onAppear` und `onChange`.

- Hotspot-Grund:
  - **duplizierte Load-/Transform-Logik**
  - **wiederholte Tasks bei Zustandsänderungen**
  - eher Maintainability-Hotspot als Scroll-Performance-Hotspot

### 2) Sync / Storage

#### A. Movie Cloud Refresh / Merge

- Betroffene Datei:
  - `MovieStore/MovieStore+CloudSync.swift`

- Beobachtung:
  - Der Pfad unterscheidet zwischen Zone-Change-Delta und Full Fetch.
  - Lokale Ratings werden gesichert, Cloud-Ratings separat gemerged.
  - Ergebnisse werden verworfen, wenn in der Zwischenzeit die aktive Gruppe gewechselt hat.

- Hotspot-Grund:
  - **mehrphasige Merge-Logik**
  - **Group-Switch Race vermeiden**
  - **MainActor contention**, weil der Store `@MainActor` ist
  - **kritischer Datenpfad**

- Was hier gut ist:
  - `requestedGroupId`-Prüfung verhindert Stale-Apply.
  - Cloud-Routing schützt UUID-Gruppen vor versehentlichem Public-DB-Fallback.

#### B. Movie Cloud Writes

- Betroffene Dateien:
  - `MovieCloudSyncCoordinator.swift`
  - `CloudKitMovieStore/CloudKitMovieStore+Modify.swift`

- Beobachtung:
  - Debounced Batch-Writes mit Pending-Sets.
  - Konflikte werden in `CloudKitMovieStore+Modify.swift` per Merge behandelt.

- Hotspot-Grund:
  - **long-lived Task / Debounce-Lifetime**
  - **Retry-/Pending-State-Komplexität**
  - **serverRecordChanged-Konflikte**

#### C. Movie Night Sync

- Betroffene Dateien:
  - `MovieNights/MovieNightStore/MovieNightStore+CloudRefresh.swift`
  - `MovieNights/MovieNightCloudSyncCoordinator.swift`
  - `MovieNights/MovieNightStore/MovieNightStore+Persistence.swift`

- Beobachtung:
  - Mehrere Datentypen pro Gruppe: Events, Responses, Activity, Presets.
  - Jeder lokale Write persistiert Snapshot asynchron.
  - Activity wird auf 200 Einträge gekappt.

- Hotspot-Grund:
  - **mehrere parallele Datendomänen pro Store**
  - **komplexe Pending-/Retry-Koordination**
  - **Snapshot-Persistenz bei häufiger Aktivität**

#### D. Group Routing / Sharing

- Betroffene Dateien:
  - `CloudKitRouting.swift`
  - `GroupContext.swift`
  - `CloudKitGroupStore/*`

- Beobachtung:
  - CloudKit-Sharing basiert auf Zonen plus Root-Record-Hierarchie.
  - Stores hängen hart an korrektem `GroupContext`.

- Hotspot-Grund:
  - **Routing-Korrektheit ist systemkritisch**
  - Fehler hier führen zu Leerzuständen, Schreibfehlern oder falscher DB-Zielwahl

#### E. Goals Storage

- Betroffene Datei:
  - `Goals/GoalsStore.swift`

- Beobachtung:
  - Yearly Goals werden lokal unter `ViewingGoalsByYear.v1` gespeichert.
  - Custom Goals werden lokal pro Gruppe gespeichert.
  - Cloud-API ist gruppenspezifisch.

- Hotspot-Grund:
  - **Scoping-Inkonsistenz lokal vs. Cloud**

- Bewertung:
  - kein Performance-Hotspot, aber ein **Datenmodell-/Produkt-Hotspot**.

### 3) Concurrency

#### MainActor als Default

- Quelle:
  - `filmfreaks.xcodeproj/project.pbxproj` → `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`

- Auswirkung:
  - Standardmäßig landet sehr viel Logik auf dem MainActor.
  - Das reduziert einige Race Conditions, erhöht aber die Gefahr von UI-Blockaden und Actor-Warnungen.

#### Positive Muster

- `StatsViewModel.swift`
  - debounced + `Task.detached`
- `AppRefreshCoordinator.swift`
  - coalesced resume refreshes
- `MovieDetailLoadCoordinator.swift`
  - dedizierter Lade-Koordinator statt nackter View-Tasks

#### Problematische Muster

- `ContentMovieItemsModel.swift`
  - rechnet synchron auf MainActor
- `TimelineViewModel.swift`
  - rechnet synchron auf MainActor
- `SearchResultDetail/SearchResultDetailView.swift`
  - View steuert mehrere Reload-Tasks direkt
- `MovieSearch/MovieSearchView/MovieSearchView.swift`
  - mehrere Trigger starten Tasks für Empfehlungen

#### Konkrete Risikotypen

- **MainActor contention**
- **Task lifetime schwer nachvollziehbar**
- **fehlende zentrale Cancellation-/dedupe-Strategie in manchen Views**
- **gleichartige Nebenläufigkeitsmuster pro Feature neu erfunden**

---

## Refactor Map

### Konkrete Splits

#### 1. `MovieStore/MovieStore+CloudSync.swift`

- Ziel:
  - Lesbarer und testbarer machen.

- Vorschlag:
  - `MovieStore+CloudRefresh.swift`
  - `MovieStore+CloudMerge.swift`
  - `MovieStore+CloudSyncMeta.swift`
  - `MovieStore+CloudBootstrap.swift`

- Nutzen:
  - Pull-/Merge-/Meta-/Initial-Upload-Verantwortung trennen.

#### 2. `MovieNights/MovieNightCloudSyncCoordinator.swift`

- Ziel:
  - Pending-State je Datentyp isolieren.

- Vorschlag:
  - `MovieNightCloudSyncCoordinator+Events.swift`
  - `...+Responses.swift`
  - `...+Activity.swift`
  - `...+Presets.swift`
  - `...+Flush.swift`

- Nutzen:
  - gezieltere Tests und weniger kognitive Last.

#### 3. `MovieNights/Roulette/MovieRouletteView.swift`

- Ziel:
  - UI-Datei verschlanken.

- Vorschlag:
  - `MovieRouletteHeaderView.swift`
  - `MovieRouletteCandidatesSection.swift`
  - `MovieRoulettePresetSection.swift`
  - `MovieRouletteResultCard.swift`
  - `MovieRouletteActionBar.swift`

- Nutzen:
  - bessere Wartbarkeit, kleinere Review-Diffs.

#### 4. `MovieDetail/MovieDetailView.swift` + `SearchResultDetail/*`

- Ziel:
  - Detaildarstellung und Detail-Laden stärker vereinheitlichen.

- Vorschlag:
  - gemeinsames Detail-Presentationsmodell
  - gemeinsamer Load-UseCase/Coordinator
  - gemeinsame Untersektionen für FilmInfo, Trailer, WatchProvider, People

- Nutzen:
  - weniger doppelte Bugs, weniger Drift.

#### 5. `Settings/GroupSettingsView.swift`

- Ziel:
  - UI von Orchestrierung entkoppeln.

- Vorschlag:
  - `GroupSettingsViewModel.swift`
  - UI-Sektionen behalten, Seiteneffekt-Logik auslagern

- Nutzen:
  - geringeres Risiko bei Gruppenwechsel-/Delete-/Leave-Flows.

### Cache- / Index-Ideen

#### A. Content-Liste

- Aktuell:
  - Such-Haystack wird bereits gecacht (`Content/MovieSearchIndexCache.swift`).

- Nächster sinnvoller Schritt:
  - vollständiges Snapshot-Building off-main rechnen.
  - ggf. Input-Signature einführen, um identische Rebuilds zu skippen.

#### B. Timeline

- Vorschlag:
  - `TimelineViewModel` wie `StatsViewModel` debouncen.
  - Snapshot detached berechnen.
  - Input-Signature beibehalten, aber Rechenphase auslagern.

#### C. Movie Detail / Search Result Detail

- Vorschlag:
  - kleine in-memory Detail-Cache-Schicht für TMDb-Details und WatchProvider-Region-Reloads.

- Risiko:
  - Invalidation nach Region-Wechsel sauber halten.

#### D. Popularity / Recommendations

- Bestehend:
  - `PersonPopularityStore.swift`
  - `RecommendationsCacheManager.swift`

- Vorschlag:
  - typed recommendation seed cache statt Reflection-Heuristik.

### Vereinheitlichungen

#### 1. Store-Sync-Pattern vereinheitlichen

- Beobachtung:
  - MovieStore, UserStore, GoalsStore und MovieNightStore haben ähnliche, aber nicht identische Muster.

- Vorschlag:
  - gemeinsames leichtgewichtiges Protokoll für:
    - sync meta
    - force/throttled refresh
    - pending write count
    - network reconnect retry

- Nicht empfohlen:
  - harter Architektur-Umbau auf generisches Repository-Framework.

#### 2. Logging vereinheitlichen

- Beobachtung:
  - viel `print(...)` im Sync-Pfad.
  - `PersistenceManager.swift` nutzt bereits `Logger`.

- Vorschlag:
  - einheitliche `OSLog`-Kategorien für:
    - CloudRouting
    - CloudFetch
    - CloudWrite
    - Merge
    - Push
    - Persistence

#### 3. Detail-Ladepattern vereinheitlichen

- `MovieDetailLoadCoordinator.swift` als Vorlage für weitere detail-lastige Screens nutzen.

---

## Risiken & Edge Cases

### Datenverlust / Persistenz

- `PersistenceManager.swift`
  - foundation layer; Pfad-/Dateifehler betreffen mehrere Stores.

- `MovieStore/MovieStore+CloudSync.swift`
  - Fehlerhafte Merge-Änderungen können Watched/Backlog/Ratings inkonsistent machen.

- `CloudKitMovieStore/CloudKitMovieStore+Modify.swift`
  - falsche Parent-/Zone-Zuweisung würde Shared Visibility brechen.

### Migration

- `Movie.swift`
  - Legacy-Cast-Migration ist vorhanden; weitere Modelländerungen müssen rückwärtskompatibel gedacht werden.

- `ViewingCustomGoalsPayload.swift`
  - Custom Goal Payload ist versioniert; das ist gut, sollte aber konsequent weitergeführt werden.

### Offline / Multi-Device

- Lokale JSON-Persistenz ist robust genug für Offline-Basics.
- Cloud-Merges können durch unterschiedliche Gerätezustände komplex werden.
- Besonders kritisch:
  - Gruppenwechsel während Cloud-Refresh
  - Pending-Writes bei Netzwechsel
  - Zone-Gruppen ohne geladenen `GroupContext`

### Share / Collaboration

- CloudKit-Sharing ist tief in Parent-/Zone-Hierarchie eingebaut.
- Besonders empfindliche Punkte:
  - `CloudKitGroupStore.refresh()`
  - `CloudKitRouting.route(...)`
  - Parent-Zuweisung in `CloudKitMovieStore+Modify.swift`
  - ähnliche Parent-Mechanik in anderen CloudKit-Stores

### Produkt-/Semantik-Risiken

- `Goals/GoalsStore.swift`
  - yearly goals lokal global, cloud-seitig gruppenspezifisch → Produktsemantik unklar.

- Legacy/Public Groups
  - Code unterstützt noch Fallbacks auf Public DB für nicht-UUID-GroupIDs.
  - **UNKNOWN**, wie relevant dieser Legacy-Pfad in der echten Nutzung noch ist.

---

## Observability / Debuggability

### Bestehende Stärken

- `AppRefreshCoordinator.swift`
  - gut nachvollziehbarer Refresh-Coalescing-Punkt.

- `CloudKitZoneChangeTokenStore.swift`
  - Persistenz der Change Tokens unterstützt reproduzierbare Delta-Probleme.

- `GroupContext.swift`
  - Routingzustand ist lokal inspectable.

- `filmfreaksTests/CloudRouting/*`
  - gute Testbasis für Routing-/Token-/Context-Logik.

- `filmfreaksTests/Persistence/*`
  - gute Testbasis für lokale Persistenz.

### Schwächen

- `print(...)` statt strukturierter Logs in vielen Sync-Pfaden.
- Kein zentrales Debug-Surface für:
  - aktive Gruppe
  - aktives Routing (public/private/shared)
  - Token-Zustand
  - Pending-Writes je Domäne
  - letzte erfolgreiche Delta- oder Snapshot-Quelle

### Konkrete Debug-Verbesserungen

- Diagnostic Panel in Settings oder Developer-Overlay mit:
  - `currentGroupId`
  - `GroupContext`
  - DB-Scope/Zone
  - Pending counts pro Store
  - last sync success/error timestamps
  - token present/absent je namespace

- Strukturierte Logs mit Korrelation:
  - `groupId`
  - `zoneName`
  - `scope`
  - `recordType`
  - `operation` (`fetchChanges`, `fetchSnapshot`, `modifyBatch`, `initialUpload`)

### Reproduzierbarkeit

- Gute Testabdeckung vorhanden für:
  - Content-Snapshot-Building
  - MovieNight-Merges
  - Routing/Token/Context
  - Persistence
  - Timeline
  - Stats
  - MovieDetailLoadCoordinator

- Schwächer testbar aktuell:
  - vollständige End-to-End CloudKit-Orchestrierung
  - View-getriggerte Task-Lifetimes in Search/Detail-Flows

---

## Open Questions

- **UNKNOWN:** Ist der Legacy/Public-DB-Pfad für nicht-UUID-Gruppen noch produktiv relevant oder nur Migrationskompatibilität?
- **UNKNOWN:** Sollen Yearly Goals tatsächlich gruppenspezifisch sein? Der Cloud-Pfad ist gruppenspezifisch, die lokale `UserDefaults`-Persistenz aktuell nicht.
- **UNKNOWN:** Ist `Secrets.xcconfig` absichtlich im Repo oder nur im ZIP enthalten?
- **UNKNOWN:** Gibt es außerhalb des ZIPs CI, Release-Automation oder weitere Build-Skripte?
- **UNKNOWN:** Gibt es eine dokumentierte CloudKit-Schema-/Migrationsstrategie außerhalb des Codes?
- **UNKNOWN:** Ist `CloudKitActivityPushFetchCoordinator` in Release tatsächlich funktional vorgesehen? Der Hauptpfad ist in `#if DEBUG` gekapselt.
- **UNKNOWN:** Sollen MovieSearch-Empfehlungen rein heuristisch bleiben oder ist eine stabilere, typed Bewertungsbasis gewünscht?

---

## First 3 Refactors I would do (P0)

### 1) Content-Snapshots off-main rechnen

- **Ziel**
  - Hauptscreen bei Such-/Filter-/Sortieränderungen spürbar entlasten.

- **Betroffene Dateien**
  - `Content/ContentMovieItemsModel.swift`
  - `Content/ContentMovieItemsSnapshotBuilder.swift`
  - optional: `Content/ContentView+Lifecycle.swift`

- **Risiko**
  - niedrig bis mittel
  - vor allem Cancellation-/Generationslogik sauber halten

- **Erwarteter Nutzen**
  - bessere UI-Reaktionszeit
  - weniger MainActor-Last im häufigsten Screen der App
  - Musterangleichung an `StatsViewModel.swift`

### 2) MovieStore-CloudSync in kleinere Verantwortungen schneiden

- **Ziel**
  - den kritischsten Sync-Pfad wartbarer und gezielter testbar machen.

- **Betroffene Dateien**
  - `MovieStore/MovieStore+CloudSync.swift`
  - optional ergänzend Tests in `filmfreaksTests/CloudRouting/*` und `filmfreaksTests/Persistence/*`

- **Risiko**
  - mittel
  - Änderungen in diesem Bereich können Merge-Verhalten beeinflussen

- **Erwarteter Nutzen**
  - bessere Reviewbarkeit
  - geringere Regression-Wahrscheinlichkeit bei Sync-Anpassungen
  - klarere Trennung von Fetch, Merge, Initial Upload und Sync Meta

### 3) Detail-Ladelogik MovieDetail / SearchResultDetail vereinheitlichen

- **Ziel**
  - doppelte TMDb-Load- und Mappinglogik abbauen.

- **Betroffene Dateien**
  - `MovieDetail/MovieDetailLoadCoordinator.swift`
  - `SearchResultDetail/SearchResultDetailView+Loading.swift`
  - `SearchResultDetail/SearchResultDetailView.swift`
  - ggf. gemeinsame Section-Views

- **Risiko**
  - mittel
  - UI-Parität und bestehende Interaktionen müssen sauber erhalten bleiben

- **Erwarteter Nutzen**
  - weniger doppelte Bugs
  - konsistentere Detaildarstellung
  - leichterer Ausbau von WatchProvider-/Trailer-/Credits-Logik

