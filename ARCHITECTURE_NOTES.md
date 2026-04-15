# ARCHITECTURE_NOTES.md

## Big Files List

Top 15 Swift-Dateien nach Zeilenanzahl im aktuellen Stand.

1. **396 Zeilen — `filmfreaks/MovieStore/MovieStore+CloudSync.swift`**  
   Zweck: Cloud-Refresh, Initial-Upload, Rating-Reconciliation, Retry-Handling, Pending-Flush-Anbindung.  
   Risiko: Zu viele Verantwortlichkeiten in einer MainActor-Datei; hoher Fehler- und Regressionsradius.

2. **369 Zeilen — `filmfreaks/ViewingCustomGoal.swift`**  
   Zweck: Domain-Modell, Regeln, Payload, Legacy-Migration, Helper.  
   Risiko: Domain + Migration + Serialisierung in einem Typ; schwer isoliert testbar.

3. **366 Zeilen — `filmfreaks/Movie.swift`**  
   Zweck: Kernmodell `Movie`, `Rating`, `CastMember`, Codable-Migration, Bewertungslogik.  
   Risiko: Zentraler Typ mit hoher Änderungsblast-radius; jede Modelländerung betrifft Persistenz, Sync und UI.

4. **365 Zeilen — `filmfreaks/Stats/StatsSnapshotBuilder.swift`**  
   Zweck: Statistische Aggregation für den Stats-Screen.  
   Risiko: Performance-sensitiv; komplexe Aggregationslogik; Änderungen können Korrektheit und Laufzeit treffen.

5. **355 Zeilen — `filmfreaks/Stats/StatsView+Cards.Leaderboards.swift`**  
   Zweck: UI-Karten für Leaderboards.  
   Risiko: Große UI-Datei mit hoher Layout-/Daten-Kopplung; mühsam zu warten.

6. **343 Zeilen — `filmfreaks/PersistenceManager.swift`**  
   Zweck: File-Persistenz, Debounce, Migration, Group-Scoping, Test-Hooks.  
   Risiko: Datenverlust-/Korruptions-Risiko bei Fehlern; zentrale Persistenzkomponente.

7. **339 Zeilen — `filmfreaks/MovieDetail/MovieDetailView.swift`**  
   Zweck: Haupt-Detailscreen eines Films.  
   Risiko: Hohe UI-Zustandsdichte; Detailregressionen wahrscheinlich.

8. **335 Zeilen — `filmfreaks/CloudKitUserStore.swift`**  
   Zweck: CloudKit-CRUD/Migration für Gruppenmitglieder.  
   Risiko: Legacy-Formate, CloudKit-Konflikte und Record-Naming in einer Datei.

9. **333 Zeilen — `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift`**  
   Zweck: Debounced batched writes für Events, Responses, Activity.  
   Risiko: Mehrere Pending-Queues, Gruppenrouting, Retry-Semantik; aktuell ohne persistente Queue.

10. **332 Zeilen — `filmfreaks/CloudKitMovieStore/CloudKitMovieStore+Modify.swift`**  
    Zweck: Save/Delete, Batch-Modify, Merge-Konflikte für Filme.  
    Risiko: Datenintegrität bei Konflikten; CloudKit-spezifische Komplexität.

11. **314 Zeilen — `filmfreaks/MovieSearch/MovieSearchView/MovieSearchView.swift`**  
    Zweck: Suchscreen, Scanner, Sheets, Result-State, Leerlauf/Loading/Error/UI.  
    Risiko: Viele lokale Zustände; UI- und State-Maschine eng gekoppelt.

12. **314 Zeilen — `filmfreaks/Content/ContentMainAreaView.swift`**  
    Zweck: Hauptlisten/Grid/Empty/Error-Zustände im Root-Screen.  
    Risiko: Zentrale Sichtbarkeit vieler App-Daten; Invalidations teuer.

