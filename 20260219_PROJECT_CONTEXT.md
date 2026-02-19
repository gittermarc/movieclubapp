# PROJECT_CONTEXT — filmfreaks (Start Here)

_Last updated: 2026-02-19 (Europe/Berlin)_

## TL;DR
- **App:** `filmfreaks` — eine Gruppen-App zum Sammeln von Filmen (gesehen + Backlog), gemeinsamen Bewerten, Ziele/Statistiken und „Filmabend“-Planung.
- **Plattform:** iOS (iPhone+iPad). **Minimum iOS:** `26.0` (aus `filmfreaks.xcodeproj/project.pbxproj`).
- **Tech:** SwiftUI + ObservableObject-Stores, **CloudKit** (Public DB für Legacy-Gruppen + Private/Shared DB mit Record Zones & Sharing), lokale JSON-Persistenz in Application Support, TMDb API für Metadaten/Poster.

---

## Key Concepts (Domänenbegriffe)
- **Group / Gruppe**
  - Gruppenkontext wird über `groupId` adressiert (RecordName der Root-Group) und per `GroupContext` geroutet.
  - Es gibt **Owned** (private DB) und **Shared** (shared DB) Gruppen.
  - Routing-Metadaten: `filmfreaks/GroupContext.swift`.
- **Watched vs Backlog**
  - Zwei Listen: gesehen (`MovieStore.movies`) und Backlog (`MovieStore.backlogMovies`).
  - CloudKit speichert beides als `Movie`-Record, differenziert über `isBacklog`.
- **Movie**
  - Zentrales Modell inkl. Ratings, Metadaten (Titel/Jahr/Poster etc.) und Gruppen-Info.
  - Datei: `filmfreaks/Movie.swift`.
- **Rating**
  - Pro Movie mehrere Ratings (typisch pro Member). CloudKit-Version „B“: pro User ein eigener Rating-Record (Creator darf updaten).
  - Modell: `filmfreaks/Movie.swift` (struct `Rating`), CloudKit: `filmfreaks/CloudKitRatingStore.swift`.
- **Active Member (ausgewähltes Mitglied)**
  - UI/Filter basieren auf `UserStore.selectedUser`.
  - Persistiert „leichtgewichtig“ über `PersistenceManager.saveSelectedUserName`.
- **Goals / Ziele**
  - Enthält „Yearly Goals“ + „Custom Goals“ (Decade/Person/Director/Genre/Keyword).
  - Modell: `filmfreaks/ViewingCustomGoal.swift`.
  - UI: Ordner `filmfreaks/Goals/`.
- **Movie Nights**
  - „Filmabend“ als Event mit Responses + Activity.
  - Store: `filmfreaks/MovieNights/MovieNightStore.swift`.
  - Lokale Snapshot-Persistenz: `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`.
  - CloudKit: `filmfreaks/CloudKitMovieNightStore.swift`.
- **Group Activity Feed**
  - „Activity“ ist aktuell **derived data** (kein eigenes CloudKit Activity-Record).
  - Movies/Ratings: `filmfreaks/MovieStore+Activity.swift`, Modell `filmfreaks/Content/GroupActivityEvent.swift`.
  - Movie nights: echte Activity Events `filmfreaks/MovieNights/MovieNightActivityEvent.swift`.
- **Display Settings**
  - Globale UI/UX-Schalter (Farben, Layout-Dichte, Rating-Modus, etc.).
  - Datei: `filmfreaks/DisplaySettings.swift`.

---

## Architecture Map (Text)
**UI (SwiftUI Views)** → konsumiert → **Stores (ObservableObject / @MainActor)** → nutzen → **Persistence + CloudKit Stores** → sprechen mit → **CloudKit / Filesystem / Network**

- **UI Layer**
  - `filmfreaks/Content/*`: Home + Listen/Grid + Group Activity
  - `filmfreaks/MovieDetail/*`: Detailansicht eines Films + Rating UI
  - `filmfreaks/MovieSearch/*` + `filmfreaks/SearchResultDetail/*`: TMDb Suche + Detail Sheet
  - `filmfreaks/Stats/*`: Statistiken
  - `filmfreaks/Timeline/*`: Timeline/History UI
  - `filmfreaks/Goals/*`, `filmfreaks/MovieNights/*`

