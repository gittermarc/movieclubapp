# PROJECT_CONTEXT.md

## TL;DR
`filmfreaks` ist eine iOS/iPadOS-App für gemeinsame Film-Listen, Bewertungen, Gruppen-Sharing, Ziele, Timeline, Statistiken und Filmabend-Planung. Produktname/Binary ist `filmfreaks`, die Haupt-UI nennt sich in `filmfreaks/Content/ContentView.swift` aber „The Movie Club“. Deployment Target ist iOS 26.0, Gerätetypen sind iPhone + iPad (`filmfreaks.xcodeproj/project.pbxproj`). Persistenz ist **nicht** SwiftData/CoreData, sondern eine Mischung aus JSON-Dateien in Application Support, `UserDefaults` für kleine Metadaten/Settings und CloudKit für Sync/Sharing (`filmfreaks/PersistenceManager.swift`, `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`, `filmfreaks/CloudKitRouting.swift`).

---

## Key Concepts / Domänenbegriffe

- **Movie**: Zentrales Domänenobjekt für gesehenen Film oder Backlog-Eintrag. Enthält Titel, Jahr, Ratings, TMDb-Metadaten, Cast/Directors, Gruppenbezug und Activity-Metadaten (`filmfreaks/Movie.swift`).
- **Rating**: Nutzerbewertung pro Film mit Kriterien-Scores, optionalem Fazit-Score und stabiler Reviewer-Identität (`filmfreaks/Movie.swift`).
- **Group / GroupContext**: Routing-Metadaten für CloudKit-Zonen und DB-Scope (private/shared). Der eigentliche Persistenzanker für Sharing (`filmfreaks/GroupContext.swift`).
- **MovieStore**: Hauptstore für gesehene Filme, Backlog, aktuelle Gruppe und Cloud-Sync-Status (`filmfreaks/MovieStore/MovieStore.swift`).
- **UserStore**: Gruppen-Mitglieder und aktive Nutzerselektion pro Gruppe (`filmfreaks/Users+Store/UserStore.swift`).
- **Goals**: Jahresziele und flexible Custom Goals für Jahrzehnt, Person, Regie, Genre oder Keyword (`filmfreaks/Goals/GoalsStore.swift`, `filmfreaks/ViewingCustomGoal.swift`).
- **Movie Night**: Vorschläge/Antworten/Aktivitäten für gemeinsame Filmabende, lokal persistent und optional via CloudKit synchronisiert (`filmfreaks/MovieNights/*`).
- **Activity**: Aus Movies, Ratings und Movie-Night-Aktivitäten abgeleitete Gruppenereignisse für Header/Feed/Notifications (`filmfreaks/Content/UnifiedGroupActivityEvent.swift`, `filmfreaks/Notifications/*`).
- **DisplaySettings**: Lokale UI- und Dichte-Einstellungen, komplett in `UserDefaults` abgelegt (`filmfreaks/Settings/DisplaySettings/*`).
- **TMDbAPI**: Externe Datenquelle für Suche, Details, Personen, Genres und Watch Provider (`filmfreaks/TMDbAPI/*`).

---

## Architecture Map

### 1) App / Entry
- `filmfreaks/filmfreaksApp.swift`
  - erstellt zentrale `@StateObject`s: `MovieStore`, `MovieNightStore`, `UserStore`, `CloudKitGroupStore`, `NetworkMonitor`, `DisplaySettings`, `AppRefreshCoordinator`
  - setzt globalen `URLCache`
  - stößt beim Wechsel auf `.active` eine Refresh-Kaskade an
- `filmfreaks/CloudKitShareAppDelegate.swift`
  - registriert Notifications
  - verarbeitet CloudKit-Remote-Notifications
  - verdrahtet `CloudKitShareSceneDelegate`
- `filmfreaks/CloudKitShareSceneDelegate.swift`
  - nimmt CloudKit-Share-Invites und Push-Deep-Links im Scene-Lifecycle entgegen

