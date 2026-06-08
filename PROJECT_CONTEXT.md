# PROJECT_CONTEXT.md

Stand: Scan des ZIP-Projekts `tmc_context.zip` am 2026-06-08. Fokus: iOS-App `filmfreaks` / The Movie Club.

## TL;DR

`filmfreaks` ist eine SwiftUI-iOS-App für gemeinsame Filmverwaltung: gesehenen Filme, Backlog, Bewertungen, Mitglieder, Gruppen, Filmabende, Roulette, Ziele, Timeline und Statistiken. Die App nutzt **kein SwiftData/CoreData**; Persistenz läuft über Codable-JSON in Application Support, UserDefaults für kleine Metadaten/Caches und manuelles CloudKit-Sync mit gruppenbezogenen Zonen/Shares. Mindestziel laut `filmfreaks.xcodeproj/project.pbxproj`: iOS `26.0`; ob das absichtlich ist, ist **UNKNOWN**.

## Key Concepts / Domänenbegriffe

- **Movie / Film**: Kernobjekt für gesehen oder Backlog; definiert in `filmfreaks/Movie.swift`.
- **Backlog**: separate Filmliste für geplante/ungesehene Filme; CloudKit-Feld `isBacklog` in `CloudKitMovieStore`.
- **Rating / Bewertung**: lokal in `Movie.ratings`, aber in CloudKit als eigener Record-Typ `MovieRating` gespeichert.
- **User / Mitglied**: Gruppenmitglied und Bewertungsidentität; definiert in `filmfreaks/Users+Store/User.swift`.
- **GroupContext**: lokale Metadaten für CloudKit-Sharing-Gruppen: Gruppe, Scope, Zone, Owner; `filmfreaks/GroupContext.swift`.
- **Local/Legacy Group**: Gruppe ohne `GroupContext`; Sync fällt auf public database zurück, sofern die Group-ID nicht UUID-artig ist.
- **Zone Group / Shared Group**: UUID-artige CloudKit-Gruppe mit eigener Record-Zone und `CKShare`.
- **Movie Night / Filmabend**: Vorschläge, Antworten, Aktivitäten und Roulette-Presets unter `filmfreaks/MovieNights/`.
- **Goals / Ziele**: Jahresziel und Custom Goals für Dekade/Person/Regie/Genre/Keyword; `filmfreaks/Goals/` und `filmfreaks/ViewingCustomGoal.swift`.
- **Stats Snapshot**: berechneter, nicht persistierter Aggregationszustand für Statistik-Views; `filmfreaks/Stats/StatsSnapshotBuilder.swift`.

## Architecture Map

Textform der aktuellen Schichtung:

1. **App Shell**
   - `filmfreaks/filmfreaksApp.swift`
   - erzeugt globale Stores, setzt EnvironmentObjects, Splash/Toast, App-Resume-Refresh.
2. **SwiftUI UI / Routing**
   - `filmfreaks/Content/ContentView.swift`
   - `filmfreaks/Content/ContentRouting.swift`
   - Feature-Views unter `MovieDetail`, `MovieSearch`, `MovieNights`, `Stats`, `Goals`, `Settings`, `Timeline`, `Users+Store`.
3. **Stores / ViewModels**
   - `MovieStore`, `MovieNightStore`, `UserStore`, `GoalsStore`, `CloudKitGroupStore`.
   - Meist `@MainActor ObservableObject`; UI bindet direkt an Published-State.
4. **Derived Snapshot Builder**
   - z.B. `ContentMovieItemsSnapshotBuilder`, `StatsSnapshotBuilder`, `TimelineSnapshotBuilder`, `GroupSettingsActiveCardSnapshotBuilder`.
   - Ziel: teure Sorts/Aggregationen aus SwiftUI-`body` herausziehen.
5. **Local Persistence**
   - `filmfreaks/PersistenceManager.swift` für Movies/Backlog/Users.
   - `filmfreaks/MovieNights/MovieNightLocalPersistence.swift` für Movie Nights.
   - UserDefaults für kleine Caches, Selections, Sync-Meta, Tokens, Goals.