13. **297 Zeilen — `filmfreaks/MovieNights/Calendar/MovieNightCalendarView.swift`**  
    Zweck: Filmabend-Kalender mit Refresh, Selection, Sheets.  
    Risiko: Screen-State + Sync + Snapshot-Ableitungen gemischt.

14. **293 Zeilen — `filmfreaks/Goals/CustomGoals/CustomGoalEditorView.swift`**  
    Zweck: Editor-UI für alle Goal-Typen.  
    Risiko: Viele Regelzweige und Eingabepfade in einem Screen.

15. **288 Zeilen — `filmfreaks/Content/ContentView.swift`**  
    Zweck: Root-Shell der App.  
    Risiko: Zentrale Navigation + Header + Content-State; jede Änderung kann global wirken.

## Hot Path Analyse

### Rendering / Scrolling

#### 1) Root-Screen hat viele Lifecycle-Trigger

**Datei:** `filmfreaks/Content/ContentView+Lifecycle.swift`

**Grund**
- viele `.onReceive` und `.onChange`
- mehrere Trigger rufen dieselben Update-Methoden auf
- potenziell exzessive View-Invalidation durch häufiges Neuaufbauen abgeleiteter Modelle

**Konkrete Beobachtung**
- Änderungen an `movies`, `backlogMovies`, `activityByGroup`, Suchtexten, Filter, Sortierung, Rating-Modus, Gruppen-ID, Gruppenname, Nutzeranzahl triggern Updates
- es gibt bereits Builder-Modelle, aber die Trigger-Dichte bleibt hoch

**Einschätzung**
- Kein klassischer „Fetch im body“
- Aber ein Koordinations-Hotspot mit Risiko für unnötige Rebuilds

#### 2) Hauptlisten-/Grid-Screen bleibt State-dicht

**Dateien**
- `filmfreaks/Content/ContentView.swift`
- `filmfreaks/Content/ContentMainAreaView.swift`

**Grund**
- zentrale Anzeige für mehrere Modi
- Listen-/Grid-Ausgabe hängt von vielen Eingaben ab
- Filter, Sortierung, Suchtext und Anzeigeeinstellungen invalidieren gemeinsam

**Positives Gegenmuster**
- `ContentMovieItemsModel` und `ContentMovieItemsSnapshotBuilder` verschieben teurere Ableitungen aus dem Body

**Restrisiko**
- viele Trigger und viele abhängige Inputs können trotzdem Recompute-Frequenz erhöhen

#### 3) Stats-Building ist bewusst ausgelagert, aber nicht kostenlos

**Dateien**
- `filmfreaks/Stats/StatsViewModel.swift`
- `filmfreaks/Stats/StatsSnapshotBuilder.swift`
- `filmfreaks/PersonPopularityStore.swift`

**Grund**
- heavy aggregation
- Sortierung/Popularitätsanreicherung
- volle `Inputs`-Struktur ist `Equatable`, enthält komplette `[Movie]` und `[User]`

**Hotspot-Grund konkret**
- große Arrays werden auf Gleichheit verglichen
- Snapshot wird detached gebaut
- danach Popularity-Preload
- danach erneute Sortierung

**Einschätzung**
- Pattern ist grundsätzlich gut
- bei großen Libraries und häufigen State-Änderungen bleibt es kostenrelevant

#### 4) Timeline ist günstiger, aber weiterhin builder-getrieben

**Dateien**
- `filmfreaks/Timeline/TimelineViewModel.swift`
- `filmfreaks/Timeline/TimelineSnapshotBuilder.swift`

**Grund**
- reine Snapshot-Ableitung
- weniger offensichtliche Nebenwirkungen als Stats

**Einschätzung**
- aktuell eher moderat riskant
- gut testbar, solange Builder rein bleibt

#### 5) Movie Detail lädt externe Daten neben UI-State

**Dateien**
- `filmfreaks/MovieDetail/MovieDetailView.swift`
- `filmfreaks/MovieDetail/MovieDetailLoadCoordinator.swift`

