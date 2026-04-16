# PROJECT_CONTEXT.md
## TL;DR
**filmfreaks** ist eine iOS-App für Filmgruppen: Filme suchen, in Watched/Backlog verwalten, gruppenbezogen bewerten, Statistiken ansehen, Ziele definieren und Filmabende planen. Die App läuft auf **iPhone und iPad** und ist im aktuellen Projektstand auf **iOS 26.0** konfiguriert (`filmfreaks.xcodeproj/project.pbxproj`). Persistenz ist **nicht** SwiftData/CoreData-basiert, sondern kombiniert **lokale JSON-Dateien + UserDefaults** mit **CloudKit** pro Domäne (`PersistenceManager.swift`, `MovieStore/*`, `Users+Store/*`, `Goals/GoalsStore.swift`, `MovieNights/*`, `CloudKit*`).
---
## Key Concepts / Domänenbegriffe
- **Group / Gruppe**
  - Funktionaler Scope fast aller Daten.
  - Es gibt lokale/default Gruppen, legacy/public Gruppen und CloudKit-Sharing-Gruppen mit Zone-Routing.
  - Relevante Dateien: `MovieStore/MovieStore+Selections.swift`, `GroupContext.swift`, `CloudKitRouting.swift`, `CloudKitGroupStore/*`.
- **GroupContext**
  - Persistierte Routing-Metadaten für CloudKit-Sharing-Gruppen.
  - Enthält `id`, `name`, `scope`, `zoneName`, `ownerName`.
  - Entscheidet, ob gegen private/shared DB + Zone oder gegen Public DB gelesen/geschrieben wird.
  - Datei: `GroupContext.swift`.
- **Movie**
  - Zentraler Inhaltsdatensatz der App.
  - Enthält Metadaten, Ratings, Personenbezüge, Gruppenbezug, Vorschlags-/Aktivitätsmetadaten.
  - Datei: `Movie.swift`.
- **Rating**
  - Gruppenbewertung pro Reviewer mit mehreren Kriterien plus optionalem Fazit-Score.
  - Ratings werden Cloud-seitig separat von Filmen gespeichert.
  - Dateien: `Movie.swift`, `CloudKitRatingStore/*`.
- **Watched / Backlog**
  - Zwei Hauptlisten im Root-Screen.
  - Persistenz lokal getrennt, Cloud-seitig über `isBacklog` am Movie-Record.
  - Dateien: `Content/*`, `MovieStore/*`, `CloudKitMovieStore/*`.
- **Movie Night**
  - Gruppenbezogene Filmabend-Planung mit Events, Responses, Activity-Feed und Roulette-Presets.
  - Dateien: `MovieNights/*`, `CloudKitMovieNightStore/*`.
- **Goals**
  - Jahresziele plus frei definierbare Viewing-Ziele.
  - Dateien: `Goals/*`, `ViewingCustomGoal.swift`, `ViewingCustomGoalsPayload.swift`, `CloudKitGoalStore.swift`.
- **Stats / Timeline**
  - Abgeleitete Analytik- und Verlaufssichten auf Basis der Filme/Ratings.
  - Dateien: `Stats/*`, `Timeline/*`.
- **TMDb**
  - Externe Metadatenquelle für Suche, Filmdetails, Personen und Watch-Provider.
  - Dateien: `TMDbAPI/*`, `MovieSearch/*`, `MovieDetail/*`, `SearchResultDetail/*`.
---
## Architecture Map
### Schichten / Module / Verantwortlichkeiten
- **App Bootstrap / Shell**
  - `filmfreaksApp.swift`
  - Baut globale EnvironmentObjects, URLCache, Splash, App-Refresh und AppDelegate-Brücke auf.
- **Root UI / Navigation**
  - `Content/*`
  - Einziger primärer Einstiegspunkt der App-Oberfläche.
  - Enthält Header, Listen/Grid, Toolbar-Menü, Deep-Link-Handling und Sheet-Routing.
- **Domain Stores**
  - `MovieStore/*`
  - `Users+Store/*`
  - `Goals/GoalsStore.swift`
  - `MovieNights/MovieNightStore/*`
  - Verantwortlich für lokalen State, lokale Persistenz, Cloud-Sync und gruppenbezogene Selektion.
