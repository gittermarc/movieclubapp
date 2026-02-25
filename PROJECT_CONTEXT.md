# PROJECT_CONTEXT.md

## TL;DR
**filmfreaks** ist eine iOS-App (iPhone + iPad) zum Tracken von Filmen in **Gruppen**: gesehene Filme + Backlog, **Bewertungen pro Mitglied**, **Stats**, **Timeline/Activity**, sowie **Movie Nights** (Filmabend-Vorschläge inkl. Zusagen/Absagen). Daten werden lokal (JSON auf Disk) persistiert und optional über **CloudKit** (inkl. Sharing/Shared DB) synchronisiert.  
**Mindest-iOS:** 26.0 (Quelle: `filmfreaks.xcodeproj/project.pbxproj`)  
**Entry Point:** `filmfreaks/filmfreaksApp.swift`

## Key Concepts / Domänenbegriffe
- **Watched vs Backlog**: Beides sind `Movie`-Listen; watched ist i.d.R. über `watchedDate != nil` erkennbar (`filmfreaks/Movie.swift`).
- **Group / groupId**: Aktive Gruppe im `MovieStore` (`currentGroupId`, `currentGroupName`) (`filmfreaks/MovieStore/MovieStore.swift` + `filmfreaks/MovieStore/MovieStore+Selections.swift`).
- **GroupContext**: Persistierte Routing-Metadaten (DB-Scope + Zone + Owner) für CloudKit-Sharing-Gruppen (`filmfreaks/GroupContext.swift`).
- **Rating**: Bewertung eines Users für einen Film (mit stabilem `reviewerId`) (`filmfreaks/Movie.swift`). Ratings werden in CloudKit als eigene Records gespeichert (`filmfreaks/CloudKitRatingStore/*`).
- **Movie Nights**: `MovieNightEvent` + `MovieNightResponse` + `MovieNightActivityEvent` pro Gruppe (`filmfreaks/MovieNights/*`).
- **Custom Goals**: Versionierbares Goal-Model (`ViewingCustomGoal`) mit Zeitraum (`startYear`, `durationYears`) (`filmfreaks/ViewingCustomGoal.swift`).

## Architecture Map (Layer + Verantwortlichkeiten)
- **UI (SwiftUI Views)**  
  - Root/Home: `filmfreaks/Content/*` (z.B. `ContentView`, Routing, Header, Listen)  
  - Feature-Views: `MovieDetail/`, `MovieSearch/`, `Stats/`, `Goals/`, `MovieNights/`, `Timeline/`, `SettingsView.swift`
- **UI Models / Cached Derivations (off render path)**  
  - z.B. `ContentMovieItemsModel`, `ContentActivityPreviewModel` werden als `@StateObject` in `ContentView` gehalten (`filmfreaks/Content/ContentView.swift`)  
  - Stats-Aggregation: `StatsViewModel` + `StatsSnapshotBuilder` (`filmfreaks/Stats/*`)
- **Stores (ObservableObject, meist @MainActor)**  
  - `MovieStore` (watched/backlog + group selection + cloud sync wiring) (`filmfreaks/MovieStore/*`)  
  - `UserStore` (aktiver User / Mitglieder-Handling) (`filmfreaks/UserStore.swift`)  
  - `MovieNightStore` (Events/Responses/Activity + Sync-Transparenz) (`filmfreaks/MovieNights/MovieNightStore.swift`)
  - `CloudKitGroupStore` (Owned/Shared Gruppen, Sharing, Subscriptions) (`filmfreaks/CloudKitGroupStore/*`)
- **Sync/Infrastructure**
  - CloudKit access “pro Domäne”:  
    - Movies: `filmfreaks/CloudKitMovieStore/*`  
    - Ratings: `filmfreaks/CloudKitRatingStore/*`  
    - Movie Nights: `filmfreaks/CloudKitMovieNightStore/*`  
    - Goals: `filmfreaks/CloudKitGoalStore.swift`  
    - Members: `filmfreaks/CloudKitUserStore.swift`
  - Routing DB/Zone: `filmfreaks/CloudKitRouting.swift` (+ `GroupContextStore` in `filmfreaks/GroupContext.swift`)
  - ChangeTokens: `filmfreaks/CloudKitZoneChangeTokenStore.swift`
  - Push/Subscriptions: `filmfreaks/CloudKit/*` + `filmfreaks/CloudKitShareAppDelegate.swift`
