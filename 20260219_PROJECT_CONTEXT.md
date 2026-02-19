# PROJECT_CONTEXT.md

## TL;DR
**filmfreaks** ist eine iOS-App (Deployment Target: iOS 26.0) für Filmgruppen: Filme werden als *gesehen* oder *Backlog* geführt, Mitglieder vergeben Bewertungen (pro Kriterium + Fazit), es gibt Ziele/Statistiken/Timeline sowie „Movie Nights“ (Vorschläge, Zusagen). Daten werden lokal als JSON pro Gruppe persistiert und optional via CloudKit (inkl. Sharing-Zonen) synchronisiert.

## Key Concepts (Domänenbegriffe)
- **Group / groupId**: Aktive Filmgruppe, an die alle Daten gebunden sind. Zwei Modi:
  - **Legacy/Public Group**: groupId ist kein UUID-String (z.B. Invite-Code). Routing kann in die Public DB fallen. (MovieStore/MovieStore+Selections.swift, CloudKitRouting.swift)
  - **CloudKit Sharing Group**: groupId ist UUID-String. Daten liegen in einer Record Zone `group.<uuid>` in Private oder Shared DB. Ohne GroupContext ist Routing **blockiert** (kein Public-Fallback). (CloudKitGroupStore.swift, GroupContext.swift, CloudKitRouting.swift)
