# PROJECT_CONTEXT

Last updated: 2026-02-25

## TL;DR

**filmfreaks** ist eine iOS‑App zum gemeinsamen Tracken von Filmen in Gruppen (gesehen + Backlog), inkl. per‑User Ratings/Fazit, Statistiken, Ziele und Movie‑Night‑Planung. Sync erfolgt über **CloudKit** (public/private/shared + Zones/Sharing), lokale Offline‑Persistenz über JSON‑Files. Mindest‑iOS: **26.0** (siehe `filmfreaks.xcodeproj/project.pbxproj`).

## Key Concepts / Domänenbegriffe

- **Watched / Backlog**: zwei Listen pro Gruppe (`MovieStore.movies` vs `MovieStore.backlogMovies`).
- **Group / GroupId**: aktueller Gruppen‑Kontext, teils „legacy/public“ (kein Zone‑Routing), teils Sharing/Zone‑basiert (UUID‑ähnliche IDs). Routing über `CloudKitRouting` + `GroupContextStore`.
- **Rating**: pro User mehrere Kriterien (1–3 Sterne) + optionaler Kommentar + optionaler **Fazit‑Score** (1–10). Modell: `filmfreaks/Movie.swift` (`struct Rating`).
- **CastMember**: Personenreferenz (TMDb Person‑ID + Name) für Cast/Directors; Grundlage u.a. für Actor‑Stats und Director‑Goals (`filmfreaks/Movie.swift`).
- **Goals**: Jahresziel + Custom Goals (z.B. Actor/Decade/…); CloudKit‑Payload pro Gruppe (`filmfreaks/CloudKitGoalStore.swift`, `filmfreaks/ViewingCustomGoal.swift`).
- **Stats**: aggregierte Snapshot‑Berechnung (off‑main), dann UI rendert nur cached Outputs (`filmfreaks/Stats/StatsViewModel.swift`, `filmfreaks/Stats/StatsSnapshotBuilder.swift`).
- **Movie Nights**: Events/Responses/Activity pro Gruppe, lokal persistiert + optional CloudKit Sync (`filmfreaks/MovieNights/*`).
- **TMDb**: Suche/Details/Person‑Meta via HTTP (`filmfreaks/TMDbAPI/*`).

## Architecture Map (Layer/Module + Verantwortlichkeiten + Abhängigkeiten)

- **UI (SwiftUI Views)**
  - Hauptscreen: `filmfreaks/Content/ContentView.swift` (List/Grid, Header, Routing).
  - Feature‑Bereiche: `Content/`, `MovieSearch/`, `MovieDetail/`, `Stats/`, `Goals/`, `MovieNights/`, `Timeline/`, `SettingsView.swift`.
- **State / Stores (ObservableObject, meist @MainActor)**
  - App‑weit: `MovieStore`, `UserStore`, `MovieNightStore`, `CloudKitGroupStore`, `DisplaySettings`, `NetworkMonitor` (siehe `filmfreaks/filmfreaksApp.swift`).
  - Feature‑spezifisch: `StatsViewModel`, `PersonPopularityStore`.
- **Local Persistence / Caches**
  - Disk (Application Support, JSON, group‑scoped): `filmfreaks/PersistenceManager.swift`.
  - MovieNight JSON: `filmfreaks/MovieNights/MovieNightLocalPersistence.swift`.
  - UserDefaults Caches: z.B. `RecommendationsCacheManager` (`filmfreaks/RecommendationsCacheManager.swift`), `GroupContextStore` (`filmfreaks/GroupContext.swift`).
  - HTTP Image Cache: `URLCache.shared` Setup in `filmfreaks/filmfreaksApp.swift` + `CachedAsyncImage.swift`.
- **Cloud Sync (CloudKit)**
  - Routing DB/Zone: `filmfreaks/CloudKitRouting.swift` + persisted `GroupContextStore`.
  - Low‑level Stores: `CloudKitMovieStore/*`, `CloudKitRatingStore/*`, `CloudKitMovieNightStore/*`, `CloudKitUserStore.swift`, `CloudKitGoalStore.swift`, `CloudKitGroupStore/*`.
  - Batching/Debounce Coordinators: `MovieCloudSyncCoordinator.swift`, `MovieNights/MovieNightCloudSyncCoordinator.swift`.
  - Sharing Acceptance + UI Feedback: `CloudKitShareAppDelegate.swift`, `CloudKitShareCoordinator.swift`, `CloudSharingControllerView.swift`.
  - Push Subscriptions/Fetch (Activity): `filmfreaks/CloudKit/CloudKitActivitySubscriptionManager.swift`, `filmfreaks/CloudKit/CloudKitActivityPushFetchCoordinator.swift`.
