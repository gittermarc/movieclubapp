# PROJECT_CONTEXT.md

## TL;DR
**filmfreaks** ist eine iPhone-/iPad-App mit sichtbarem Produktnamen **„The Movie Club“** (`filmfreaks/Content/ContentView.swift`), Deployment Target **iOS 26.0** (`filmfreaks.xcodeproj/project.pbxproj`). Die App verwaltet gruppenspezifische Film-Listen, Bewertungen, Filmabende, Statistiken und Ziele. **Wichtig:** Das Projekt nutzt **kein SwiftData/CoreData**. Persistenz und Sync basieren auf **JSON-Dateien in Application Support**, **UserDefaults** für kleine State-/Meta-Daten, **CloudKit** für Gruppen-/Sharing-Daten sowie mehrere lokale Caches (`filmfreaks/PersistenceManager.swift`, `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`, `filmfreaks/CloudKitRouting.swift`).

## Key Concepts / Domänenbegriffe
- **Movie**: Zentrales Domain-Objekt für beobachtete Filme oder Backlog-Einträge (`filmfreaks/Movie.swift`).
- **Rating**: Nutzerbewertung pro Film, lokal im `Movie.ratings` eingebettet, in CloudKit aber als eigener Record-Typ `MovieRating` gespeichert (`filmfreaks/Movie.swift`, `filmfreaks/CloudKitRatingStore/CloudKitRatingStore+Schema.swift`).
- **Group / GroupContext**: Routing-Metadaten für eine Filmgruppe. Enthält `groupId`, `scope`, `zoneName`, `ownerName` und entscheidet, ob Daten in private/shared DB + Zone oder legacy/public liegen (`filmfreaks/GroupContext.swift`, `filmfreaks/CloudKitRouting.swift`).
- **Owned Group / Shared Group**: CloudKit-Record-Sharing-Modell. Owned = private Zone des Erstellers, Shared = angenommene Share-Zone (`filmfreaks/CloudKitGroupStore/CloudKitGroupStore.swift`).
- **Default / Local Group**: Gruppe ohne `groupId` bzw. ohne routbaren `GroupContext`; nutzt lokale Dateien und legacy/public-Fallback für einzelne Cloud-Pfade (`filmfreaks/PersistenceManager.swift`, `filmfreaks/CloudKitRouting.swift`).
- **Movie Night**: Gruppenspezifische Terminplanung für Filmabende mit Event, Antwort und Activity-Stream (`filmfreaks/MovieNights/MovieNightEvent.swift`, `filmfreaks/MovieNights/MovieNightResponse.swift`, `filmfreaks/MovieNights/MovieNightActivityEvent.swift`).
- **Viewing Goal / Custom Goal**: Jahresziele und regelbasierte Sammelziele (Dekade, Person, Director, Genre, Keyword) (`filmfreaks/CloudKitGoalStore.swift`, `filmfreaks/ViewingCustomGoal.swift`, `filmfreaks/ViewingCustomGoalsPayload.swift`).
- **Content Route**: Zentrale Sheet-Routing-Enum für die Hauptoberfläche (`filmfreaks/Content/ContentRouting.swift`).
- **Push Deep Link**: Notification-getriebener Gruppenwechsel + Öffnen der Activity-Ansicht (`filmfreaks/Notifications/PushDeepLinkRouter.swift`, `filmfreaks/Content/ContentView.swift`).

## Architecture Map
### High-level Layering

1. **UI / Feature Views**
   - `filmfreaks/Content/*`
   - `filmfreaks/MovieSearch/*`
   - `filmfreaks/MovieDetail/*`
   - `filmfreaks/SearchResultDetail/*`
   - `filmfreaks/MovieNights/*`
   - `filmfreaks/Goals/*`
   - `filmfreaks/Stats/*`
   - `filmfreaks/Timeline/*`
   - `filmfreaks/SettingsView.swift`, `filmfreaks/GroupSettingsView.swift`, `filmfreaks/UsersView.swift`