- **External API**
  - TMDb: `filmfreaks/TMDbAPI/*` (Search, Details, WatchProviders etc.)

## Folder Map (Ordner → Zweck)
- `Assets.xcassets/` — App-Assets (Icons, Farben, Bilder).  
  *Swift files:* 0
- `CloudKit/` — Cross-cutting CloudKit/Push-Helfer (Subscriptions, Remote-Notification Debug/Fetch).  
  *Swift files:* 3
- `CloudKitGroupStore/` — Gruppenverwaltung via CloudKit Sharing (Listen, Erstellen/Joinen, Subscriptions).  
  *Swift files:* 4
- `CloudKitMovieNightStore/` — CloudKit-Access für Movie Nights (Schema, Reads, Writes, ZoneChanges).  
  *Swift files:* 6
- `CloudKitMovieStore/` — CloudKit-Access für Movie Records (Schema, Routing, Modify, ZoneChanges, Merge).  
  *Swift files:* 6
- `CloudKitRatingStore/` — CloudKit-Access für Ratings (separate Records, Queries, ZoneChanges).  
  *Swift files:* 5
- `Content/` — Root/Home UI, Routing, Listen/Grid, Activity-Preview, Header-Komposition.  
  *Swift files:* 32
- `DisplaySettings/` — UI/Appearance Settings (Tint, LayoutMetrics, Persistenz).  
  *Swift files:* 7
- `Goals/` — Ziele (Yearly + Custom Goals), Matching, Editor, Persistenz/Cloud Sync.  
  *Swift files:* 22
- `MovieDetail/` — Film-Detail UI (Rating, Providers, Aktionen, Sections).  
  *Swift files:* 19
- `MovieNights/` — Movie Night Domain (Event/Response/Activity) + Calendar + Sheets + Store.  
  *Swift files:* 24
- `MovieSearch/` — TMDb Suche UI (Query, Sorting, Pagination) + Detail Sheet Routing.  
  *Swift files:* 20
- `MovieStore/` — Zentraler Store für watched/backlog + Group Selection + Persistenz + Cloud Sync.  
  *Swift files:* 6
- `Notifications/` — Push/Permissions/Deep-Link Utilities.  
  *Swift files:* 6
- `SearchResultDetail/` — TMDb Suchergebnis-Detail Sheet (Loads/Actions/State).  
  *Swift files:* 13
- `Stats/` — Stats UI + ViewModel + Snapshot Compute + Komponenten.  
  *Swift files:* 18
- `TMDbAPI/` — Netzwerk-Layer für TMDb (Search, Details, Providers, Models).  
  *Swift files:* 7
- `Timeline/` — Timeline UI/Model (Aktivitäten/Events in der Gruppe).  
  *Swift files:* 7

## Data Model Map (Entities, Relationships, wichtige Felder)
- `Movie` (`filmfreaks/Movie.swift`) — watched/backlog Item (via `watchedDate`)
  - `var id: UUID`
  - `var title: String`
  - `var year: String`
  - `var tmdbRating: Double?`
  - `var ratings: [Rating]`
  - `var posterPath: String?`
  - `var watchedDate: Date?`
  - `var watchedLocation: String?`
  - `var tmdbId: Int?`
  - `var genres: [String]?`
  - `var genreIds: [Int]?`
  - `var keywords: [String]?`
  - `var keywordIds: [Int]?`
  - `var suggestedBy: String?`
  - `var addedAt: Date? = nil`
  - `var addedById: UUID? = nil`
  - `var addedByName: String? = nil`
  - `var cast: [CastMember]?`
  - `var directors: [CastMember]?`
  - `var groupId: String?`
  - `var groupName: String?`

- `Rating` (`filmfreaks/Movie.swift`) — User-Bewertung pro Film (CloudKit separat)
  - `var id = UUID()`
  - `var reviewerId: UUID? = nil`
  - `var reviewerName: String`
  - `var scores: [RatingCriterion: Int]`
  - `var comment: String? = nil`
  - `var fazitScore: Int? = nil`
  - `var updatedAt: Date? = nil`

- `User` (`filmfreaks/User.swift`)
  - `var id = UUID()`
  - `var name: String`

- `GroupContext` (`filmfreaks/GroupContext.swift`) — Routing-Metadaten für CloudKit DB/Zone
  - `let id: String`
  - `var name: String`
  - `var scope: GroupScope`
  - `var zoneName: String`
  - `var ownerName: String`

