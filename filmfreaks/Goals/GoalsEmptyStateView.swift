//
//  GoalsEmptyStateView.swift
//  filmfreaks
//
//  Extracted empty state used in custom goals section.
//

internal import SwiftUI

struct GoalsEmptyStateView: View {

    let selectedYear: Int
    let otherYearsCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: "In \(selectedYear) sind noch keine Custom Goals angelegt.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if otherYearsCount > 0 {
                Text("Du hast \(otherYearsCount) Ziel(e) in anderen Jahren – die siehst du, wenn du oben das Jahr wechselst.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Beispiele: „10 Filme aus den 50ern“, „15 Filme von Nolan“, „8 Filme mit time travel“.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
