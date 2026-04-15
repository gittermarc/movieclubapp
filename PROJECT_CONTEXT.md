# PROJECT_CONTEXT.md

## TL;DR

`filmfreaks` ist eine SwiftUI-iOS-App mit einem einzigen App-Target (`filmfreaks`), die Filme, Gruppenmitglieder, Bewertungen, Ziele, Statistiken, Timeline-Ansichten und Filmabend-Planung in CloudKit-geteilten Gruppen organisiert. Persistiert wird **nicht** über SwiftData/Core Data, sondern primär über file-basierte JSON-Caches in `Application Support` plus `UserDefaults` für kleine Zustände; Synchronisation und Kollaboration laufen über CloudKit (inkl. Sharing/Custom Zones). Mindest-iOS laut Projektdatei: **iOS 26.0** (`filmfreaks.xcodeproj/project.pbxproj`).

## Key Concepts / Domänenbegriffe

- **Movie**  
  Kernobjekt der App. Enthält Filmdaten, optionale TMDb-Metadaten, Gruppenkontext und eingebettete lokale Ratings.  
  Pfad: `filmfreaks/Movie.swift`

- **Rating**  
  Bewertung eines Films durch genau eine Person. In CloudKit separat als `MovieRating` gespeichert, lokal aber im `Movie` eingebettet geführt.  
  Pfade: `filmfreaks/Movie.swift`, `filmfreaks/CloudKitRatingStore/*`

- **Group / GroupContext**  
  Logische Gruppe, in der Filme, Nutzer, Ziele und Filmabende geteilt werden. `GroupContext` ist das Routing-Metadatum für CloudKit-Datenbank + Zone.  
  Pfad: `filmfreaks/GroupContext.swift`

- **Owned Group / Shared Group**  
  Eigene Gruppen leben in der privaten CloudKit-DB; geteilte Gruppen in der Shared-DB.  
  Pfad: `filmfreaks/CloudKitGroupStore/CloudKitGroupStore.swift`

- **Backlog vs. Watched**  
  Filme werden in zwei getrennten Listen geführt: gesehen (`movies`) und Backlog (`backlogMovies`).  
  Pfade: `filmfreaks/MovieStore/MovieStore.swift`, `filmfreaks/PersistenceManager.swift`

- **Movie Night**  
  Eigener Feature-Block für Terminvorschläge, Antworten und Aktivitätslog eines Filmabends.  
  Pfade: `filmfreaks/MovieNights/*`

- **Goals / Custom Goals**  
  Jahresziele und benutzerdefinierte Ziele für Sehgewohnheiten (Dekade, Person, Regie, Genre, Keyword).  
  Pfade: `filmfreaks/Goals/*`, `filmfreaks/ViewingCustomGoal.swift`

- **Snapshot Builder**  
  Pattern für abgeleitete, potentiell teure UI-Modelle außerhalb des Renderpfads. Wird u. a. für Content-Listen, Activity Preview, Stats und Timeline genutzt.  
  Pfade:  
  - `filmfreaks/Content/ContentMovieItemsSnapshotBuilder.swift`  
  - `filmfreaks/Content/ContentActivityPreviewSnapshotBuilder.swift`  
  - `filmfreaks/Stats/StatsSnapshotBuilder.swift`  
  - `filmfreaks/Timeline/TimelineSnapshotBuilder.swift`

- **TMDbAPI**  
  Fassade für externe Filmmetadaten, Suche, Details, Cast, Keywords, Watch Provider.  
  Pfade: `filmfreaks/TMDbAPI/*`

## Architecture Map

Textuelle Layer-Sicht, von oben nach unten:

1. **App Shell / Composition**
   - `filmfreaks/filmfreaksApp.swift`
   - Baut `StateObject`-Stores, setzt `URLCache`, verbindet `AppDelegate`, injiziert `EnvironmentObject`s, startet Foreground-Refresh-Kaskaden.

2. **Screen Orchestration / Navigation**
   - `filmfreaks/Content/*`
   - `filmfreaks/Settings/*`
   - `filmfreaks/Stats/*`
   - `filmfreaks/Timeline/*`
   - `filmfreaks/Goals/*`
   - `filmfreaks/MovieNights/*`
   - `filmfreaks/MovieSearch/*`
   - `filmfreaks/MovieDetail/*`
   - Verantwortlich für Navigation, Sheet-Routing, Screen-State, UI-Komposition.