### 2) Presentation / Screens
- `filmfreaks/Content/*`
  - Root-Screen, Routing, Header, Listen/Grid, Activity-Preview, Onboarding
- `filmfreaks/MovieDetail/*`
  - Detailansicht für lokale Filme
- `filmfreaks/SearchResultDetail/*`
  - Detailansicht für TMDb-Suchergebnisse
- `filmfreaks/MovieSearch/*`
  - TMDb-Suche, Empfehlungen, OCR/Scanner-Helfer, Result-Sorting
- `filmfreaks/Goals/*`
  - Ziele-UI, Editor, Matching, Persistenz-Brücken
- `filmfreaks/Stats/*`
  - Statistikscreen, Snapshot/ViewModel, Drilldowns
- `filmfreaks/Timeline/*`
  - chronologische Darstellung gesehener Filme
- `filmfreaks/MovieNights/*`
  - Kalender, Sheets, Planungsflows
- `filmfreaks/Settings/*`
  - Darstellung, Cache, Gruppenverwaltung, Sync-Präsentation
- `filmfreaks/Users+Store/UsersView.swift`
  - Mitgliederverwaltung

### 3) App State / Stores
- `filmfreaks/MovieStore/*`
  - lokaler Cache, Gruppenauswahl, Cloud-Sync, Rating-Sync, Pending-State
- `filmfreaks/Users+Store/*`
  - Mitglieder, Auswahl des aktiven Users, Sync-Status
- `filmfreaks/Goals/GoalsStore.swift`
  - Zielzustand + lokaler/Cloud-Sync
- `filmfreaks/MovieNights/MovieNightStore.swift`
  - Movie-Night-Zustand + Upload/Refresh + lokale Persistenz
- `filmfreaks/CloudKitGroupStore/*`
  - Gruppen anlegen, laden, teilen, verlassen, löschen
- `filmfreaks/Settings/DisplaySettings/*`
  - rein lokaler UI-Zustand

### 4) Persistence / Integration
- `filmfreaks/PersistenceManager.swift`
  - JSON-Dateien in Application Support, gruppenspezifisch, debounced writes
- `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`
  - eigener JSON-Snapshot für Movie Nights
- `filmfreaks/GroupContext.swift`
  - `UserDefaults`-Persistenz für CloudKit-Routing-Metadaten
- `filmfreaks/SelectedUserSelectionStore.swift`
  - aktive Userwahl pro Gruppe in `UserDefaults`
- `filmfreaks/Notifications/*`
  - Notification-Dedupe, Current-User-Identität, Deep-Link-Routing
- `filmfreaks/TMDbAPI/*`
  - HTTP-Layer und Decoding für TMDb

### 5) Cloud Sync Layer
- `filmfreaks/CloudKitRouting.swift`
  - zentrale Entscheidung Public vs Private vs Shared DB + Zone
- `filmfreaks/CloudKitMovieStore/*`
  - Movie-Records
- `filmfreaks/CloudKitRatingStore/*`
  - getrennte Rating-Records
- `filmfreaks/CloudKitMovieNightStore/*`
  - Movie-Night Event/Response/Activity Records
- `filmfreaks/CloudKitUserStore.swift`
  - GroupMember-Records
- `filmfreaks/CloudKitGoalStore.swift`
  - ViewingGoal + ViewingCustomGoals Records
- `filmfreaks/CloudKitZoneChanges.swift`
  - inkrementelle Zone-Change-Reads
- `filmfreaks/CloudKitZoneChangeTokenStore.swift`
  - Change-Token-Speicherung in `UserDefaults`

### Abhängigkeitsrichtung
- Views hängen an Stores/Models, nicht direkt an CloudKit-Stores.
- Stores hängen an lokaler Persistenz + CloudKit-Stores.
- CloudKit-Stores hängen an `CloudKitRouting` + `GroupContextStore`.
- Notification-Flows hängen an CloudKit-Push → Summary-Decoding → Local Notification → Deep-Link-NotificationCenter.