- **CloudKit Adapter / Sync Layer**
  - `CloudKitMovieStore/*`
  - `CloudKitRatingStore/*`
  - `CloudKitMovieNightStore/*`
  - `CloudKitGroupStore/*`
  - `CloudKitGoalStore.swift`
  - `CloudKitUserStore.swift`
  - `CloudKitRouting.swift`
  - `CloudKitZoneChanges.swift`
  - `CloudKitZoneChangeTokenStore.swift`
  - Kapselt Record-Schema, Routing, Zone-Change-Fetches, Batch-Writes, Sharing und Push-Integration.
- **Local Persistence Layer**
  - `PersistenceManager.swift`
  - `MovieNights/MovieNightLocalPersistence.swift`
  - `SelectedUserSelectionStore.swift`
  - `GroupContext.swift`
  - Diverse `UserDefaults`-Stores.
- **Derived Snapshot / ViewModel Layer**
  - `Content/ContentMovieItemsModel.swift`
  - `Content/ContentActivityPreviewModel.swift`
  - `Stats/StatsViewModel.swift`
  - `Timeline/TimelineViewModel.swift`
  - `MovieDetail/MovieDetailLoadCoordinator.swift`
  - Ziel: Renderpfad entlasten, Derived State bündeln.
- **Feature UI**
  - `MovieSearch/*`
  - `MovieDetail/*`
  - `SearchResultDetail/*`
  - `Stats/*`
  - `Timeline/*`
  - `Goals/*`
  - `Settings/*`
  - `MovieNights/*`
### Abhängigkeitsrichtung
- Root/App → Domain Stores → Local Persistence + CloudKit Adapter
- Root/App → Feature Views → Domain Stores / Feature ViewModels
- Feature Views greifen überwiegend **direkt** auf Stores via `@EnvironmentObject` zu.
- Es gibt **keine** klar separierte Repository-/UseCase-Schicht.
- Es gibt **keine** SwiftData/CoreData-ORM-Schicht.
---
## Folder Map
- `filmfreaksApp.swift`
  - App Entry Point.
- `Content/`
  - Root-Screen, Toolbar, Context Bar, Routing, Activity-Preview, List/Grid-Derivation.
- `MovieStore/`
  - Hauptstore für Filme/Backlog, Selektion, Persistenz, Cloud-Sync, Activity.
- `Users+Store/`
  - Mitgliederverwaltung, Cloud-Sync, aktiver User, User-spezifische Auswahl.
- `MovieNights/`
  - Filmabend-Domain, Kalender, Roulette, Sheets, Cloud-Sync-Koordination.
- `Goals/`
  - Ziel-UI und Goal-Store.
- `Stats/`
  - Snapshot-Building, ViewModel, Stats-Cards.
- `Timeline/`
  - Timeline-Snapshot und UI.
- `MovieSearch/`
  - Suche, Empfehlungen, Ergebnislisten, Scanner.
- `MovieDetail/`
  - Detailscreen für bereits gespeicherte Filme.
- `SearchResultDetail/`
  - Detailscreen für Suchergebnisse vor dem Hinzufügen.
- `TMDbAPI/`
  - HTTP-Client, Models, Search/Detail/People/Meta-Endpunkte.
- `Settings/`
  - Settings-Hub, Display-Settings, Group-Settings und Sync-Status-Präsentation.
- `CloudKit*/`
  - CloudKit-Domänenadapter und Gruppensharing.
- `Notifications/`
  - Notification-Permission, Local Notifier, Push/Activity-Support.
- `Assets.xcassets/`
  - AppIcon, AccentColor.
- `filmfreaksTests/`
  - Unit-Tests über mehrere Feature-Module.
- `filmfreaksUITests/`
  - Basale UI-Tests.
