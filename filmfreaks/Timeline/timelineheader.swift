//
//  timelineheader.swift
//  filmfreaks
//

internal import SwiftUI

struct TimelineHeaderView: View {

    let groupName: String?

    @Binding var filterMode: TimelineFilterMode
    @Binding var selectedRange: TimelineTimeRange
    @Binding var selectedYear: Int

    let availableYears: [Int]
    let movieCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            if let groupName, !groupName.isEmpty {
                Text("Für „\(groupName)“")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Für deine aktuelle Gruppe")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Ansicht")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Ansicht", selection: $filterMode) {
                    ForEach(TimelineFilterMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if filterMode == .year {
                    Text("Jahr")
                        .font(.subheadline)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(availableYears, id: \.self) { year in
                                let isSelected = year == selectedYear
                                Button {
                                    selectedYear = year
                                } label: {
                                    Text(String(year))
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 999)
                                                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 999)
                                                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1)
                                        )
                                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    Text("Zeitraum")
                        .font(.subheadline)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(TimelineTimeRange.allCases) { range in
                                let isSelected = range == selectedRange
                                Button {
                                    selectedRange = range
                                } label: {
                                    Text(range.rawValue)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 999)
                                                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 999)
                                                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1)
                                        )
                                        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Text("\(movieCount) Filme")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
}
