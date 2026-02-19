# PROJECT_CONTEXT

## TL;DR
**filmfreaks** ist eine iOS-App für Filmgruppen: Filme suchen (TMDb), zur Gruppe hinzufügen (Gesehen/Backlog), pro Film Bewertungen pro Mitglied erfassen, Stats/Timeline/Goals anzeigen und „Gruppen“ via **CloudKit Sharing** (Owned/Shared) verwalten. Zielplattform: **iOS (iPhone+iPad)**, Deployment Target laut Xcode-Projekt: **iOS 26.0** (`filmfreaks.xcodeproj/project.pbxproj`, `IPHONEOS_DEPLOYMENT_TARGET = 26.0`).

> Wichtig: Im Code ist **keine SwiftData-Nutzung** erkennbar (keine `@Model`, kein `SwiftData`-Import). Persistenz ist **Datei-JSON** + **CloudKit (direkt)**.

---

## Key Concepts / Domänenbegriffe
- **Watched / Backlog**: Zwei Listen pro Gruppe, lokal als JSON persistiert und optional via CloudKit synchronisiert (`filmfreaks/MovieStore.swift`).
- **Group (Owned/Shared)**: CloudKit-Sharing basierte Gruppen. Owned = in privater DB + Share erzeugbar; Shared = im Shared-DB Bereich (`filmfreaks/CloudKitGroupStore.swift`, `filmfreaks/GroupContext.swift`).
- **GroupContext**: Routing-Metadaten (scope + zoneName + ownerName) um CloudKit DB/Zone zu wählen (`filmfreaks/GroupContext.swift`).
- **Zone-based Sync (Phase 2/3)**: Für Sharing-Gruppen werden inkrementelle Zone-Changes genutzt (ChangeTokens) (`filmfreaks/CloudKitZoneChanges.swift`, `filmfreaks/CloudKitZoneChangeTokenStore.swift`).
- **Legacy/Public Mode**: Wenn kein `GroupContext` vorliegt, fallen manche Stores auf Public DB + Query zurück (z.B. `filmfreaks/CloudKitUserStore.swift`).
- **Ratings**: Pro Film mehrere `Rating`-Einträge (Reviewer + Kriterien-Scores + Kommentar + FazitScore) (`filmfreaks/Movie.swift`).
- **Movie Nights**: Vorschläge/Responses/Aktivität pro Gruppe, lokal (JSON Snapshot) und via CloudKit (Zone-Changes + Batch-Queue) (`filmfreaks/MovieNights/MovieNightStore.swift`, `filmfreaks/CloudKitMovieNightStore.swift`).
- **ContentRoute**: Zentrales Sheet-Routing aus `ContentView` (`filmfreaks/Content/ContentRouting.swift`).

---

## Architecture Map (Layer/Module → Verantwortung → Abhängigkeiten)

### 1) App / Composition Root
- `filmfreaks/filmfreaksApp.swift`
  - Initialisiert globale Caches (`URLCache.shared`).
  - Erstellt Stores als `@StateObject` und injiziert sie via `.environmentObject(...)`.
  - Triggert bei `.active` einen Refresh-Flow:
    - `groupStore.refresh()` (`filmfreaks/CloudKitGroupStore.swift`)
    - `movieNightStore.flushPendingCloudChanges()` (`filmfreaks/MovieNights/MovieNightStore.swift`)
    - `movieStore.refreshFromCloud(force: false)` (`filmfreaks/MovieStore.swift`)
    - `userStore.refreshFromCloud(force: false)` (`filmfreaks/UserStore.swift`)
    - `movieNightStore.refreshFromCloud(groupId: movieStore.currentGroupId, force: false)`.