---

## Folder Map

### Root-Dateien in `filmfreaks/`
- `filmfreaks/filmfreaksApp.swift`: App-Einstieg und globale Dependency-Wiring
- `filmfreaks/PersistenceManager.swift`: JSON-Persistenz für Movies/Backlog/Users
- `filmfreaks/Movie.swift`: Kernmodell Film + Rating + CastMember
- `filmfreaks/ViewingCustomGoal.swift`: Custom-Goal-Domäne
- `filmfreaks/GroupContext.swift`: CloudKit-Gruppenrouting
- `filmfreaks/AppRefreshCoordinator.swift`: Debounced App-Resume-Refresh
- `filmfreaks/SelectedUserSelectionStore.swift`: aktive Userwahl pro Gruppe

### Unterordner
- `filmfreaks/Content/`: Root-UI, Header, Listen, Activity-Preview, Routing
- `filmfreaks/MovieStore/`: Filmstore nach Verantwortung gesplittet
- `filmfreaks/Users+Store/`: Userstore, Views, Fehlerformatierung
- `filmfreaks/Goals/`: Ziele-UI + Store + Editoren
- `filmfreaks/Stats/`: Snapshot/ViewModel/Card-UI
- `filmfreaks/Timeline/`: Timeline-Snapshot + Views
- `filmfreaks/MovieSearch/`: Suche, Empfehlungen, Kandidatenhilfe
- `filmfreaks/MovieDetail/`: lokale Film-Detailansicht
- `filmfreaks/SearchResultDetail/`: TMDb-Detailansicht vor dem Hinzufügen
- `filmfreaks/MovieNights/`: Planung, Kalender, Persistenz, Sync
- `filmfreaks/Settings/`: App-Settings + Gruppenverwaltung + Sync-Anzeige
- `filmfreaks/TMDbAPI/`: API-Client und Modelle
- `filmfreaks/CloudKit*/`: pro Domäne getrennte CloudKit-Zugriffsschicht
- `filmfreaks/Notifications/`: lokale Notification-Verarbeitung
- `filmfreaks/CloudKit/`: Push-Fetch, Subscription-Management, Debugging

### Tests
- `filmfreaksTests/Persistence/*`: Persistenz und Legacy-Fixture-Decoding
- `filmfreaksTests/Content/*`: Snapshot-Builder-Tests für Listen/Activity
- `filmfreaksTests/Goals/*`: GoalsStore
- `filmfreaksTests/Timeline/*`: Timeline-Snapshot
- `filmfreaksTests/MovieSearch/*`: Suchzustand/Sorting
- `filmfreaksTests/CloudRouting/*`: Routing, Tokens, GroupContext
- `filmfreaksTests/UserStore/*`: Fehlerformatierung

---

## Data Model Map

### `Movie` (`filmfreaks/Movie.swift`)
Wichtige Felder:
- `id: UUID`
- `title: String`
- `year: String`
- `tmdbId: Int?`
- `tmdbRating: Double?`
- `ratings: [Rating]`
- `posterPath: String?`
- `watchedDate: Date?`
- `watchedLocation: String?`
- `genres: [String]?`, `genreIds: [Int]?`
- `keywords: [String]?`, `keywordIds: [Int]?`
- `cast: [CastMember]?`
- `directors: [CastMember]?`
- `suggestedBy: String?`
- `addedAt`, `addedById`, `addedByName`
- `groupId`, `groupName`

Beziehungen:
- 1 `Movie` → n `Rating`
- 1 `Movie` → n `CastMember` (Cast)
- 1 `Movie` → n `CastMember` (Directors)
- Gruppenbezug nur logisch per `groupId`, nicht als ORM-Relationship

Migrationen:
- Legacy-`cast: [String]` wird in `CastMember` migriert
- Legacy-Ratings ohne `reviewerId` bleiben toleriert