2. **App Shell / Composition Root**
   - `filmfreaks/filmfreaksApp.swift`
   - `filmfreaks/CloudKitShareAppDelegate.swift`
   - `filmfreaks/CloudKitShareSceneDelegate.swift`
   - `filmfreaks/AppRefreshCoordinator.swift`

3. **State / Stores**
   - `filmfreaks/MovieStore/*`
   - `filmfreaks/UserStore.swift`
   - `filmfreaks/MovieNights/MovieNightStore*.swift`
   - `filmfreaks/CloudKitGroupStore/*`
   - `filmfreaks/DisplaySettings/*`

4. **Persistence / Sync / Infrastructure**
   - `filmfreaks/PersistenceManager.swift`
   - `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`
   - `filmfreaks/CloudKitRouting.swift`
   - `filmfreaks/CloudKitZoneChangeTokenStore.swift`
   - `filmfreaks/CloudKitZoneChanges.swift`
   - `filmfreaks/CloudKitMovieStore/*`
   - `filmfreaks/CloudKitRatingStore/*`
   - `filmfreaks/CloudKitMovieNightStore/*`
   - `filmfreaks/CloudKitUserStore.swift`
   - `filmfreaks/CloudKitGoalStore.swift`
   - `filmfreaks/CloudKit/*`
   - `filmfreaks/Notifications/*`

5. **External API / Caches / Utility**
   - `filmfreaks/TMDbAPI/*`
   - `filmfreaks/CachedAsyncImage.swift`
   - `filmfreaks/RecommendationsCacheManager.swift`
   - `filmfreaks/SearchHistoryManager.swift`
   - `filmfreaks/PersonPopularityStore.swift`
   - `filmfreaks/SelectedUserSelectionStore.swift`

### Dependency Shape
- `filmfreaksApp` erzeugt die globalen `EnvironmentObject`s und steckt sie in `ContentView` (`filmfreaks/filmfreaksApp.swift`).
- Feature-Views hängen stark an `@EnvironmentObject` statt expliziter DI.
- `MovieStore`, `UserStore`, `MovieNightStore` hängen lokal an `PersistenceManager`/`MovieNightLocalPersistence` und optional an ihren jeweiligen CloudKit-Stores.
- Alle CloudKit-Stores hängen an `CloudKitRouting`, `GroupContextStore` und teilweise `CloudKitZoneChangeTokenStore`.
- `TMDbAPI.shared` ist ein globaler Service ohne sichtbare abstrakte Interface-Schicht (`filmfreaks/TMDbAPI/TMDbAPI.swift`).
- `DisplaySettings` ist ein lokaler UI-State-Store auf Basis von `UserDefaults` (`filmfreaks/DisplaySettings/DisplaySettings+Persistence.swift`).

### Architektur-Stil
- Pragmatischer **View + Store + Service**-Stil.
- Keine klare Repository-/UseCase-Schicht.
- Teilweise saubere File-Splits per Extension (`MovieStore+CloudSync.swift`, `GoalsView+Persistence.swift`, `ContentView+Toolbar.swift`), aber kein durchgängig einheitlicher Standard.
- Viel **MainActor-zentrierter Zustand** in den Stores.

