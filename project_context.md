# PROJECT_CONTEXT.md

## TL;DR
**filmfreaks** ist eine SwiftUI iOS-App (Deployment Target **iOS 26.0**) zum Tracken von Filmen in Gruppen: **Gesehen** + **Backlog**, **Ratings pro Mitglied**, **Stats/Timeline/Goals**, plus TMDb-gestützte Suche/Details/Watch-Provider. Persistenz ist **lokal-first** (JSON auf Disk) mit optionalem **CloudKit Sync + Sharing**.

---

## Key Concepts / Domänenbegriffe

- **Group / Gruppe**
  - Eine Filmgruppe, in der alle Daten (Filme, Mitglieder, Goals, Ratings) gruppen-spezifisch gespeichert/synchronisiert werden.
  - CloudKit-Sharing basiert auf einer **Record Zone pro Gruppe** (siehe `CloudKitGroupStore.swift`, `GroupContext.swift`).

- **GroupId**
  - String-ID der Gruppe. Wird überall als Routing-Key genutzt (z.B. in Movie/Rating-Records).
  - Legacy/No-Context-Fälle routen in die **Public DB ohne Zone** (siehe `CloudKitMovieStore.swift`).

- **GroupContext**
  - Persistierte Routing-Metadaten: `scope` (private/shared), `zoneName`, `ownerName`.
  - Quelle: `GroupContextStore` in `GroupContext.swift`.

- **Watched vs Backlog**
  - Zwei Listen: `MovieStore.movies` (gesehen) und `MovieStore.backlogMovies` (Backlog) (`MovieStore.swift`).

- **Member / User**
  - Mitglieder der Gruppe (für Ratings, Filter, UI). Model: `User` (`User.swift`), Sync-Logik: `UserStore.swift` + `CloudKitUserStore.swift`.

- **Rating**
  - Bewertungsobjekt pro Film und Reviewer. Enthält Kriterien-Sterne + optional „Fazit“ (1–10) + Kommentar.
  - Wichtig: `reviewerId` ist die stabile Identität; `reviewerName` ist Display (siehe `Movie.swift`).

- **TMDb**
  - Externer Datenprovider für Suche/Details/Cast/Keywords/Trailer/Watch Providers (`TMDbAPI.swift`).

- **Goals**
  - Jahresziel + Custom Goals (Decade/Person/Director/Genre/Keyword).
  - Models/Logic: `ViewingCustomGoal.swift` und `Goals/*`.
  - CloudKit-Store: `CloudKitGoalStore.swift`.

- **Activity Feed**
  - UI-freundliche Events, **abgeleitet** aus Movie+Rating-Daten; kein eigener CloudKit-Record (`Content/GroupActivityEvent.swift`).

- **Sync Transparency**
  - Subtile Sync-Status-Felder (pending changes, last sync, last error) v.a. in `MovieStore.swift` und `UserStore.swift`.

---

## Architecture Map (Layer / Module / Abhängigkeiten)

### UI Layer (SwiftUI)
- Entry: `filmfreaksApp.swift` → `ContentView` (NavigationStack).
- Hauptscreens als Views + viele Subviews/Extensions:
  - `Content/*`, `MovieDetail/*`, `MovieSearch/*`, `SearchResultDetail/*`, `Stats/*`, `Goals/*`.

**Abhängigkeiten:**
- UI → `MovieStore`, `UserStore`, `CloudKitGroupStore`, `DisplaySettings`, `NetworkMonitor` (via `.environmentObject` in `filmfreaksApp.swift`).

### State / Stores (MainActor ObservableObjects)
- `MovieStore.swift` (Filme + Cloud Sync Koordination)
- `UserStore.swift` (Mitglieder + Cloud Sync)
- `CloudKitGroupStore.swift` (Gruppen erstellen/listen, Sharing, Repair)
- `DisplaySettings.swift` (Appearance/Density/Theme)
- `NetworkMonitor.swift` (Online/Offline)

### Persistence & Sync
- Lokal:
  - `PersistenceManager.swift` (JSON-Dateien in Application Support, debounced writes)
  - UserDefaults für Settings/Flags/Tokens/Goals (u.a. `OnboardingProgress.swift`, `CloudKitZoneChangeTokenStore.swift`)
