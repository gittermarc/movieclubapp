//
//  MovieDetailView+Ratings.swift
//  filmfreaks
//
//  Created by Marc Fechner on 06.02.26.
//

internal import SwiftUI

extension MovieDetailView {

    // MARK: - Rating Helpers

    func normalizedScoresFromLocal() -> [RatingCriterion: Int] {
        var scores: [RatingCriterion: Int] = [:]
        for criterion in RatingCriterion.allCases {
            scores[criterion] = localScores[criterion] ?? 0
        }
        return scores
    }

    func normalizedCommentFromLocal() -> String? {
        let trimmedComment = localComment.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedComment.isEmpty ? nil : trimmedComment
    }

    func isAllDefault(scores: [RatingCriterion: Int], comment: String?, fazit: Int?) -> Bool {
        let allZero = RatingCriterion.allCases.allSatisfy { (scores[$0] ?? 0) == 0 }
        return allZero && comment == nil && fazit == nil
    }

    func saveRating() {
        guard let selectedUser = userStore.selectedUser else { return }

        let scores = normalizedScoresFromLocal()
        let finalComment = normalizedCommentFromLocal()
        let fazit = localFazitScore
        let name = selectedUser.name

        let existingIndex = movie.ratings.firstIndex(where: { r in
            if let rid = r.reviewerId { return rid == selectedUser.id }
            return r.reviewerName.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        })
        let existingRating: Rating? = existingIndex.map { movie.ratings[$0] }

        if existingRating == nil, isAllDefault(scores: scores, comment: finalComment, fazit: fazit) {
            hasPendingRatingChanges = false
            hapticWarning()
            presentSaveToast("Keine Änderungen zum Speichern festgestellt")
            return
        }

        var newRating = Rating(
            reviewerId: selectedUser.id,
            reviewerName: name,
            scores: scores,
            comment: finalComment,
            fazitScore: fazit
        )

        if let index = existingIndex {
            let old = movie.ratings[index]
            newRating.id = old.id

            let oldComment = (old.comment ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let newComment = (newRating.comment ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            let noScoreChanges = old.scores == newRating.scores
            let noCommentChanges = oldComment == newComment
            let noFazitChanges = old.fazitScore == newRating.fazitScore

            if noScoreChanges && noCommentChanges && noFazitChanges {
                hasPendingRatingChanges = false
                hapticWarning()
                presentSaveToast("Keine Änderungen zum Speichern festgestellt")
                return
            }
        }

        Task {
            let ok = await movieStore.upsertRating(for: movie.id, rating: newRating)

            hasPendingRatingChanges = false

            if ok {
                hapticSuccess()
                presentSaveToast("Bewertung gespeichert")
            } else {
                hapticWarning()
                presentSaveToast("Bewertung gespeichert – iCloud Sync fehlgeschlagen")
            }
        }
    }

    func loadExistingRatingForSelectedUser() {
        guard let selectedUser = userStore.selectedUser else {
            localScores = [:]
            localComment = ""
            localFazitScore = nil
            hasPendingRatingChanges = false
            return
        }

        if let rating = movie.ratings.first(where: { r in
            if let rid = r.reviewerId { return rid == selectedUser.id }
            return r.reviewerName.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(selectedUser.name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        }) {
            var scores: [RatingCriterion: Int] = [:]
            for criterion in RatingCriterion.allCases {
                scores[criterion] = rating.scores[criterion] ?? 0
            }
            localScores = scores
            localComment = rating.comment ?? ""
            localFazitScore = rating.fazitScore
        } else {
            var scores: [RatingCriterion: Int] = [:]
            for criterion in RatingCriterion.allCases {
                scores[criterion] = 0
            }
            localScores = scores
            localComment = ""
            localFazitScore = nil
        }

        hasPendingRatingChanges = false
    }
}
