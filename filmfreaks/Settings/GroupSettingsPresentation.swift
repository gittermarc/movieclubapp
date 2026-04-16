import Foundation

struct GroupSettingsPresentation {
    static func activeGroupBadgeText(currentGroupId: String?, activeContext: GroupContext?) -> String {
        if currentGroupId == nil {
            return "Lokal"
        }
        if let activeContext {
            return groupKindText(for: activeContext)
        }
        return "Cloud"
    }

    static func groupKindText(for group: GroupContext) -> String {
        group.isShared ? "Geteilte Gruppe" : "Eigene Gruppe"
    }

    static func activeGroupDescription(currentGroupId: String?, activeContext: GroupContext?) -> String {
        if currentGroupId == nil {
            return "Diese Gruppe bleibt lokal auf diesem Gerät und wird nicht per iCloud geteilt."
        }
        guard let activeContext else {
            return "Die Gruppe wird gerade aus iCloud-Kontextdaten geladen."
        }
        return groupDetailText(for: activeContext)
    }

    static func groupDetailText(for group: GroupContext) -> String {
        if group.isShared {
            return "Du bist über eine iCloud-Einladung Teil dieser Gruppe."
        }
        return "Du verwaltest diese Gruppe selbst und kannst sie direkt per iCloud teilen."
    }

    static func localGroupTitle() -> String {
        "Nur auf diesem Gerät"
    }

    static func localGroupDetailText() -> String {
        "Lokale Standardgruppe ohne iCloud-Freigabe – gut für privat, schnell und offline."
    }

    static func activeGroupSummary(memberCount: Int, watchedCount: Int, backlogCount: Int) -> String {
        [
            memberCountText(memberCount),
            countText(watchedCount, singular: "Film", plural: "Filme"),
            "\(backlogCount) im Backlog"
        ]
        .joined(separator: " • ")
    }

    static func memberCountText(_ count: Int) -> String {
        countText(count, singular: "Mitglied", plural: "Mitglieder")
    }

    static func recentActivityText(for event: UnifiedGroupActivityEvent, now: Date = .now) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated

        let relativeText = formatter.localizedString(for: event.date, relativeTo: now)
        return "Zuletzt aktiv \(relativeText) · \(activitySummaryText(for: event))"
    }

    static func activitySummaryText(for event: UnifiedGroupActivityEvent) -> String {
        switch event.payload {
        case .movie(let movieEvent):
            let actor = normalizedActorName(movieEvent.actorName)
            switch movieEvent.kind {
            case .movieAdded:
                return "\(actor) hat \(movieEvent.movieTitle) hinzugefügt"
            case .movieRated:
                return "\(actor) hat \(movieEvent.movieTitle) bewertet"
            }

        case .movieNight(let movieNightEvent):
            let actor = normalizedActorName(movieNightEvent.actorName)
            switch movieNightEvent.kind {
            case .proposed:
                return "\(actor) hat einen Filmabend vorgeschlagen"
            case .responded:
                switch movieNightEvent.decision {
                case .accepted:
                    return "\(actor) hat für den Filmabend zugesagt"
                case .declined:
                    return "\(actor) hat für den Filmabend abgesagt"
                case .pending, .none:
                    return "\(actor) hat auf den Filmabend reagiert"
                }
            case .statusChanged:
                if movieNightEvent.newStatus == .scheduled {
                    return "\(actor) hat den Filmabend geplant"
                }
                if movieNightEvent.newStatus == .cancelled {
                    return "\(actor) hat den Filmabend abgesagt"
                }
                return "\(actor) hat den Filmabend aktualisiert"
            case .deleted:
                return "\(actor) hat einen Filmabend-Vorschlag gelöscht"
            }
        }
    }

    static func emptyCloudGroupsMessage() -> String {
        "Noch keine Cloud-Gruppen. Erstell eine eigene Gruppe oder tritt per iCloud-Einladung einer bestehenden Gruppe bei."
    }

    private static func normalizedActorName(_ value: String?) -> String {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Jemand" : trimmed
    }

    private static func countText(_ count: Int, singular: String, plural: String) -> String {
        "\(count) \(count == 1 ? singular : plural)"
    }
}

enum GroupSettingsActionKind: String {
    case deleteOwned
    case leaveShared
}

struct GroupSettingsPendingAction: Identifiable {
    let kind: GroupSettingsActionKind
    let group: GroupContext

    var id: String {
        "\(kind.rawValue)-\(group.id)"
    }

    var title: String {
        switch kind {
        case .deleteOwned:
            return "Gruppe löschen?"
        case .leaveShared:
            return "Gruppe verlassen?"
        }
    }

    var message: String {
        switch kind {
        case .deleteOwned:
            return "„\(group.name)“ wird endgültig gelöscht (Cloud + lokaler Cache). Das kann nicht rückgängig gemacht werden."
        case .leaveShared:
            return "Du verlässt „\(group.name)“. Du kannst später nur per Einladung wieder beitreten."
        }
    }
}