- CloudKit:
  - `CloudKitMovieStore.swift` (Movie Records)
  - `CloudKitRatingStore.swift` (MovieRating Records)
  - `CloudKitUserStore.swift` (GroupMember Records)
  - `CloudKitGoalStore.swift` (ViewingGoal + ViewingCustomGoals)
  - Zone Changes wrapper: `CloudKitZoneChanges.swift` + Token store `CloudKitZoneChangeTokenStore.swift`

### Services / Utilities
- TMDb: `TMDbAPI.swift`
- Image caching: `CachedAsyncImage.swift` (+ App-weites `URLCache` Setup in `filmfreaksApp.swift`)
- Toast UX: `AppToast.swift` + `ToastHost` (wird in `filmfreaksApp.swift` gezeigt)

---

## Folder Map (Ordner → Zweck)

- `filmfreaks/` (Root)
  - Stores/Services/Settings/Utilities, CloudKit-Sharing Delegates, Models (`Movie.swift`, `User.swift`).
- `filmfreaks/Content/`
  - Startscreen (Header/Controls/MainArea), Routing für Sheets, Activity UI.
- `filmfreaks/MovieSearch/`
  - Suche (TMDb), Ergebnisse, Empfehlungen, ggf. Scanner (`MediaTitleScannerView.swift`).
- `filmfreaks/SearchResultDetail/`
  - Detailansicht für Suchresultate (vor dem Hinzufügen), Trailer/Watch Providers/Film Info.
- `filmfreaks/MovieDetail/`
  - Detailansicht eines gespeicherten Films inkl. Ratings, TMDb-Details, Watch Providers.
- `filmfreaks/Stats/`
  - Statistik-Dashboard, Filter, Aggregationen.
- `filmfreaks/Goals/`
  - Goals UI + Models + Persist/Sync.
- `filmfreaks/Assets.xcassets/`
  - AppIcon/AccentColor etc.

---

## Data Model Map (Entities, Relationships, wichtige Felder)

### Core Models
- `Movie` (`Movie.swift`)
  - `id: UUID`
  - `title, year`
  - `tmdbId: Int?`, `posterPath: String?`, `tmdbRating: Double?`
  - `watchedDate: Date?`, `watchedLocation: String?`
  - `ratings: [Rating]` (wird lokal gehalten; CloudKit speichert Ratings separat)
  - `genres/genreIds`, `keywords/keywordIds`
  - `cast: [CastMember]?`, `directors: [CastMember]?`
  - `addedAt`, `addedById`, `addedByName` (für Activity)
  - `groupId`, `groupName`

- `Rating` (`Movie.swift`)
  - `id: UUID`
  - `reviewerId: UUID?` (stabil), `reviewerName: String` (Display)
  - `scores: [RatingCriterion: Int]` (0–3)
  - `fazitScore: Int?` (1–10)
  - `comment: String?`
  - `updatedAt: Date?` (CloudKit-Record `updatedAt`, best-effort)

- `User` (`User.swift`)
  - `id: UUID`, `name: String`

- `GroupContext` (`GroupContext.swift`)
  - `id: String` (groupId)
  - `name: String`
  - `scope: GroupScope` (`private`/`shared`)
  - `zoneName: String`, `ownerName: String`
  - Persistiert via `GroupContextStore` (UserDefaults)

### Goals
- `ViewingCustomGoal*` (`ViewingCustomGoal.swift`)
  - Typen: decade/person/director/genre/keyword
  - Rule enthält IDs (TMDb personId/genreId/keywordId) für stabile Matches
  - Year-scoped / duration Hinweise in den Kommentaren (Details: `ViewingCustomGoal.swift`)

### Derived UI Models
- `GroupActivityEvent` (`Content/GroupActivityEvent.swift`)
  - Abgeleitet aus Movie/Rating; keine eigene Persistenz.

---

## Sync/Storage