## Folder Map
- `filmfreaks/Content/` → Home-Screen, Routing, Activity Preview, Toolbar, Listen/Grid-UI.
- `filmfreaks/MovieStore/` → zentrales Movie-State-Management, lokale Persistenz, Cloud-Sync, Mutationen, Group-Selektion.
- `filmfreaks/MovieSearch/` → Suche gegen TMDb, Empfehlungen, Scanner, Sortierung, Such-UI.
- `filmfreaks/MovieDetail/` → Detailansicht für bestehende Filme inklusive Ratings, Trailer, Watch Providers.
- `filmfreaks/SearchResultDetail/` → Detailansicht für TMDb-Suchergebnisse vor Übernahme in Listen.
- `filmfreaks/MovieNights/` → Domänenmodell, Store, Local Persistence, Cloud-Sync, Kalender-UI, Sheets.
- `filmfreaks/Goals/` → Ziele-Feature, Persistenz, Enrichment, Matching, Editor-UI.
- `filmfreaks/Stats/` → Statistik-UI, Snapshot-Building, Drilldowns.
- `filmfreaks/Timeline/` → chronologische Filmanzeige auf Basis `movieStore.movies`.
- `filmfreaks/CloudKitGroupStore/` → Gruppenliste, Zone-Lifecycle, Share-Erzeugung, Share-Hierarchy-Repair, Subscriptions.
- `filmfreaks/CloudKitMovieStore/` → CloudKit-Persistenz für Filme inkl. Merge, Modify, Zone Changes.
- `filmfreaks/CloudKitRatingStore/` → CloudKit-Persistenz für Bewertungen.
- `filmfreaks/CloudKitMovieNightStore/` → CloudKit-Persistenz für Movie-Night-Events/Responses/Activity.
- `filmfreaks/CloudKit/` → Push-Fetch, Subscription-Management, Debugging für Remote Notifications.
- `filmfreaks/Notifications/` → Local Notification Routing, Dedupe, Identity, Notification Summary.
- `filmfreaks/DisplaySettings/` → UI-Präferenzen, Layout-Metriken, Tint, Presets.
- `filmfreaks/TMDbAPI/` → HTTP-Fassade, Modelle, Search/Details/People/Meta-Endpunkte.
- `filmfreaksTests/` → Fokus auf Routing/Persistenz-Funktions-Tests.
- `filmfreaksUITests/` → nur Template-/Smoke-Tests.

## Data Model Map
### Core Entities

#### `Movie` (`filmfreaks/Movie.swift`)
- Schlüssel: `id: UUID`
- Wichtige Felder:
  - `title`, `year`
  - `tmdbId`, `tmdbRating`, `posterPath`
  - `watchedDate`, `watchedLocation`
  - `ratings: [Rating]`
  - `genres`, `genreIds`
  - `keywords`, `keywordIds`
  - `suggestedBy`
  - `addedAt`, `addedById`, `addedByName`
  - `cast`, `directors`
  - `groupId`, `groupName`
- Nutzung:
  - Watched- und Backlog-Listen lokal als JSON.
  - CloudKit Record-Typ `Movie` plus separates `MovieRating`.

#### `Rating` (`filmfreaks/Movie.swift`)
- Schlüssel: `id: UUID`
- Wichtige Felder:
  - `reviewerId`, `reviewerName`
  - `scores: [RatingCriterion: Int]`
  - `comment`, `fazitScore`, `updatedAt`
- Beziehung:
  - Lokal eingebettet in `Movie.ratings`
  - Cloud-seitig eigenständiger Record mit `movieId`-Bezug.

#### `User` (`filmfreaks/User.swift`)
- Schlüssel: `id: UUID`
- Feld: `name`
- Verwendung:
  - Gruppenmitglieder, Filter, Bewertungsidentität, Notification-Suppression.

#### `GroupContext` (`filmfreaks/GroupContext.swift`)
- Schlüssel: `id: String`
- Felder:
  - `name`
  - `scope: private/shared`
  - `zoneName`
  - `ownerName`
- Kritisch für sicheres Routing. UUID-artige `groupId`s ohne Context dürfen **nicht** in Public DB fallen (`filmfreaks/CloudKitRouting.swift`).

#### `MovieNightEvent` (`filmfreaks/MovieNights/MovieNightEvent.swift`)
- Schlüssel: `id: UUID`
- Felder:
  - `groupId`
  - `proposedStart`
  - `createdAt`, `updatedAt`
  - `proposerUserId`, `proposerName`
  - `suggestedMovie`, `note`, `status`

#### `MovieNightResponse` (`filmfreaks/MovieNights/MovieNightResponse.swift`)
- Schlüssel: zusammengesetzt aus `eventId + userId` (`id` als computed String)
- Felder:
  - `eventId`, `userId`, `userName`
  - `decision`, `respondedAt`