- **External Integration**
  - TMDb HTTP API: `filmfreaks/TMDbAPI/*` (Key via Info.plist/Env; siehe Build‑Config).

## Folder Map (Ordner → Zweck)

- `filmfreaks/Content/` — Home: Header, List/Grid, Activity‑Preview, Routing/Sheets.
- `filmfreaks/MovieStore/` — MovieStore Extensions (Persistence/Selections/CloudSync).
- `filmfreaks/CloudKitMovieStore/` — CloudKit „Movie“ Records (Routing/ZoneChanges/Modify/Merge/Schema).
- `filmfreaks/CloudKitRatingStore/` — CloudKit „MovieRating“ Records (Query/Modify/ZoneChanges/Schema).
- `filmfreaks/CloudKitMovieNightStore/` — CloudKit „MovieNight*“ Records (Routing/ZoneChanges/Modify/Schema).
- `filmfreaks/CloudKitGroupStore/` — Groups via CloudKit Zones/Sharing (Listing/Sharing/…); hängt an `CloudKitGroupStore`.
- `filmfreaks/TMDbAPI/` — HTTP Client + Modelle für TMDb.
- `filmfreaks/MovieSearch/` — Suche: UI, Debounce/Tasks, Recommendations, Scanner, Result Cards.
- `filmfreaks/MovieDetail/` — Movie Detail Screen + Subsections (Hero, Overview, Ratings, Providers).
- `filmfreaks/Stats/` — Stats UI + Snapshot‑Compute + ViewModel.
- `filmfreaks/Goals/` — Goals UI/Matching/Enrichment/TMDb helpers + Custom Goals Subtypes (`Goals/CustomGoals/*`).
- `filmfreaks/MovieNights/` — Movie Night Domain + Store + Calendar + Sheets.
- `filmfreaks/Timeline/` — Timeline UI + data helpers.
- `filmfreaks/DisplaySettings/` — Appearance/Theme/UX Settings + Persistence + Presets.
- `filmfreaks/Notifications/` — lokale Notification‑State/Permissions etc.

## Data Model Map (Entities, Relationships, wichtige Felder)

### Core

- **Movie** (`filmfreaks/Movie.swift`)
  - `id: UUID`, `title`, `year`, `tmdbId`, `tmdbRating`, `posterPath`
  - Listen/Group Meta: `watchedDate`, `watchedLocation`, `groupId`, `groupName`, `addedAt`, `addedById`, `addedByName`
  - Taxonomie: `genres`/`genreIds`, `keywords`/`keywordIds`
  - People: `cast: [CastMember]?`, `directors: [CastMember]?`
  - Ratings: `ratings: [Rating]` (**lokal** im Movie‑Payload; CloudKit speichert Ratings separat, siehe unten)

- **Rating** (`filmfreaks/Movie.swift`)
  - Identity: `id: UUID`, `reviewerId: UUID?`, `reviewerName: String`
  - `scores: [RatingCriterion: Int]`, optional `comment`, optional `fazitScore`, optional `updatedAt`.

- **CastMember** (`filmfreaks/Movie.swift`)
  - `personId: Int` (TMDb Person ID), `name: String`.

- **User** (`filmfreaks/User.swift`)
  - `id: UUID`, `name: String`.

### Groups / Sharing

- **GroupContext** (`filmfreaks/GroupContext.swift`)
  - `id` (groupId), `name`, `scope` (`private`/`shared`), `zoneName`, `ownerName`.
  - Persistiert in `UserDefaults` via `GroupContextStore` (Routing‑Metadata).

### Movie Nights

- **MovieNightEvent** (`filmfreaks/MovieNights/MovieNightEvent.swift`)
  - `id`, `groupId`, `proposedStart`, `status` (open/scheduled/cancelled), proposer meta, optional `suggestedMovie`.