**Grund**
- Details, Watch Provider, Region-Sensitivität, Credits, Bewertungsdarstellung
- potenziell mehrere asynchrone Ladepfade pro Detailscreen

**Hotspot-Grund konkret**
- externer I/O auf UI-kritischem Screen
- Region- oder Reload-abhängige Neu-Ladungen

### Sync / Storage

#### 1) `MovieStore+CloudSync` ist der zentrale Sync-Hotspot

**Datei:** `filmfreaks/MovieStore/MovieStore+CloudSync.swift`

**Grund**
- mischt:
  - Throttling
  - Routing-Schutz
  - Fetch-Strategie (zone changes vs full fetch)
  - Initial-Upload
  - lokale Ratings konservieren
  - Cloud-Ratings mergen
  - Gruppenwechsel-Schutz
  - lokale Persistenz nach Cloud-Apply

**Hotspot-Grund konkret**
- heavy merge
- MainActor contention
- hoher Verantwortungsumfang
- Fehler hier betreffen fast die ganze App

#### 2) File-Persistenz ist solide, aber zentral und empfindlich

**Datei:** `filmfreaks/PersistenceManager.swift`

**Stärken**
- group-scoped
- atomic writes
- Debounce
- Tests vorhanden
- Migrationspfad vorhanden

**Risiken**
- eine zentrale Klasse für mehrere Datenarten
- `UserDefaults`-Migration und File-I/O gemeinsam
- keine strukturierte Metrik/Telemetry, hauptsächlich Fehlerlogging

#### 3) Movie Nights nutzen eigenen Snapshot-Store

**Datei:** `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`

**Stärken**
- Actor-isoliert
- Snapshot schema-versioniert
- simple API

**Risiken**
- ein File für alle Gruppen
- keine inkrementelle lokale Persistenz
- bei stark wachsender Aktivität kann Snapshot unnötig groß werden

#### 4) Pending Cloud Writes sind nicht persistent

**Dateien**
- `filmfreaks/MovieCloudSyncCoordinator.swift`
- `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift`

**Grund**
- Pending-Queues liegen nur im RAM
- bei App-Terminierung vor Flush droht Änderungsverlust

**Hotspot-Grund konkret**
- offline mutation + app kill + kein rehydrierbarer outbox state

#### 5) Group-Refresh fannt in weitere Aufgaben aus

**Dateien**
- `filmfreaks/CloudKitGroupStore/CloudKitGroupStore.swift`
- `filmfreaks/CloudKitGroupStore/CloudKitGroupStore+Sharing.swift`
- `filmfreaks/CloudKit/CloudKitActivitySubscriptionManager.swift`

**Grund**
- `refresh()` lädt Gruppen
- persistiert `GroupContext`
- startet Subscription-Setup
- startet Share-Hierarchy-Repair pro Owned Group

**Hotspot-Grund konkret**
- potenzieller Burst an CloudKit-Arbeit
- schwer zu beobachten, weil Nebenarbeiten via `Task` ausgelagert werden

#### 6) Push-Fetch-Verhalten wirkt Release-abgeschnitten

**Datei:** `filmfreaks/CloudKit/CloudKitActivityPushFetchCoordinator.swift`

**Beobachtung**
- `fetchAndHandle(userInfo:)` führt Logik nur unter `#if DEBUG` aus
- außerhalb davon `return false`

**Risiko**
- Push-basierte Aktivitätsbenachrichtigungen funktionieren in Release sehr wahrscheinlich nicht
- falls beabsichtigt, fehlt Dokumentation
- falls unbeabsichtigt, ist das ein echter Produktionsdefekt

### Concurrency

#### 1) Viele UI-nahe Stores auf `@MainActor`