### 2) UI Layer (SwiftUI)
- Root: `filmfreaks/Content/ContentView.swift`
- Sheet-Routing: `filmfreaks/Content/ContentRouting.swift` (enum `ContentRoute` + `.sheet(item:)` zentral)
- Feature-Screens (Auszug, Entry Files):
  - Settings: `filmfreaks/SettingsView.swift`
  - Search: `filmfreaks/MovieSearch/MovieSearchView.swift`
  - Saved Movie Detail: `filmfreaks/MovieDetail/MovieDetailView.swift` (**Detail-files in `filmfreaks/MovieDetail/`**)
  - TMDb Result Detail: `filmfreaks/SearchResultDetail/SearchResultDetailView.swift`
  - Stats: `filmfreaks/Stats/StatsView.swift` + `filmfreaks/Stats/StatsView+Calculations.swift`
  - Timeline: `filmfreaks/Timeline/TimelineView.swift` (**falls vorhanden; siehe Folder**)
  - Goals: `filmfreaks/Goals/GoalsView.swift` + Editor `filmfreaks/Goals/CustomGoalEditorView.swift`
  - Groups/Sharing: `filmfreaks/GroupSettingsView.swift`, `filmfreaks/GroupShareSheetView.swift`, `filmfreaks/CloudSharingControllerView.swift`
  - Movie Nights: `filmfreaks/MovieNights/*` (Kalender + Detail-Sheets)
- Abhängigkeiten: UI → Stores (`MovieStore`, `UserStore`, `MovieNightStore`, `CloudKitGroupStore`) + Settings (`DisplaySettings`) + Services (TMDb, Caches, NetworkMonitor).

### 3) State/Stores Layer (ObservableObject, meist @MainActor)
- Movies/Backlog + Sync:
  - `filmfreaks/MovieStore.swift`
  - Cloud read/write: `filmfreaks/CloudKitMovieStore.swift`, `filmfreaks/CloudKitRatingStore.swift`
  - Batched writes: `filmfreaks/MovieCloudSyncCoordinator.swift`
- Members:
  - `filmfreaks/UserStore.swift`
  - Cloud: `filmfreaks/CloudKitUserStore.swift` (RecordType `"GroupMember"`)
- Groups/Sharing:
  - `filmfreaks/CloudKitGroupStore.swift`
  - Routing metadata: `filmfreaks/GroupContext.swift`
- Movie Nights:
  - `filmfreaks/MovieNights/MovieNightStore.swift`
  - Local actor: `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`
  - Cloud: `filmfreaks/CloudKitMovieNightStore.swift`
- Abhängigkeiten: Stores → (Persistence + CloudKit + GroupContextStore + NetworkMonitor)

### 4) Persistence / Caching
- Disk (Application Support):
  - `filmfreaks/PersistenceManager.swift` (Movies/Backlog/Users; debounce + atomic write)
  - `filmfreaks/MovieNights/MovieNightLocalPersistence.swift` (Movie nights; eigener JSON-Snapshot)
- UserDefaults:
  - `filmfreaks/GroupContext.swift` (GroupContextsById)
  - `filmfreaks/CloudKitZoneChangeTokenStore.swift` (CKServerChangeToken per zone+namespace)
  - `filmfreaks/SearchHistoryManager.swift` (recent queries)
  - `filmfreaks/RecommendationsCacheManager.swift` (Recommendations TTL cache)
- Caching (Media):
  - `filmfreaks/CachedAsyncImage.swift` + `filmfreaks/ImageCacheStore.swift` (Disk + Memory cache, deduped downloads)
  - Global HTTP cache: `URLCache.shared` in `filmfreaks/filmfreaksApp.swift`

### 5) External Services / Integration
- TMDb:
  - `filmfreaks/TMDbAPI.swift` (API Calls + Models; API-Key via Info.plist `TMDB_API_KEY`)
- CloudKit + Sharing:
  - `filmfreaks/CloudKitShareAppDelegate.swift` (Push routing + share acceptance)
  - `filmfreaks/CloudKitShareCoordinator.swift`
  - `filmfreaks/CloudKitShareSceneDelegate.swift`
- Push / Subscriptions:
  - `filmfreaks/CloudKit/CloudKitActivitySubscriptionManager.swift`
  - `filmfreaks/CloudKit/CloudKitActivityPushFetchCoordinator.swift`
  - `filmfreaks/CloudKit/CloudKitMovieNightSubscriptionManager.swift`

---

