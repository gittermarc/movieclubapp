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
            countText(memberCount, singular: "Mitglied", plural: "Mitglieder"),
            countText(watchedCount, singular: "Film", plural: "Filme"),
            "\(backlogCount) im Backlog"
        ]
        .joined(separator: " • ")
    }

    static func emptyCloudGroupsMessage() -> String {
        "Noch keine Cloud-Gruppen. Erstell eine eigene Gruppe oder tritt per iCloud-Einladung einer bestehenden Gruppe bei."
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