3. **Stores / Feature State**
   - `filmfreaks/MovieStore/*`
   - `filmfreaks/Users+Store/*`
   - `filmfreaks/Goals/GoalsStore.swift`
   - `filmfreaks/MovieNights/MovieNightStore/*`
   - `filmfreaks/CloudKitGroupStore/*`
   - Halten `ObservableObject`-State, triggern Persistenz/Sync, kapseln Anwendungslogik.

4. **Persistence / Sync / Routing**
   - `filmfreaks/PersistenceManager.swift`
   - `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`
   - `filmfreaks/CloudKitRouting.swift`
   - `filmfreaks/CloudKitZoneChangeTokenStore.swift`
   - `filmfreaks/CloudKitMovieStore/*`
   - `filmfreaks/CloudKitRatingStore/*`
   - `filmfreaks/CloudKitMovieNightStore/*`
   - `filmfreaks/CloudKitUserStore.swift`
   - `filmfreaks/CloudKitGoalStore.swift`
   - Verantwortlich für lokale JSON-Dateien, UserDefaults-Metadaten, CloudKit CRUD, Zone-Change-Tokens, DB/Zone-Routing.

5. **Domain Models**
   - `filmfreaks/Movie.swift`
   - `filmfreaks/Users+Store/User.swift`
   - `filmfreaks/ViewingCustomGoal.swift`
   - `filmfreaks/MovieNights/MovieNightEvent.swift`
   - `filmfreaks/MovieNights/MovieNightResponse.swift`
   - `filmfreaks/MovieNights/MovieNightActivityEvent.swift`

6. **Infrastructure / Utilities**
   - `filmfreaks/TMDbAPI/*`
   - `filmfreaks/NetworkMonitor.swift`
   - `filmfreaks/AppRefreshCoordinator.swift`
   - `filmfreaks/SearchHistoryManager.swift`
   - `filmfreaks/RecommendationsCacheManager.swift`
   - `filmfreaks/PersonPopularityStore.swift`
   - `filmfreaks/Notifications/*`

Abhängigkeitsrichtung im Ist-Zustand:

- Views -> Stores -> Persistence/CloudKit/TMDb
- Views -> Snapshot Builder
- Stores -> CloudKitRouting / GroupContextStore / PersistenceManager
- Notifications -> GroupContextStore / CurrentUserIdentityStore / CloudKit push summary decoding
- **Kein sauber erzwungener Repository-Layer**; Stores sprechen CloudKit-Implementierungen direkt an.

## Folder Map

- `filmfreaks/`
  - App-Root, Shared Utilities, Kernmodelle, Config-Dateien.

- `filmfreaks/CloudKit/`
  - Push-Handling, Subscriptions, Debugging rund um CloudKit-Aktivitäten.

- `filmfreaks/CloudKitGroupStore/`
  - Gruppenanlage, Listing, Share-Erzeugung, Share-Hierarchie-Reparatur, Subscription-Setup.

- `filmfreaks/CloudKitMovieStore/`
  - CloudKit-Persistenz für Filme inkl. Batch-Modify, Merge, Zone-Changes, Routing.

- `filmfreaks/CloudKitRatingStore/`
  - Separate CloudKit-Persistenz für Ratings.

- `filmfreaks/CloudKitMovieNightStore/`
  - CloudKit-Persistenz für Filmabend-Events, Responses, Activity.

- `filmfreaks/Content/`
  - Root-Screen der App, Routing, Header, Listen/Grid, Activity-Preview, Snapshot-Modelle.

- `filmfreaks/Goals/`
  - Ziele-Feature, Ziel-Store, Ziel-Views, TMDb-/Persistence-/Derived-Extensions.

- `filmfreaks/Goals/CustomGoals/`
  - Editor und UI für benutzerdefinierte Ziele.

- `filmfreaks/MovieDetail/`
  - Detailansicht eines Films, Lade-Koordinator, Credits, Watch Provider, Bewertungs-UI.

- `filmfreaks/MovieNights/`
  - Filmabend-Domäne und UI.

- `filmfreaks/MovieNights/Calendar/`
  - Kalender-Screen + Snapshot Builder für Filmabende.