## Folder Map (Ordner → Zweck)
- `filmfreaks/Content/` → Home/Listen-UI + Toolbar + Routing
- `filmfreaks/MovieSearch/` → Suche, Empfehlungen, Scan/LiveText, Ergebnislisten
- `filmfreaks/SearchResultDetail/` → Detail-UI zu TMDb Ergebnis
- `filmfreaks/MovieDetail/` → Detail-UI zu gespeicherten Filmen (Ratings etc.)
- `filmfreaks/Stats/` → Statistiken UI + Aggregationen/Drilldowns
- `filmfreaks/Timeline/` → Timeline/Feed
- `filmfreaks/Goals/` → Ziele + Custom Goals
- `filmfreaks/MovieNights/` → Filmabende: Events/Responses/Activity + Sheets + Persistence
- `filmfreaks/CloudKit/` → Subscriptions/Push-Fetch/Helpers
- `filmfreaks/Notifications/` → Notification layer (Mapping + UI/Settings)

---

## Data Model Map (Entities, Relationships, wichtige Felder)

### App-Domain (Codable structs)
- `Movie` (`filmfreaks/Movie.swift`)
  - Identity: `id: UUID`
  - TMDb link: `tmdbId: Int?`, `posterPath: String?`
  - Meta: `title`, `year`, `addedAt`, `addedById/name`
  - Watched: `watchedDate`, `watchedLocation`
  - Ratings: `ratings: [Rating]`
  - Tags: `genres/genreIds`, `keywords/keywordIds`
  - People: `cast: [CastMember]?`, `directors: [CastMember]?` (Legacy-Migration: `legacyCast/legacyDirectors`)
  - Group: `groupId/groupName` (optional)
- `Rating` (`filmfreaks/Movie.swift`)
  - `id: UUID`, `reviewerId: UUID?`, `reviewerName`
  - `scores: [RatingCriterion:Int]`, `comment`, `fazitScore`, `updatedAt`
- `User` (`filmfreaks/User.swift`)
  - `id: UUID`, `name`
- `GroupContext` (`filmfreaks/GroupContext.swift`)
  - `id: String` (GroupId), `name`, `scope: private/shared`, `zoneName`, `ownerName`
- Movie Nights (`filmfreaks/MovieNights/*`)
  - `MovieNightEvent` (`filmfreaks/MovieNights/MovieNightEvent.swift`)
    - `id: UUID`, `groupId: String`, `proposedStart: Date`, `status: enum`
    - `proposerUserId`, `proposerName`
    - optional Movie snapshot: `movieId`, `movieTitle`, `movieYear`, `moviePosterPath`, `movieTmdbId`
    - `note`, `createdAt`, `updatedAt`
  - `MovieNightResponse` (`filmfreaks/MovieNights/MovieNightResponse.swift`)
    - composite `id` (String), `eventId`, `userId`, `userName`, `decision`, `respondedAt`
  - `MovieNightActivityEvent` (`filmfreaks/MovieNights/MovieNightActivityEvent.swift`)
    - `id: UUID`, `groupId`, `kind`, `eventStart`, `actorUserId/name`, `newStatus` etc.

### CloudKit Record Types (aus Code ersichtlich)
- Groups: `FFGroup` (`filmfreaks/CloudKitGroupStore.swift`)
- Movies: `Movie` + Field `isBacklog` (`filmfreaks/CloudKitMovieStore.swift`)
- Ratings: `MovieRating` (`filmfreaks/CloudKitRatingStore.swift`)
- Members: `GroupMember` (`filmfreaks/CloudKitUserStore.swift`)
  - Keys: `groupId`, `memberId`, `name`, `updatedAt`
- Goals: `ViewingGoal`, `ViewingCustomGoals` (`filmfreaks/CloudKitGoalStore.swift`)
- Movie Nights: `MovieNightEvent`, `MovieNightResponse`, `MovieNightActivity` (`filmfreaks/CloudKitMovieNightStore.swift`)

---

## Sync/Storage

