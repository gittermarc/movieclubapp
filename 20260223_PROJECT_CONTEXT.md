# PROJECT_CONTEXT — filmfreaks (The Movie Club)

## TL;DR
**filmfreaks** ist eine SwiftUI iOS/iPadOS App für gemeinsames Film-Tracking in Gruppen: Filme (gesehen + Backlog), Bewertungen (Kriterien + Fazit), Aktivitätsfeed, Ziele, Timeline und „Filmabende“. Sync/Sharing läuft über **CloudKit** (inkl. CKSharing + Push). Deployment Target ist **iOS 26.0** (Xcodeproj: `IPHONEOS_DEPLOYMENT_TARGET = 26.0`), Device Family iPhone+iPad (`TARGETED_DEVICE_FAMILY = 1,2`). **SwiftData wird nicht verwendet** (Stand Projekt-Scan) → Persistenz ist file-basiert + UserDefaults + CloudKit.

---

## Key Concepts / Domänenbegriffe

- **Group / Gruppe**
  - Identifiziert über `groupId: String` (Invite-Code bzw. Gruppenkennung).
  - Routing-Metadaten über `GroupContext` (Scope/Zone/Owner) für private vs shared DB/Zone.
  - Datei: `filmfreaks/GroupContext.swift`

- **GroupContext**
  - Minimaler „Router“: `scope` (`private|shared`), `zoneName`, `ownerName`.
  - Lokal gespeichert in UserDefaults via `GroupContextStore`.
  - Datei: `filmfreaks/GroupContext.swift`

- **Watched vs Backlog**
  - Zwei Listen: gesehen (`movies`) und vorgemerkt (`backlogMovies`) im `MovieStore`.
  - Datei: `filmfreaks/MovieStore/MovieStore.swift`

- **Movie**
  - Zentrales Domain-Objekt inkl. `ratings: [Rating]`, optional TMDb IDs, Poster, Genres/Keywords, Cast/Directors.
  - Datei: `filmfreaks/Movie.swift`

- **Rating**
  - Pro User/Reviewer: Sterne pro Kriterium (0–3), optional Kommentar, optional `fazitScore (1–10)`, `updatedAt`.
  - Datei: `filmfreaks/Movie.swift`

- **Movie Night / Filmabend**
  - `MovieNightEvent`: Vorschlag/Termin pro Gruppe, optional gewählter Film (Snapshot).
  - `MovieNightResponse`: per User Antwort (accepted/declined/pending).
  - Dateien:
    - `filmfreaks/MovieNights/MovieNightEvent.swift`
    - `filmfreaks/MovieNights/MovieNightResponse.swift`
    - `filmfreaks/MovieNights/MovieNightMovieRef.swift`

- **DisplaySettings**
  - Globale UI-Settings (Tint, ColorScheme, Layout-Metriken, Rating Anzeige/Badge Style etc.).
  - Datei: `filmfreaks/DisplaySettings/DisplaySettings.swift`

- **Activity Feed**
  - Wird aus Movie-Metadaten (addedAt/addedBy) und Rating.updatedAt abgeleitet (keine extra CloudKit-Schema-Änderung).
  - Datei: `filmfreaks/MovieStore/MovieStore+Activity.swift`

---

## Architecture Map (Layer / Module / Abhängigkeiten)

### 1) UI (SwiftUI Screens + Komponenten)
- Root: `ContentView` (NavigationStack, Header, Listen/Grids, In-List Search, Sheets)
  - Datei: `filmfreaks/Content/ContentView.swift`
- Zentrale Sheet-Routing-Schicht: `ContentRoute` + `contentRouting(...)`
  - Datei: `filmfreaks/Content/ContentRouting.swift`
- Feature-Screens (Auswahl):
  - Suche: `filmfreaks/MovieSearch/MovieSearchView.swift`
  - Detail: `filmfreaks/MovieDetail/*`, `filmfreaks/SearchResultDetail/SearchResultDetailView.swift`
  - Stats: `filmfreaks/Stats/*`
  - Timeline: `filmfreaks/Timeline/*`
  - Movie Nights: `filmfreaks/MovieNights/*`
  - Goals: `filmfreaks/Goals/*`
  - Settings: `filmfreaks/SettingsView.swift`

**UI hängt ab von:** Stores als `EnvironmentObject` + Domain-Models + kleine ViewModels/Helper.