6. **CloudKit Stores / Sync Coordinators**
   - Routing: `filmfreaks/CloudKitRouting.swift`.
   - Gruppen/Shares: `CloudKitGroupStore/*`.
   - Filme: `CloudKitMovieStore/*` + `MovieCloudSyncCoordinator.swift`.
   - Ratings: `CloudKitRatingStore/*`.
   - Filmabende: `CloudKitMovieNightStore/*` + `MovieNightCloudSyncCoordinator.swift`.
   - Ziele: `CloudKitGoalStore.swift`.
7. **External API / Caches**
   - TMDb: `filmfreaks/TMDbAPI/*`.
   - Images: `filmfreaks/CachedAsyncImage.swift`.
   - Person Popularity: `filmfreaks/PersonPopularityStore.swift`.

Dependency-Richtung: Views -> Stores/ViewModels -> Local Persistence + CloudKit Stores + TMDbAPI. CloudKit stores sollten keine SwiftUI-Abhängigkeit haben; einige Stores sind bewusst `@MainActor`, was Sync- und UI-Arbeit auf denselben Actor koppelt.

## Folder Map

| Pfad | Zweck |
|---|---|
| `filmfreaks/` | App-Root, App-Struct, Kernmodelle, Shared Utilities, Persistence, CloudKit Share Handling. |
| `filmfreaks/Content/` | Home Screen, Hauptliste/Grid, Sheet-Routing, Activity Preview, Toolbar, Onboarding-Trigger. |
| `filmfreaks/MovieStore/` | Lokaler Movie-State, Mutationen, Auswahl/Gruppe, Cloud-Refresh, Persistence Hooks. |
| `filmfreaks/CloudKitMovieStore/` | CloudKit CRUD, Query, Zone Changes und Merge für Movie-Records. |
| `filmfreaks/CloudKitRatingStore/` | CloudKit CRUD/Query/Zone Changes für Rating-Records. |
| `filmfreaks/CloudKitGroupStore/` | CloudKit-Gruppen, Zonen, Shares, Share-Hierarchy-Repair. |
| `filmfreaks/CloudKitMovieNightStore/` | CloudKit Snapshot/Zone Changes/Modify für Movie-Night-Recordtypen. |
| `filmfreaks/CloudKit/` | Push-Subscriptions, Push-Fetch, Debugging für CloudKit-Aktivität. |
| `filmfreaks/MovieDetail/` | Detailansicht, Rating-Flow, TMDb-Detail/Provider/Person-Sheets. |
| `filmfreaks/MovieSearch/` | TMDb-Suche, Recommendations, Scanner, Result-Model/ViewModel. |
| `filmfreaks/SearchResultDetail/` | Detailflow für Suchergebnisse vor dem Hinzufügen. |
| `filmfreaks/MovieNights/` | Filmabend-Modelle, Store, Kalender, Planning, Roulette, Sheets, UI-Bausteine. |
| `filmfreaks/Stats/` | Statistik-Snapshots, ViewModel, Karten/Drilldowns. |
| `filmfreaks/Goals/` | Ziele-UI, GoalsStore, CustomGoal-Editor, Matching/Enrichment. |
| `filmfreaks/Settings/` | App-, Sync-, Appearance- und Group-Settings. |
| `filmfreaks/Timeline/` | Timeline-View und Snapshot/ViewModel. |
| `filmfreaks/TMDbAPI/` | API-Facade, Networking, Search, Details, People/Metadata, Modelle. |
| `filmfreaks/Users+Store/` | Mitglieder-UI, UserStore, Cloud Refresh, Selection. |
| `filmfreaks/Notifications/` | Notification Permission, Local Notifier, Push Deep Link Routing. |
| `filmfreaksTests/` | Unit Tests für Routing, Persistence, Content, MovieNights, Stats, Goals usw. |
| `filmfreaksUITests/` | UI-/Launch-Tests. |

## Data Model Map