### `Rating` (`filmfreaks/Movie.swift`)
Wichtige Felder:
- `id: UUID`
- `reviewerId: UUID?`
- `reviewerName: String`
- `scores: [RatingCriterion: Int]`
- `comment: String?`
- `fazitScore: Int?`
- `updatedAt: Date?`

Hinweis:
- lokal eingebettet in `Movie.ratings`
- in CloudKit separat als `MovieRating` gespeichert (`filmfreaks/CloudKitRatingStore/CloudKitRatingStore+Schema.swift`)

### `User` (`filmfreaks/Users+Store/User.swift`)
- `id: UUID`
- `name: String`

### `GroupContext` (`filmfreaks/GroupContext.swift`)
- `id: String`
- `name: String`
- `scope: GroupScope` (`private`/`shared`)
- `zoneName: String`
- `ownerName: String`

### `ViewingCustomGoal` (`filmfreaks/ViewingCustomGoal.swift`)
- `id: UUID`
- `type: ViewingCustomGoalType`
- `rule: ViewingCustomGoalRule`
- `target: Int`
- `createdAt: Date`
- `startYear: Int`
- `durationYears: Int`

Beziehungen:
- referenziert Personen/Genres/Keywords indirekt über IDs im `rule`
- keine harte DB-Referenz auf `Movie`

### `MovieNightEvent` (`filmfreaks/MovieNights/MovieNightEvent.swift`)
- `id: UUID`
- `groupId: String`
- `proposedStart: Date`
- `createdAt`, `updatedAt`
- `proposerUserId`, `proposerName`
- `suggestedMovie: MovieNightMovieRef?`
- `note`, `status`

### `MovieNightResponse` (`filmfreaks/MovieNights/MovieNightResponse.swift`)
- `eventId: UUID`
- `userId: UUID`
- `userName: String`
- `decision`
- `respondedAt`
- zusammengesetzte ID über `eventId + userId`

### `MovieNightActivityEvent` (`filmfreaks/MovieNights/MovieNightActivityEvent.swift`)
- `id: UUID`
- `groupId: String`
- `kind`
- `createdAt`
- `eventId`, `eventStart`
- `actorUserId`, `actorName`
- optional `decision`, `newStatus`, `note`

### Weitere strukturprägende Typen
- `GroupInfo` in `filmfreaks/MovieStore/MovieStore.swift`: lokale Merkliste bekannter Gruppen
- `StatsSnapshot` in `filmfreaks/Stats/StatsSnapshot.swift`: rein abgeleiteter Read-Model-Snapshot
- `TimelineSnapshot` in `filmfreaks/Timeline/TimelineSnapshotBuilder.swift`: rein abgeleiteter Read-Model-Snapshot

---

## Sync / Storage

### Lokale Persistenz
- **Movies / Backlog / Users**
  - JSON-Dateien unter Application Support, gruppenspezifisch in `groups/<groupId>/...`
  - Implementierung: `filmfreaks/PersistenceManager.swift`
  - Features:
    - debounced writes
    - atomic writes
    - Migration aus alten `UserDefaults`-Keys
- **Movie Nights**
  - eigener Snapshot `movieNights.json` unter Application Support
  - Implementierung: `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`
- **Kleine Zustände in `UserDefaults`**
  - `CurrentGroupId`, `CurrentGroupName`, bekannte Gruppen, Sync-Metadaten, selektierter User, DisplaySettings, Notification-Dedupe, GroupContexts, Goal-Payloads

### Cloud-Sync
- **CloudKit ist aktiv**
  - Entitlement: `filmfreaks/filmfreaks.entitlements`
  - Container: `iCloud.de.marcfechner.filmfreaks`
- **Routing-Modell**
  - kein `groupId` → Public DB
  - `GroupContext` vorhanden → Private oder Shared DB + Zone
  - UUID-artige `groupId` ohne `GroupContext` → harter Fehler statt unsicherem Public-Fallback
  - Implementierung: `filmfreaks/CloudKitRouting.swift`
