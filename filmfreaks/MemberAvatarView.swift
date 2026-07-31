//
//  MemberAvatarView.swift
//  filmfreaks
//
//  Reusable image-or-initials avatar for a group member.
//

internal import SwiftUI
internal import UIKit

enum MemberAvatarInitials {
    static func text(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(whereSeparator: { $0.isWhitespace })

        if words.count >= 2 {
            let first = words.first?.prefix(1) ?? "?"
            let last = words.last?.prefix(1) ?? "?"
            return String(first + last).uppercased()
        }

        guard trimmed.isEmpty == false else { return "?" }
        return String(trimmed.prefix(2)).uppercased()
    }
}

struct MemberAvatarView: View {

    let member: User?
    let fallbackName: String
    let groupId: String?
    let size: CGFloat
    let tintColor: Color

    @State private var avatarImage: UIImage?

    init(
        member: User?,
        fallbackName: String? = nil,
        groupId: String?,
        size: CGFloat,
        tintColor: Color = .accentColor
    ) {
        self.member = member
        self.fallbackName = fallbackName ?? member?.name ?? ""
        self.groupId = groupId
        self.size = size
        self.tintColor = tintColor
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tintColor.opacity(0.14))

            if let avatarImage {
                Image(uiImage: avatarImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(MemberAvatarInitials.text(for: fallbackName))
                    .font(.system(size: max(10, size * 0.34), weight: .bold, design: .rounded))
                    .foregroundStyle(tintColor)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .accessibilityLabel(accessibilityLabel)
        .task(id: avatarIdentity) {
            loadAvatarImage()
        }
    }

    private var avatarIdentity: String {
        let groupKey = GroupScopedStorage.selectedUserGroupKey(for: groupId)
        let memberKey = member?.id.uuidString.lowercased() ?? "anonymous"
        return groupKey + "|" + memberKey + "|" + (member?.avatarVersion ?? "none")
    }

    private var accessibilityLabel: String {
        let name = fallbackName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Mitglied" : name
    }

    @MainActor
    private func loadAvatarImage() {
        guard let member,
              member.avatarVersion != nil,
              let data = MemberAvatarStorage.shared.avatarData(memberId: member.id, groupId: groupId),
              let image = UIImage(data: data) else {
            avatarImage = nil
            return
        }

        avatarImage = image
    }
}