- **MovieNightResponse** (`filmfreaks/MovieNights/MovieNightResponse.swift`)
  - Antworten pro User/Event (accept/decline + timestamps).
- **MovieNightActivityEvent** (`filmfreaks/MovieNights/MovieNightActivityEvent.swift`)
  - Activity Stream für Movie Night‑Änderungen.

### Goals

- **ViewingCustomGoal** (`filmfreaks/ViewingCustomGoal.swift`)
  - Custom Goal Typen + Matching/Progress (Details je nach Goal‑Kind).
- **ViewingCustomGoalsPayload** (`filmfreaks/ViewingCustomGoalsPayload.swift`)
  - Versionierter Payload, der als ein CloudKit Record gespeichert wird (`ViewingCustomGoals`).

### Activity

- **GroupActivityEvent / UnifiedGroupActivityEvent** (`filmfreaks/Content/*`)
  - Vereinheitlichte Darstellung von Movie/Ratings/MovieNight‑Activity in der UI.

### TMDb Modelle

- `filmfreaks/TMDbAPI/TMDbAPI+Models.swift` (z.B. `TMDbMovieResult`, `TMDbPersonDetails`, …).

## Sync/Storage (CloudKit, Caches, Migration, Offline)

### Lokal (Offline‑State)

- **Disk‑Persistenz (JSON)**: `filmfreaks/PersistenceManager.swift`
  - Base dir: Application Support `…/FilmFreaks/groups/<group>/`
  - Dateien: `movies_watched.json`, `movies_backlog.json`, `users.json` (pro Gruppe).
  - Writes: debounced (`~0.55s`), auf Utility‑Queue, `Data.write(.atomic)`.
  - Migration: `migrateFromUserDefaultsIfNeeded()` (Flag `FilmFreaks.diskPersistence.v2.migrated`).

- **UserDefaults**
  - Kleinzeug: selected group (`CurrentGroupId`, `CurrentGroupName`), GroupContexts (`GroupContextStore`), diverse UI/Cache keys.
  - Recommendations Cache: `filmfreaks/RecommendationsCacheManager.swift`.

### Cloud (CloudKit)

- **Routing (DB + Zone)**: `filmfreaks/CloudKitRouting.swift`
  - Keine groupId → Public DB, keine Zone.
  - GroupContext vorhanden → Private oder Shared DB + Zone (aus `GroupContextStore`).
  - UUID‑ähnliche groupIds **müssen** GroupContext haben, sonst `CloudKitRoutingError.groupContextNotReady` (kein unsafe Public‑Fallback).

- **Record Types (gefunden im Code)**
  - `Movie`, `MovieRating`, `ViewingGoal`, `ViewingCustomGoals`, `FFGroup`, `GroupMember`, `MovieNightEvent`, `MovieNightResponse`, `MovieNightActivity`.

- **Stores**
  - Movies: `filmfreaks/CloudKitMovieStore/*` (Movie‑Payload ohne `ratings`, siehe `sanitizedMovieForCloud`).
  - Ratings: `filmfreaks/CloudKitRatingStore/*` (ein Record pro (Movie, Reviewer) → Creator darf updaten).
  - Users: `filmfreaks/CloudKitUserStore.swift` (GroupMember Records).
  - Goals: `filmfreaks/CloudKitGoalStore.swift` (Jahresziele + Custom Goals Payload).
  - Movie Nights: `filmfreaks/CloudKitMovieNightStore/*`.
  - Groups: `filmfreaks/CloudKitGroupStore/*` (Zone/Share erstellen, owned/shared listen).

- **Debounced Upload / Pending Queue**
  - Movies: `filmfreaks/MovieCloudSyncCoordinator.swift` (pending saves/deletes, debounce `~0.8s`).
  - Movie Nights: `filmfreaks/MovieNights/MovieNightCloudSyncCoordinator.swift` (analoges Muster).
  - Sync‑Transparenz (UI): pending counts + last sync + last error werden pro Gruppe in UserDefaults persistiert (z.B. `filmfreaks/MovieStore/MovieStore+Persistence.swift`).

### Push / Subscriptions (Activity)