**Dateien**
- `filmfreaks/MovieStore/MovieStore.swift`
- `filmfreaks/Users+Store/UserStore.swift`
- `filmfreaks/MovieNights/MovieNightStore/MovieNightStore.swift`
- `filmfreaks/Goals/GoalsStore.swift`
- `filmfreaks/Stats/StatsViewModel.swift`
- `filmfreaks/Timeline/TimelineViewModel.swift`

**Vorteil**
- einfacheres Thread-Sicherheitsmodell

**Nachteil**
- Gefahr von MainActor contention, wenn zu viel Datenaufbereitung direkt im Store verbleibt

#### 2) Teure Arbeit wird teilweise korrekt ausgelagert

**Dateien**
- `filmfreaks/Stats/StatsViewModel.swift`
- `filmfreaks/Timeline/TimelineViewModel.swift`

**Gut**
- `Task.detached` für Snapshot-Building
- Generation-Tokens gegen veraltete Ergebnisse

**Restrisiko**
- Input-Vergleich und finaler Apply bleiben MainActor-nah
- Zusatzschritte wie Popularity-Preload hängen wieder an weiterer Async-Koordination

#### 3) Debounced Flush-Tasks ohne persisted lifecycle

**Dateien**
- `filmfreaks/MovieCloudSyncCoordinator.swift`
- `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift`
- `filmfreaks/AppRefreshCoordinator.swift`

**Gut**
- Koalescing vorhanden
- Parallelität wird begrenzt
- Re-Run-Semantik in `AppRefreshCoordinator` sauber

**Risiko**
- Task-Lebensdauer endet mit Prozess
- keine Wiederaufnahme nach App-Neustart

#### 4) Gruppenwechsel während Fetch wird berücksichtigt

**Datei:** `filmfreaks/MovieStore/MovieStore+CloudSync.swift`

**Gut**
- Ergebnisse werden verworfen, wenn `currentGroupId` während des Loads wechselt

**Nutzen**
- reduziert falsche UI-Anzeige der falschen Gruppe

#### 5) `MovieNightLocalPersistence` ist Actor-isoliert

**Datei:** `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`

**Gut**
- saubere Serialisierung des lokalen Snapshot-Zugriffs

#### 6) Push-/DeepLink-Refresh kann mehrere Stores gleichzeitig triggern

**Dateien**
- `filmfreaks/Content/ContentView+DeepLink.swift`
- `filmfreaks/filmfreaksApp.swift`

**Risiko**
- parallele Refreshes auf MovieStore/UserStore/MovieNightStore/GroupStore
- aktuell kein zentraler, stores-übergreifender Refresh-Trace

## Refactor Map

### Konkrete Splits

#### 1) `MovieStore+CloudSync.swift` weiter zerlegen

**Heute**
- eine Datei mit Setup, Refresh, Fetch-Strategie, Merge, Ratings, Apply, Retry, Sync-State

**Zielschnitt**
- `MovieStore+CloudRefresh.swift`
- `MovieStore+CloudMerge.swift`
- `MovieStore+CloudRatings.swift`
- `MovieStore+CloudApply.swift`
- `MovieStore+CloudRetry.swift`

**Nutzen**
- kleinere Testoberflächen
- klarere Fehlerlokalisierung
- gezieltere Off-Main-Auslagerung einzelner Schritte

#### 2) `Movie.swift` aufteilen

**Heute**
- Kernmodell + Nested Types + Migration + Bewertungshelper in einer Datei

**Zielschnitt**
- `Movie.swift` nur Kernmodell
- `Movie+Ratings.swift`
- `Movie+CastMigration.swift`
- `Rating.swift`
- `CastMember.swift`

**Nutzen**
- geringerer Merge-Konflikt
- Modelländerungen isolierbarer

#### 3) `ViewingCustomGoal.swift` aufteilen

**Heute**
- Modell, Regeln, Payload, Legacy-Migration, Serialisierung