- **State/Domain Layer (Stores)**
  - `filmfreaks/MovieStore.swift` (+ Extensions wie `MovieStore+Activity.swift`)
  - `filmfreaks/UserStore.swift`
  - `filmfreaks/MovieNights/MovieNightStore.swift`
  - `filmfreaks/CloudKitGroupStore.swift` (Gruppen + Sharing)
  - `filmfreaks/DisplaySettings.swift`
  - `filmfreaks/NetworkMonitor.swift`

- **Persistence Layer**
  - `filmfreaks/PersistenceManager.swift` (JSON-Dateien pro Gruppe in Application Support)
  - `filmfreaks/MovieNights/MovieNightLocalPersistence.swift` (separates Snapshot-File)

- **Cloud Sync Layer (CloudKit)**
  - `filmfreaks/CloudKitMovieStore.swift` (Movies)
  - `filmfreaks/CloudKitRatingStore.swift` (Ratings)
  - `filmfreaks/CloudKitUserStore.swift` (Users/Members)
  - `filmfreaks/CloudKitGoalStore.swift` (Goals)
  - `filmfreaks/CloudKitMovieNightStore.swift` (Movie nights)
  - `filmfreaks/CloudKitGroupStore.swift` (Groups + Sharing)
  - Token + Zone changes: `filmfreaks/CloudKitZoneChangeTokenStore.swift`, `filmfreaks/CloudKitZoneChanges.swift`

- **Infra/Utilities**
  - Image caching: `filmfreaks/CachedAsyncImage.swift` (Actor `ImageCacheStore` + Disk/Memory)
  - Push/Deep link: `filmfreaks/CloudKitShareAppDelegate.swift`, Ordner `filmfreaks/Notifications/*`
  - TMDb API: `filmfreaks/TMDbAPI.swift`

---

## Folder Map
Top-Level unter `filmfreaks/`:
- `Assets.xcassets/` — AppIcon, AccentColor etc.
- `CloudKit/` — CloudKit Activity/Subscriptions, Helpers (zusätzlich liegen mehrere CloudKit Stores auch im Root).
- `Content/` — Home-Screen, Header, Listen/Grid, Group-Activity Feed, Routing.
- `Goals/` — Ziel-System + UI + TMDb-Enrichment.
- `MovieDetail/` — Film-Details, Rating UI, Subviews.
- `MovieNights/` — Movie Night Feature (Calendar, Sheets, UI).
- `MovieSearch/` — Suche über TMDb.
- `Notifications/` — Push Bootstrap + Local Notifications + Deep Link Routing.
- `SearchResultDetail/` — Detail-Sheet für TMDb Suchergebnis.
- `Stats/` — Statistik-Tab.
- `Timeline/` — Timeline UI.

---

## Data Model Map (Entities + Relationships)
### Core Models
- `Movie` (`filmfreaks/Movie.swift`)
  - Identität: `id: UUID`
  - Inhalt: `title`, `year`, `posterPath`, `overview`, `runtime`, …
  - Gruppenbindung: `groupId: String?`
  - Zustand: `watchedDate: Date?`, `watchedLocation: String?`, `isFavorite`, …
  - Backlog/Quelle: `suggestedBy: String?`, `addedAt: Date?`, `addedById: UUID?`, `addedByName: String?`
  - Beziehungen: `ratings: [Rating]` (embedded im Movie; zusätzlich existiert ein CloudKit-Rating-Store)
  - TMDb: `tmdbId: Int?`, plus arrays `cast/directors/genres/keywords` etc.

- `Rating` (`filmfreaks/Movie.swift`)
  - Identität: `id: UUID`
  - Reviewer: `reviewerName: String`, `reviewerId: UUID?`
  - Scores: `criteriaScores: [Int]`, `fazitScore: Int?`, `averageScore: Double` (u.a. Helpers: `averageScoreNormalizedTo10`)
  - Sync-Metadaten: `updatedAt: Date?` (wird aus CloudKit-Record `updatedAt` gespeist; siehe `filmfreaks/CloudKitRatingStore.swift`)
  - Beziehung: embedded in `Movie.ratings`.

- `User` (`filmfreaks/User.swift`)
  - `id: UUID`, `name: String`
  - Beziehung: wird in UI/Filter und Ratings als Reviewer referenziert.

### Group / Sharing Models
- `GroupContext` (`filmfreaks/GroupContext.swift`)
  - `id` (groupId), `name`, `scope` (`private`/`shared`), `zoneName`, `ownerName`.
  - Persistenz: UserDefaults (`GroupContextStore`).

