//
//  OnboardingProgress.swift
//  filmfreaks
//
//  Created by Marc Fechner on 27.12.25.
//

import Foundation

enum OnboardingProgress {

    // MARK: - Keys

    private static let hasSeenQuickStartKey = "Onboarding_HasSeenQuickStart"

    private static func groupNamespace(_ groupId: String?) -> String {
        let gid = (groupId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        ? groupId!
        : "Default"
        return "Onboarding_\(gid)"
    }

    private static func key(_ suffix: String, groupId: String?) -> String {
        "\(groupNamespace(groupId))_\(suffix)"
    }

    // MARK: - Global

    static func getHasSeenQuickStart() -> Bool {
        UserDefaults.standard.bool(forKey: hasSeenQuickStartKey)
    }

    static func setHasSeenQuickStart(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: hasSeenQuickStartKey)
    }

    // MARK: - Per Group: Completion

    static func isGroupOnboardingComplete(forGroupId groupId: String?) -> Bool {
        UserDefaults.standard.bool(forKey: key("complete", groupId: groupId))
    }

    static func setGroupOnboardingComplete(_ value: Bool, forGroupId groupId: String?) {
        UserDefaults.standard.set(value, forKey: key("complete", groupId: groupId))
    }

    // MARK: - Per Group: Counters

    static func incrementSearchOpenCount(forGroupId groupId: String?) {
        let k = key("searchOpenCount", groupId: groupId)
        let current = UserDefaults.standard.integer(forKey: k)
        UserDefaults.standard.set(current + 1, forKey: k)
    }

    static func incrementDetailOpenCount(forGroupId groupId: String?) {
        let k = key("detailOpenCount", groupId: groupId)
        let current = UserDefaults.standard.integer(forKey: k)
        UserDefaults.standard.set(current + 1, forKey: k)
    }

    static func getSearchOpenCount(forGroupId groupId: String?) -> Int {
        UserDefaults.standard.integer(forKey: key("searchOpenCount", groupId: groupId))
    }

    static func getDetailOpenCount(forGroupId groupId: String?) -> Int {
        UserDefaults.standard.integer(forKey: key("detailOpenCount", groupId: groupId))
    }
}