### Lokal (Disk + UserDefaults)
- Movies/Backlog/Users:
  - Persistiert als JSON pro Gruppe in Application Support via `PersistenceManager.swift`.
  - Writes sind **debounced** (`debounceSeconds = 0.55`) und laufen auf eigener Queue.
  - Migration: `migrateFromUserDefaultsIfNeeded()` in `PersistenceManager.swift`.

- Settings/Flags/Tokens/Goals:
  - UserDefaults/AppStorage (z.B. `DisplaySettings.swift`, `OnboardingProgress.swift`,
    `CloudKitZoneChangeTokenStore.swift`, `Goals/GoalsView+Persistence.swift`).

### CloudKit (Sync + Sharing)
- Container: Default CloudKit Container (Entitlements siehe `filmfreaks.entitlements`)
- Sharing:
  - Share acceptance via Scene Delegate + App Delegate:
    - `CloudKitShareAppDelegate.swift`
    - `CloudKitShareSceneDelegate.swift`
    - `CloudKitShareCoordinator.swift` (zeigt Toasts, akzeptiert Share, postet `.cloudKitShareAccepted`)
- Gruppen:
  - `CloudKitGroupStore.swift`
    - RecordType: `"FFGroup"`
    - Zone pro Gruppe: `zoneName = "group.<groupId>"` (create path in `createGroup`)
    - private DB für owned, shared DB für geteilte Gruppen
- Movies:
  - `CloudKitMovieStore.swift`
    - RecordType: `"Movie"` (payload + isBacklog + updatedAt + groupId)
    - Routing:
      - Wenn `GroupContextStore.context(forGroupId:)` fehlt → Public DB (Legacy)
      - Sonst private/shared DB + Zone
    - Skalierung:
      - Zone-basierte Gruppen nutzen `CKFetchRecordZoneChangesOperation` via `fetchMovieChanges` + Token store.
- Ratings:
  - `CloudKitRatingStore.swift`
    - RecordType: `"MovieRating"` (payload + movieId + groupId + reviewerId + updatedAt)
    - Jeder Reviewer ist Creator seines Rating-Records.
- Users/Members:
  - `CloudKitUserStore.swift`
    - RecordType: `"GroupMember"`
    - Legacy-Migration: alter RecordName ohne memberId wird best-effort migriert.
- Goals:
  - `CloudKitGoalStore.swift`
    - `"ViewingGoal"` (year, target)
    - `"ViewingCustomGoals"` (payload)

### Offline-Verhalten (beobachtbar im Code)
- Lokal-first: UI arbeitet mit lokalem Cache; Cloud-Refresh passiert später.
- Refresh Trigger:
  - Bei `.scenePhase == .active` wird `groupStore.refresh()`, `movieStore.refreshFromCloud()`, `userStore.refreshFromCloud()` gestartet (`filmfreaksApp.swift`).
  - Pull-to-refresh parallelisiert Movie/User Refresh (`Content/ContentView+Refresh.swift`).
- Ohne Subscriptions:
  - Kommentar in `filmfreaksApp.swift` deutet an, dass dies ein bewusster Ersatz ist (kein Push-Trigger).

---

## UI Map (Hauptscreens + Navigation + Flows)

### Entry
- `filmfreaksApp.swift`
  - Root: `ContentView()` in einem ZStack
  - Global: `ToastHost()` overlay
  - Optional: `SplashView`

### Hauptscreen
- `Content/ContentView.swift`
  - `NavigationStack` als Root
  - Header + Main Area
  - Sheets via zentralem Routing:
    - `Content/ContentRouting.swift` (`ContentRoute` + `.sheet(item:)`)
    - Routes: settings, quickStart, movieSearch, users, stats, timeline, activity, goals, groupSettings

### Listen/Details
- Liste/Grid:
  - `Content/ContentMainAreaView.swift` (List / Grid)
  - `Content/ContentMoviesListSection.swift`:
    - `NavigationLink` → `MovieDetail/MovieDetailView.swift` (Binding auf `$movies[item.index]`)
- Movie Detail:
  - `MovieDetail/MovieDetailView.swift` + Extensions (Lifecycle/Loading/etc.)
  - Lädt TMDb Details (Task in `MovieDetailView+Lifecycle.swift`)