#### `MovieNightActivityEvent` (`filmfreaks/MovieNights/MovieNightActivityEvent.swift`)
- Schlüssel: `id: UUID`
- Felder:
  - `groupId`
  - `kind`
  - `createdAt`
  - `eventId`, `eventStart`
  - `actorUserId`, `actorName`
  - `decision`, `newStatus`, `note`

#### `ViewingCustomGoal` (`filmfreaks/ViewingCustomGoal.swift`)
- Schlüssel: `id: UUID`
- Felder:
  - `type`
  - `rule`
  - `target`
  - `createdAt`
  - `startYear`, `durationYears`
  - `uniqueKey` (semantischer Dedupe-Key)

### Relationships / Ownership
- `Movie` → viele `Rating` (embedded lokal, separat in CloudKit).
- `Movie` → optionale Cast-/Director-Listen als Value Objects (`CastMember`).
- `GroupContext` → bestimmt Routing für `Movie`, `Rating`, `User`, `Goals`, `MovieNight*`.
- `MovieNightEvent` → viele `MovieNightResponse` und viele `MovieNightActivityEvent`.
- `Goals` sind gruppenspezifisch, aber lokal über `UserDefaults` und cloud über `ViewingGoal`/`ViewingCustomGoals` gespeichert.

### Migrationen im Datenmodell
- Legacy `Movie.cast: [String]` wird beim Decode nach `[CastMember]` migriert (`filmfreaks/Movie.swift`).
- `ViewingCustomGoalsPayload` migriert ältere Goal-Strukturen in eine versionierte Payload (`filmfreaks/ViewingCustomGoalsPayload.swift`).
- `MovieNightLocalPersistence.Snapshot` unterstützt v1 ohne `activityByGroup` und hebt auf `schemaVersion = 2` an (`filmfreaks/MovieNights/MovieNightLocalPersistence.swift`).

## Sync / Storage
### Was wird verwendet?

- **Kein SwiftData**: nicht vorhanden.
- **Kein Core Data**: nicht vorhanden.
- **Dateibasierte JSON-Persistenz**:
  - `PersistenceManager` für Filme, Backlog, Nutzer (`filmfreaks/PersistenceManager.swift`).
  - `MovieNightLocalPersistence` für kompletten Movie-Night-Snapshot (`filmfreaks/MovieNights/MovieNightLocalPersistence.swift`).
- **UserDefaults** für:
  - kleinere Settings / UI-Status / Onboarding / Sync-Meta / GroupContexts / Change Tokens / Suchhistorie / Cache-Meta.
- **CloudKit** für gruppenspezifische Daten inkl. Sharing.
- **URLCache + Image Disk Cache** für Netzwerkbilder (`filmfreaks/filmfreaksApp.swift`, `filmfreaks/CachedAsyncImage.swift`).

### Lokale Persistenz
#### `PersistenceManager` (`filmfreaks/PersistenceManager.swift`)
- Speicherort: `Application Support/FilmFreaks/groups/<group>/...`
- Dateien:
  - `movies_watched.json`
  - `movies_backlog.json`
  - `users.json`
- Eigenschaften:
  - Debounced writes (`0.55s`)
  - atomare Writes
  - pro Gruppe eigener Ordner
  - Migrationslogik von alten `UserDefaults`-Keys

#### `MovieNightLocalPersistence` (`filmfreaks/MovieNights/MovieNightLocalPersistence.swift`)
- Speicherort: `Application Support/filmfreaks/movieNights.json`
- Eigenschaften:
  - actor-isoliert
  - ein Snapshot für alle Gruppen
  - best-effort Load/Save
  - bei Fehlern Fallback auf leeren Snapshot

### CloudKit-Modell
#### Routing (`filmfreaks/CloudKitRouting.swift`)
- `groupId == nil/leer` → `publicCloudDatabase`, keine Zone.
- vorhandener `GroupContext` → `privateCloudDatabase` oder `sharedCloudDatabase` + `zoneID`.
- UUID-artige `groupId` ohne `GroupContext` → `throw groupContextNotReady`.
- Nicht-UUID-`groupId` ohne Context → legacy/public-Fallback.