---
## Data Model Map
### Core Models
- `Movie` — `Movie.swift`
  - Wichtige Felder:
    - `id: UUID`
    - `title: String`
    - `year: String`
    - `tmdbRating: Double?`
    - `ratings: [Rating]`
    - `posterPath: String?`
    - `watchedDate: Date?`
    - `watchedLocation: String?`
    - `tmdbId: Int?`
    - `genres: [String]?`, `genreIds: [Int]?`
    - `keywords: [String]?`, `keywordIds: [Int]?`
    - `suggestedBy: String?`
    - `addedAt: Date?`, `addedById: UUID?`, `addedByName: String?`
    - `cast: [CastMember]?`
    - `directors: [CastMember]?`
    - `groupId: String?`, `groupName: String?`
  - Beziehungen:
    - 1:n zu `Rating`
    - optionale Personenreferenzen via `CastMember`
- `Rating` — `Movie.swift`
  - Wichtige Felder:
    - `id: UUID`
    - `reviewerId: UUID?`
    - `reviewerName: String`
    - `scores: [RatingCriterion: Int]`
    - `comment: String?`
    - `fazitScore: Int?`
    - `updatedAt: Date?`
- `CastMember` — `Movie.swift`
  - `personId: Int`
  - `name: String`
- `User` — `Users+Store/User.swift`
  - `id: UUID`
  - `name: String`
### Group / Routing Models
- `GroupInfo` — `MovieStore/MovieStore.swift`-naher Scope
  - Light-weight Gruppenreferenz für lokale bekannte Gruppen.
- `GroupContext` — `GroupContext.swift`
  - `id`, `name`, `scope`, `zoneName`, `ownerName`
  - zentrale Routingbasis für CloudKit-Sharing.
### Goals Models
- `ViewingCustomGoal` — `ViewingCustomGoal.swift`
  - Frei definierte Zielinstanz.
- `ViewingCustomGoalType` — `ViewingCustomGoal.swift`
  - Fälle: `decade`, `actor`, `director`, `genre`, `keyword`.
- `ViewingCustomGoalRule` — `ViewingCustomGoal.swift`
  - Regeltyp mit IDs/Namen je Zielart.
- `ViewingCustomGoalsPayload` — `ViewingCustomGoalsPayload.swift`
  - versioniertes Persistenz-/Cloud-Payload für Custom Goals.
### Movie Night Models
- `MovieNightEvent` — `MovieNights/MovieNightEvent.swift`
  - `id`, `groupId`, `proposedStart`, `createdAt`, `updatedAt`, `proposerUserId`, `proposerName`, `suggestedMovie`, `note`, `status`.
- `MovieNightResponse` — `MovieNights/MovieNightResponse.swift`
  - pro `(eventId, userId)` eine Antwort.
  - `decision`, `respondedAt`.
- `MovieNightActivityEvent` — `MovieNights/MovieNightActivityEvent.swift`
  - `kind`, `groupId`, `createdAt`, `eventId`, `eventStart`, `actorUserId`, `actorName`, optionale Payload.
- `MovieNightMovieRef` — `MovieNights/MovieNightMovieRef.swift`
  - referenziert Filmauswahl für Event/Preset.
- `MovieRoulettePreset` — `MovieNights/Roulette/MovieRoulettePreset.swift`
  - `id`, `groupId`, `name`, `sortIndex`, `movieRefs`, `updatedAt`.
---
## Sync / Storage
### Lokal
- **Große Collections** werden als JSON-Dateien in `Application Support/FilmFreaks/groups/<group>/...json` gespeichert.
  - Datei: `PersistenceManager.swift`
  - Persistiert:
    - Watched Movies
    - Backlog Movies
    - Users
- **Movie Night Snapshot** wird separat lokal gespeichert.
  - Datei: `MovieNights/MovieNightLocalPersistence.swift`
- **UserDefaults** werden für kleine, gruppenspezifische oder UI-bezogene Daten verwendet.
  - Beispiele:
    - aktuelle Gruppe: `MovieStore/MovieStore+Selections.swift`
    - bekannte Gruppen: `MovieStore/MovieStore+Selections.swift`
    - aktiver User pro Gruppe: `SelectedUserSelectionStore.swift`
    - GroupContexts: `GroupContext.swift`
    - Change Tokens: `CloudKitZoneChangeTokenStore.swift`
    - Search History: `SearchHistoryManager.swift`
    - Recommendations Cache: `RecommendationsCacheManager.swift`
    - Display Settings: `Settings/DisplaySettings/*`