- `filmfreaks/MovieNights/MovieNightStore/`
  - Store-Erweiterungen für Merge, Sync, Retry, Snapshots, Persistence.

- `filmfreaks/MovieNights/Sheets/`
  - Sheets/Editoren innerhalb des Filmabend-Features.

- `filmfreaks/MovieNights/UI/`
  - Reusable UI-Bausteine für Movie Nights.

- `filmfreaks/MovieSearch/`
  - Suche, Empfehlungen, Scanner, Result-Modelle, Zustände.

- `filmfreaks/MovieSearch/MovieSearchResults/`
  - Suchergebnis-Komponenten.

- `filmfreaks/MovieSearch/MovieSearchView/`
  - Haupt-Suchscreen und Unteransichten.

- `filmfreaks/MovieStore/`
  - Kern-Store für Filme/Backlog, Cloud-Sync, Mutationen, Selektion, Persistenz.

- `filmfreaks/Notifications/`
  - Notification-Permissions, Deep-Link-Router, lokale Aktivitäts-Benachrichtigungen, aktuelle Benutzeridentität.

- `filmfreaks/SearchResultDetail/`
  - Detail-Sheet/Ansicht für Suchergebnisse.

- `filmfreaks/Settings/`
  - Einstellungen, Gruppen-Settings, Sync-Status-Präsentation.

- `filmfreaks/Settings/DisplaySettings/`
  - Anzeigeoptionen, Theme, Layout-Metriken, Rating-Anzeige.

- `filmfreaks/Stats/`
  - Statistik-Screen, ViewModel, Snapshot Builder, Karten.

- `filmfreaks/TMDbAPI/`
  - API-Fassade und Request-/Model-Erweiterungen.

- `filmfreaks/Timeline/`
  - Timeline-Screen, ViewModel, Snapshot Builder, Unteransichten.

- `filmfreaks/Users+Store/`
  - Nutzer-Modell, Nutzer-Store, Cloud-Refresh, Mutations, Selection, Sync-Status, Nutzer-Screen.

- `filmfreaksTests/`
  - Unit-Tests mit `Testing`-Framework.

- `filmfreaksUITests/`
  - UI-Tests mit XCTest.

## Data Model Map

### Movie-Domäne

**`filmfreaks/Movie.swift`**

- `Movie`
  - `id: UUID`
  - `title: String`
  - `year: String`
  - `tmdbRating: Double?`
  - `ratings: [Rating]`
  - `posterPath: String?`
  - `watchedDate: Date?`
  - `watchedLocation: String?`
  - `tmdbId: Int?`
  - `genres: [String]?`
  - `genreIds: [Int]?`
  - `keywords: [String]?`
  - `keywordIds: [Int]?`
  - `suggestedBy: String?`
  - `addedAt: Date?`
  - `addedById: UUID?`
  - `addedByName: String?`
  - `cast: [CastMember]?`
  - `directors: [String]?`
  - `groupId: String?`
  - `groupName: String?`

- `Rating`
  - `id: UUID`
  - `reviewerId: UUID?`
  - `reviewerName: String`
  - `scores: [RatingCriterion: Int]`
  - `comment: String?`
  - `fazitScore: Int?`
  - `updatedAt: Date?`

- `CastMember`
  - `personId: Int`
  - `name: String`

- `RatingCriterion`
  - Einzelkriterien für Bewertungen.

**Beziehungen**
- `Movie` -> viele `Rating`
- `Movie` -> viele `CastMember`
- `Movie` gehört logisch zu genau einer Gruppe über `groupId`, aber nur optional im Modell.

**Migrationshinweis**
- `Movie` decodiert Legacy-Castdaten (`[String]`) in `CastMember`.  
  Pfad: `filmfreaks/Movie.swift`

### User-Domäne

**`filmfreaks/Users+Store/User.swift`**

- `User`
  - `id: UUID`
  - `name: String`

**Beziehungen**
- `User` ist nicht relational modelliert, sondern wird in Arrays pro Gruppe gehalten.
- Ratings referenzieren User nur über `reviewerId`/`reviewerName`.

### Group-Domäne

**`filmfreaks/GroupContext.swift`**