- **Domänenspezifische CloudStores**
  - Movie: `filmfreaks/CloudKitMovieStore/*`
  - Rating: `filmfreaks/CloudKitRatingStore/*`
  - User: `filmfreaks/CloudKitUserStore.swift`
  - Goals: `filmfreaks/CloudKitGoalStore.swift`
  - Movie Nights: `filmfreaks/CloudKitMovieNightStore/*`
  - Groups: `filmfreaks/CloudKitGroupStore/*`
- **Inkrementelle Sync-Strategie**
  - Zone-Change-Tokens in `UserDefaults` (`filmfreaks/CloudKitZoneChangeTokenStore.swift`)
  - Zone-Deltas via `filmfreaks/CloudKitZoneChanges.swift`
- **Write-Verhalten**
  - Movies und Movie Nights nutzen debounced/batched Coordinators (`filmfreaks/MovieCloudSyncCoordinator.swift`, `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift`)
  - bei Offline→Online wird Flush getriggert
- **Push / Background-Verhalten**
  - `UIBackgroundModes = remote-notification` in `filmfreaks/Info.plist`
  - Push-Fetch-Handling in `filmfreaks/CloudKitShareAppDelegate.swift` und `filmfreaks/CloudKit/CloudKitActivityPushFetchCoordinator.swift`
  - BGTaskScheduler / BackgroundTasks-Code wurde **nicht** gefunden

### Migration / Backwards Compatibility
- `PersistenceManager` migriert alte UserDefaults-basierte Arrays nach Disk (`filmfreaks/PersistenceManager.swift`)
- `Movie` migriert Legacy-`cast` von `[String]` nach `[CastMember]` (`filmfreaks/Movie.swift`)
- `ViewingCustomGoal` toleriert fehlende `startYear`/`durationYears` (`filmfreaks/ViewingCustomGoal.swift`)
- `MovieNightLocalPersistence.Snapshot` toleriert ältere Payloads ohne `activityByGroup` (`filmfreaks/MovieNights/MovieNightLocalPersistence.swift`)

### Offline-Verhalten
- App startet aus lokalem Cache
- Cloud-Sync ist best effort und throttled
- Standard-/Lokalkontext ohne `groupId` bleibt lokal/Public-DB-orientiert
- Notification-Suppression und User-Selektion bleiben lokal erhalten

---

## UI Map

### Root
- `filmfreaks/Content/ContentView.swift`
  - Hauptscreen mit Header, Gruppenstatus, Aktivitätskarte, Modusumschaltung (`watched`/`backlog`), Sortierung, Nutzerfilter, Listen/Grid
  - Routing über Sheets in `filmfreaks/Content/ContentRouting.swift`

### Hauptflows aus `ContentRoute` (`filmfreaks/Content/ContentRouting.swift`)
- `.settings` → `filmfreaks/Settings/SettingsView.swift`
- `.quickStart` → `filmfreaks/QuickStartView.swift`
- `.movieSearch` → `filmfreaks/MovieSearch/MovieSearchView/MovieSearchView.swift`
- `.users` → `filmfreaks/Users+Store/UsersView.swift`
- `.stats` → `filmfreaks/Stats/StatsView.swift`
- `.timeline` → `filmfreaks/Timeline/TimelineView.swift`
- `.calendar` → `filmfreaks/MovieNights/Calendar/MovieNightCalendarView.swift`
- `.activity` → `filmfreaks/Content/GroupActivityListView.swift`
- `.goals` → `filmfreaks/Goals/GoalsView.swift`
- `.groupSettings` → `filmfreaks/Settings/GroupSettingsView.swift`

