//
//  MovieDetailWatchedSectionView.swift
//  filmfreaks
//
//  Extracted from MovieDetailView.swift.
//

internal import SwiftUI

struct MovieDetailWatchedSectionView: View {
    let isBacklog: Bool
    @Binding var localWatchedDate: Date
    @Binding var localWatchedLocation: String
    @Binding var localSuggestedBy: String

    let locationOptions: [String]
    let suggestedByOptions: [String]
    let onMarkAsWatched: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            if isBacklog {
                Text("Dieser Film ist noch im Backlog.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    onMarkAsWatched()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Als gesehen markieren")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else {
                DatePicker(
                    "Gesehen am",
                    selection: $localWatchedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
            }

            // Ort
            HStack {
                Text("Ort")
                    .font(.subheadline.weight(.semibold))
                Spacer()

                Menu {
                    Button {
                        localWatchedLocation = ""
                    } label: {
                        Label(
                            "Ohne Angabe",
                            systemImage: localWatchedLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "checkmark" : ""
                        )
                    }

                    Divider()

                    ForEach(locationOptions, id: \.self) { loc in
                        Button {
                            localWatchedLocation = loc
                        } label: {
                            Label(loc, systemImage: localWatchedLocation == loc ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(localWatchedLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Ohne Angabe" : localWatchedLocation)
                            .font(.caption)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.12))
                    .clipShape(Capsule())
                }
            }

            // Vorgeschlagen von
            HStack {
                Text("Vorgeschlagen von")
                    .font(.subheadline.weight(.semibold))
                Spacer()

                Menu {
                    Button {
                        localSuggestedBy = ""
                    } label: {
                        Label(
                            "Ohne Angabe",
                            systemImage: localSuggestedBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "checkmark" : ""
                        )
                    }

                    Divider()

                    ForEach(suggestedByOptions, id: \.self) { name in
                        Button {
                            localSuggestedBy = name
                        } label: {
                            Label(name, systemImage: localSuggestedBy == name ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(localSuggestedBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Ohne Angabe" : localSuggestedBy)
                            .font(.caption)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.12))
                    .clipShape(Capsule())
                }
            }
        }
    }
}