#### Gruppen (`filmfreaks/CloudKitGroupStore/*`)
- Record-Typ: `FFGroup`
- Zone-Namensschema: `group.<GROUP_ID>`
- Root-Record-Name: `<GROUP_ID>`
- Listing erfolgt **über Zonen + Root-Record-Fetch**, nicht über FFGroup-Query (`filmfreaks/CloudKitGroupStore/CloudKitGroupStore+Fetch.swift`).
- Beim Refresh werden `GroupContext`s lokal persistiert.
- Owned-Gruppen werden auf Share-Hierarchy repariert, damit Children in Shares sichtbar/schreibbar sind (`filmfreaks/CloudKitGroupStore/CloudKitGroupStore+Sharing.swift`).

#### Filme (`filmfreaks/CloudKitMovieStore/*`)
- Record-Typ: `Movie`
- Zone-Changes-Pfad für Gruppen mit `GroupContext`
- Full-query-Pfad für legacy/public-Gruppen
- Merge-Logik bei `serverRecordChanged`
- `MovieCloudSyncCoordinator` bündelt Writes debounced (`filmfreaks/MovieCloudSyncCoordinator.swift`)

#### Ratings (`filmfreaks/CloudKitRatingStore/*`)
- Record-Typ: `MovieRating`
- getrennt von `Movie`, damit Rating-Änderungen nicht das komplette Movie-Payload überschreiben
- ebenfalls mit Zone-Changes für moderne Gruppenzonen

#### Users (`filmfreaks/CloudKitUserStore.swift`)
- Record-Typ: `GroupMember`
- `UserStore` seeded Cloud, wenn Gruppe leer ist und lokal bereits Nutzer existieren (`filmfreaks/UserStore.swift`)

#### Goals (`filmfreaks/CloudKitGoalStore.swift`)
- Record-Typen:
  - `ViewingGoal`
  - `ViewingCustomGoals`
- Custom Goals liegen als versioniertes Payload in **einem** Record pro Gruppe

#### Movie Nights (`filmfreaks/CloudKitMovieNightStore/*`)
- Record-Typen:
  - `MovieNightEvent`
  - `MovieNightResponse`
  - `MovieNightActivity`
- Snapshot-/Zone-Changes-Mix analog Movies

### Offline-Verhalten
- Stores laden zunächst lokale Daten, dann Cloud nach (`filmfreaks/MovieStore/MovieStore.swift`, `filmfreaks/UserStore.swift`, `filmfreaks/MovieNights/MovieNightStore.swift`).
- Pending Cloud Writes bleiben bei Fehlern erhalten und werden bei Reconnect geflusht.
- UUID-Gruppen ohne geladenen `GroupContext` bleiben lokal pending; kein unsicherer Public-Fallback.
- App-Resume löst coalesced Refresh aus (`filmfreaks/AppRefreshCoordinator.swift`, `filmfreaks/filmfreaksApp.swift`).

### Change Tokens / Incremental Sync
- Tokens liegen in `UserDefaults` über `CloudKitZoneChangeTokenStore` (`filmfreaks/CloudKitZoneChangeTokenStore.swift`).
- Inkrementelles Fetching nutzt `CKFetchRecordZoneChangesOperation` via `CloudKitZoneChanges.fetchAllChanges(...)` (`filmfreaks/CloudKitZoneChanges.swift`).

### Caches
- `URLCache.shared` global in App-Init (`filmfreaks/filmfreaksApp.swift`).
- `ImageCacheStore` mit NSCache + Disk Cache (`filmfreaks/CachedAsyncImage.swift`).
- Empfehlungen in `RecommendationsCacheManager` (`filmfreaks/RecommendationsCacheManager.swift`).
- Suchhistorie in `SearchHistoryManager` (`filmfreaks/SearchHistoryManager.swift`).
- Person-Popularity in `PersonPopularityStore` (`filmfreaks/PersonPopularityStore.swift`).