### 2) Stores (ObservableObject / MainActor, App State)
- `MovieStore` (Movies + Backlog + Sync-Meta + Group Selection)
  - Datei: `filmfreaks/MovieStore/MovieStore.swift` (+ Extensions)
- `UserStore` (Mitglieder + Auswahl + Sync)
  - Datei: `filmfreaks/UserStore.swift`
- `MovieNightStore` (Events/Responses + UI Helpers + Sync Hooks)
  - Datei: `filmfreaks/MovieNights/MovieNightStore.swift`
- `CloudKitGroupStore` (Group/Sharing/Contexts/Refresh)
  - Datei: `filmfreaks/CloudKitGroupStore.swift`

**Stores hängen ab von:** CloudKit-Stores (unten), lokaler Persistenz, NetworkMonitor.

### 3) CloudKit Access Layer (thin wrappers + split Extensions)
- Movies: `CloudKitMovieStore` + `+Modify/+Routing/+ZoneChanges/+Merge/+Schema`
  - Ordner: `filmfreaks/CloudKitMovieStore/*`
- Ratings: `CloudKitRatingStore/*` (analoges Muster; Details: **UNKNOWN** ohne weiteren Deep-Scan)
- Movie Nights: `CloudKitMovieNightStore/*` (Schema/ZoneChanges etc; Details: **UNKNOWN** ohne weiteren Deep-Scan)
- Zone Changes Utility: `CloudKitZoneChanges`
  - Datei: `filmfreaks/CloudKitZoneChanges.swift`
- Token Storage: `CloudKitZoneChangeTokenStore`
  - Datei: `filmfreaks/CloudKitZoneChangeTokenStore.swift`

### 4) Local Persistence / Caches
- File-basierte Persistenz (Application Support), debounced + atomic writes:
  - Datei: `filmfreaks/PersistenceManager.swift`
- GroupContext + Tokens in UserDefaults:
  - `filmfreaks/GroupContext.swift`
  - `filmfreaks/CloudKitZoneChangeTokenStore.swift`
- HTTP Cache global konfiguriert beim App-Start:
  - Datei: `filmfreaks/filmfreaksApp.swift`
- App-eigener Image Cache Store (Cache löschen/Größe in Settings):
  - Nutzung sichtbar in `filmfreaks/SettingsView.swift`
  - Implementierungspfad: **UNKNOWN** (Name: `ImageCacheStore.shared` ist referenziert)

---

## Folder Map (Ordner → Zweck)

Top-Level in `filmfreaks/`:

- `CloudKit/`
  - CloudKit Sharing/Push/Activity/Debug Utilities (z.B. Share Coordinator, Push Fetch, Routing).
  - Konkrete Files: u.a. `filmfreaks/CloudKitShareAppDelegate.swift`, `filmfreaks/CloudKitZoneChanges.swift`

- `CloudKitGroupStore.swift`
  - Group + Sharing Management (zentral, groß)

- `CloudKitMovieStore/`
  - CloudKit CRUD + Routing + Zone Changes für Movie Records.

- `CloudKitRatingStore/`
  - CloudKit CRUD + Zone Changes für Ratings (Details: **UNKNOWN** ohne Deep-Scan)

- `CloudKitMovieNightStore/`
  - CloudKit CRUD + Zone Changes für Movie Nights (Details: **UNKNOWN** ohne Deep-Scan)

- `Content/`
  - Root Screen `ContentView`, Routing, Toolbar, Header, derived item models.

- `DisplaySettings/`
  - UI/Appearance Settings, Layout Metrics, Badge Styles etc.

- `Goals/`
  - Zielsystem, Editor, Goal-Views.

- `MovieDetail/`
  - Detail UI für lokale Movie Entities (gesehen/backlog).

- `MovieNights/`
  - Filmabend Feature (Model, Store, Calendar UI, Sheets, UI components).

- `MovieSearch/`
  - TMDb Suche UI (Query, Ergebnisse, Pagination, Recommendations/History).

- `MovieStore/`
  - MovieStore + Extensions (Cloud Sync, Activity, Selections etc.).

- `Notifications/`
  - Push/Local notifications plumbing (Permissions, routing). Details: **UNKNOWN** ohne Deep-Scan.

- `SearchResultDetail/`
  - Detail UI für TMDb Suchresultate (nicht zwingend schon im Store).