### Goals
- `ViewingCustomGoal` (`filmfreaks/ViewingCustomGoal.swift`)
  - `type` + `rule` (Decade/Person/Director/Genre/Keyword), `target`, `startYear`, `durationYears`.
  - Beziehung: gematched gegen Movie-Metadaten (TMDb IDs/Genres/Keywords) in `filmfreaks/Goals/GoalsView+Matching.swift`.

### Movie Nights
- `MovieNightEvent` (`filmfreaks/MovieNights/MovieNightEvent.swift`)
  - `groupId`, `proposedStart`, `proposerUserId/name`, optional `suggestedMovie`, `status`, `note`.
- `MovieNightResponse`, `MovieNightActivityEvent`, `MovieNightMovieRef` (Dateien in `filmfreaks/MovieNights/*`) — Antworten & Activity.

---

## Sync/Storage
### Lokale Persistenz (offline-first Basis)
- **Movies/Backlog/Users**: `filmfreaks/PersistenceManager.swift`
  - Speicherort: `~/Library/Application Support/FilmFreaks/groups/<gid>/...json`
    - `<gid>`: `default` wenn `groupId` leer/nil.
  - Debounced writes (0.55s) auf einer Utility-Queue.
  - Migration: UserDefaults → Files (Flag: `FilmFreaks.diskPersistence.v2.migrated`).

- **Movie nights**: `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`
  - Ein JSON Snapshot-File: `~/Library/Application Support/filmfreaks/movieNights.json` (Achtung: anderer Basisordner als `PersistenceManager`).
  - Schema-Version im Snapshot (`schemaVersion`).

### Cloud Sync (CloudKit)
- Kein SwiftData/CoreData im Projekt gefunden (Suche nach `import SwiftData`/`import CoreData` ergab **keine Treffer**). Persistenz/Sync ist **custom**.

- **CloudKit Routing-Konzept**
  - Für `groupId` mit bekanntem `GroupContext`:
    - DB: private oder shared (`CKContainer.privateCloudDatabase` / `CKContainer.sharedCloudDatabase`)
    - Zone: `CKRecordZone.ID(zoneName: ctx.zoneName, ownerName: ctx.ownerName)`
    - Beispiel: `filmfreaks/CloudKitMovieStore.swift:routedDatabase(forGroupId:)`.
  - Für Legacy/no-group:
    - DB: `CKContainer.publicCloudDatabase`, keine Zone.

- **Record Types (aus Code)**
  - Movies: `recordType = "Movie"` (`filmfreaks/CloudKitMovieStore.swift`)
    - Keys: `payload(Data)`, `isBacklog(Bool)`, `updatedAt(Date)`, `groupId(String)`.
  - Ratings: `recordType = "MovieRating"` (`filmfreaks/CloudKitRatingStore.swift`)
    - Keys: `payload(Data)`, `movieId(String)`, `groupId(String)`, `reviewerId(String)`, `reviewerName(String)`, `updatedAt(Date)`.
  - Groups: `recordType = "FFGroup"` (`filmfreaks/CloudKitGroupStore.swift`)
    - Keys: `name(String)`, `createdAt(Date)`.
  - Goals/Movie nights/Users: RecordTypes & Keys in `filmfreaks/CloudKitGoalStore.swift`, `filmfreaks/CloudKitMovieNightStore.swift`, `filmfreaks/CloudKitUserStore.swift`.

- **Inkrementelle Sync (Sharing-Gruppen)**
  - Movies/Ratings/Movie nights nutzen `CKFetchRecordZoneChangesOperation` via Helper `filmfreaks/CloudKitZoneChanges.swift`.
  - Zone-Change Tokens werden persistiert: `filmfreaks/CloudKitZoneChangeTokenStore.swift`.

- **Write/Retry-Mechanik**
  - Movies: Debounced + batched writes über `filmfreaks/MovieCloudSyncCoordinator.swift`.
  - Network gating: `NetworkMonitor` (siehe `filmfreaks/NetworkMonitor.swift`) + „pending changes“ Anzeige.

### Offline-Verhalten
- UI arbeitet primär auf lokalen Arrays in Stores (Movies/Users/Nights) und schreibt lokal weg.
- CloudKit-Flush ist best-effort (queued/debounced). Bei Offline bleiben Änderungen lokal und werden später gesendet.
- Konfliktauflösung / Merge-Strategie: **UNKNOWN** (teilweise aus Code ableitbar, aber nicht konsistent dokumentiert). Siehe „Open Questions“.

---