**Zielschnitt**
- `ViewingCustomGoal.swift`
- `ViewingCustomGoalRule.swift`
- `ViewingCustomGoalsPayload.swift`
- `ViewingCustomGoal+LegacyMigration.swift`

**Nutzen**
- bessere Lesbarkeit
- zielgerichtete Tests für Regeln vs. Migration

#### 4) `MovieNightCalendarView.swift` reduzieren

**Heute**
- Screen-State, Refresh, Snapshot-Aufbau, Sheet-Steuerung

**Zielschnitt**
- `MovieNightCalendarView.swift`
- `MovieNightCalendarView+Sheets.swift`
- `MovieNightCalendarView+Actions.swift`
- `MovieNightCalendarViewModel.swift` oder zumindest lokaler Coordinator

**Nutzen**
- weniger UI-State-Dichte in einer Datei

#### 5) `MovieSearchView.swift` in State/Presentation trennen

**Heute**
- sehr viel lokaler View-State

**Zielschnitt**
- Präsentations-SubViews
- klarer State-Container
- Scanner-/Search-Routing entflechten

### Cache- / Index-Ideen

#### 1) Persistente Outbox für Cloud-Writes

**Heute**
- nur RAM-Queues

**Vorschlag**
- pro Gruppe Outbox-Datei
- Struktur:
  - saves
  - deletes
  - version
  - enqueuedAt
- beim App-Start rehydrieren und flushen

**Invalidation**
- nach erfolgreichem Batch einzelne Einträge entfernen
- bei Konflikt gezielt behalten

#### 2) Hash-/Fingerprint-basierte Derived-State-Invalidation für Content

**Heute**
- viele Trigger, direkte `updateMovieItemsModel()`-Aufrufe

**Vorschlag**
- kompakten Input-Fingerprint bilden aus:
  - groupId
  - counts
  - relevant timestamps
  - active filters
  - search text
  - rating mode
- nur neu berechnen, wenn Fingerprint sich ändert

#### 3) Persistenznahe Caches für Movie Night Snapshots pro Gruppe

**Heute**
- ein Gesamtsnapshot-File

**Vorschlag**
- `movieNights/<groupId>.json`
- optional eigenes Activity-File
- reduziert Schreib- und Ladevolumen pro Änderung

#### 4) CloudKit-Refresh-Metrik-Cache

**Vorschlag**
- letzte Dauer, letzte Fetch-Art (full vs delta), last changed count
- im Settings-/Debug-Screen sichtbar machen

### Vereinheitlichungen

#### 1) Sync-Protokolle ausweiten

**Heute**
- `GoalsStore` nutzt `GoalsCloudSyncing`
- andere Stores sprechen konkrete CloudKit-Typen direkt an

**Vorschlag**
- Protokolle für:
  - Movies
  - Ratings
  - Users
  - Movie Nights
- Ziel: bessere Testbarkeit, weniger harte CloudKit-Kopplung

#### 2) Gemeinsames Sync-Status-Modell

**Heute**
- MovieStore, UserStore und MovieNightStore haben jeweils eigene Sync-Metadatenformen

**Vorschlag**
- vereinheitlichte Struktur für:
  - pending count
  - last success
  - last attempt
  - last error
  - scope/group

#### 3) Logger-Standard statt `print`

**Heute**
- gemischt: `Logger` in `PersistenceManager`, sonst häufig `print`

**Vorschlag**
- strukturierte Kategorien:
  - sync
  - routing
  - persistence
  - push
  - tmdb
  - ui-performance

#### 4) Builder-Pattern konsequenter dokumentieren

**Heute**
- faktisch im Einsatz, aber nicht dokumentiert

**Vorschlag**
- als Projektkonvention festhalten:
  - heavy derivation nicht im Body
  - pure snapshot builder bevorzugen
  - Ergebnisse testbar halten

## Risiken & Edge Cases

### Datenverlust / Persistenz

- Pending Cloud Writes nur im RAM  
  Risiko: lokale Änderungen gehen bei App-Kill verloren.