- **Migration lokal**
  - `PersistenceManager.swift` migriert Altbestände aus UserDefaults in Dateipersistenz.
  - `Movie.swift` migriert Legacy-`cast: [String]` nach `[CastMember]`.
  - `ViewingCustomGoalsPayload.swift` migriert Legacy-v2 nach v3.
### Cloud
- CloudSync ist **domänenspezifisch** implementiert, nicht zentral generisch.
  - Filme: `CloudKitMovieStore/*`
  - Ratings: `CloudKitRatingStore/*`
  - Users/Members: `CloudKitUserStore.swift`
  - Goals: `CloudKitGoalStore.swift`
  - Movie Nights: `CloudKitMovieNightStore/*`
  - Groups/Sharing: `CloudKitGroupStore/*`
- **Routing-Modell**
  - Datei: `CloudKitRouting.swift`
  - Logik:
    - keine Gruppe → Public DB
    - `GroupContext` vorhanden → private/shared DB + Zone
    - UUID-artige `groupId` ohne `GroupContext` → Fehler `groupContextNotReady`
    - nicht-UUID ohne `GroupContext` → legacy/public Gruppe
- **Inkrementeller Sync**
  - Zone-Gruppen nutzen Change Tokens.
  - Dateien: `CloudKitZoneChangeTokenStore.swift`, `CloudKitZoneChanges.swift`, `CloudKitMovieStore+ZoneChanges.swift`, `CloudKitRatingStore+ZoneChanges.swift`, `CloudKitMovieNightStore+ZoneChanges.swift`
- **Offline-Verhalten**
  - Lokale Daten bleiben benutzbar.
  - Writes werden in Sync-Koordinatoren gepuffert und bei Netzverfügbarkeit erneut geflusht.
  - Dateien: `MovieCloudSyncCoordinator.swift`, `MovieNights/MovieNightCloudSyncCoordinator.swift`, `NetworkMonitor.swift`
- **Push / Background**
  - `Info.plist` enthält `remote-notification`.
  - `CloudKitShareAppDelegate.swift` registriert Notifications und verarbeitet eingehende CloudKit-Pushes.
  - `CloudKit/CloudKitActivityPushFetchCoordinator.swift` lädt best effort den geänderten Record nach und kann daraus lokale Benachrichtigungen auslösen.
### Storage-/Sync-Befunde
- **Kein SwiftData/CoreData** gefunden.
- **Kein lokaler relationaler Store** gefunden.
- **Kein generisches Repository/DAO-System** gefunden.
- **Kein zentraler Sync-Orchestrator über alle Domänen** gefunden; Koordination erfolgt pro Store plus `AppRefreshCoordinator.swift`.
---
## UI Map
### Root / Primary Flow
- Einstieg: `filmfreaksApp.swift` → `ContentView()`
- `ContentView.swift` ist der primäre Root-Screen.
- Navigation erfolgt primär über **einen `NavigationStack` + Sheet-Routing**, nicht über `TabView`.
### Root-Screen (`ContentView`)
- Header / Gruppe / aktives Mitglied / Activity-Shortcut:
  - `Content/ContentHeaderView.swift`
- Hauptinhalt Watched/Backlog:
  - `Content/ContentMainAreaView.swift`
- Toolbar-Menü:
  - `Content/ContentView+Toolbar.swift`
- Sheet-Routing:
  - `Content/ContentRouting.swift`
### Sheets / Secondary Flows aus `ContentRoute`
- `settings` → `SettingsView()`
- `quickStart` → `QuickStartView(...)`
- `movieSearch` → `MovieSearchView(...)`
- `users` → `UsersView()`
- `stats` → `StatsView()`
- `timeline` → `TimelineView()`
- `calendar` → `MovieNightPlanningView()`
- `activity` → `GroupActivityListView()`
- `goals` → `GoalsView()`
- `groupSettings` → `NavigationStack { GroupSettingsView() }`
### Wichtige Feature-Flows
- **Movie Search**
  - `MovieSearch/MovieSearchView/MovieSearchView.swift`
  - Suche, Empfehlungen, Ergebnisse, Scanner.
- **Movie Detail**
  - `MovieDetail/MovieDetailView.swift`
  - Detailansicht für gespeicherte Filme.