| Entity | Pfad | Wichtige Felder | Beziehungen / Hinweise |
|---|---|---|---|
| `Movie` | `filmfreaks/Movie.swift` | `id`, `title`, `year`, `tmdbRating`, `ratings`, `posterPath`, `watchedDate`, `watchedLocation`, `tmdbId`, `genres`, `genreIds`, `keywords`, `keywordIds`, `suggestedBy`, `addedAt`, `addedById`, `addedByName`, `cast`, `directors`, `groupId`, `groupName` | Kernentity; CloudKit-Movie-Payload speichert Ratings nicht mit. |
| `Rating` | `filmfreaks/Movie.swift` | `id`, `reviewerId`, `reviewerName`, `scores`, `comment`, `fazitScore`, `updatedAt` | Lokal embedded in `Movie`; CloudKit separat als `MovieRating` pro Movie+Reviewer. |
| `RatingCriterion` | `filmfreaks/Movie.swift` | `action`, `suspense`, `emotion`, `humor`, `music`, `ambition`, `erotic` | Bewertungsskalen für Ratings. |
| `CastMember` | `filmfreaks/Movie.swift` | `personId`, `name` | Für Cast und Directors; Legacy-Namen werden auf negative IDs migriert/abgebildet. |
| `User` | `filmfreaks/Users+Store/User.swift` | `id`, `name` | CloudKit `GroupMember`; `selectedUser` pro Gruppe via UserDefaults. |
| `GroupContext` | `filmfreaks/GroupContext.swift` | `id`, `name`, `scope`, `zoneName`, `ownerName` | Lokaler Schlüssel für CloudKit Routing in private/shared DB + Zone. |
| `MovieNightEvent` | `filmfreaks/MovieNights/MovieNightEvent.swift` | `id`, `groupId`, `proposedStart`, `createdAt`, `updatedAt`, `proposerUserId`, `proposerName`, `suggestedMovie`, `note`, `status` | Filmabend-Vorschlag, gehört zu Gruppe. |
| `MovieNightResponse` | `filmfreaks/MovieNights/MovieNightResponse.swift` | `eventId`, `userId`, `userName`, `decision`, `respondedAt` | Antwort pro Event+User; `id` ist Composite. |
| `MovieNightActivityEvent` | `filmfreaks/MovieNights/MovieNightActivityEvent.swift` | `id`, `groupId`, `kind`, `createdAt`, `eventId`, `eventStart`, `actorUserId`, `actorName`, `decision`, `newStatus`, `note` | Persistierte/synchronisierte Activity für Filmabende. Kommentar „Local-only“ wirkt veraltet. |
| `MovieRoulettePreset` | `filmfreaks/MovieNights/Roulette/MovieRoulettePreset.swift` | `id`, `groupId`, `name`, `sortIndex`, `movieRefs`, `updatedAt` | Vordefinierte Film-Auswahlen für Roulette. |
| `ViewingCustomGoal` | `filmfreaks/ViewingCustomGoal.swift` | `id`, `type`, `rule`, `target`, `createdAt`, `startYear`, `durationYears` | Versioniertes Codable-Migrationsmodell für Custom Goals. |
| `ViewingCustomGoalsPayload` | `filmfreaks/ViewingCustomGoalsPayload.swift` | `version`, `goals` | Version `3`; migriert Legacy-Decade/Actor-Goals. |
| `GroupActivityEvent` | `filmfreaks/Content/GroupActivityEvent.swift` | `kind`, `date`, `actorName`, `actorId`, `movieId`, `movieTitle`, `ratingValue` | Abgeleitet aus Movie/Rating; kein eigener CloudKit-Record. |

## Sync/Storage

### Lokal

- SwiftData/CoreData: **nicht vorhanden**; kein `import SwiftData`, kein `@Model`, kein CoreData-Stack gefunden.
- Movies/Backlog/Users: `filmfreaks/PersistenceManager.swift`.
  - Base dir: `Application Support/FilmFreaks/`.
  - Dateien pro Gruppe: `groups/<safeGroupFolderName>/movies_watched.json`, `movies_backlog.json`, `users.json`.
  - Debounced writes über `DispatchWorkItem`, `0.55s`, atomic write.
