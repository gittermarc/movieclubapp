//
//  CustomGoalEditorSection.Keyword.swift
//  filmfreaks
//

internal import SwiftUI

struct CustomGoalKeywordSection: View {

    @Binding var keywordQuery: String
    @Binding var isSearchingKeyword: Bool
    @Binding var keywordResults: [TMDbKeywordSummary]
    @Binding var selectedKeywordId: Int
    @Binding var selectedKeywordName: String

    let onQueryChanged: (String) -> Void

    var body: some View {
        Section("Keyword") {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Keyword suchen …", text: $keywordQuery)
                    .textInputAutocapitalization(.never)
                    .onChange(of: keywordQuery) { _, newValue in
                        onQueryChanged(newValue)
                    }

                if selectedKeywordId > 0 {
                    HStack {
                        Text(selectedKeywordName)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Button(role: .destructive) {
                            selectedKeywordId = 0
                            selectedKeywordName = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }

                if isSearchingKeyword {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Suche …").font(.caption).foregroundStyle(.secondary)
                    }
                }

                if !keywordResults.isEmpty {
                    // Use `enumerated()` as identity to avoid any weirdness if TMDb ever returns duplicates.
                    ForEach(Array(keywordResults.enumerated()), id: \.offset) { _, k in
                        Button {
                            selectedKeywordId = k.id
                            selectedKeywordName = k.name
                            keywordQuery = ""
                            keywordResults = []
                        } label: {
                            HStack {
                                Text(k.name)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } else if !keywordQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isSearchingKeyword {
                    Text("Keine Treffer.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