- Mehrere Persistenzmechanismen parallel  
  `Application Support` + `UserDefaults` + CloudKit + separate Movie-Night-Datei.  
  Risiko: Inkonsistente Wiederherstellung bei partiellen Fehlern.

- `Movie` enthält lokal Ratings, Cloud speichert Ratings separat  
  Risiko: Merge-Fehler könnten Ratings doppelt/fehlend erscheinen lassen, wenn Reconciliation fehlschlägt.

### Migration

- Legacy-Cast-Migration in `Movie`
- Legacy-User-Migration in `CloudKitUserStore`
- alte `UserDefaults`-Datenmigration in `PersistenceManager`
- MovieNight Snapshot v1/v2

**Risiko**
- Jede Modelländerung mit Persistenzbezug braucht expliziten Backward-Compatibility-Plan.

### Offline / Multi-Device / Sharing

- UUID-artige Gruppen ohne `GroupContext` dürfen nicht auf Public DB fallen  
  gut geschützt, aber Fehler dort blockieren Sync komplett.

- Teilnehmer in Shared Groups sehen nur Daten, die unter dem Root-Record hängen  
  daher existiert Share-Hierarchy-Repair.

- Multi-Device-Konflikte landen in CloudKit-Merge-Logik  
  vor allem kritisch in:
  - `CloudKitMovieStore+Modify.swift`
  - `CloudKitRatingStore+Modify.swift`
  - `CloudKitMovieNightStore+Modify.swift`

### Push / Notifications

- Push-Fetch in Release vermutlich deaktiviert
- Notification-Suppression basiert auf globaler Best-Effort-Benutzeridentität
- **UNKNOWN**: Wie zuverlässig die Identität in Multi-User-Wechseln auf einem Gerät real gehalten werden soll

### UI / State

- Gruppenwechsel während laufender Requests ist berücksichtigt, aber nicht überall gleich sichtbar dokumentiert
- viele Sheets/Stacks im Content-Screen erhöhen Routing-Komplexität
- `AddMovieView.swift` scheint unreferenziert; wenn doch indirekt genutzt, fehlt die Dokumentation

## Observability / Debuggability

### Ist-Zustand

Positiv:
- Es gibt dedizierte Tests für viele Builder und Persistenzpfade
- `PersistenceManager` nutzt `Logger`
- Push-Fetch loggt Details in DEBUG

Schwach:
- viele `print`-Statements statt strukturierter Logs
- kein einheitlicher Sync-Trace über mehrere Stores hinweg
- keine Metrik über Delta-Fetch-Dauern, Queue-Größen, Merge-Konflikte
- kein sichtbarer zentraler Debug-Screen für CloudKit-Routing oder Pending-Outbox

### Was ich ergänzen würde

1. **Einheitliche Logging-Kategorien**
   - `sync.movies`
   - `sync.users`
   - `sync.movienights`
   - `cloud.routing`
   - `cloud.push`
   - `persistence.files`
   - `tmdb.api`

2. **Refresh Trace ID**
   - pro Foreground-Refresh / Pull-to-refresh / Push-Refresh eine ID
   - alle beteiligten Stores loggen mit

3. **Settings-Debugsektion**
   - aktuelle `groupId`
   - `GroupContext`
   - DB/Zone-Routing-Ergebnis
   - pending outbox size
   - last sync error
   - last delta token timestamp **UNKNOWN**, falls nicht verfügbar

4. **Merge-Konflikt-Zähler**
   - wie oft `serverRecordChanged` auftritt
   - wie oft Retrys nötig waren

### Wie Probleme reproduzierbar werden

- Offline gehen
- lokale Änderung machen
- App killen
- wieder online starten  
  -> validiert Outbox-/Persistenz-Verhalten

- Gruppe wechseln, während Cloud-Fetch läuft  
  -> validiert Apply-Guard