- Movie Nights: `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`.
  - Eine Datei: `Application Support/filmfreaks/movieNights.json`.
  - Achtung: anderer Ordnername (`filmfreaks`) als `PersistenceManager` (`FilmFreaks`).
- UserDefaults:
  - Group selection: `CurrentGroupId`, `CurrentGroupName`, `KnownGroups`.
  - Change tokens: `CKZoneToken.<namespace>.<scope>.<zoneName>.<ownerName>`.
  - Goals, search history/recommendations, popularity cache, onboarding flags, display settings.

### CloudKit

- Entitlements: `filmfreaks/filmfreaks.entitlements` mit iCloud container `iCloud.de.marcfechner.filmfreaks` und CloudKit.
- `filmfreaks/Info.plist` aktiviert `CKSharingSupported` und Background Mode `remote-notification`.
- Routing: `filmfreaks/CloudKitRouting.swift`.
  - Kein Group-ID: public DB.
  - `GroupContext` vorhanden: private/shared DB + group zone.
  - UUID-artige Group-ID ohne Context: Fehler, kein public fallback.
  - Nicht-UUID Legacy-Gruppe ohne Context: public DB.
- Gruppen/Shares: Record `FFGroup` als Root in Zone `group.<UUID>`; `CKShare` über `CloudKitGroupStore+Sharing.swift`.
- Recordtypen:
  - `Movie` in `CloudKitMovieStore/*`.
  - `MovieRating` in `CloudKitRatingStore/*`.
  - `GroupMember` in `CloudKitUserStore.swift`.
  - `ViewingGoal`, `ViewingCustomGoals` in `CloudKitGoalStore.swift`.
  - `MovieNightEvent`, `MovieNightResponse`, `MovieNightActivity`, `MovieRoulettePreset` in `CloudKitMovieNightStore/*`.
- Zone Changes:
  - Movies: namespace `movies`.
  - Ratings: namespace `ratings`.
  - Movie Nights: namespace `movieNights`.
- Sync-Trigger:
  - App active in `filmfreaks/filmfreaksApp.swift`.
  - Pull-to-refresh in Home/Settings/Calendar-Flows.
  - Network reconnect über `NetworkMonitor`.
  - GroupContext-Upsert nach Share/Gruppenrefresh.
- Offline-Verhalten:
  - UI schreibt lokal zuerst und queued CloudKit-Uploads im Speicher.
  - **Risiko:** Pending CloudKit Queues sind nicht als Dirty Journal persistent; nach App-Kill können lokale Änderungen ohne erneutes Editieren unsynchronisiert bleiben.

## UI Map

- App Root: `filmfreaks/filmfreaksApp.swift` -> `ContentView` in `WindowGroup`.
- Root Navigation: `filmfreaks/Content/ContentView.swift` nutzt `NavigationStack`.
- Main UI: `ContentMainAreaView` zeigt gesehen/backlog als `List` oder `ScrollView` + `LazyVGrid`.
- Sheet Router: `filmfreaks/Content/ContentRouting.swift` über `ContentRoute`.
- Haupt-Sheets:
  - Settings: `filmfreaks/Settings/SettingsView.swift`.
  - QuickStart: `filmfreaks/QuickStartView.swift`.
  - Search: `filmfreaks/MovieSearch/MovieSearchView/MovieSearchView.swift`.
  - Users: `filmfreaks/Users+Store/UsersView.swift`.
  - Stats: `filmfreaks/Stats/StatsView.swift`.
  - Timeline: `filmfreaks/Timeline/TimelineView.swift`.
  - Movie Nights/Calendar: `filmfreaks/MovieNights/Planning/MovieNightPlanningView.swift`.
  - Activity: `filmfreaks/Content/GroupActivityListView.swift`.
  - Goals: `filmfreaks/Goals/GoalsView.swift`.
  - Group Settings: `filmfreaks/Settings/GroupSettingsView.swift`.