- `ViewingCustomGoal` (`filmfreaks/ViewingCustomGoal.swift`) — Custom Goal + Zeitraum
  - `var id: UUID`
  - `var type: ViewingCustomGoalType`
  - `var rule: ViewingCustomGoalRule`
  - `var target: Int`
  - `var createdAt: Date`
  - `var startYear: Int`
  - `var durationYears: Int`

- `MovieNightEvent` (`filmfreaks/MovieNights/MovieNightEvent.swift`)
  - `var id: UUID`
  - `var groupId: String`
  - `var proposedStart: Date`
  - `var createdAt: Date`
  - `var updatedAt: Date`
  - `var proposerUserId: UUID`
  - `var proposerName: String`
  - `var suggestedMovie: MovieNightMovieRef?`
  - `var note: String?`
  - `var status: Status`

- `MovieNightResponse` (`filmfreaks/MovieNights/MovieNightResponse.swift`)
  - `var eventId: UUID`
  - `var userId: UUID`
  - `var userName: String`
  - `var decision: Decision`
  - `var respondedAt: Date`

- `MovieNightActivityEvent` (`filmfreaks/MovieNights/MovieNightActivityEvent.swift`)
  - `var id: UUID = UUID()`
  - `var groupId: String`
  - `var kind: Kind`
  - `var createdAt: Date`
  - `var eventId: UUID`
  - `var eventStart: Date`
  - `var actorUserId: UUID`
  - `var actorName: String`
  - `var decision: MovieNightResponse.Decision?`
  - `var newStatus: MovieNightEvent.Status?`
  - `var note: String?`

- `MovieNightMovieRef` (`filmfreaks/MovieNights/MovieNightMovieRef.swift`) — referenziert Backlog-Movie
  - `var movieId: UUID`
  - `var title: String`
  - `var year: String`
  - `var posterPath: String?`
  - `var tmdbId: Int?`

## Sync/Storage
### Lokal (Disk / UserDefaults)
- **Movies/Backlog/Users**: File-basierte Persistenz in Application Support via `PersistenceManager` (`filmfreaks/PersistenceManager.swift`).  
  - Debounce-Schreiben (0.55s) + atomic writes via Hintergrund-Queue.  
  - Migration von UserDefaults (Flag: `"FilmFreaks.diskPersistence.v2.migrated"`).
- **GroupContext**: Speicherung als `[String: Data]` in UserDefaults (`filmfreaks/GroupContext.swift`).
- **Settings/Preferences**:  
  - Display: `filmfreaks/DisplaySettings/DisplaySettings+Persistence.swift`  
  - Goals: `filmfreaks/Goals/GoalsView+Persistence.swift`  
  - Weitere kleine Flags: z.B. `@AppStorage("Onboarding_HasSeenQuickStart")` (`filmfreaks/Content/ContentView.swift`)
- **Movie Nights (local-first)**: JSON via `MovieNightLocalPersistence` (`filmfreaks/MovieNights/MovieNightLocalPersistence.swift`) + Store-Persistenz (`filmfreaks/MovieNights/MovieNightStore+Persistence.swift`).

### CloudKit
- **Sharing + Gruppen**
  - Gruppendefinition: RecordType `"FFGroup"` (`filmfreaks/CloudKitGroupStore/CloudKitGroupStore.swift`)
  - DBs: private + shared (`container.privateCloudDatabase`, `container.sharedCloudDatabase`) (`filmfreaks/CloudKitGroupStore/CloudKitGroupStore.swift`)
  - GroupContext wird genutzt, um DB/Zone korrekt zu routen (kein “Public-Fallback” bei UUID-GroupIds) (`filmfreaks/CloudKitRouting.swift`).
- **Movies**
  - RecordType `"Movie"`, Payload-Key `"payload"` (Data: JSON-encoded `Movie`) + `isBacklog` + `updatedAt` + `groupId` (`filmfreaks/CloudKitMovieStore/CloudKitMovieStore.swift`).
  - Writes: debounced + batched via `MovieCloudSyncCoordinator` (`filmfreaks/MovieCloudSyncCoordinator.swift`) und Integration im `MovieStore` (`filmfreaks/MovieStore/MovieStore+Persistence.swift` + `...+CloudSync.swift`).
- **Ratings**
  - RecordType `"MovieRating"` mit separatem Payload (`Rating`) und Indizes (`movieId`, `groupId`, `reviewerId`) (`filmfreaks/CloudKitRatingStore/CloudKitRatingStore+Schema.swift`).