- `GroupContext`
  - `id: String`
  - `name: String`
  - `scope: GroupScope` (`private` / `shared`)
  - `zoneName: String`
  - `ownerName: String`

**Beziehungen**
- `GroupContext` verbindet logische Gruppe mit CloudKit-DB + Zone.
- Persistenz in `UserDefaults`, nicht als SwiftData/CoreData-Modell.

### Goals-Domäne

**`filmfreaks/ViewingCustomGoal.swift`**

- `ViewingCustomGoal`
  - `id: UUID`
  - `type: ViewingCustomGoalType`
  - `rule: ViewingCustomGoalRule`
  - `target: Int`
  - `createdAt: Date`
  - `startYear: Int`
  - `durationYears: Int`

- `ViewingCustomGoalsPayload`
  - versionierte Hülle für Cloud/UserDefaults-Persistenz benutzerdefinierter Ziele.

**Jahresziele**
- `[Int: Int]` im `GoalsStore`: Jahr -> Zielwert  
  Pfad: `filmfreaks/Goals/GoalsStore.swift`

### Movie Night-Domäne

**`filmfreaks/MovieNights/MovieNightEvent.swift`**
- `MovieNightEvent`
  - `id: UUID`
  - `groupId: String`
  - `proposedStart: Date`
  - `createdAt: Date`
  - `updatedAt: Date`
  - `proposerUserId: UUID`
  - `proposerName: String`
  - `suggestedMovie: Movie?`
  - `note: String?`
  - `status: MovieNightEventStatus`

**`filmfreaks/MovieNights/MovieNightResponse.swift`**
- `MovieNightResponse`
  - `eventId: UUID`
  - `userId: UUID`
  - `userName: String`
  - `decision: MovieNightResponseDecision`
  - `respondedAt: Date`
  - `id` als zusammengesetzter Schlüssel

**`filmfreaks/MovieNights/MovieNightActivityEvent.swift`**
- `MovieNightActivityEvent`
  - `id: UUID`
  - `groupId: String`
  - `kind: MovieNightActivityKind`
  - `createdAt: Date`
  - `eventId: UUID`
  - `eventStart: Date`
  - `actorUserId: UUID`
  - `actorName: String`
  - `decision: String?`
  - `newStatus: String?`
  - `note: String?`

## Sync / Storage

### Was die App **nicht** verwendet

- Kein SwiftData gefunden.
- Kein Core Data gefunden.
- Kein lokales SQLite/Realm/GRDB gefunden.

### Lokale Persistenz

#### 1) Große Kernlisten als JSON-Dateien

**`filmfreaks/PersistenceManager.swift`**

- Speichert pro Gruppe in `Application Support/FilmFreaks/groups/<group>/`
- Dateinamen:
  - `movies_watched.json`
  - `movies_backlog.json`
  - `users.json`
- Eigenschaften:
  - group-scoped
  - atomic writes
  - debounced writes (`0.55s`)
  - Migration alter `UserDefaults`-Payloads zu Files
  - Löschfunktion pro Gruppe für lokale Caches

#### 2) Movie Nights als ein Snapshot

**`filmfreaks/MovieNights/MovieNightLocalPersistence.swift`**

- Speichert `movieNights.json` in `Application Support/filmfreaks/`
- Snapshot enthält:
  - `schemaVersion`
  - `savedAt`
  - `eventsByGroup`
  - `responsesByGroup`
  - `activityByGroup`
- Backward-compatible Decoder für ältere Snapshot-Versionen

#### 3) UserDefaults / AppStorage für Kleinzustände

Beispiele:

- `CurrentGroupId`, `CurrentGroupName`, `KnownGroups`  
  Pfade: `filmfreaks/MovieStore/MovieStore.swift`, `filmfreaks/MovieStore/MovieStore+Selections.swift`

- `GroupContextsById`  
  Pfad: `filmfreaks/GroupContext.swift`

- Pro-Gruppe ausgewählter Benutzer  
  Pfad: `filmfreaks/SelectedUserSelectionStore.swift`

- Aktuelle globale Benutzeridentität für Notification-Suppression  
  Pfad: `filmfreaks/Notifications/CurrentUserIdentityStore.swift`

- Display-/Theme-/Layout-Settings  
  Pfad: `filmfreaks/Settings/DisplaySettings/*`