## UI Map
### App Entry / Root

- Einstieg: `filmfreaks/filmfreaksApp.swift`
- Root-View: `ContentView()` in einem `ZStack` mit:
  - `ToastHost()`
  - `SplashView`
- Global State via `EnvironmentObject`:
  - `MovieStore`
  - `MovieNightStore`
  - `UserStore`
  - `CloudKitGroupStore`
  - `NetworkMonitor`
  - `DisplaySettings`

### Hauptnavigation
- Hauptshell: **ein** `NavigationStack` in `ContentView` (`filmfreaks/Content/ContentView.swift`)
- Kein `TabView` als App-Hauptnavigation.
- Zentrale Sheet-Navigation via `ContentRoute` (`filmfreaks/Content/ContentRouting.swift`):
  - `settings`
  - `quickStart`
  - `movieSearch`
  - `users`
  - `stats`
  - `timeline`
  - `calendar`
  - `activity`
  - `goals`
  - `groupSettings`

### Hauptscreens
- `ContentView` → Home für Watched/Backlog, Activity Preview, Onboarding, Toolbar.
- `MovieSearchView` → Suche und Hinzufügen von Filmen.
- `MovieDetailView` → Detailansicht für bestehende Filme.
- `SearchResultDetailView` → Detailansicht für Suchresultate vor Übernahme.
- `UsersView` → Gruppenmitglieder / aktive Person.
- `StatsView` → Statistiken.
- `TimelineView` → chronologische Liste.
- `MovieNightCalendarView` → Kalenderansicht für Filmabende.
- `GoalsView` → Zielverwaltung.
- `SettingsView` → Sync/Cache/Appearance/Info.
- `GroupSettingsView` → Cloud-Gruppen erstellen, aktivieren, teilen, löschen, verlassen.
- `GroupActivityListView` → Gruppenaktivitäten.

### Wichtige Flows
- **App Resume** → `groupStore.refresh()` + Cloud-Refresh auf Movies, Users, MovieNights (`filmfreaks/filmfreaksApp.swift`).
- **Push Tap** → `PushDeepLinkRouter` → Notification → `ContentView.handlePushDeepLink(...)` → Gruppenwechsel + Activity-Sheet (`filmfreaks/Notifications/PushDeepLinkRouter.swift`, `filmfreaks/Content/ContentView.swift`).
- **Quick Start** → Onboarding-Sheet mit Folgeaktionen in Gruppen, Users, Search (`filmfreaks/QuickStartView.swift`, `filmfreaks/Content/ContentRouting.swift`).
- **Group Create/Activate** → `GroupSettingsView` → `CloudKitGroupStore.createGroup` → `MovieStore.activateCloudGroup` → Refresh-Kaskade (`filmfreaks/GroupSettingsView.swift`).
- **Pull to Refresh** → paralleler Refresh von Movies, Users, MovieNights (`filmfreaks/Content/ContentView+Refresh.swift`).

## Build & Configuration
### Targets

- App: `filmfreaks`
- Tests: `filmfreaksTests`
- UI Tests: `filmfreaksUITests`
- Quelle: `filmfreaks.xcodeproj/project.pbxproj`

### Plattform / Deployment
- iOS Deployment Target: **26.0** (`filmfreaks.xcodeproj/project.pbxproj`)
- Device Family: `1,2` = iPhone + iPad (`filmfreaks.xcodeproj/project.pbxproj`)

### Info.plist / Entitlements
- `CKSharingSupported = YES` (`filmfreaks/Info.plist`)
- `TMDB_API_KEY = $(TMDB_API_KEY)` (`filmfreaks/Info.plist`)
- `UIBackgroundModes = [remote-notification]` (`filmfreaks/Info.plist`)
- iCloud Container: `iCloud.de.marcfechner.filmfreaks` (`filmfreaks/filmfreaks.entitlements`)
- `aps-environment = development` (`filmfreaks/filmfreaks.entitlements`)