- **Goals**
  - Yearly: RecordType `"ViewingGoal"` (groupId + year + target)  
  - Custom: RecordType `"ViewingCustomGoals"` (payload) (`filmfreaks/CloudKitGoalStore.swift`)
- **Movie Nights**
  - RecordTypes `"MovieNightEvent"`, `"MovieNightResponse"`, `"MovieNightActivity"` (`filmfreaks/CloudKitMovieNightStore/CloudKitMovieNightStore.swift`)
  - Inkrementelle Sync-Strategie über ZoneChanges + Tokens: `CloudKitZoneChangeTokenStore` (`filmfreaks/CloudKitZoneChangeTokenStore.swift`) + ZoneChanges Implementierungen (`filmfreaks/CloudKitMovieNightStore/*ZoneChanges.swift`, `filmfreaks/CloudKitMovieStore/*ZoneChanges.swift`, `filmfreaks/CloudKitRatingStore/*ZoneChanges.swift`).

### Offline-Verhalten (best effort, aus Code ableitbar)
- Änderungen werden lokal persistiert (Movies/Backlog/Goals/MovieNights).  
- Cloud-Uploads sind debounced/queued (Movies: `MovieCloudSyncCoordinator`, Movie Nights: `MovieNightCloudSyncCoordinator`) und hängen von Network-Availability ab (`filmfreaks/NetworkMonitor.swift`).  
- **UNKNOWN**: Ob UI explizit “offline mode” zeigt oder nur Sync-Status in Settings/Views (bitte verifizieren).

## UI Map (Hauptscreens + Navigation)
### Root
- `filmfreaksApp` → `ContentView` als Root (`filmfreaks/filmfreaksApp.swift`)
- `ContentView` ist `NavigationStack`-Root und hängt Sheet-Routing über `ContentRoute` an (`filmfreaks/Content/ContentView.swift`, `filmfreaks/Content/ContentRouting.swift`).

### Sheet-Routing (aus `ContentRoute`)
- `settings` → Settings (`filmfreaks/SettingsView.swift`)
- `quickStart` → QuickStart (`filmfreaks/QuickStartView.swift`)
- `movieSearch` → Suche (`filmfreaks/MovieSearch/MovieSearchView.swift`)
- `users` → User-Management (`filmfreaks/UsersView.swift`)
- `stats` → Stats (`filmfreaks/Stats/StatsView.swift`)
- `timeline` → Timeline (`filmfreaks/Timeline/*`)
- `calendar` → Movie Nights Calendar (`filmfreaks/MovieNights/Calendar/MovieNightCalendarView.swift`)
- `activity` → Group Activity (`filmfreaks/Content/GroupActivityListView.swift`)
- `goals` → Goals (`filmfreaks/Goals/GoalsView.swift`)
- `groupSettings` → Gruppen/Sharing Settings (`filmfreaks/GroupSettingsView.swift`)

### Detail-Flows (Auswahl)
- Movie Detail: `filmfreaks/MovieDetail/MovieDetailView.swift` (von Listen/Backlog)
- Search Result Detail (TMDb): `filmfreaks/SearchResultDetail/*` (Sheet)
- Movie Night Detail Sheet: `filmfreaks/MovieNights/Sheets/MovieNightDetailSheet/*`

## Build & Configuration
- Xcode Project: `filmfreaks.xcodeproj`
- Targets: `filmfreaks, filmfreaksTests, filmfreaksUITests` (Quelle: `filmfreaks.xcodeproj/project.pbxproj`)
- Deployment Target: `26.0` (`IPHONEOS_DEPLOYMENT_TARGET` in `project.pbxproj`)
- Device Family: `1,2` (1=iPhone, 2=iPad; `TARGETED_DEVICE_FAMILY` in `project.pbxproj`)
- Entitlements: `filmfreaks/filmfreaks.entitlements`
  - iCloud Container: `iCloud.de.marcfechner.filmfreaks`
  - iCloud Service: CloudKit
  - APS Environment: `development`
- Info.plist: `filmfreaks/Info.plist`
  - `CKSharingSupported = True`
  - `UIBackgroundModes = ['remote-notification']`
  - `TMDB_API_KEY` existiert als Key (Wert kommt via Build Settings / .xcconfig)