- Search History / Recommendations Cache / Popularity Cache  
  Pfade:
  - `filmfreaks/SearchHistoryManager.swift`
  - `filmfreaks/RecommendationsCacheManager.swift`
  - `filmfreaks/PersonPopularityStore.swift`

### CloudKit-Sync

#### Routing

**`filmfreaks/CloudKitRouting.swift`**

- Kein `groupId` -> Public DB
- `GroupContext` vorhanden -> Private oder Shared DB + Zone
- UUID-artige `groupId` ohne `GroupContext` -> Fehler `groupContextNotReady`
- Legacy, nicht-UUID-artige Gruppen -> Public DB-Fallback

Das ist wichtig: neue Sharing-Gruppen sind **zone-basiert**, und das Routing verhindert explizit den unsicheren Public-DB-Fallback.

#### Gruppen

**`filmfreaks/CloudKitGroupStore/CloudKitGroupStore.swift`**

- Root-Record-Type: `FFGroup`
- Pro Gruppe wird eine Zone `group.<groupId>` angelegt
- Share-Basis ist der Root-Record der Gruppe
- `refresh()` lädt Owned + Shared Gruppen, persistiert `GroupContext`, richtet Subscriptions ein
- ältere Datenstrukturen werden über `repairShareHierarchyIfNeeded` nachträglich unter den Root-Record gehängt

#### Filme

**`filmfreaks/CloudKitMovieStore/*`**

- Record-Type: `Movie`
- Payload:
  - `payload` (serialisierter `Movie` ohne Ratings)
  - `isBacklog`
  - `updatedAt`
  - `groupId`
- Unterstützt:
  - Full Fetch für Legacy/Public
  - inkrementelle Zone Changes für Sharing-Gruppen
  - Konfliktbehandlung bei `serverRecordChanged`
  - Batch Save/Delete

#### Ratings

**`filmfreaks/CloudKitRatingStore/*`**

- Record-Type: `MovieRating`
- Ratings liegen separat von Filmen
- Felder:
  - `payload`
  - `movieId`
  - `groupId`
  - `reviewerId`
  - `reviewerName`
  - `updatedAt`
- Record-Namen basieren auf `groupId|movieId|reviewerId`

#### Nutzer

**`filmfreaks/CloudKitUserStore.swift`**

- Record-Type: `GroupMember`
- Felder:
  - `groupId`
  - `memberId`
  - `name`
  - `updatedAt`
- Enthält Legacy-Migration für alte Member-Datensätze ohne `memberId`

#### Goals

**`filmfreaks/CloudKitGoalStore.swift`**

- Jahresziele: `ViewingGoal`
- Custom Goals: `ViewingCustomGoals` als Payload-Record pro Gruppe

#### Movie Nights

**`filmfreaks/CloudKitMovieNightStore/*`**

- Record-Types:
  - `MovieNightEvent`
  - `MovieNightResponse`
  - `MovieNightActivity`

#### Zone Change Tokens

**`filmfreaks/CloudKitZoneChangeTokenStore.swift`**

- Speichert `CKServerChangeToken` in `UserDefaults`
- Schlüsselstruktur:
  - `CKZoneToken.<namespace>.<scope>.<zoneName>.<ownerName>`

### Sync-Trigger

- App wird aktiv -> `filmfreaks/filmfreaksApp.swift` -> `AppRefreshCoordinator`
- Pull-to-refresh -> `filmfreaks/Content/ContentView+Refresh.swift`
- Netzwerk reconnect -> `filmfreaks/NetworkMonitor.swift` + Store-spezifische Reconnect-Handler
- GroupContext verfügbar -> Retry-Handling in `MovieStore` / `MovieNightStore`
- Push / content-available -> `filmfreaks/CloudKit/CloudKitActivityPushFetchCoordinator.swift` + `CloudKitShareAppDelegate.swift`

### Offline-Verhalten

- Lokal gespeicherte Filme, Backlog, Nutzer und Movie-Night-Snapshots sind offline lesbar.
- Cloud-Schreibvorgänge werden debounced/batched in Pending-Queues gesammelt.
- **Risiko:** Pending-Queues für Filme und Movie Nights sind nur im Speicher sichtbar; es wurde keine Persistenz dieser Queues gefunden. Ein App-Kill zwischen lokaler Mutation und erfolgreichem Flush kann Änderungen verlieren.  
  Betroffene Pfade:
  - `filmfreaks/MovieCloudSyncCoordinator.swift`
  - `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift`