## UI Map (Screens + Navigation + wichtige Flows)
### Entry Points
- App Entry: `filmfreaks/filmfreaksApp.swift`
  - `WindowGroup` → `ContentView()`.
  - EnvironmentObjects: `MovieStore`, `MovieNightStore`, `UserStore`, `CloudKitGroupStore`, `NetworkMonitor`, `DisplaySettings`.
  - Lifecycle: bei `.active` → `groupStore.refresh()` + `movieStore/userStore/movieNightStore.refreshFromCloud(...)`.

- App Delegate / Sharing / Push: `filmfreaks/CloudKitShareAppDelegate.swift`
  - CloudKit share acceptance routing + remote notification entry point.

### Root Navigation
- Root: `filmfreaks/Content/ContentView.swift`
  - `NavigationStack`.
  - “Routing” über `ContentRoute` + `contentRouting(...)` Modifier (`filmfreaks/Content/ContentRouting.swift`).
  - Sheets/Flows (aus `ContentRoute`):
    - Movie Search (`.movieSearch`), Settings (`.settings`), Users (`.users`), Stats (`.stats`), Timeline (`.timeline`)
    - Group Settings (`.groupSettings`), Activity (`.activity`)
    - Movie nights: Calendar (`.movieNightCalendar`), Propose (`.movieNightPropose`), Detail (`.movieNightDetail`)

### Haupt-Screens (wichtigste)
- Home (Listen/Grid): `filmfreaks/Content/ContentMainAreaView.swift`
  - NavigationLink → `filmfreaks/MovieDetail/MovieDetailView.swift`.
  - View Style: Cards vs Grid (`MovieViewStyle`).
- Movie Detail: `filmfreaks/MovieDetail/*`
- Suche: `filmfreaks/MovieSearch/MovieSearchView.swift` + Detail-Sheet `filmfreaks/SearchResultDetail/SearchResultDetailView.swift`
- Groups/Sharing: `filmfreaks/GroupSettingsView.swift` + CloudKit group store.
- Users/Members: `filmfreaks/UsersView.swift`
- Stats: `filmfreaks/Stats/StatsView.swift` (+ `StatsView+Calculations.swift`)
- Timeline: `filmfreaks/Timeline/TimelineView.swift`
- Settings: `filmfreaks/SettingsView.swift`

---

## Build & Configuration
### Xcode / Targets
- Projekt: `filmfreaks.xcodeproj`
- Target(s):
  - App: `filmfreaks`
  - Tests: `filmfreaksTests`, UI Tests: `filmfreaksUITests` (aus `project.pbxproj`).

### Deployment & Devices
- `IPHONEOS_DEPLOYMENT_TARGET = 26.0` (Debug+Release, `project.pbxproj`).
- `TARGETED_DEVICE_FAMILY = 1,2` (iPhone + iPad, `project.pbxproj`).

### Entitlements / Capabilities
- Entitlements: `filmfreaks/filmfreaks.entitlements`
  - iCloud Container: `iCloud.com.marcfechner.filmfreaks`
  - `com.apple.developer.icloud-services`: `CloudKit`
  - Push: `aps-environment`.

### Info.plist
- `filmfreaks/Info.plist`
  - `CKSharingSupported = YES`
  - Background modes: `remote-notification`
  - `TMDB_API_KEY` wird via Build-Setting ersetzt (`$(TMDB_API_KEY)`)

### .xcconfig / Secrets
- `filmfreaks/Debug.xcconfig` + `filmfreaks/Release.xcconfig` inkludieren `filmfreaks/Secrets.xcconfig`.
- `filmfreaks/Secrets.xcconfig` enthält `TMDB_API_KEY = ...` (**Secret; nicht in Doku ausgeben, nicht committen**).

### Abhängigkeiten
- Keine SwiftPM Packages im `project.pbxproj` gefunden.
- Frameworks: SwiftUI, CloudKit, Combine, UserNotifications, CryptoKit, UIKit (u.a. via `CachedAsyncImage.swift`).

---

## Conventions (Do/Don’t)
### Naming & File Layout
- SwiftUI große Views werden bereits teils per „`+`“-Dateien modularisiert (z.B. `StatsView+Calculations.swift`, `ContentView+Filtering.swift`).
- Viele Dateien nutzen Zugriffsebene beim Import (`internal import SwiftUI`).

### Patterns
- Stores leben überwiegend auf `@MainActor` und werden als `@EnvironmentObject` injiziert.
- CloudKit ist in dedizierten `CloudKit*Store.swift` Dateien gekapselt; „Coordinator“-Objekte orchestrieren Debounce/Batch.