- **Search Result Detail**
  - `SearchResultDetail/SearchResultDetailView.swift`
  - Detailansicht für TMDb-Suchergebnis vor Übernahme.
- **Stats**
  - `Stats/StatsView.swift`
  - Snapshot-getriebene Statistikansicht.
- **Timeline**
  - `Timeline/TimelineView.swift`
  - Verlauf/Snapshot nach Jahr/Zeitraum.
- **Goals**
  - `Goals/GoalsView.swift`
  - Jahresziele und Custom Goals.
- **Movie Night Planning Hub**
  - `MovieNights/Planning/MovieNightPlanningView.swift`
  - Segmentiert zwischen Kalender und Roulette.
- **Group Management / Sharing**
  - `Settings/GroupSettingsView.swift`
  - `GroupShareSheetView.swift`
### Deep Links / Push-Einstieg
- `Content/ContentView+DeepLink.swift`
  - aktiviert Gruppe, lädt relevante Stores nach und öffnet `.activity`.
---
## Build & Configuration
### Targets
- `filmfreaks`
- `filmfreaksTests`
- `filmfreaksUITests`
- Quelle: `filmfreaks.xcodeproj/project.pbxproj`
### Plattform / Deployment
- `IPHONEOS_DEPLOYMENT_TARGET = 26.0`
- `TARGETED_DEVICE_FAMILY = "1,2"` → iPhone + iPad
- `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"`
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- `ENABLE_PREVIEWS = YES`
### Build-Konfiguration
- `Debug.xcconfig`
- `Release.xcconfig`
- beide includen `Secrets.xcconfig`
### Info.plist / Entitlements
- `Info.plist`
  - `CKSharingSupported = YES`
  - `TMDB_API_KEY = $(TMDB_API_KEY)`
  - `UIBackgroundModes` enthält `remote-notification`
- `filmfreaks.entitlements`
  - `aps-environment`
  - iCloud/CloudKit-Container `iCloud.de.marcfechner.filmfreaks`
### Dependencies
- **Keine SPM-Package-Dependencies** in `project.pbxproj` gefunden.
- Externe API-Nutzung über TMDb via eigenem `URLSession`-Client.
### Secrets Handling
- Der API-Key wird runtime-seitig über `Info.plist`/Environment gelesen (`TMDbAPI/TMDbAPI.swift`).
- **Wichtig:** In `Secrets.xcconfig` liegt im aktuellen ZIP ein konkreter `TMDB_API_KEY` im Repo.
- Das ist technisch funktionsfähig, aber aus Security-/Repo-Hygiene-Sicht ein klarer Quick Win.
### CI / Automation
- **UNKNOWN:** Keine CI-Definition oder Build-Pipeline-Datei im gelieferten ZIP sichtbar.
---
## Conventions
### Sichtbare Architektur-/Coding-Patterns
- Viele Typen sind `@MainActor`, besonders Stores und ViewModels.
- Komplexe Views sind häufig bereits in Extensions/Subviews geschnitten.
- Derived State wird oft bewusst aus dem `body` ausgelagert.
  - Beispiele:
    - `ContentMovieItemsModel.swift`
    - `ContentActivityPreviewModel.swift`
    - `StatsViewModel.swift`
    - `MovieDetailLoadCoordinator.swift`