### Migration

- Alte große `UserDefaults`-Blobs werden einmalig in Dateipersistenz migriert.  
  Pfad: `filmfreaks/PersistenceManager.swift`
- Movie-Night-Snapshot ist schema-versioniert.  
  Pfad: `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`
- `Movie` und `CloudKitUserStore` enthalten Legacy-Decoding/-Migration für ältere Datenformen.

## UI Map

### App Entry

- `filmfreaks/filmfreaksApp.swift`
  - erzeugt Stores
  - injiziert `EnvironmentObject`s
  - zeigt `SplashView`
  - hostet `ToastHost`

### Hauptscreen

- `filmfreaks/Content/ContentView.swift`
  - Root `NavigationStack`
  - Header, Gruppen-/Mitgliederstatus, Onboarding-Checklist, Watched/Backlog-Switch, Listen/Grid
  - mehrere abgeleitete Teilmodelle (`ContentMovieItemsModel`, `ContentActivityPreviewModel`)

### Zentrales Sheet-Routing

- `filmfreaks/Content/ContentRouting.swift`
  - `ContentRoute`
    - `.settings`
    - `.quickStart`
    - `.movieSearch`
    - `.users`
    - `.stats`
    - `.timeline`
    - `.calendar`
    - `.activity`
    - `.goals`
    - `.groupSettings`

### Wichtige Flows / Screens

- **Movie Search**
  - `filmfreaks/MovieSearch/MovieSearchView/MovieSearchView.swift`
  - Sheet vom Content-Screen aus
  - kann Filme zu Watched/Backlog hinzufügen

- **Movie Detail**
  - `filmfreaks/MovieDetail/MovieDetailView.swift`
  - Navigation aus Listen/Grid/Suchergebnissen
  - lädt Details, Watch Provider, Cast/Meta

- **Users**
  - `filmfreaks/Users+Store/UsersView.swift`
  - Mitglieder pflegen, aktiven Nutzer wählen

- **Stats**
  - `filmfreaks/Stats/StatsView.swift`
  - arbeitet auf `StatsViewModel` + `StatsSnapshotBuilder`

- **Timeline**
  - `filmfreaks/Timeline/TimelineView.swift`
  - arbeitet auf `TimelineViewModel` + `TimelineSnapshotBuilder`

- **Goals**
  - `filmfreaks/Goals/GoalsView.swift`
  - Jahresziel + Custom Goals

- **Movie Nights / Calendar**
  - `filmfreaks/MovieNights/Calendar/MovieNightCalendarView.swift`
  - Kalenderansicht + Propose/Edit/Respond-Flows

- **Group Activity**
  - `filmfreaks/GroupActivityListView.swift`
  - Aktivitätsliste einer Gruppe

- **Settings**
  - `filmfreaks/Settings/SettingsView.swift`
  - Anzeigeoptionen, Benachrichtigungen, Sync-Status

- **Group Settings**
  - `filmfreaks/Settings/GroupSettingsView.swift`
  - Gruppen erzeugen, teilen, löschen, verlassen

### Deeplinks / Push-Routing

- `filmfreaks/Content/ContentView+DeepLink.swift`
- `filmfreaks/Notifications/PushDeepLinkRouter.swift`

Push-Infos können Gruppe aktivieren, Refresh triggern und direkt in die Activity-Sicht routen.

## Build & Configuration

### Targets

- `filmfreaks`
- `filmfreaksTests`
- `filmfreaksUITests`

Quelle: `filmfreaks.xcodeproj/project.pbxproj`

### Deployment / Version

- `IPHONEOS_DEPLOYMENT_TARGET = 26.0`
- App-Version: `MARKETING_VERSION = 1.5`
- Build: `CURRENT_PROJECT_VERSION = 1`

### Config-Dateien

- `filmfreaks/Debug.xcconfig`
- `filmfreaks/Release.xcconfig`
- beide inkludieren `filmfreaks/Secrets.xcconfig`

### Secrets-Handling