### Lokal (Disk / UserDefaults)
- Movies/Backlog/Users (Disk):
  - `filmfreaks/PersistenceManager.swift`
  - Application Support:
    - `~/Library/Application Support/FilmFreaks/groups/<group>/movies_watched.json`
    - `~/Library/Application Support/FilmFreaks/groups/<group>/movies_backlog.json`
    - `~/Library/Application Support/FilmFreaks/groups/<group>/users.json`
- Movie Nights (Disk, Snapshot):
  - `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`
  - `~/Library/Application Support/filmfreaks/movieNights.json`
  - ⚠️ Inkonsequentes Directory-Naming vs. `FilmFreaks/` (**siehe ARCHITECTURE_NOTES → Risiken**)
- Routing/Meta (UserDefaults):
  - `CurrentGroupId`, `CurrentGroupName` (MovieStore/UserStore)
  - Group contexts: `GroupContextsById` (`filmfreaks/GroupContext.swift`)
  - ChangeTokens: pro `(namespace, scope, zoneID)` (`filmfreaks/CloudKitZoneChangeTokenStore.swift`)

### Cloud (CloudKit direkt, nicht SwiftData)
- DB/Zone Routing über `GroupContextStore.context(forGroupId:)`.
  - Owned Group → private DB + Zone
  - Shared Group → shared DB + shared zone
  - Legacy Group → public DB (ohne Zone)
- Sync-Triggers
  - App active: `filmfreaks/filmfreaksApp.swift`
  - Offline → online: flush (MovieStore) (`filmfreaks/MovieStore.swift`), MovieNights flush (`filmfreaks/MovieNights/MovieNightStore.swift`)
  - Push/Subs: `filmfreaks/CloudKit/*` (Activity/MovieNights subscriptions)
- Incremental Sync
  - Zone-Changes + Tokens: `filmfreaks/CloudKitZoneChanges.swift`, `filmfreaks/CloudKitZoneChangeTokenStore.swift`
- Konflikte
  - `CKError.serverRecordChanged` wird teils „last write wins“ gehandhabt (z.B. Goals payload: `filmfreaks/CloudKitGoalStore.swift`).
  - Movies/Ratings: eigene Merge-Strategien (siehe `filmfreaks/CloudKitMovieStore.swift`, `filmfreaks/CloudKitRatingStore.swift`).

---

## UI Map (Hauptscreens, Navigation, wichtige Sheets/Flows)

### Root
- `ContentView` (`filmfreaks/Content/ContentView.swift`)
  - zeigt Watch/Backlog + Header + Sort/Filter („derived model“: `filmfreaks/Content/ContentMovieItemsModel.swift`)
  - Toolbar + Aktionen: `filmfreaks/Content/ContentView+Toolbar.swift`

### Sheet-Routing (zentral)
- `ContentRoute` enum (Cases: settings, quickStart, movieSearch, users, stats, timeline, calendar, activity, goals, groupSettings)
  - `filmfreaks/Content/ContentRouting.swift`

### Häufige Flows
- **Film hinzufügen**
  - `ContentView` → `.movieSearch` → `MovieSearchView` (`filmfreaks/MovieSearch/MovieSearchView.swift`)
  - Auswahl → `SearchResultDetailView` (`filmfreaks/SearchResultDetail/SearchResultDetailView.swift`) → Add to watched/backlog via closures.
- **Film ansehen & bewerten**
  - Aus Listen → `MovieDetailView` (Saved movie details; Folder `filmfreaks/MovieDetail/`)
  - Ratings editieren → `MovieStore` Update → Persistence + optional Cloud sync enqueue.
- **Gruppen**
  - `GroupSettingsView` → Create/Join/Share → `CloudKitGroupStore` + `GroupContextStore` updates.
- **Filmabend**
  - Calendar / Detail sheets (`filmfreaks/MovieNights/*`)
  - Local snapshot persistiert + optional Cloud deltas.

---

## Build & Configuration
- Xcode Projekt: `filmfreaks.xcodeproj`
- Deployment Target: iOS 26.0 (`filmfreaks.xcodeproj/project.pbxproj`)
- Entitlements: `filmfreaks/filmfreaks.entitlements`
  - iCloud container: `iCloud.de.marcfechner.filmfreaks`
  - Push: `aps-environment = development`