- Subscriptions werden deterministisch pro Gruppe gepflegt: `filmfreaks/CloudKit/CloudKitActivitySubscriptionManager.swift`.
- Remote notification entry: `filmfreaks/CloudKitShareAppDelegate.swift` (`didReceiveRemoteNotification`).
- **Achtung**: `CloudKitActivityPushFetchCoordinator.fetchAndHandle` ist in Release derzeit `return false` (via `#if DEBUG` in `filmfreaks/CloudKit/CloudKitActivityPushFetchCoordinator.swift`).

## UI Map (Hauptscreens + Navigation + wichtige Sheets/Flows)

### App Entry

- `filmfreaks/filmfreaksApp.swift`
  - Injected EnvironmentObjects: `MovieStore`, `MovieNightStore`, `UserStore`, `CloudKitGroupStore`, `NetworkMonitor`, `DisplaySettings`.
  - On app becomes active: `AppRefreshCoordinator.triggerRefresh { await groupStore.refresh(); ... }` (Cloud pull).

### Home (ContentView)

- `filmfreaks/Content/ContentView.swift`
  - NavigationStack mit Header + Main Area.
  - List mode: Watched vs Backlog (`MovieListMode`).
  - ViewStyle: cards vs list (persistiert via `@AppStorage("ContentView_ViewStyle")`).
  - Derived models off render path: `ContentMovieItemsModel`, `ContentActivityPreviewModel`.
- Sheets / Routing: `filmfreaks/Content/ContentRouting.swift` (`ContentRoute`):
  - Settings, QuickStart, MovieSearch, Users, Stats, Timeline, Calendar, Activity, Goals, GroupSettings.

### Movie Search

- `filmfreaks/MovieSearch/MovieSearchView.swift` (+ Extensions `MovieSearchView+*.swift`)
  - TMDb search, Recommendations, Scanner, Candidate Picker Sheet.

### Movie Detail

- `filmfreaks/MovieDetail/MovieDetailView.swift`
  - Sections: Hero, Title/Meta, Watch Providers, Overview, Ratings Sheet, etc.

### Stats

- `filmfreaks/Stats/StatsView.swift` + `StatsViewModel.swift`
  - Snapshot compute debounced/off‑main; UI rendert Snapshot.

### Movie Nights

- Calendar + Sheets: `filmfreaks/MovieNights/Calendar/MovieNightCalendarView.swift`, `MovieNights/Sheets/*`.

### Settings / Appearance

- `filmfreaks/SettingsView.swift`, `filmfreaks/AppearanceSettingsView.swift`, `filmfreaks/DisplaySettings/*`.

## Build & Configuration (Targets, Info.plist, Entitlements, SPM, Secrets)

- Xcode project: `filmfreaks.xcodeproj`
  - Deployment target: **iOS 26.0** (`IPHONEOS_DEPLOYMENT_TARGET = 26.0`).
  - Targets: `filmfreaks`, `filmfreaksTests`, `filmfreaksUITests`.

- Info.plist: `filmfreaks/Info.plist`
  - `CKSharingSupported = YES`
  - `UIBackgroundModes = [remote-notification]`
  - `TMDB_API_KEY = $(TMDB_API_KEY)` (Build Setting via xcconfig).

- Entitlements: `filmfreaks/filmfreaks.entitlements`
  - iCloud container: `iCloud.de.marcfechner.filmfreaks`
  - iCloud service: CloudKit
  - `aps-environment` (dev).

- Build Config
  - `filmfreaks/Debug.xcconfig` + `filmfreaks/Release.xcconfig` inkludieren `#include "Secrets.xcconfig"`.
  - `filmfreaks/Secrets.xcconfig` enthält `TMDB_API_KEY = ...` (**REDACTED** in dieser Doku; siehe Sicherheit unten).
  - `.gitignore` enthält `Secrets.xcconfig` (soll nicht versioniert werden).

- SPM Dependencies: **keine** `XCRemoteSwiftPackageReference` im `project.pbxproj` gefunden → keine externen Packages (Stand dieses ZIPs).

### Secrets Handling (wichtig, weil’s sonst irgendwann weh tut)

- Der TMDb Key ist client‑seitig ohnehin extrahierbar; trotzdem sollte er nicht im Repo landen.
- Empfehlung: `Secrets.xcconfig` nur lokal, plus `Secrets.sample.xcconfig` (ohne echten Key) für Onboarding neuer Devs.

## Conventions (Naming, Patterns, Do/Don’t)