- `Stats/`
  - Stats UI + ViewModel + Cards/Leaderboards.

- `TMDbAPI/`
  - Networking Models + Calls zu TMDb (Key via xcconfig/Info.plist).

- `Timeline/`
  - Timeline Screen/UI.

---

## Data Model Map (Entities / Relationships / wichtige Felder)

### Movie (`filmfreaks/Movie.swift`)
- Identity:
  - `id: UUID`
  - optional `tmdbId: Int?`
- Core:
  - `title: String`, `year: String`
  - `posterPath: String?`
- State:
  - `watchedDate: Date?`, `watchedLocation: String?`
  - `groupId: String?`, `groupName: String?`
  - `addedAt: Date?`, `addedById: UUID?`, `addedByName: String?`
- Relationships:
  - `ratings: [Rating]`
  - optional `cast: [CastMember]?`, `directors: [CastMember]?`
- Taxonomy:
  - `genres: [String]?`, `genreIds: [Int]?`
  - `keywords: [String]?`, `keywordIds: [Int]?`

### Rating (`filmfreaks/Movie.swift`)
- `id: UUID`
- Reviewer identity:
  - `reviewerId: UUID?` (stable), `reviewerName: String`
- Content:
  - `scores: [RatingCriterion: Int]` (0..3)
  - `comment: String?`
  - `fazitScore: Int?` (1..10)
- Sync metadata:
  - `updatedAt: Date?` (aus CloudKit record `updatedAt`)
- Derived:
  - `averageStars`, `averageScoreNormalizedTo10`

### User (`filmfreaks/User.swift`)
- `id: UUID`, `name: String`

### GroupContext (`filmfreaks/GroupContext.swift`)
- `id: String` (groupId)
- `name: String`
- `scope: GroupScope` (`private|shared`)
- `zoneName: String`, `ownerName: String`

### MovieNightEvent (`filmfreaks/MovieNights/MovieNightEvent.swift`)
- `id: UUID`, `groupId: String`
- `proposedStart: Date`
- `createdAt/updatedAt: Date`
- Proposer:
  - `proposerUserId: UUID`, `proposerName: String`
- Optional `suggestedMovie: MovieNightMovieRef?`
- `note: String?`
- `status: open|scheduled|cancelled`

### MovieNightResponse (`filmfreaks/MovieNights/MovieNightResponse.swift`)
- Composite identity (SwiftUI-friendly):
  - `id: String = "\(eventId)_\(userId)"`
- `eventId: UUID`, `userId: UUID`, `userName: String`
- `decision: pending|accepted|declined`, `respondedAt: Date`

### MovieNightMovieRef (`filmfreaks/MovieNights/MovieNightMovieRef.swift`)
- Snapshot:
  - `movieId: UUID`, `title/year`, `posterPath`, `tmdbId`

---

## Sync / Storage

### Local (Offline/Startup)
- **Disk persistence (JSON) in Application Support**
  - Motivation explizit: große Arrays nicht in UserDefaults, atomic writes, debounce, group-scoped.
  - Datei: `filmfreaks/PersistenceManager.swift`
  - Gespeicherte Kinds (enum `Kind`): `watchedMovies`, `backlogMovies`, `users`
- **UserDefaults**
  - GroupContexts: `filmfreaks/GroupContext.swift`
  - Zone Change Tokens: `filmfreaks/CloudKitZoneChangeTokenStore.swift`
  - UI Settings via `@AppStorage` in Views (z.B. `ContentView`, `SettingsView`) und `DisplaySettings`.

### CloudKit (Sync/Sharing)
- CloudKit Container: Default (`CKContainer.default()`)
  - z.B. `CloudKitMovieStore` init: `container: CKContainer = .default()`
  - Datei: `filmfreaks/CloudKitMovieStore/CloudKitMovieStore.swift`
- Sharing:
  - App unterstützt CKSharing: Info.plist `CKSharingSupported = true`
  - Datei: `filmfreaks/Info.plist`
- Push / Background:
  - Info.plist `UIBackgroundModes` enthält `remote-notification`
  - AppDelegate verarbeitet remote notifications:
    - Datei: `filmfreaks/CloudKitShareAppDelegate.swift`