- Build Config (.xcconfig): `filmfreaks/Debug.xcconfig`, `filmfreaks/Release.xcconfig`, `filmfreaks/Secrets.xcconfig`
  - `Secrets.xcconfig` enthält `TMDB_API_KEY` als Klartext. **Sicherheitsrisiko** (siehe Quick Wins).

## Conventions (Naming, Patterns, Do/Don’t)
- **File-Splits via Extensions/Subviews**: `Type+Topic.swift` Pattern ist Standard (z.B. `MovieStore+CloudSync.swift`, `CloudKitMovieStore+*.swift`, `SearchResultDetailView+*.swift`).
- **Stores auf MainActor**: Viele Stores sind `@MainActor` und liefern `@Published` State (z.B. `MovieStore`, `StatsViewModel`, `MovieNightStore`).
- **Expensive Work aus dem Render-Pfad raus**:
  - Content: `ContentMovieItemsModel` + `ContentActivityPreviewModel` (off render path) (`filmfreaks/Content/ContentView.swift`)
  - Stats: Snapshot-Compute in `StatsSnapshotBuilder` und im `StatsViewModel` debounced off-main (`filmfreaks/Stats/StatsSnapshotBuilder.swift`, `filmfreaks/Stats/StatsViewModel.swift`)
- **CloudKit**: Routing zentral über `CloudKitRouting` (Guard gegen falsches Routing bei UUID-like groupIds) (`filmfreaks/CloudKitRouting.swift`).

## How to work on this project (Setup + wo anfangen)
1. Öffne `filmfreaks.xcodeproj` in Xcode.
2. Prüfe Build Settings:
   - Deployment Target iOS `26.0`
   - `.xcconfig` include: `Debug.xcconfig` / `Release.xcconfig` inkludieren `Secrets.xcconfig` (`filmfreaks/Debug.xcconfig`, `filmfreaks/Release.xcconfig`).
3. CloudKit / iCloud:
   - Entitlements + Container-ID prüfen (`filmfreaks/filmfreaks.entitlements`).
   - **UNKNOWN**: Ob CloudKit Dashboard Schema bereits provisioniert ist (RecordTypes siehe Sync/Storage).
4. Push Notifications:
   - Background Mode `remote-notification` aktiv (`filmfreaks/Info.plist`)
   - Delegate: `CloudKitShareAppDelegate` registriert UNUserNotificationCenter Delegate (`filmfreaks/CloudKitShareAppDelegate.swift`)
5. “Start Here” fürs Verständnis:
   - Root & Refresh-Cascade: `filmfreaks/filmfreaksApp.swift`
   - Group Routing: `filmfreaks/CloudKitRouting.swift` + `filmfreaks/GroupContext.swift`
   - Movie Data Flow: `filmfreaks/MovieStore/MovieStore.swift` + `...+Persistence.swift` + `...+CloudSync.swift`

## Quick Wins (max. 10, konkret)
1. **Secrets rotieren & aus Repo entfernen**: `filmfreaks/Secrets.xcconfig` enthält `TMDB_API_KEY` im Klartext → Key rotieren; `Secrets.xcconfig` per `.gitignore` und `Secrets.example.xcconfig` einführen.
2. **Calendar Render-Pfad glätten**: `MonthGridView` gruppiert Events per `Dictionary(grouping:)` im View-Compute (`filmfreaks/MovieNights/Calendar/MonthGridView.swift`) → vorcomputen/cachen im Model.
3. **Activity Sorting cachen**: `GroupActivityListView` sortiert `(movies + nights)` im View-Compute (`filmfreaks/Content/GroupActivityListView.swift`) → sortierte Liste im `ContentActivityPreviewModel` bereitstellen.
4. **GoalsView: Jahr-Liste stabilisieren**: `Array(Set(...)).sorted` im View (`filmfreaks/Goals/GoalsView.swift`) → in derived model auslagern.
5. **CloudKitRouting Errors sichtbar machen**: `CloudKitRoutingError.groupContextNotReady` konsequent als UX-Toast/Hint mappen (statt silent fail) (Startpunkt: `filmfreaks/CloudKitRouting.swift`).
6. **OSLog statt print**: vereinheitlichen (es gibt bereits `Logger` in `PersistenceManager`) → Kategorien für CloudKit/MovieStore/MovieNights.
7. **Unit-Tests für deterministische IDs**: z.B. Stable reviewerId-Migration in `CloudKitRatingStore` (`filmfreaks/CloudKitRatingStore/CloudKitRatingStore+Schema.swift`) + `CloudKitUserStore` Legacy-Migration (`filmfreaks/CloudKitUserStore.swift`).
8. **“Refresh cascade” Telemetrie**: `AppRefreshCoordinator` loggt Start/Ende + Dauer, um CloudKit-Spikes zu finden (`filmfreaks/AppRefreshCoordinator.swift`).
9. **File Split**: `MovieStore+CloudSync.swift` weiter splitten (Fetch vs Merge vs Apply) → bessere Orientierung, weniger Merge-Konflikte.
10. **Audit: MainActor contention**: JSON encode/decode + diff-work prüfen (Movies/Ratings) → wo möglich in Hintergrund-Queue verlagern (unter Wahrung der Thread-Safety).


