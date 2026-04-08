import Foundation

struct GroupSettingsPresentation {
    static func activeGroupBadgeText(currentGroupId: String?, activeContext: GroupContext?) -> String {
        if currentGroupId == nil {
            return "Lokal"
        }
        if let activeContext {
            return activeContext.isShared ? "Shared" : "Owned"
        }
        return "Cloud"
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
