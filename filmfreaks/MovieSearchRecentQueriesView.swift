//
//  MovieSearchRecentQueriesView.swift
//  filmfreaks
//

internal import SwiftUI

struct MovieSearchRecentQueriesView: View {

    let recentQueries: [String]
    let onTap: (String) -> Void
    let onClearHistory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Zuletzt gesucht")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !recentQueries.isEmpty {
                    Button(action: onClearHistory) {
                        Text("Verlauf löschen")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recentQueries, id: \.self) { term in
                        Button {
                            onTap(term)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption2)
                                Text(term)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 2)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 4)
    }
}