- Shared Group erstellen, Teilnehmer beitreten lassen, Alt-Daten prüfen  
  -> validiert Share-Hierarchy-Repair

- Push-Ereignis in Debug und Release prüfen  
  -> validiert `CloudKitActivityPushFetchCoordinator`

## Open Questions

- **UNKNOWN**: Soll die Legacy/Public-DB-Strategie langfristig beibehalten werden oder ist vollständige Migration auf zone-based sharing geplant?
- **UNKNOWN**: Ist das `#if DEBUG` in `CloudKitActivityPushFetchCoordinator.fetchAndHandle` bewusst als temporärer Guard gesetzt oder ein versehentlich verbliebener Zustand?
- **UNKNOWN**: Gibt es externe CloudKit-Schema-Migrationsskripte oder erfolgt alles implizit aus der App?
- **UNKNOWN**: Gibt es Anforderungen an Konfliktauflösung, die über den aktuellen „best effort“-Ansatz hinausgehen?
- **UNKNOWN**: Wie groß können Movie-Night-Aktivitätsfeeds realistisch werden, und reicht ein einzelnes Snapshot-File dann noch?
- **UNKNOWN**: Ist `AddMovieView.swift` absichtlich legacy/unreferenziert?
- **UNKNOWN**: Gibt es produktive Telemetrie/Crash-Reporting außerhalb des Projekt-Zips?

## First 3 Refactors I would do (P0)

### 1) `MovieStore`-CloudSync entflechten und partielle Arbeit off-main vorbereiten

- **Ziel**  
  Den größten Sync-Hotspot in klar getrennte Verantwortungsblöcke zerlegen und Merge-/Reconciliation-Schritte isolierbar machen.

- **Betroffene Dateien**
  - `filmfreaks/MovieStore/MovieStore+CloudSync.swift`
  - ggf. neue Dateien:
    - `MovieStore+CloudRefresh.swift`
    - `MovieStore+CloudMerge.swift`
    - `MovieStore+CloudRatings.swift`
    - `MovieStore+CloudApply.swift`

- **Risiko**  
  Mittel. Sync-Verhalten ist sensibel; gute Tests nötig.

- **Erwarteter Nutzen**  
  Höhere Wartbarkeit, bessere Testbarkeit, geringeres Risiko für MainActor-Überlastung, sauberere Fehlersuche.

### 2) Persistente Outbox für Movie- und MovieNight-Sync einführen

- **Ziel**  
  Lokale Änderungen dürfen nicht verloren gehen, wenn die App vor dem Flush beendet wird.

- **Betroffene Dateien**
  - `filmfreaks/MovieCloudSyncCoordinator.swift`
  - `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift`
  - neue Outbox-Persistenzdateien
  - ggf. Store-Init-Dateien zur Rehydrierung

- **Risiko**  
  Mittel bis hoch. Outbox-Design und Konfliktbereinigung müssen sauber sein.

- **Erwarteter Nutzen**  
  Deutlich robusteres Offline-/Reconnect-Verhalten; weniger potenzieller Datenverlust.

### 3) Content-Lifecycle und Derived-State-Trigger koaleszieren

- **Ziel**  
  Recompute-Frequenz und Invalidations im Root-Screen reduzieren, ohne die bestehende Snapshot-Builder-Architektur aufzugeben.

- **Betroffene Dateien**
  - `filmfreaks/Content/ContentView+Lifecycle.swift`
  - `filmfreaks/Content/ContentView+DerivedState.swift`
  - `filmfreaks/Content/ContentMovieItemsModel.swift`
  - `filmfreaks/Content/ContentActivityPreviewModel.swift`

- **Risiko**  
  Niedrig bis mittel. Gefahr v. a. in verpassten Update-Fällen.

- **Erwarteter Nutzen**  
  Ruhigerer Root-Screen, weniger unnötige Rebuilds, besser nachvollziehbarer Triggerpfad.
