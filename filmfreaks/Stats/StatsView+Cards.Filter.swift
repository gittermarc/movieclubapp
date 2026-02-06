//
//  StatsView+Cards.Filter.swift
//  filmfreaks
//
//  Filter card for StatsView.
//

internal import SwiftUI

extension StatsView {

    var filterCard: some View {
        StatsDashboardCard(title: "Filter", systemImage: "line.3.horizontal.decrease.circle") {
            VStack(alignment: .leading, spacing: 12) {

                if let groupName = movieStore.currentGroupName {
                    Text("Statistiken für „\(groupName)“")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Statistiken für deine aktuelle Gruppe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Zeitraum")
                        .font(.subheadline.weight(.semibold))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(StatsTimeRange.allCases) { range in
                                let isSelected = (range == selectedRange)

                                Button { selectedRange = range } label: {
                                    Text(range.rawValue)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(
                                            RoundedRectangle(cornerRadius: 999)
                                                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.gray.opacity(0.12))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 999)
                                                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                                        )
                                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                HStack {
                    Text("Ort")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)

                    Menu {
                        Button {
                            selectedLocationFilter = nil
                        } label: {
                            Label("Alle Orte", systemImage: selectedLocationFilter == nil ? "checkmark" : "")
                        }

                        Divider()

                        ForEach(availableLocations, id: \.self) { loc in
                            Button {
                                selectedLocationFilter = loc
                            } label: {
                                Label(loc, systemImage: selectedLocationFilter == loc ? "checkmark" : "")
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(selectedLocationFilter ?? "Alle Orte")
                                .font(.caption)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }
}