- File Splits über `+`‑Files/Extensions sind Standard (z.B. `MovieStore+CloudSync.swift`, `StatsView+Cards.*.swift`).
- Stores sind oft `@MainActor` + `ObservableObject` + `@Published`.
- CloudKit Stores sind meist `struct`/`final class` ohne UI‑State; UI‑State sitzt im Store/Coordinator.
- Routing in `ContentView` läuft zentral über `ContentRoute` + `.sheet(item:)` (`filmfreaks/Content/ContentRouting.swift`).
- **Do**: teure Aggregationen off‑main (Beispiel: `StatsViewModel.update` nutzt `Task.detached`).
- **Don’t**: `.sorted/.filter` auf großen Arrays direkt im `body` (siehe Hotspots in Architecture Notes).

## How to work on this project (Setup + wo anfangen)

### Setup Checklist

- [ ] Xcode öffnen: `filmfreaks.xcodeproj`
- [ ] Signing/Team setzen (Target `filmfreaks`).
- [ ] iCloud Capability aktiv (CloudKit Container muss zur Team‑ID passen) — Datei: `filmfreaks/filmfreaks.entitlements`.
- [ ] Push Notifications / Background Modes aktiv (Remote Notifications).
- [ ] `Secrets.xcconfig` lokal anlegen (oder Wert über Env `TMDB_API_KEY` setzen).
- [ ] Auf echtem Gerät testen (CloudKit Sharing + Push sind im Simulator eingeschränkt/inkonsistent).

### Where to start (neue Devs)

1. `filmfreaks/filmfreaksApp.swift` (EnvironmentObjects, Refresh‑Trigger).
2. `filmfreaks/Content/ContentView.swift` + `Content/ContentRouting.swift` (Hauptnavigation).
3. `filmfreaks/MovieStore/MovieStore.swift` + `MovieStore+Persistence.swift` + `MovieStore+CloudSync.swift` (Datenhaltung + Sync).
4. `filmfreaks/CloudKitRouting.swift` + `GroupContext.swift` (DB/Zone Routing).
5. `filmfreaks/TMDbAPI/TMDbAPI.swift` (External API Boundary).

## Quick Wins (max. 10, konkret, umsetzbar)

1) **Push Fetch in Release aktivieren oder klar abschalten**: `filmfreaks/CloudKit/CloudKitActivityPushFetchCoordinator.swift` ist aktuell `#if DEBUG`‑only → definieren, ob Production‑Feature oder Debug‑Tool.
2) **Cancellable TMDb Tasks** (Search + Actor Sheet): Task‑Refs halten und bei neuem Request canceln (`MovieSearchView+Search.swift`, `StatsView+Actors.swift`).
3) **ProposeMovieNightSheet: backlog sort/filter aus dem Renderpfad ziehen** (siehe Hotspots; `filmfreaks/MovieNights/Sheets/ProposeMovieNightSheet.swift`).
4) **MovieStore enqueueCloudSync off‑main vorbereiten**: Diff‑Berechnung nicht im didSet/MainActor (siehe `MovieStore+CloudSync.swift`).
5) **Logging vereinheitlichen**: statt `print(...)` in CloudKit‑Pipelines → `os.Logger` Kategorien (z.B. `CloudKit`, `Sync`, `Push`).
6) **Secrets.sample.xcconfig hinzufügen** (ohne Key) + kurzer Setup‑Hinweis in README/PROJECT_CONTEXT (Onboarding).
7) **GroupContextStore Beobachtung zentralisieren**: mehrere Stores hören auf Notifications/Combine; ggf. gemeinsamer Helper für „GroupContext wurde verfügbar“‑Retry.
8) **„server wins“ Merge dokumentieren + testen**: `CloudKitMovieStore+Merge.swift` (Konfliktauflösung) mit Tests/Fixtures absichern.
9) **Preview data entkoppeln**: Sample Users/Movies aus produktivem Code in `PreviewData/` verschieben (kleiner Clean‑up).
10) **Static analysis**: Script/CI Step für „Top Big Files + Hotspots“ (line count + grep) um Regressionen sichtbar zu machen.

## Open Questions (aus diesem Scan)