### Detailflows
- Movie-Liste → `NavigationLink` → `filmfreaks/MovieDetail/MovieDetailView.swift` (`filmfreaks/Content/ContentMoviesListSection.swift`)
- Search-Result → Sheet → `filmfreaks/SearchResultDetail/SearchResultDetailView.swift` (`filmfreaks/MovieSearch/MovieSearchView/MovieSearchView.swift`)
- Stats → Actor/Genre/Drilldown-Sheets (`filmfreaks/Stats/StatsView.swift`)
- Group Settings → Share-Sheet `filmfreaks/GroupShareSheetView.swift`

### Onboarding
- First-run/undismissed Quick Start über `@AppStorage("Onboarding_HasSeenQuickStart")` in `filmfreaks/Content/ContentView.swift`
- inhaltlich ausgelagert in `filmfreaks/QuickStartView.swift`

---

## Build & Configuration

### Targets
- `filmfreaks` (App)
- `filmfreaksTests` (Unit Tests)
- `filmfreaksUITests` (UI Tests)
- Quelle: `filmfreaks.xcodeproj/project.pbxproj`

### Plattform / Deployment
- `SDKROOT = iphoneos`
- `SUPPORTED_PLATFORMS = iphoneos iphonesimulator`
- `TARGETED_DEVICE_FAMILY = 1,2` → iPhone + iPad
- `IPHONEOS_DEPLOYMENT_TARGET = 26.0`
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- `SWIFT_APPROACHABLE_CONCURRENCY = YES`
- Quelle: `filmfreaks.xcodeproj/project.pbxproj`

### Info.plist / Entitlements
- `filmfreaks/Info.plist`
  - `CKSharingSupported = true`
  - `TMDB_API_KEY = $(TMDB_API_KEY)`
  - `UIBackgroundModes = [remote-notification]`
- `filmfreaks/filmfreaks.entitlements`
  - `aps-environment = development`
  - iCloud Container + CloudKit aktiviert

### xcconfig / Secrets
- `filmfreaks/Debug.xcconfig` und `filmfreaks/Release.xcconfig` includen `filmfreaks/Secrets.xcconfig`
- `filmfreaks/Secrets.xcconfig` enthält aktuell einen konkreten `TMDB_API_KEY`
- Technische Bewertung:
  - Laufzeit-Verkabelung über `Info.plist` ist sauber (`filmfreaks/TMDbAPI/TMDbAPI.swift`)
  - **aber** der Schlüssel liegt in dieser Projektkopie im Repo/Projektbaum und ist damit nicht wirklich secret

### Package Management
- Keine Swift Package Manager Dependencies gefunden
- `packageProductDependencies` in `project.pbxproj` sind leer

### Project File Handling
- Das Xcode-Projekt nutzt `fileSystemSynchronizedGroups`; neue Dateien unter den synchronisierten Root-Gruppen werden von Xcode 15+ typischerweise automatisch mitgeführt (`filmfreaks.xcodeproj/project.pbxproj`)

---

## Conventions

### Wiederkehrende Muster
- große Typen werden per `+`-Dateien nach Verantwortung gesplittet, z. B.
  - `MovieStore+CloudSync.swift`
  - `UserStore+CloudRefresh.swift`
  - `DisplaySettings+*.swift`
  - `ContentView+Lifecycle.swift`
- teure UI-Ableitungen werden aus dem Renderpfad gezogen in Snapshot-/Model-Typen:
  - `ContentMovieItemsModel` + `ContentMovieItemsSnapshotBuilder`
  - `ContentActivityPreviewModel` + `ContentActivityPreviewSnapshotBuilder`
  - `StatsViewModel` + `StatsSnapshotBuilder`
  - `TimelineSnapshotBuilder`
- Stores sind meist `@MainActor`
- reine Hilfsfunktionen müssen unter `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` explizit `nonisolated`/pure gehalten werden, sonst drohen Swift-6-artige Isolationswarnungen

### Do
- neue Logik zuerst in Builder/Store/Helper, nicht direkt in `body`
- gruppenspezifische Daten immer über `groupId` oder `GroupContext` denken
- CloudKit-Routing zentral über `CloudKitRouting` lassen
- lokale Caches vor UI-Zugriff laden, dann Cloud überschreiben lassen
- bei Performance-Themen zuerst Renderpfad prüfen: `onChange`, `onReceive`, Sorts, Array-Kopien