- Background Modes:
  - `remote-notification` (`filmfreaks/Info.plist`)
- Build Configs via `.xcconfig`:
  - `filmfreaks/Debug.xcconfig` und `filmfreaks/Release.xcconfig` inkludieren `#include "Secrets.xcconfig"`.
  - `filmfreaks/Secrets.xcconfig` setzt `TMDB_API_KEY = ...` (⚠️ Secret).
- SPM / CocoaPods:
  - Keine `Package.swift`, keine Pods im Archiv; pbxproj zeigt keine Remote Swift Packages.

---

## Conventions (Naming, Patterns, Do/Don’t)
- **View Splits** per Suffix:
  - `FooView+Toolbar.swift`, `StatsView+Calculations.swift`, `MovieStore+X.swift` Pattern (siehe `filmfreaks/Content/*`, `filmfreaks/Stats/*`).
- **Zentraler Sheet-Router** statt verstreuter `.sheet(...)`:
  - `ContentRoute` + `ContentRoutingModifier` (`filmfreaks/Content/ContentRouting.swift`).
- **MainActor Stores**:
  - `MovieStore`, `UserStore`, `MovieNightStore` sind (implizit/explicit) UI-getrieben; Cloud-Work läuft oft im selben Actor-Kontext → Performance-Hotspot-Risiko (Details in ARCHITECTURE_NOTES).
- **CloudKit Sharing Parent References**:
  - In Zone-Gruppen: Child records müssen `record.parent = rootGroupRecordRef` setzen (z.B. `CloudKitUserStore`, `CloudKitGoalStore`).

---

## How to work on this project (Setup + Startpunkte)

### Setup Steps (neuer Dev)
1. Öffne `filmfreaks.xcodeproj` und baue Target **filmfreaks**.
2. Setze TMDb Key:
   - `filmfreaks/Secrets.xcconfig` muss `TMDB_API_KEY` enthalten, sonst schlagen TMDb Calls fehl.
3. iCloud/CloudKit:
   - Capabilities (iCloud + CloudKit, Sharing) müssen für deine Signierung aktiv sein (Entitlements: `filmfreaks/filmfreaks.entitlements`).
4. Push / Remote Notifications:
   - Für Live-Push: App ID + Push certs; in Simulator/ohne Setup ist das Verhalten **best effort**.

### Wo anfangen (für neue Features)
- Neues Sheet aus dem Home:
  - Case in `ContentRoute` ergänzen + `routedSheet` Switch erweitern (`filmfreaks/Content/ContentRouting.swift`)
  - UI Trigger in `ContentView+Toolbar` oder Header ergänzen (`filmfreaks/Content/ContentView+Toolbar.swift`)
- Neue Daten pro Gruppe speichern:
  - Lokal: `PersistenceManager` erweitern (neuer `Kind` + save/load) **oder** eigener kleiner Actor wie `MovieNightLocalPersistence`.
  - Cloud: eigene `CloudKitXStore` analog zu `CloudKitGoalStore`/`CloudKitMovieNightStore`.
- Neue CloudKit Daten in Sharing-Gruppen:
  - DB/Zone Routing immer über `GroupContextStore` machen.
  - Für Sharing: `parent` auf Root-Group Record setzen (Beispiele in `CloudKitUserStore`, `CloudKitGoalStore`).

### Typischer Workflow „Feature hinzufügen“ (Checkliste)
- [ ] Domain-Type (Codable) ergänzen/erweitern (z.B. in `filmfreaks/Movie.swift` oder neuer Datei).
- [ ] Lokale Persistenz:
  - [ ] Disk (Application Support) via `PersistenceManager`/Actor, oder UserDefaults wenn klein.
- [ ] Cloud Sync (falls relevant):
  - [ ] RecordType + Keys definieren
  - [ ] `routedDatabase(forGroupId:)` implementieren
  - [ ] Zone-Group: `record.parent` setzen
  - [ ] ChangeToken Namespace hinzufügen (falls incremental)