- **UNKNOWN**: Gibt es ein separates Backend/Service für TMDb‑Key Rotation/Rate‑Limit Mitigation (oder ist Client‑Key die einzige Quelle)?
- **UNKNOWN**: CloudKit Dashboard Indizes / Query‑Performance (Record Types oben sind aus Code, nicht aus Dashboard).

### Typische Workflows (wo in den Code greifen)

#### 1) Einen Film hinzufügen (Watched/Backlog)
- Einstieg: `ContentRoute.movieSearch` → `MovieSearchView` (`filmfreaks/Content/ContentRouting.swift`).
- Add‑Callback enrich’t Group‑Meta + Activity‑Meta und mutiert Store‑Arrays:
  - `addMovieToWatched(_:)` / `addMovieToBacklog(_:)` in `filmfreaks/Content/ContentRouting.swift`.
- Persistenz + Sync passieren automatisch über didSet:
  - Disk: `PersistenceManager.saveMovies/saveBacklogMovies` (`filmfreaks/MovieStore/MovieStore+Persistence.swift`).
  - Cloud: `enqueueCloudSync(...)` → `MovieCloudSyncCoordinator.queueSave` (`filmfreaks/MovieStore/MovieStore+CloudSync.swift`, `filmfreaks/MovieCloudSyncCoordinator.swift`).

#### 2) Rating/Fazit bearbeiten
- UI: `MovieRatingsSheetView` (siehe `filmfreaks/MovieDetail/*` + `MovieRatingsSheetView.swift`).
- Model: `Movie.ratings: [Rating]` (`filmfreaks/Movie.swift`).
- Cloud: Ratings sind eigene Records (`MovieRating`), nicht im Movie‑Payload.
  - Write/Query: `filmfreaks/CloudKitRatingStore/*`.
- Wichtiger Guard: Rating‑Only Edits sollen keine Movie‑Diffs triggern (`isApplyingRatingUpdate` in `MovieStore`; siehe `filmfreaks/MovieStore/MovieStore.swift` + `MovieStore+Persistence.swift`).

#### 3) Gruppe erstellen / teilen / beitreten
- Owned/shared Gruppenliste + Refresh: `filmfreaks/CloudKitGroupStore/CloudKitGroupStore.swift`.
- Sharing UI: `GroupShareSheetView.swift`, `CloudSharingControllerView.swift`.
- Share Acceptance: `CloudKitShareAppDelegate` + `CloudKitShareSceneDelegate` → `CloudKitShareCoordinator.accept(...)`.
- Routing‑Meta (Zone/Scope) wird als `GroupContext` persistiert (`filmfreaks/GroupContext.swift`).

#### 4) Stats aktualisieren
- Trigger: `.onAppear` + `.onChange` in `filmfreaks/Stats/StatsView.swift` ruft `StatsViewModel.update(...)` auf.
- Compute: `StatsViewModel` debounced + `Task.detached` → `StatsSnapshotBuilder.computeSnapshot(...)`.
- Actor‑Popularity: `PersonPopularityStore.preloadPopularity` vor Publish (damit Sorting stabil ist).

#### 5) Neue CloudKit Record Type / Feld hinzufügen
- CloudKit Stores enthalten die Schema‑Keys (z.B. `CloudKitMovieStore.swift` keys).
- Änderungen müssen in folgenden Schichten konsistent sein:
  - Record encode/decode (`CloudKit…Store+Schema.swift`)
  - Modify/Save (`CloudKit…Store+Modify.swift`)
  - ZoneChanges/Fetch (`CloudKit…Store+ZoneChanges.swift`)
  - Merge/Conflict Policy (falls relevant; z.B. `CloudKitMovieStore+Merge.swift`).

### Debugging‑Einstiegspunkte
- Local persistence: `filmfreaks/PersistenceManager.swift` (Logger Kategorie `Persistence`).
- CloudKit routing failures: `CloudKitRoutingError.groupContextNotReady` (`filmfreaks/CloudKitRouting.swift`).
- Push payload logging: `filmfreaks/CloudKit/CloudKitRemoteNotificationDebugger.swift` (DEBUG).

## Nicht gefunden (bewusst, damit man nicht sucht bis man alt wird)
- **SwiftData/CoreData**: keine `import SwiftData` / `@Model` / `CoreData` Verwendungen im Code‑Scan (Stand dieses ZIPs).