- Toolbar: `filmfreaks/Content/ContentView+Toolbar.swift` öffnet Calendar, Users, Groups, Stats, Timeline, Goals, Settings; separater Search-Button.
- Deep Links:
  - Push: `filmfreaks/Content/ContentView+DeepLink.swift`.
  - CloudKit Share Acceptance: `CloudKitShareAppDelegate.swift`, `CloudKitShareSceneDelegate.swift`, `CloudKitShareCoordinator.swift`.
- Tab-Struktur: Hauptnavigation ist **kein** TabView; QuickStart kann intern Tabs/Pages verwenden. Globale App-Navigation läuft über Stack + Sheets.

## Build & Configuration

- Xcode-Projekt: `filmfreaks.xcodeproj`.
- Targets laut `project.pbxproj`: `filmfreaks`, `filmfreaksTests`, `filmfreaksUITests`.
- Bundle ID App: `de.marcfechner.filmfreaks`.
- App-Version: `MARKETING_VERSION = 1.5`, `CURRENT_PROJECT_VERSION = 2`.
- Swift: `SWIFT_VERSION = 5.0` im Projektfile.
- iOS Deployment Target: `IPHONEOS_DEPLOYMENT_TARGET = 26.0`; **UNKNOWN**, ob bewusst oder durch lokale Xcode-Beta entstanden.
- Info: `filmfreaks/Info.plist`.
- Entitlements: `filmfreaks/filmfreaks.entitlements`.
- Configs: `filmfreaks/Debug.xcconfig`, `filmfreaks/Release.xcconfig` inkludieren `Secrets.xcconfig`.
- Secrets:
  - `filmfreaks/Secrets.xcconfig` enthält `TMDB_API_KEY` im Klartext in diesem ZIP.
  - Wert nicht dokumentieren; Schlüssel rotieren und Datei aus Repo/ZIP entfernen.
- SPM:
  - Kein `Package.swift`, kein `Package.resolved` gefunden.
  - Dependencies außerhalb Apple SDK sind **UNKNOWN**, aber nicht sichtbar.
- CloudKit Dashboard Schema/Indexes: **UNKNOWN**, da nicht exportiert.
- Release Push Umgebung: Entitlements enthalten `aps-environment = development`; Release-Provisioning/Archive-Verhalten ist **UNKNOWN**.

## Conventions

- Stores sind überwiegend `@MainActor ObservableObject`; UI liest Published-State direkt.
- Teure UI-Ableitungen sollen in SnapshotBuilder/ViewModels, nicht in SwiftUI-`body`.
- CloudKit-Sharing-Gruppen müssen über `GroupContext` geroutet werden; UUID-artige IDs niemals in public DB fallbacken.
- CloudKit-Records in geteilten Zonen müssen `record.parent` auf den `FFGroup`-Root setzen.
- Ratings nicht in Movie-Cloud-Payload persistieren; `MovieRating` bleibt eigener Recordtyp.
- Group-scoped Daten müssen mit normalisierter Group-ID keyed werden.
- Bei neuen Codable-Feldern Defaults/Migration berücksichtigen; viele Entities werden aus Legacy-Fixtures dekodiert.
- Kein Fetch/Sort/Network direkt in `body`; `.task(id:)` und cancellable ViewModels bevorzugen.
- Verwende bestehende Caches: `CachedAsyncImage`, `MovieSearchIndexCache`, `PersonPopularityStore`.
- Fehler mit Sync-Status/Toast sichtbar machen; reine `print`-Fehler sind schwer zu debuggen.

## How to work on this project

1. `filmfreaks.xcodeproj` öffnen; aktives Projekt scheint `filmfreaks.xcodeproj` zu sein. Zweck von `TMC - The Movie Club.xcodeproj` ist **UNKNOWN**.
2. `TMDB_API_KEY` über sichere lokale Config/CI setzen; den im ZIP gefundenen Klartext-Key nicht weiterverwenden.
3. iCloud/CloudKit Capabilities prüfen: Container `iCloud.de.marcfechner.filmfreaks`, CloudKit Dashboard Schema, Query Indexes und Push Notifications.
4. Tests zuerst über `filmfreaksTests` laufen lassen; relevante Tests existieren für Cloud Routing, Persistence, Content, MovieNights, Stats, Goals.
5. Für neue UI-Flows:
   - Route in `ContentRoute` ergänzen.
   - Sheet in `ContentRoutingModifier.routedSheet` verdrahten.
   - Toolbar/Header-Action in `ContentView+Toolbar.swift` oder Header-Komponenten ergänzen.