- `Info.plist` erwartet `TMDB_API_KEY=$(TMDB_API_KEY)`
- `TMDbAPI.loadAPIKey()` liest:
  1. Environment Variable
  2. Info.plist

Pfad: `filmfreaks/TMDbAPI/TMDbAPI.swift`

**Wichtige Beobachtung:**  
Im aktuellen Repo-Stand liegt `filmfreaks/Secrets.xcconfig` im Projekt und enthält den API-Key im Klartext. Das widerspricht dem eigenen Kommentar in `TMDbAPI.swift`, der gerade verhindern will, dass der Schlüssel im Repo landet.

### Entitlements / Capabilities

- CloudKit aktiviert
- iCloud-Container:
  - `iCloud.de.marcfechner.filmfreaks`
- APS Environment:
  - `development`
- `CKSharingSupported = true`
- Background Mode:
  - `remote-notification`

Pfade:
- `filmfreaks/filmfreaks.entitlements`
- `filmfreaks/Info.plist`

### Dependencies

- Keine Swift Package Dependencies im Projektfile gefunden.
- Verwendete Apple-Frameworks im Code:
  - SwiftUI
  - Combine
  - CloudKit
  - Network
  - UserNotifications
  - Foundation

### Xcode-Projektstruktur

- `PBXFileSystemSynchronizedRootGroup` ist aktiv.  
  Neue Dateien im Dateisystem werden daher grundsätzlich besser mit der Projektstruktur synchron gehalten als bei klassisch manuell gepflegten Gruppen.  
  Quelle: `filmfreaks.xcodeproj/project.pbxproj`

### CI / Secret-Rotation / Environment-Strategie

- **UNKNOWN**: Keine CI-Konfiguration im Zip gefunden.
- **UNKNOWN**: Keine dokumentierte Strategie für Secret-Rotation oder lokale Entwickler-Overrides außer `Secrets.xcconfig`.

## Conventions

### Erkennbare Patterns

- Große Typen werden per Dateisplitting in Extensions zerlegt.  
  Beispiele:
  - `MovieStore/*`
  - `ContentView+*.swift`
  - `MovieDetail/*`
  - `TMDbAPI+*.swift`
  - `UserStore+*.swift`

- Heavy Derived State wird bevorzugt aus dem SwiftUI-Body ausgelagert.  
  Beispiele:
  - `ContentMovieItemsSnapshotBuilder`
  - `ContentActivityPreviewSnapshotBuilder`
  - `StatsSnapshotBuilder`
  - `TimelineSnapshotBuilder`

- `@MainActor` auf UI-nahen Stores/ViewModels ist Standard.
- CloudKit-Zugriff ist feature-spezifisch gekapselt, aber nicht über ein einheitliches Repository-Protokoll abstrahiert.
- UserDefaults für kleine Zustände, Datei-Persistenz für große Arrays/Snapshots.
- Testbare Konstruktoren mit injizierbaren Defaults/Stores sind vorhanden, aber nicht überall konsistent.

### Do

- Bei group-scoped Daten immer `groupId` und `GroupContext` mitdenken.
- Bei CloudKit für UUID-artige Gruppen nie Public-DB-Fallback einführen.
- Abgeleitete Listen/Sortierungen außerhalb des Renderpfads berechnen.
- Bestehende Split-Struktur pro Feature respektieren.
- Für neue Persistenzpfade Migrations-/Fallback-Verhalten definieren.
- Neue Performance-relevante Logik mit Snapshot-Builder oder Cache absichern.
- Tests ergänzen, besonders für Routing, Persistenz und Snapshot-Builder.

### Don’t

- Keine Fetches/Sortierungen direkt in SwiftUI-`body` einbauen.
- Keine neue Persistenz in große `UserDefaults`-Blobs kippen.
- Keine CloudKit-Routing-Abkürzungen ohne `GroupContext` für UUID-Gruppen.
- Keine Store-Mutationen vom Hintergrundthread aus.
- Keine Secrets im Repo lassen.

## How to work on this project

### Setup Steps

1. Xcode öffnen über `filmfreaks.xcodeproj`
2. Prüfen, ob iCloud/CloudKit-Capabilities mit dem richtigen Team signiert sind
3. `TMDB_API_KEY` lokal bereitstellen
   - idealerweise nicht via eingecheckter `Secrets.xcconfig`