## Dependencies (Frameworks / 3rd Party)
- Apple Frameworks (in Code sichtbar): `SwiftUI`, `Combine`, `CloudKit`, `CryptoKit`, `UserNotifications`, `os`, `UIKit` (z.B. `filmfreaks/CloudKitShareAppDelegate.swift`, `filmfreaks/PersistenceManager.swift`).
- Swift Package Manager:
  - **Kein** `XCRemoteSwiftPackageReference` im `filmfreaks.xcodeproj/project.pbxproj` gefunden → aktuell **keine** SPM-Dependencies im Projekt.  
    **UNKNOWN**: Falls Packages via Workspace eingebunden sind (nicht im Upload), bitte verifizieren.

## Typical Workflows (wie fügt man ein Feature hinzu)
### 1) Neuer Screen / neue Sheet-Route
- Route ergänzen: `filmfreaks/Content/ContentRouting.swift` (`ContentRoute` + `ContentRoutingModifier`)
- Entry point (wo öffnen): meist `ContentHeaderView` / Buttons in `filmfreaks/Content/*`
- View implementieren in Feature-Ordner (z.B. `Stats/`, `Goals/`, `MovieNights/`)
- Test-Checklist:
  - Sheet öffnet/schließt korrekt (Swipe-Down, Dismiss Button)
  - NavigationStack State bleibt stabil (kein “double present”)

### 2) Neue persisted Einstellung (UI/Behavior)
- Modell:
  - Falls display/appearance: `filmfreaks/DisplaySettings/*`
  - Sonst: eigener kleiner Settings-Store oder `@AppStorage` Key (sparsam!)
- Persistenz:
  - Kleine Werte: `@AppStorage` / `UserDefaults`
  - Größere Payloads: Disk-File (Pattern: `PersistenceManager` oder “LocalPersistence”-File)
- UI:
  - `filmfreaks/SettingsView.swift` + ggf. Section-SubViews
- Test-Checklist:
  - Setting togglen → App kill/relaunch → Wert bleibt
  - Setting wirkt ohne UI-Flackern (tint/font/colorScheme)

### 3) Neuer CloudKit-syncbarer Datentyp (Pattern)
- Domain Model: `struct ...: Codable` (wie `MovieNightEvent`, `ViewingCustomGoal`)
- Local-first Persistenz:
  - JSON file + load/save (siehe `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`)
- CloudKit Store:
  - `CloudKit<Domain>Store` mit klarer Schema-Sektion + Routing via `CloudKitRouting`
  - Optional: ZoneChanges + TokenStore für inkrementelles Syncing
- Upload Coordinator:
  - Debounced + batched Writer (siehe `MovieCloudSyncCoordinator`, `MovieNightCloudSyncCoordinator`)
- Test-Checklist:
  - Offline edit → pending count steigt → später Upload klappt
  - Multi-device: Änderung A auf Gerät 1 → Gerät 2 sieht’s nach Refresh/Push

### 4) Neuer Goal-Typ (Custom Goals)
- Goal Type / Rule erweitern: `filmfreaks/ViewingCustomGoal.swift`
- Payload Versioning beachten: `filmfreaks/ViewingCustomGoalsPayload.swift`
- Matching: `filmfreaks/Goals/GoalsView+Matching.swift` + `GoalsView+Derived.swift`
- UI:
  - Editor: `filmfreaks/Goals/CustomGoals/*`
  - Cards/Sections: `filmfreaks/Goals/*`
- CloudKit:
  - Custom goals payload wird als ein Record pro Gruppe gespeichert (`ViewingCustomGoals`) (`filmfreaks/CloudKitGoalStore.swift`)