### Build Config
- `Debug.xcconfig` und `Release.xcconfig` inkludieren beide `Secrets.xcconfig` (`filmfreaks/Debug.xcconfig`, `filmfreaks/Release.xcconfig`).
- `Secrets.xcconfig` ist **im Projekt enthalten** und definiert `TMDB_API_KEY`.
- Das widerspricht teilweise dem Kommentar in `TMDbAPI.loadAPIKey()` („nicht offen im Git“) (`filmfreaks/TMDbAPI/TMDbAPI.swift`).
- **Empfehlung:** Secret aus VCS entfernen und nur Placeholder-Datei committen.

### SPM / Dependencies
- Keine Swift Package Dependencies im `.pbxproj` gefunden.
- Externe Abhängigkeiten laufen über Apple Frameworks + direkte HTTP-Nutzung gegen TMDb.

### Secrets Handling
- Aktueller Stand: Secret wird zur Build-Zeit über `Secrets.xcconfig` in `Info.plist` durchgereicht.
- Risiko: Secret liegt im Repository, falls diese Datei committed bleibt.

### CI / Release Pipeline
- **UNKNOWN**: Keine eindeutige CI-Konfiguration (z. B. GitHub Actions, Fastlane) im bereitgestellten ZIP gefunden.

## Conventions
### Naming / Struktur

- Feature-Ordner statt technisch rein geschichteter Ordnerstruktur.
- Größere Typen werden oft per Extensions gesplittet:
  - `MovieStore+CloudSync.swift`
  - `GoalsView+Persistence.swift`
  - `ContentView+Toolbar.swift`
  - `TMDbAPI+Search.swift`
- Englisch in Typ-/Dateinamen, gemischt mit deutschen Kommentaren und UI-Strings.

### Architektur-Patterns
- `@MainActor` auf zentralen Stores (`MovieStore`, `UserStore`, `MovieNightStore`, `CloudKitGroupStore`).
- Breiter Einsatz von `@EnvironmentObject`.
- Singletons/Globals:
  - `TMDbAPI.shared`
  - `NetworkMonitor.shared`
  - `PersistenceManager.shared`
  - `CloudKitGoalStore.shared`
  - `NotificationsPermissionManager.shared`
  - `GroupActivityLocalNotifier.shared`
- Debounced/Batched Cloud-Sync über dedizierte Coordinatoren.

### Do
- Gruppenspezifische Daten immer über `groupId` + `CloudKitRouting` denken.
- UUID-artige `groupId`s ohne `GroupContext` als Fehler behandeln, nicht stillschweigend in Public DB speichern.
- Teure Filter-/Sortier-Logik aus `body` herausziehen.
- Lokale Daten zuerst laden, Cloud anschließend darüberlegen.
- Migrationskompatibilität bei JSON-/Payload-Änderungen mitdenken.

### Don’t
- Keine großen Arrays in `UserDefaults` ablegen, wenn `PersistenceManager` oder Datei-Snapshots besser passen.
- Keine CloudKit-Queries über FFGroup erzwingen; das Projekt verlässt sich auf Zone-Listing (`filmfreaks/CloudKitGroupStore/CloudKitGroupStore+Fetch.swift`).
- Keine Ratings als Movie-Gesamtpayload syncen, wenn eigentlich nur `MovieRating` angepasst wird.
- Keine renderpfadnahen `filter/sort/group`-Berechnungen in großen Views lassen.

## How to work on this project
### Setup Steps

1. ZIP entpacken und `filmfreaks.xcodeproj` öffnen.
2. Prüfen, ob `Secrets.xcconfig` vorhanden ist und `TMDB_API_KEY` aufgelöst wird.
3. iCloud-/Push-Entitlements im Signing prüfen, falls CloudKit-Flows getestet werden sollen.
4. App starten und mindestens folgende Flows testen:
   - Home / Search / Add Movie
   - Group wechseln / Group anlegen
   - Mitglieder laden
   - Movie Nights Kalender
   - Goals / Stats
5. Tests aus `filmfreaksTests` laufen lassen; Fokus liegt auf Routing/Persistenz.