- Refresh Trigger:
  - Beim ScenePhase `.active` wird ein Refresh-Coordinator getriggert:
    - `groupStore.refresh()`
    - `movieStore.refreshFromCloud(...)`
    - `userStore.refreshFromCloud(...)`
    - `movieNightStore.refreshFromCloud(...)`
    - Datei: `filmfreaks/filmfreaksApp.swift`
- Inkrementeller Sync in Sharing-Zonen:
  - `CKFetchRecordZoneChangesOperation` Wrapper:
    - Datei: `filmfreaks/CloudKitZoneChanges.swift`
  - Token Persistenz:
    - Datei: `filmfreaks/CloudKitZoneChangeTokenStore.swift`
  - Movie Delta Fetch:
    - Datei: `filmfreaks/CloudKitMovieStore/CloudKitMovieStore+ZoneChanges.swift`

### Offline Verhalten (best-effort)
- Movie Writes werden debounced + gebatched und behalten pending Changes bei Fehler:
  - Datei: `filmfreaks/MovieCloudSyncCoordinator.swift`
- MovieNightStore hat `flushPendingCloudChanges()` Hook beim App-Aktivieren:
  - Datei: `filmfreaks/filmfreaksApp.swift`
  - Details zur Pending-Queue Implementierung: **UNKNOWN** ohne Deep-Scan.

---

## UI Map (Hauptscreens + Navigation + Sheets/Flows)

### Entry / Root
- App Root: `filmfreaksApp` → `ContentView()` in `WindowGroup`
  - EnvironmentObjects: `MovieStore`, `MovieNightStore`, `UserStore`, `CloudKitGroupStore`, `NetworkMonitor`, `DisplaySettings`
  - Datei: `filmfreaks/filmfreaksApp.swift`

### Primary Navigation
- `ContentView` ist ein `NavigationStack` Root.
  - Datei: `filmfreaks/Content/ContentView.swift`

### Sheet Routing ab Content
- Central enum: `ContentRoute`
- Attachment Modifier: `contentRouting(route:hasSeenQuickStart:trackSearchOpened:)`
  - Datei: `filmfreaks/Content/ContentRouting.swift`
- Routes (Sheets):
  - Settings (`SettingsView`)
  - Quick Start
  - Movie Search
  - Users
  - Stats
  - Timeline
  - Calendar (Movie Nights)
  - Activity
  - Goals
  - Group Settings

### Detail Flows
- Movie Detail Screens (lokale Movies):
  - Ordner: `filmfreaks/MovieDetail/*` (**konkrete Entry Views: UNKNOWN** ohne Deep-Scan)
- TMDb Search Result Detail:
  - Datei: `filmfreaks/SearchResultDetail/SearchResultDetailView.swift`
- MovieNight Sheets:
  - z.B. `filmfreaks/MovieNights/Sheets/*`

---

## Build & Configuration

### Xcode / Targets
- Projekt: `filmfreaks.xcodeproj`
- Deployment Target: iOS **26.0**
- Device Family: iPhone + iPad (`1,2`)
- SPM Dependencies: **UNKNOWN** (kein offensichtlicher Package.resolved im Projekt-Root; Xcodeproj enthält keine `XCRemoteSwiftPackageReference` im Scan)

### Info.plist
- `CKSharingSupported = true`
- `TMDB_API_KEY = $(TMDB_API_KEY)`
- `UIBackgroundModes = remote-notification`
- Datei: `filmfreaks/Info.plist`

### Entitlements
- Push: `aps-environment = development`
- iCloud Container: `iCloud.de.marcfechner.filmfreaks`
- iCloud Service: CloudKit
- Datei: `filmfreaks/filmfreaks.entitlements`

### xcconfig / Secrets Handling
- `Debug.xcconfig` und `Release.xcconfig` inkludieren `Secrets.xcconfig`
  - Dateien:
    - `filmfreaks/Debug.xcconfig`
    - `filmfreaks/Release.xcconfig`
- `Secrets.xcconfig` enthält aktuell **TMDB_API_KEY im Klartext**
  - Datei: `filmfreaks/Secrets.xcconfig`
  - Risiko: Schlüssel landet im Repo/Build-Artefakten (siehe Architecture Notes → Quick Wins).

---

## Conventions (Naming, Patterns, Do/Don’t)

### Patterns, die bereits konsequent sind
- File-Splits per Extension:
  - `MovieStore+CloudSync.swift`, `MovieStore+Activity.swift`, `CloudKitMovieStore+*.swift`
