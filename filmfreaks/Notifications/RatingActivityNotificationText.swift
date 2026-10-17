import Foundation

/// Reuses the existing fazit-first notification policy without inventing a score.
nonisolated enum RatingActivityNotificationText {
    static func body(for rating: Rating) -> String {
        let actor = rating.reviewerName
        guard let value = RatingCalculation.value(for: rating, displayMode: .fazitAverage) else {
            return "\(actor) hat eine Bewertung abgegeben."
        }
        let score = Int(value.rounded())
        return "\(actor) hat eine Bewertung abgegeben (\(score)/10)."
    }
}