- [ ] UI:
  - [ ] Routing (Sheet/NavigationDestination)
  - [ ] State binding an Store
  - [ ] Performance: keine teuren Aggregationen im `body`/computed properties.

---

## Quick Wins (max. 10, konkret)
1. **Public-Fallback Guard für UUID-Gruppen**: Wenn `currentGroupId` UUID ist, aber `GroupContextStore.context(...) == nil`, nicht auf Public DB fallen (Risiko: Upload in Public) – `MovieNightStore` hat das Pattern bereits, `MovieStore`/`CloudKitUserStore` aktuell nicht konsequent.
2. **Stats Aggregationen cachen**: `filmfreaks/Stats/StatsView+Calculations.swift` berechnet `filteredMovies`/Buckets mehrfach pro Render. Introduce Cache/VM, invalidiert bei `selectedRange/location/movies`.
3. **Doppelte Subscription-Calls entfernen**: `CloudKitGroupStore.refresh()` ruft `ensureSubscriptions(...)` doppelt (identische Task-Blöcke) in `filmfreaks/CloudKitGroupStore.swift`.
4. **Persistenz-Verzeichnisse vereinheitlichen**: `FilmFreaks/` vs `filmfreaks/` (MovieNights) – reduziert Debugging-Friction.
5. **Task-Cancellation konsistent**: Long-running Cloud refresh Tasks abbrechen/ignorieren bei group switch (MovieStore macht „capture requestedGroupId“; konsequent auch in MovieNightStore/UserStore/Push-Fetch).
6. **Secrets hygiene**: `Secrets.xcconfig` aus VCS ausklammern + `Secrets.example.xcconfig` anlegen.
7. **Privacy Manifest hinzufügen**: Kein `PrivacyInfo.xcprivacy` im Archiv gefunden (**App Store Relevanz: UNKNOWN**).
8. **Logging vereinheitlichen**: `print(...)` in CloudKit-Stores → `os.Logger` (Categories: CloudKit, Sync, UI).
9. **Background push-fetch throttling**: Falls `CloudKitActivityPushFetchCoordinator` in kurzen Abständen ganze Gruppen re-synct → Min-Interval + Coalescing.
10. **Derived list computations off-main**: `ContentMovieItemsModel.update(...)` sortiert/filtered auf MainActor; bei großen Listen kann das UI stottern.

---

## Key Files Index (Startpunkte)
- Entry: `filmfreaks/filmfreaksApp.swift`
- Root UI + Routing: `filmfreaks/Content/ContentView.swift`, `filmfreaks/Content/ContentRouting.swift`
- Movies: `filmfreaks/MovieStore.swift`, Cloud: `filmfreaks/CloudKitMovieStore.swift`, Ratings: `filmfreaks/CloudKitRatingStore.swift`
- Members: `filmfreaks/UserStore.swift`, Cloud: `filmfreaks/CloudKitUserStore.swift`
- Groups: `filmfreaks/CloudKitGroupStore.swift`, `filmfreaks/GroupContext.swift`
- Movie Nights: `filmfreaks/MovieNights/MovieNightStore.swift`, `filmfreaks/CloudKitMovieNightStore.swift`
- Persistence: `filmfreaks/PersistenceManager.swift`
- TMDb: `filmfreaks/TMDbAPI.swift`
- Images: `filmfreaks/CachedAsyncImage.swift`, `filmfreaks/ImageCacheStore.swift`
- Settings: `filmfreaks/DisplaySettings.swift`, `filmfreaks/SettingsView.swift`

---

## Open Questions (UNKNOWN)
- **CloudKit Dashboard State**: Sind RecordTypes/Zones/Indexes in Dev+Prod korrekt deployed? (Code sagt „so sollte es sein“, Dashboard ist **UNKNOWN**).
- **Push-Setup**: Welche Push-Events sollen wirklich genutzt werden (nur Activity/MovieNights vs. alles)? Server-side Subscription Coverage ist **UNKNOWN** ohne Dashboard.
- **Test Coverage**: Im Archiv sind keine Test-Sources erkennbar; ob Tests existieren/gewollt sind ist **UNKNOWN**.