- Movie Search:
  - `MovieSearch/MovieSearchView.swift`
  - Detail für Suchresultat:
    - `SearchResultDetail/SearchResultDetailView.swift`
  - Add-to-list Sektionen: `SearchResultDetail/*AddToList*`
- Stats:
  - `Stats/StatsView.swift` + viele Extensions für Karten/Rows/Calculations
- Goals:
  - `Goals/GoalsView.swift` + Editor etc.
- Group Settings:
  - `GroupSettingsView.swift` + `GroupShareSheetView.swift`

---

## Build & Configuration

- Xcode Project: `filmfreaks.xcodeproj`
- Targets (aus Projektstruktur ersichtlich): `filmfreaks`, `filmfreaksTests`, `filmfreaksUITests` (**Testsources: UNKNOWN**)
- Deployment Target: **iOS 26.0** (Build Setting)
- Info.plist: `filmfreaks/Info.plist`
  - `TMDB_API_KEY` wird via Build Setting `$(TMDB_API_KEY)` injiziert
  - `CKSharingSupported = true`
- Entitlements: `filmfreaks/filmfreaks.entitlements`
  - iCloud Container: `iCloud.de.marcfechner.filmfreaks`
  - iCloud Service: CloudKit
  - `aps-environment = development` (Production Setup: **UNKNOWN**)
- xcconfig:
  - `Debug.xcconfig` / `Release.xcconfig` inkludieren `Secrets.xcconfig`
  - `.gitignore` ignoriert `Secrets.xcconfig`
  - Sicherheits-Hinweis: In deinem ZIP liegt `Secrets.xcconfig` dennoch bei → Schlüssel-Leak-Risiko beim Teilen.

---

## Conventions (Naming, Patterns, Do/Don’t)

- Stores sind i.d.R. `@MainActor` + `ObservableObject`:
  - `MovieStore`, `UserStore`, `CloudKitGroupStore`, `NetworkMonitor`
- Sheet Routing zentralisiert:
  - `ContentRoute` + `contentRouting(...)` (`Content/ContentRouting.swift`)
- Große Views werden via Extensions gesplittet:
  - z.B. `MovieDetailView+Lifecycle.swift`, `ContentView+MovieItems.swift`, `StatsView+…`
- Group-Scoping überall:
  - Local file names + UserDefaults keys + CloudKit predicates/zone routing hängen an `groupId`.
- Image Loading:
  - Prefer `CachedAsyncImage` statt ad-hoc `AsyncImage` (Cache + dedupe).
- Don’t:
  - Secrets in Git/ZIP teilen (auch wenn `.gitignore` korrekt ist).

---

## How to work on this project (Setup + wo anfangen)

### Setup Steps (neuer Dev)
1. Xcode öffnen: `filmfreaks.xcodeproj`
2. Signing / Team prüfen, iCloud Capability aktiv (CloudKit Container: `iCloud.de.marcfechner.filmfreaks`).
3. `TMDB_API_KEY` bereitstellen:
   - lokal `Secrets.xcconfig` anlegen (nicht committen)
   - oder per CI/Build Setting injizieren.
4. Build + Run auf iOS 26 Device/Simulator.

### First Files to Read
- App + Wiring:
  - `filmfreaksApp.swift`, `Content/ContentView.swift`, `Content/ContentRouting.swift`
- Sync/Persist:
  - `MovieStore.swift`, `CloudKitMovieStore.swift`, `CloudKitZoneChanges.swift`, `CloudKitZoneChangeTokenStore.swift`
  - `UserStore.swift`, `CloudKitUserStore.swift`
  - `PersistenceManager.swift`
- TMDb:
  - `TMDbAPI.swift`

### Adding a new Sheet Route (typischer Workflow)
- Edit:
  - `Content/ContentRouting.swift` (`ContentRoute` erweitern + switch in `routedSheet`)
  - `Content/ContentView.swift` (UI-Aktion setzt `route = .newCase`)
```swift
internal enum ContentRoute: String, Identifiable { case myNewSheet /* ... */ }
@ViewBuilder private func routedSheet(for route: ContentRoute) -> some View {
  switch route { case .myNewSheet: themed(MyNewSheetView()) /* ... */ }
}