### Do
- Group-abhängige Datenzugriffe immer über `groupId` und `GroupContextStore.context(forGroupId:)` routen.
- Bei neuen CloudKit-Records: Keys als `let` Konstanten im Store definieren (so wie in `CloudKitMovieStore.swift`).
- Bei UI-heavy Berechnungen: in Store/Service vorrechnen oder cachen (nicht im `body`).

### Don’t
- Keine direkten CloudKit Calls aus Views.
- Keine ungebremsten `Task { ... }`-Kaskaden in `.onAppear` ohne Cancellation/Throttle.
- Secrets nicht in `Info.plist` hardcoden.

---

## How to work on this project
### Setup (neuer Dev / neues Gerät)
1. Projekt öffnen: `filmfreaks.xcodeproj`.
2. Signing/Team setzen.
3. Capabilities prüfen:
   - iCloud (CloudKit) + Container `iCloud.com.marcfechner.filmfreaks`
   - Push Notifications
   - Background Modes: Remote notifications
4. `Secrets.xcconfig` lokal bereitstellen (mind. `TMDB_API_KEY`).
5. Auf Device/Simulator in iCloud eingeloggt sein (für CloudKit Sharing + shared DB notwendig).

### „Wie füge ich ein Feature hinzu?“ (typischer Workflow)
- **Neue Domain-Funktionalität**
  1. Modell anlegen/erweitern (Codable, stabiler `id`), Pfad z.B. `filmfreaks/<Feature>/<Model>.swift`.
  2. Lokale Persistenz: wenn groß → `PersistenceManager`/dedizierter Persistence-Actor.
  3. Cloud Sync: `CloudKit<Feature>Store.swift` mit:
     - `recordType` + Keys
     - Routing (public vs private/shared+zone)
     - fetch + modify + (optional) zone changes
  4. Store/Coordinator erweitern (Debounce/Batch, error handling, pending count).
  5. UI bauen (View + Subviews, idealerweise nicht „alles in einer Datei“).
  6. Bei Navigation: `ContentRoute` + `contentRouting` erweitern.

- **Neuer Screen / Flow**
  - Entry: `ContentRoute` (`filmfreaks/Content/ContentRoute.swift`) + Sheet/Navigation im Routing.

---

## Quick Wins (max 10, konkret)
1. **Cache/Memoize `ContentView` List/Grid Items**: `filmfreaks/Content/ContentView+MovieItems.swift` baut pro Render `enumerated → filter → sort → map` neu (O(n log n)). In einen dedizierten ViewModel/Cache verschieben.
2. **Search-Haystack cachen**: `passesListSearch` (`filmfreaks/Content/ContentView+Filtering.swift`) normalisiert/konkateniert Strings pro Movie pro Render. Precompute `searchIndex` pro Movie-ID.
3. **Activity Feed cachen**: `filmfreaks/MovieStore+Activity.swift` erzeugt Events jedes Mal neu; in Store zwischenspeichern und bei Änderungen inkrementell updaten.
4. **Stats-Berechnungen bündeln**: `filmfreaks/Stats/StatsView+Calculations.swift` enthält viele `var`-Aggregationen, die mehrfach laufen. Ein `StatsCalculator` (einmal pro Filter) reduziert Recompute.
5. **CloudKit Query Helper deduplizieren**: `queryAllRecords(...)` existiert mehrfach (`CloudKit*Store.swift`). Gemeinsamer Helper reduziert Bugs & Code.
6. **Duplicate Subscription-Calls entfernen**: In `filmfreaks/CloudKitGroupStore.swift:refresh()` wird `ensureSubscriptions(...)` aktuell doppelt gestartet.
7. **Consistency: Application Support Base Dir vereinheitlichen**: `PersistenceManager` nutzt `FilmFreaks/`, MovieNights nutzt `filmfreaks/`.
8. **Throttle für `groupStore.refresh()`**: wird bei jedem `.active` getriggert (siehe `filmfreaksApp.swift`). Ein Minimum-Intervall verhindert Battery/Network Peaks.
9. **Secrets Hygiene**: `filmfreaks/Secrets.xcconfig` muss in `.gitignore` (und ggf. Beispiel `Secrets.example.xcconfig`).
10. **Observability**: CloudKit Ops mit `Logger` kategorisieren (Movies/Ratings/Groups) + optional `os_signpost` für Fetch/Modify Dauer.