### Don’t
- keine direkte CloudKit-Logik in SwiftUI-Views mischen
- keine Annahme „UUID groupId = public group“; genau das verhindert `CloudKitRouting`
- keine geheimen Schlüssel in committed `Secrets.xcconfig` lassen
- keine schweren Sort/Filter/Map-Pipelines in großen `body`-Blöcken neu aufbauen

---

## How to work on this project

### Setup
1. `filmfreaks.xcodeproj` in Xcode öffnen.
2. Signing/iCloud/Push korrekt für dein Team konfigurieren.
3. `TMDB_API_KEY` über `Secrets.xcconfig` oder Environment bereitstellen (`filmfreaks/TMDbAPI/TMDbAPI.swift`).
4. App-Target `filmfreaks` bauen.
5. Unit Tests in `filmfreaksTests` ausführen.

### Wo neue Entwickler zuerst lesen sollten
- `filmfreaks/filmfreaksApp.swift`
- `filmfreaks/Content/ContentView.swift`
- `filmfreaks/MovieStore/MovieStore.swift`
- `filmfreaks/MovieStore/MovieStore+CloudSync.swift`
- `filmfreaks/Users+Store/UserStore.swift`
- `filmfreaks/GroupContext.swift`
- `filmfreaks/CloudKitRouting.swift`
- `filmfreaks/PersistenceManager.swift`

### Feature hinzufügen – empfohlener Ablauf
- **Neues UI-Feature auf Movie-Liste**
  - erst prüfen, ob es nur abgeleitete Darstellung ist → dann Snapshot/Model erweitern
  - ansonsten Store/API anpassen und View nur binden
- **Neues gruppenspezifisches Cloud-Datum**
  - Domain-Typ definieren
  - lokalen Persistenzort entscheiden
  - CloudKit-Store mit klaren Keys/RecordType bauen
  - Routing über `CloudKitRouting` / `GroupContext`
  - Tests in passendem Testordner ergänzen
- **Neue Settings**
  - in `DisplaySettings` oder eigener Settings-Präsentation ablegen
  - Persistence in `UserDefaults`
  - keine UI-seitigen magischen String-Keys verstreuen

---

## Quick Wins

1. `filmfreaks/Secrets.xcconfig`: echten TMDb-Key aus der Projektkopie entfernen und nur Template committen.
2. `filmfreaks/Settings/GroupSettingsView.swift`: aktive Group-Aktionen weiter auslagern; die View enthält noch viel Ablaufsteuerung.
3. `filmfreaks/MovieDetail/MovieDetailView.swift`: weiter in Subsections/Action-Handler splitten; Datei ist groß und multifunktional.
4. `filmfreaks/MovieSearch/MovieSearchView/MovieSearchView.swift`: State-Menge reduzieren, Such- und Empfehlungslogik weiter isolieren.
5. `filmfreaks/MovieNights/MovieNightStore.swift`: Read-API, Write-API, Retry-Handling und Sync-Status trennen.
6. `filmfreaks/Stats/StatsView.swift`: viele `onChange`-Trigger in eine konsolidierte Input-Beobachtung überführen.
7. `filmfreaks/Timeline/TimelineView.swift`: Snapshot ebenfalls in eigenes Model verlagern, analog zu Stats/Content.
8. `filmfreaks/PersistenceManager.swift`: Fehler-/Metrik-Observability ergänzen; aktuell nur Logging, aber keine sichtbare Diagnose.
9. `filmfreaks/CloudKitGroupStore/CloudKitGroupStore+Sharing.swift`: Share-Hierarchy-Repair testen und instrumentieren; potenziell teurer Pfad.
10. `filmfreaks/Notifications/*`: Push/Notification-Flows per Integrationstest oder manueller Repro-Checkliste absichern.
