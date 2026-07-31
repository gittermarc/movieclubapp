//
//  MemberAvatarResolver.swift
//  filmfreaks
//
//  Resolves stored rating and activity identities back to current members.
//

import Foundation

enum MemberAvatarResolver {

    static func member(
        memberId: UUID?,
        name: String?,
        in members: [User]
    ) -> User? {
        if let memberId,
           let exactMatch = members.first(where: { $0.id == memberId }) {
            return exactMatch
        }

        let normalizedName = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedName.isEmpty == false else { return nil }

        let matches = members.filter {
            $0.name.caseInsensitiveCompare(normalizedName) == .orderedSame
        }
        return matches.count == 1 ? matches.first : nil
    }

    static func member(for rating: Rating, in members: [User]) -> User? {
        member(memberId: rating.reviewerId, name: rating.reviewerName, in: members)
    }
}