- „Store als App State“ via `EnvironmentObject` (Root in App struct)
- CloudKit Layer als kleine structs + extension files (gute Navigierbarkeit)

### Do
- Derived/expensive list building aus dem Renderpfad rausziehen (Beispiel: `ContentMovieItemsModel` in `ContentView`).
- CloudKit-Routing immer über `GroupContext` (Zone/DB) statt „Public Fallback“.

### Don’t
- Große Arrays in UserDefaults serialisieren (wird bereits explizit vermieden → `PersistenceManager`).
- Secrets im Repo belassen (siehe `Secrets.xcconfig`).

---

## How to work on this project (Setup + Einstieg)

### Setup Steps (lokal)
1. Xcode öffnen: `filmfreaks.xcodeproj`
2. Build Config prüfen:
   - `Debug.xcconfig`/`Release.xcconfig` inkludieren `Secrets.xcconfig`
   - `TMDB_API_KEY` muss gesetzt sein (aktuell im Repo gesetzt; besser lokal/CI, siehe Quick Wins)
3. Capabilities:
   - iCloud/CloudKit aktiv, Container `iCloud.de.marcfechner.filmfreaks`
   - Push Notifications + Background Modes (remote notifications)
4. Device empfehlenswert:
   - Push/CloudKit Sharing verifiziert man am saubersten auf echten Geräten + 2 Accounts.

### Wo anfangen (für neue Devs)
- App Entry: `filmfreaks/filmfreaksApp.swift`
- Root UI + Routing: `filmfreaks/Content/ContentView.swift` und `filmfreaks/Content/ContentRouting.swift`
- Domain Models: `filmfreaks/Movie.swift`, `filmfreaks/User.swift`, `filmfreaks/GroupContext.swift`
- CloudKit: `filmfreaks/CloudKitGroupStore.swift` + `filmfreaks/CloudKitMovieStore/*`

---

## Quick Wins (max 10, konkret)

1. **Secrets aus dem Repo raus**
   - Betroffen: `filmfreaks/Secrets.xcconfig`
   - Ziel: API Key nur lokal/CI (z.B. `Secrets.local.xcconfig` gitignored)

2. **Activity Feed Berechnung cachen / entkoppeln**
   - Betroffen: `filmfreaks/MovieStore/MovieStore+Activity.swift`, `filmfreaks/Content/ContentView.swift`
   - Grund: `activityEvents(...)` iteriert + sortiert über alle Movies/Ratings.

3. **App-Refresh beim `.active` throttlen**
   - Betroffen: `filmfreaks/filmfreaksApp.swift`, `AppRefreshCoordinator` (**UNKNOWN Pfad**)
   - Ziel: weniger CloudKit fetches bei häufigem App Switching.

4. **Große Views in Subviews splitten (Compile-Time/Review-Risiko runter)**
   - Betroffen: siehe Top 15 Big Files (Architecture Notes)

5. **CloudKit Fetches: Streaming/Merge statt „alles sammeln“ wo möglich**
   - Betroffen: `filmfreaks/CloudKitZoneChanges.swift` (collects arrays), Merge-Files in Stores (**teilweise UNKNOWN**)

6. **Logger Kategorien konsistent machen**
   - Betroffen: `filmfreaks/PersistenceManager.swift` nutzt `Logger(subsystem:, category:)`
   - Ziel: gleiche Pattern auch in CloudKit Stores für Debuggability.

7. **Cancellation Hygiene bei Tasks in Views**
   - Betroffen: große Screens (`ContentView`, `MovieSearchView`, `SearchResultDetailView`)
   - Ziel: `task(id:)` wo sinnvoll, Debounce zentralisieren.

8. **Group-scoped caches klar invalidieren**
   - Betroffen: `PersistenceManager`, `GroupContextStore`, ggf. Stats Caches (**UNKNOWN**)
   - Ziel: beim Group Switch keine „alte Gruppe“-Artefakte.

9. **„MainActor heavy work“ identifizieren und offloaden**
   - Betroffen: Stores mit großen Arrays + sorting/aggregation (MovieStore/Stats)
   - Ziel: weniger UI Jank.

10. **Konkrete Repro-Skripte in Architecture Notes**
   - Betroffen: Dev Workflow (kein Code)
   - Ziel: schneller reproduzierbare Sync/Share Bugs.

---