- **GroupContext**: Persistierte Routing-Metadaten (Scope private/shared, zoneName, ownerName) für eine groupId. (GroupContext.swift)
- **Watched vs Backlog**: Zwei Listen pro Gruppe. (MovieStore.swift, Content/ContentTypes.swift)
- **Rating**: Bewertung pro User und Film, mit Kriterien (1–3 Sterne), optionalem Kommentar und optionalem Fazit (1–10). (Movie.swift)
- **Goals**: Jahresziel (Anzahl Filme) + Custom Goals (Decade, Person, Director, Genre, Keyword) als versionierter Payload. (CloudKitGoalStore.swift, ViewingCustomGoal.swift, Goals/*)
- **Movie Night**: Vorschlag/Termin pro Gruppe + Responses pro User + Activity-Events. (MovieNights/*)

## Architecture Map (Layer, Verantwortlichkeiten, Abhängigkeiten)
- **UI (SwiftUI Views)**
  - Root: `filmfreaksApp.swift` (EnvironmentObject-Wiring, global refresh bei `.active`, Splash, ToastHost)
  - Hauptscreen: `Content/ContentView.swift` (NavigationStack, Listen/Poster-Grid, Header/Controls, Sheet-Routing über `Content/ContentRouting.swift`)
  - Feature-Screens (als Sheets/Flows): Movie Search (`MovieSearch/*`), Movie Detail (`MovieDetail/*`), Goals (`Goals/*`), Stats (`Stats/*`), Timeline (`Timeline/*`), Movie Nights (`MovieNights/UI`, `MovieNights/Calendar`, `MovieNights/Sheets`), Settings (`SettingsView.swift`, `AppearanceSettingsView.swift`), Users (`UsersView.swift`), Group Settings (`GroupSettingsView.swift`).

- **State/Stores (ObservableObject, überwiegend @MainActor)**
  - `MovieStore` (Movies + Backlog, Gruppen-Selektion, Cloud Sync State, Activity Feed) (MovieStore/*)
  - `MovieNightStore` (Events/Responses/Activity, Local Persistence, Cloud Flush) (MovieNights/MovieNightStore.swift + Extensions)
  - `UserStore` (Mitgliederverwaltung pro Gruppe, Selected User) (UserStore.swift)
  - `CloudKitGroupStore` (Owned/Shared Groups, Zone/Share Handling, Subscriptions) (CloudKitGroupStore.swift)
  - `DisplaySettings` (Theme, Layout-Metrics, Toggles) (DisplaySettings.swift + DisplaySettings+*.swift)
  - `NetworkMonitor` (Connectivity) (NetworkMonitor.swift)

- **Persistence & Caches**
  - `PersistenceManager` (JSON Files in Application Support, debounced atomic writes, Migration aus UserDefaults) (PersistenceManager.swift)
  - Kleine Flags/Preferences: `@AppStorage` und `UserDefaults` (z.B. `Onboarding_HasSeenQuickStart`, `ContentView_ViewStyle`, Sync-Meta pro Gruppe) (Content/ContentView.swift, MovieStore/MovieStore+Persistence.swift)
  - HTTP Image Cache: `URLCache.shared` wird im App-Init gesetzt (filmfreaksApp.swift)
  - Feature-Caches: z.B. `Content/MovieSearchIndexCache.swift`, `RecommendationsCacheManager.swift`, `SearchHistoryManager.swift`.

- **CloudKit Integration**
  - **Routing + Safety Guard**: `CloudKitRouting.route(container:groupId:)` entscheidet DB (public/private/shared) und Zone (optional). UUID-like groupIds erfordern `GroupContext` und werfen sonst `groupContextNotReady`. (CloudKitRouting.swift, GroupContext.swift)
  - **CloudKit Stores (low-level, struct/actor-like)**
    - Movies: `CloudKitMovieStore` (RecordType `"Movie"`, payload Data, isBacklog Bool, updatedAt Date, groupId String) (CloudKitMovieStore/*)
    - Ratings: `CloudKitRatingStore` (RecordType `"MovieRating"`, 1 Record pro (movieId, reviewerId, groupId)) (CloudKitRatingStore.swift)
    - Members: `CloudKitUserStore` (RecordType `"GroupMember"`, 1 Record pro Mitglied) (CloudKitUserStore.swift)
    - Goals: `CloudKitGoalStore` (RecordType `"ViewingGoal"`, `"ViewingCustomGoals"`) (CloudKitGoalStore.swift)
    - Movie Nights: `CloudKitMovieNightStore` (RecordTypes `"MovieNightEvent"`, `"MovieNightResponse"`, `"MovieNightActivity"`) (CloudKitMovieNightStore/*)
  - **Sync Koordinatoren**: Debounced + batched Uploads (Movies: `MovieCloudSyncCoordinator.swift`, Movie Nights: `MovieNights/MovieNightCloudSyncCoordinator.swift`)
  - **Incremental Sync (Sharing Groups)**: `CKFetchRecordZoneChangesOperation` Wrapper + ChangeToken Store (CloudKitZoneChanges.swift, CloudKitZoneChangeTokenStore.swift, CloudKitMovieStore/CloudKitMovieStore+ZoneChanges.swift)
  - **Sharing Acceptance**: AppDelegate + SceneDelegate + Coordinator (CloudKitShareAppDelegate.swift, CloudKitShareSceneDelegate.swift, CloudKitShareCoordinator.swift)
  - **Push/Notifications (P2)**: Subscription Manager + Push Fetch Coordinator + Local Notifier (CloudKit/CloudKitActivitySubscriptionManager.swift, CloudKit/CloudKitActivityPushFetchCoordinator.swift, Notifications/GroupActivityLocalNotifier.swift)

## Folder Map (Ordner → Zweck)
- `Content/` → Home-Screen UI, Routing, Onboarding, Group Activity, Derived Data für Listen/Grid.
- `MovieStore/` → `MovieStore` Kernlogik + Extensions (Mutations, Persistence, Cloud Sync, Selections, Activity).
- `CloudKitMovieStore/` → CloudKit Read/Write/Merge/ZoneChanges für Movie Records.
- `CloudKitMovieNightStore/` → CloudKit Read/Write/Snapshot/ZoneChanges für Movie Night Records.
- `MovieNights/` → Domain-Modelle, Store, Local Persistence, UI (Calendar/Sheets).
- `MovieSearch/` → Suche (TMDb), Ergebnislisten, UI-Flow.
- `SearchResultDetail/` → Detailansicht für Such-Ergebnis (TMDb Details).
- `MovieDetail/` → Detailansicht für gespeicherte Filme, Ratings UI, Trailer, Watch Providers.
- `Goals/` → Ziele UI + Goal-Typen + Matching/Enrichment/Derived Helpers.
- `Stats/` → Statistiken UI + Aggregationen + Drilldowns.
- `Timeline/` → Timeline UI + Datenaufbereitung.
- `Notifications/` → Permission, DeepLink Router, Local Notifications, Identity Store.
- `CloudKit/` → Subscriptions, Push Debugger, Push Fetch Coordinator.
- `Assets.xcassets/` → App Assets.

## Data Model Map (Entities, Relationships, wichtige Felder)
- **Movie** (Movie.swift)
  - `id: UUID`, `title`, `year`, `tmdbId`, `posterPath`, `watchedDate`, `watchedLocation`
  - `ratings: [Rating]` (lokal; CloudKitMovieStore entfernt Ratings aus dem Movie-Payload) (CloudKitMovieStore/CloudKitMovieStore+Merge.swift)
  - `addedAt`, `addedById`, `addedByName` (Activity/Timeline)
  - `genres/genreIds`, `keywords/keywordIds`, `cast`, `directors`
  - `groupId`, `groupName` (best-effort)
- **Rating** (Movie.swift)
  - `id: UUID`, `reviewerId: UUID?` (stabil), `reviewerName`, `scores: [RatingCriterion:Int]`, `comment`, `fazitScore`, `updatedAt`
- **User** (User.swift)
  - `id: UUID`, `name`
- **GroupContext** (GroupContext.swift)
  - `id: String` (groupId), `name`, `scope: private/shared`, `zoneName`, `ownerName`
- **GroupInfo** (MovieStore.swift)
  - `id`, `name` für „bekannte Gruppen“ (UserDefaults)
- **Viewing Goals**
  - Jahresziel: `year -> target` (CloudKitGoalStore.swift)
  - Custom Goals: `ViewingCustomGoal` + `ViewingCustomGoalRule` (ViewingCustomGoal.swift)
- **Movie Nights**
  - `MovieNightEvent` (MovieNights/MovieNightEvent.swift): `groupId`, `proposedStart`, `proposerUserId`, `suggestedMovie`, `status`, `createdAt/updatedAt`
  - `MovieNightResponse` (MovieNights/MovieNightResponse.swift): `(eventId, userId)` + `decision`, `respondedAt`

## Sync/Storage (SwiftData/CoreData? CloudKit? Caches? Migration? Offline)
- **SwiftData/CoreData**: **Nicht verwendet** (keine @Model Entities im Projekt; Persistenz ist JSON-basiert). **UNKNOWN** falls in einem anderen Target/Branch existiert.
- **Lokale Persistenz**
  - Movies/Backlog/Users werden pro Gruppe als JSON in `~/Library/Application Support/FilmFreaks/groups/<gid>/*.json` gespeichert. (PersistenceManager.swift)
  - Writes sind debounced (0.55s) und atomic; Writes werden bei Gruppen-Delete gecancelt. (PersistenceManager.swift)
  - Migration: UserDefaults Keys (`FilmFreaks.movies.v1`, `FilmFreaks.backlogMovies.v1`, `FilmFreaks.users.v1`, `Users_*`) werden best-effort in Files migriert und das Flag `FilmFreaks.diskPersistence.v2.migrated` gesetzt. (PersistenceManager.swift)
- **CloudKit Sync**
  - Group Routing: `CloudKitRouting.swift` entscheidet DB + Zone; UUID-like groupId ohne GroupContext wirft Fehler (kein Public-Fallback). (CloudKitRouting.swift)
  - Movies: payload ohne Ratings (Ratings separat). (CloudKitMovieStore/*)
  - Ratings: 1 Record pro (movieId, reviewerId, groupId). RecordName ist base64-url codiert (stabil). (CloudKitRatingStore.swift)
  - Pending Uploads: debounced Batch Flush in `MovieCloudSyncCoordinator.swift` und `MovieNights/MovieNightCloudSyncCoordinator.swift`.
  - Incremental Sync für Sharing-Gruppen: Zone Changes + ChangeToken Store. (CloudKitZoneChanges.swift, CloudKitZoneChangeTokenStore.swift, CloudKitMovieStore/CloudKitMovieStore+ZoneChanges.swift)
- **Offline-Verhalten**
  - UI arbeitet auf lokalen Arrays; Änderungen werden lokal persistiert und (bei vorhandenem Cloud) queued. (MovieStore/MovieStore+Persistence.swift, MovieCloudSyncCoordinator.swift)
  - Sync-Transparenz pro Gruppe: `pendingCloudChangesCount`, `lastCloudSyncAt`, `lastCloudSyncError` werden in UserDefaults pro groupId gespeichert. (MovieStore/MovieStore+Persistence.swift)

## UI Map (Hauptscreens, Navigation, wichtige Sheets/Flows)
- Root Scene: `filmfreaksApp.swift` → `ContentView` im `NavigationStack`.
- Home (`Content/ContentView.swift`)
  - Header (Group, User, Activity Teaser) + Mode Switch (watched/backlog) + Liste/Grid.
  - Sheets über `ContentRoute` (Content/ContentRouting.swift):
    - Settings (SettingsView.swift)
    - Quick Start (QuickStartView.swift)
    - Movie Search (MovieSearch/MovieSearchView.swift)
    - Users (UsersView.swift)
    - Stats (Stats/StatsView.swift)
    - Timeline (Timeline/TimelineView.swift)
    - Calendar / Movie Nights (MovieNights/Calendar/*)
    - Group Activity (Content/GroupActivityListView.swift)
    - Goals (Goals/GoalsView.swift)
    - Group Settings (GroupSettingsView.swift)
- Movie Detail: `MovieDetail/MovieDetailView.swift` + Ratings Sheet `MovieDetail/MovieRatingsSheetView.swift`.
- Group Sharing: `GroupShareSheetView.swift`, `CloudSharingControllerView.swift`, `CloudKitShareCoordinator.swift`.
- Notifications: DeepLinks via `Notifications/PushDeepLinkRouter.swift`.

## Build & Configuration
- Target: `filmfreaks` (und `filmfreaksTests`, siehe `filmfreaks.xcodeproj/project.pbxproj`) (filmfreaks.xcodeproj/project.pbxproj)
- Deployment Target: iOS **26.0** (filmfreaks.xcodeproj/project.pbxproj)
- Entitlements: CloudKit + iCloud Container `iCloud.de.marcfechner.filmfreaks`, APS env `development`. (filmfreaks.entitlements)
- Info.plist:
  - `CKSharingSupported = true`
  - `UIBackgroundModes = remote-notification`
  - `TMDB_API_KEY = $(TMDB_API_KEY)` (Info.plist)
- Build Config:
  - `Debug.xcconfig`, `Release.xcconfig`, `Secrets.xcconfig` (TMDb Key). (Debug.xcconfig, Release.xcconfig, Secrets.xcconfig)
  - `.gitignore` ignoriert `Secrets.xcconfig`. (/.gitignore)
- Dependencies: keine SPM Packages im pbxproj; Nutzung von System-Frameworks (SwiftUI, CloudKit, Combine, CryptoKit, UserNotifications). (Imports in diversen Dateien)

## Conventions (Naming, Patterns, Do/Don't)
- Stores sind häufig `@MainActor` + `ObservableObject` und werden als `EnvironmentObject` injiziert. (filmfreaksApp.swift, MovieStore.swift, MovieNightStore.swift, UserStore.swift, CloudKitGroupStore.swift)
- Große Komponenten werden per File-Split über `+Feature.swift` Extensions modularisiert (z.B. `MovieStore/*`, `MovieDetail/*`, `Content/ContentView+*.swift`, `Stats/StatsView+*.swift`).
- CloudKit Store Layer ist als `struct` kapsuliert und ebenfalls per Extensions getrennt. (CloudKitMovieStore/*, CloudKitMovieNightStore/*)
- **Do**: Derived Data aus Renderpfaden halten (Beispiel: `Content/ContentMovieItemsModel.swift`).
- **Don't**: Unbounded `.task {}` ohne Gate/Throttle in häufig invalidierten Views. (Siehe Hotspot-Notes in ARCHITECTURE_NOTES.md)

## How to work on this project (Setup + wo anfangen)
### Setup Steps
1. Xcode öffnen, `filmfreaks.xcodeproj`.
2. iCloud/CloudKit Capability aktiv, Container `iCloud.de.marcfechner.filmfreaks` muss im Team existieren. (filmfreaks.entitlements)
3. `Secrets.xcconfig` lokal hinterlegen (TMDb Key). Datei ist in `.gitignore`. (Secrets.xcconfig, /.gitignore)
4. Run auf Device/Simulator mit iCloud Login testen (Sharing + Shared DB erfordert iCloud).

### Wo anfangen (für neue Devs)
- Einstieg: `filmfreaksApp.swift` → `Content/ContentView.swift` → `MovieStore/MovieStore.swift`
- Sync-Routing verstehen: `CloudKitRouting.swift` + `GroupContext.swift` + `CloudKitGroupStore.swift`
- Movie Nights: `MovieNights/MovieNightStore.swift` + `CloudKitMovieNightStore/*`

## Quick Wins (max. 10, konkret)
1. **Secrets absichern**: Sicherstellen, dass `Secrets.xcconfig` nie in Releases/Repos landet; Key-Rotation falls bereits geleakt. (Secrets.xcconfig, /.gitignore)
2. **Stats Aggregationen cachen**: `Stats/StatsView+Calculations.swift` in ein `@StateObject` ViewModel verschieben, das nur neu rechnet wenn `movieStore.movies` oder Filter sich ändern. (Stats/StatsView+Calculations.swift)
3. **Public Group Skalierung**: Für legacy/public Gruppen (ohne Zone) einen „incremental-ish“ Fetch einführen: Query nach `updatedAt` > lastSyncAt, statt full query. (CloudKitMovieStore/CloudKitMovieStore+Routing.swift, MovieStore/MovieStore+Persistence.swift)
4. **Task-Cancellation/Throttle im App-Refresh**: In `filmfreaksApp.swift` (scenePhase `.active`) parallele Refresh-Tasks vermeiden (Cancel + debounce). (filmfreaksApp.swift)
5. **UI Invalidations reduzieren**: In `Content/ContentView.swift` Derived Computations weiter minimieren und `@State`/`@EnvironmentObject` nur dort binden, wo nötig. (Content/ContentView.swift, Content/ContentMovieItemsModel.swift)
6. **Logging vereinheitlichen**: `os.Logger` statt `print` in Cloud/Sync Paths (z.B. MovieStore+CloudSync, CloudKitGroupStore). (MovieStore/MovieStore+CloudSync.swift, CloudKitGroupStore.swift)
7. **GroupContext Readiness sichtbar machen**: `CloudKitRoutingError.groupContextNotReady` als UI State behandeln (disable Aktionen, „wird geladen“ Hinweis, optional Retry). (CloudKitRouting.swift, MovieNights/Sheets/*)
8. **Consistency: groupId Normalization**: Einheitlich `CloudKitRouting.normalizedGroupId(_:)` nutzen statt eigener Trim-Logik in Stores. (CloudKitRouting.swift, CloudKitRatingStore.swift)
9. **File Size Guards**: In `PersistenceManager` optional „max file size“ + Warnung bei sehr großen JSONs (Disk/Decode Zeit). (PersistenceManager.swift)
10. **Smoke Tests**: Minimaltests für Rating RecordID Encoding + Movie Merge Helpers. (CloudKitRatingStore.swift, CloudKitMovieStore/CloudKitMovieStore+Merge.swift)

## Open Questions (UNKNOWN)

- **UNKNOWN**: Gibt es geplante Migration zu SwiftData oder CoreData in einem anderen Branch/Target
- **UNKNOWN**: Welche CloudKit Record Types und Indexes sind in der CloudKit Console tatsächlich angelegt, inkl. Query Subscriptions
- **UNKNOWN**: CI/CD (Fastlane, TestFlight), Crash Reporting, Analytics
- **UNKNOWN**: App Groups / Shared Container Nutzung (aktuell nicht sichtbar)