### Wo neue Entwickler anfangen sollten
- Zuerst `filmfreaks/filmfreaksApp.swift` lesen.
- Dann `filmfreaks/Content/ContentView.swift` + `filmfreaks/Content/ContentRouting.swift`.
- Danach die drei Hauptstores:
  - `filmfreaks/MovieStore/MovieStore.swift`
  - `filmfreaks/UserStore.swift`
  - `filmfreaks/MovieNights/MovieNightStore.swift`
- Anschließend Routing-/CloudKit-Basis:
  - `filmfreaks/GroupContext.swift`
  - `filmfreaks/CloudKitRouting.swift`
  - `filmfreaks/CloudKitGroupStore/CloudKitGroupStore.swift`

### Vorgehen für ein neues Feature
1. **Scope klären**
   - rein lokal?
   - gruppenspezifisch?
   - CloudKit-shared?
2. **Domain-Modell erweitern**
   - z. B. `Movie`, `MovieNightEvent`, `ViewingCustomGoal`
3. **Lokale Persistenz anpassen**
   - `PersistenceManager` oder `MovieNightLocalPersistence`
4. **CloudKit nur falls nötig erweitern**
   - Schema-Datei
   - Modify/Fetch/ZoneChanges
   - ggf. Share-Hierarchy-Reparenting
5. **UI/Store anschließen**
   - EnvironmentObject-Flow prüfen
   - Refresh-/Sync-Transparenz aktualisieren
6. **Tests ergänzen**
   - JSON-Fixtures / Routing / Token-Store / Migrationen

## Quick Wins
1. `ContentView`-Orchestrierung weiter zerlegen; die View reagiert auf sehr viele Trigger (`filmfreaks/Content/ContentView.swift`).
2. Sortierung in `MovieSearchView+Derived.sortedResults` aus dem Renderpfad in einen ViewModel-/Memoization-Pfad ziehen (`filmfreaks/MovieSearch/MovieSearchView+Derived.swift`).
3. `TimelineView`-Filter/Grouping cachen statt on-demand zu berechnen (`filmfreaks/Timeline/timelineview+data.swift`).
4. `UserStore`-Cloud-Writes bündeln statt pro User Task + Refresh zu fahren (`filmfreaks/UserStore.swift`).
5. `MovieNightStore.persist()` auf inkrementellere Persistenz umstellen; aktuell wird das gesamte Snapshot-JSON neu geschrieben (`filmfreaks/MovieNights/MovieNightStore+Persistence.swift`).
6. Secret-Handling härten: `Secrets.xcconfig` nicht committed halten (`filmfreaks/Secrets.xcconfig`).
7. Push-Fetch-Pipeline für Release prüfen; aktuell ist die Fetch-Logik DEBUG-gated (`filmfreaks/CloudKit/CloudKitActivityPushFetchCoordinator.swift`).
8. Mehr Unit Tests für `MovieStore+CloudSync` und `MovieNightCloudSyncCoordinator` ergänzen; dort steckt viel kritische Orchestrierung.
9. Gemeinsames Pattern für lokale Persistenz + Sync-Meta über Stores vereinheitlichen (`MovieStore`, `UserStore`, `MovieNightStore`, `GoalsView+Persistence`).
10. Observability verbessern: strukturierte Logs statt verstreuter `print(...)`-Statements in Cloud-/Sync-Pfaden.

## Open Questions / UNKNOWN
- **UNKNOWN:** Soll der legacy/public-Fallback langfristig bestehen bleiben oder ist er nur Migrationskompatibilität? (`filmfreaks/CloudKitRouting.swift`)
- **UNKNOWN:** Ist die DEBUG-Gating in `CloudKitActivityPushFetchCoordinator.fetchAndHandle(...)` absichtlich temporär oder versehentlich produktionskritisch? (`filmfreaks/CloudKit/CloudKitActivityPushFetchCoordinator.swift`)
- **UNKNOWN:** Gibt es außerhalb des ZIPs Build-/Release-Automation oder weitere Geheimnisquellen?