6. Für neue persistente Domain:
   - Codable-Modell + Migration/Default-Werte definieren.
   - Lokale group-scoped Speicherung festlegen.
   - CloudKit RecordType + Routing + Parent-Root in geteilten Zonen implementieren.
   - Zone Changes, Token-Namespace und Retry/Dirty Queue einplanen.
7. Für neue Movie-Felder:
   - `Movie.swift` erweitern.
   - TMDb-Mapping in `MovieDetailLoadedMoviePatch` oder Search Mapper anpassen.
   - CloudKit Payload/Merge prüfen.
   - Legacy-Fixture-Decoding-Tests ergänzen.
8. Für neue Stats:
   - `StatsSnapshot`/Builder erweitern.
   - Heavy Work in `StatsViewModel` detached halten.
   - UI-Karte separat halten, keine Aggregation in View.
9. Für neue MovieNight-Recordtypen:
   - `CloudKitMovieNightStore` Schema/Modify/Snapshot/ZoneChanges erweitern.
   - `CloudKitGroupStore+Sharing.swift` Share-Hierarchy-Repair erweitern.
   - Subscriptions/Push ggf. anpassen.
10. Vor Sync-Änderungen: Offline, App-Kill, Share-Participant und Group-Switch explizit testen.

## Quick Wins

1. `Secrets.xcconfig` aus Repo/ZIP entfernen, API-Key rotieren, `.gitignore`/CI Secret Handling ergänzen.
2. `GoalsStore.yearlyGoalsStorageKey` group-scopen und leere Remote-Ziele korrekt als leer anwenden.
3. Local-Persistence-Ordner vereinheitlichen: `FilmFreaks` vs. `filmfreaks`.
4. `CKError.changeTokenExpired` zentral behandeln: Token löschen, Full/Initial Zone Fetch erzwingen.
5. MovieNight-Recordtypen in `CloudKitGroupStore+Sharing.swift` zur Share-Hierarchy-Repair-Liste hinzufügen.
6. `CloudKitMovieNightStore+Modify.swift` wie Movie-Modify in Chunks schreiben/löschen.
7. Persistentes Dirty Journal für CloudKit-Pending-Queues oder Startup-Diff-Reconciliation einführen.
8. `MovieRouletteView.currentGroupBacklogMovies` von O(n²) auf Dictionary-Lookup umstellen.
9. `GroupSettingsView.activeCardSnapshot` in ViewModel/cached Snapshot verschieben.
10. TMDb Detail-/Cast-Migration-Tasks begrenzen und mit `.task(id:)`/Cancellation strukturieren.

## Open Questions

- **UNKNOWN:** Ist iOS `26.0` als Deployment Target absichtlich?
- **UNKNOWN:** Ist `TMC - The Movie Club.xcodeproj` noch relevant oder ein Artefakt?
- **UNKNOWN:** Welche CloudKit Dashboard Indexes/Schema-Versionen sind deployed?
- **UNKNOWN:** Soll Push-Fetch in Release aktiv sein? `CloudKitActivityPushFetchCoordinator` gibt außerhalb DEBUG aktuell `false` zurück.
- **UNKNOWN:** Wie wird `aps-environment = development` für Release-Builds gehandhabt?
- **UNKNOWN:** Sind Legacy/public Gruppen weiterhin ein Produktfeature oder nur Migration?
- **UNKNOWN:** Gewünschte Konfliktpolitik bei gleichzeitigen Rating-/Goal-/MovieNight-Änderungen auf mehreren Geräten.
- **UNKNOWN:** Ob `Secrets.xcconfig` im echten Repo getrackt ist; im ZIP ist der Key vorhanden.