4. App starten
5. Optional:
   - iCloud-Login auf Gerät/Simulator prüfen
   - Push/remote notification Verhalten separat testen

### Wo anfangen als neuer Entwickler

1. `filmfreaks/filmfreaksApp.swift`
2. `filmfreaks/Content/ContentView.swift`
3. `filmfreaks/MovieStore/MovieStore.swift`
4. `filmfreaks/PersistenceManager.swift`
5. `filmfreaks/CloudKitRouting.swift`
6. dann je Feature den zugehörigen Store + CloudKit-Store + Hauptview

### Typischer Workflow für ein neues Feature

1. Prüfen, ob das Feature group-scoped ist
2. Domain-Modell anlegen/erweitern
3. lokale Persistenz definieren
4. CloudKit-Record-Strategie definieren
5. Routing/Sharing-Fähigkeit prüfen
6. Store oder ViewModel ergänzen
7. UI anbinden
8. Snapshot Builder einführen, falls derived/heavy
9. Unit-Tests hinzufügen
10. Edge Cases testen:
   - offline
   - Gruppenwechsel während Task läuft
   - Erstsync / leere Cloud
   - Legacy-Daten / fehlender GroupContext

### Typischer Workflow für Änderungen an bestehender UI

1. prüfen, ob bereits ein `+Derived`, `+Lifecycle`, `+Persistence`, `+Mutations`-Split existiert
2. Ableitungen nicht in die Hauptdatei zurückholen
3. State-Invalidationen bewusst begrenzen
4. Tests/Preview/Regressionen mit Gruppenwechsel und leeren States prüfen

## Quick Wins

1. **TMDb-Key aus Repo entfernen**  
   `filmfreaks/Secrets.xcconfig` nicht einchecken; stattdessen Beispiel-Datei + lokale Overrides.

2. **Pending-Cloud-Writes persistent machen**  
   In-Memory-Queues in `MovieCloudSyncCoordinator` und `MovieNightCloudSyncCoordinator` auf Disk spiegeln.

3. **`MovieStore+CloudSync.swift` weiter zerlegen**  
   Fetch, Merge, Ratings-Reconciliation, Apply, Initial-Upload und Error-Handling trennen.

4. **Release-Verhalten für Push-Fetch prüfen und fixen**  
   `CloudKitActivityPushFetchCoordinator.fetchAndHandle` ist aktuell in Release effektiv deaktiviert.

5. **Observability vereinheitlichen**  
   `print`-Statements durch `Logger` ersetzen; Sync- und Routing-Metriken strukturiert loggen.

6. **Content-Lifecycle-Triggers konsolidieren**  
   `filmfreaks/Content/ContentView+Lifecycle.swift` triggert viele Updates; Input-Hasing/Coalescing einziehen.

7. **`AddMovieView.swift` prüfen**  
   Im Repo wurde keine Referenz gefunden; Kandidat für Entfernung oder klare Dokumentation als Legacy/Testdatei.

8. **Store-Protokolle weiter vereinheitlichen**  
   `GoalsStore` nutzt bereits ein Sync-Protokoll; ähnliches Muster für weitere Stores wäre hilfreich.

9. **Mehr diskrete Test-Doubles für CloudKit einführen**  
   Vor allem für `MovieStore`, `UserStore`, `MovieNightStore`, um Cloud-/Offline-Flows gezielter zu testen.

10. **Secrets-/Build-Dokumentation ergänzen**  
   Ein kurzes `README` oder `DEVELOPMENT_SETUP.md` fehlt aktuell.

## Open Questions

- **UNKNOWN**: Gibt es eine separate CI/CD-Pipeline für Tests, Signierung und CloudKit-Schema-Deployment?
- **UNKNOWN**: Gibt es produktive APNS-/CloudKit-Umgebungen außerhalb des aktuellen `development`-Entitlement-Setups?
- **UNKNOWN**: Sollen Legacy/Public-DB-Gruppen langfristig weiter unterstützt oder migriert werden?
- **UNKNOWN**: Ist `AddMovieView.swift` absichtlich unreferenziert oder historischer Rest?
- **UNKNOWN**: Gibt es außerhalb des Zips noch externe Dokumentation zu CloudKit-Schema, Teams/Container-Setup oder Release-Prozess?