- Persistenz und Sync werden meist direkt im jeweiligen Store behandelt.
- CloudKit-Konflikt- und Merge-Logik sitzt nahe am Adapter, nicht im UI.
### Do
- Änderungen gruppenspezifisch denken.
- Vor Cloud-Routing prüfen, ob `GroupContext` vorhanden sein muss.
- Derived State aus Renderpfaden herausziehen.
- Tests in bestehende Modulstruktur einordnen.
- Bei CloudKit-/Merge-Änderungen sowohl lokale Persistenz als auch Push/Retry-Pfade mitdenken.
### Don’t
- Keine implizite Public-DB-Fallback-Logik für UUID-Gruppen einbauen.
- Keine teuren Filter-/Sortieroperationen zurück in SwiftUI-`body` verschieben.
- Keine neuen Feature-States direkt in `ContentView.swift` stapeln, wenn sie als Model/Snapshot isolierbar sind.
- Keine Secrets dauerhaft im Repo tracken.
---
## How to work on this project
### Setup Steps
1. Xcode-Projekt `filmfreaks.xcodeproj` öffnen.
2. Prüfen, dass `Secrets.xcconfig` vorhanden ist und gültige Werte liefert.
3. App mit iCloud-/Push-Fähigkeit auf einem passenden Signing-Setup bauen.
4. Für Sharing/Cloud-Funktionen echtes iCloud-fähiges Gerät oder korrekt konfigurierten Simulator verwenden.
5. Tests über `filmfreaksTests` zuerst lokal laufen lassen.
### Wo neue Entwickler anfangen sollten
- Zuerst lesen:
  - `filmfreaksApp.swift`
  - `Content/ContentView.swift`
  - `MovieStore/MovieStore.swift`
  - `MovieStore/MovieStore+CloudSync.swift`
  - `Users+Store/UserStore.swift`
  - `MovieNights/MovieNightStore/MovieNightStore.swift`
  - `Goals/GoalsStore.swift`
  - `CloudKitRouting.swift`
  - `PersistenceManager.swift`
### Typischer Workflow für ein neues Feature
- UI-Entry in `Content/` oder passendem Feature-Ordner lokalisieren.
- Prüfen, ob Daten gruppenspezifisch sind.
- Falls ja:
  - lokale Persistenz
  - CloudKit-Routing
  - GroupContext/Sharing
  - Pending-Write-/Retry-Verhalten
  - Push-/Activity-Auswirkungen
  - Tests
  zusammen denken.
- Derived Berechnungen eher in Snapshot/ViewModel statt in Views einbauen.
### Typischer Workflow für Sync-/Storage-Änderungen
- Zuerst lokalen Storepfad prüfen.
- Dann CloudKit-Adapter + Routing + Merge-Pfade prüfen.
- Dann Persistenz-/Migrationstests ergänzen.
- Danach Push/Deep-Link/Foreground-Refresh auf Seiteneffekte prüfen.
---
## Quick Wins
1. **TMDb-Key aus tracked `Secrets.xcconfig` entfernen und rotieren.**
   - Pfade: `Secrets.xcconfig`, `TMDbAPI/TMDbAPI.swift`
2. **Content-Listen-Snapshot off-main rechnen statt synchron auf MainActor.**
   - Pfade: `Content/ContentMovieItemsModel.swift`, `Content/ContentMovieItemsSnapshotBuilder.swift`
3. **Timeline-Snapshot analog zu Stats entkoppeln/debouncen.**
   - Pfade: `Timeline/TimelineViewModel.swift`, `Timeline/TimelineSnapshotBuilder.swift`
4. **Doppelte Detail-Ladelogik zwischen MovieDetail und SearchResultDetail zusammenführen.**
   - Pfade: `MovieDetail/MovieDetailLoadCoordinator.swift`, `SearchResultDetail/SearchResultDetailView+Loading.swift`
5. **`print`-basierte CloudKit-Logs auf `OSLog`/strukturierte Logs umstellen.**
   - Pfade: `MovieStore/MovieStore+CloudSync.swift`, `MovieNights/MovieNightStore/MovieNightStore+CloudRefresh.swift`, `CloudKit*`
6. **Reflection in Empfehlungslogik entfernen.**
   - Pfad: `MovieSearch/MovieSearchView/MovieSearchViewModel+Recommendations.swift`
7. **Zielpersistenz für yearly goals auf Gruppen-Semantik prüfen und vereinheitlichen.**
   - Pfad: `Goals/GoalsStore.swift`
8. **Group-Switch-Orchestrierung aus UI herausziehen.**
   - Pfade: `Settings/GroupSettingsView.swift`, `MovieStore/*`, `Users+Store/*`, `MovieNights/*`
9. **CloudKit-Retry/Backpressure-Pfade stärker testbar machen.**
   - Pfade: `MovieCloudSyncCoordinator.swift`, `MovieNights/MovieNightCloudSyncCoordinator.swift`
10. **Open Questions explizit dokumentieren und Architekturentscheidungen nachziehen.**
   - Vor allem zu legacy/public Gruppen und Goal-Scoping.
