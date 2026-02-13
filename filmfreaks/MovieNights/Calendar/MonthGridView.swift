//
//  MonthGridView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

internal import SwiftUI

/// Month grid with weekday headers and tappable day cells.
struct MonthGridView: View {

    let monthAnchor: Date
    @Binding var selectedDay: Date
    let events: [MovieNightEvent]

    @EnvironmentObject private var displaySettings: DisplaySettings

    private var m: DisplaySettings.LayoutMetrics { displaySettings.metrics }

    private var weekdaySymbols: [String] {
        let cal = Calendar.current
        let symbols = cal.shortWeekdaySymbols
        let firstWeekdayIndex = cal.firstWeekday - 1
        let first = Array(symbols[firstWeekdayIndex...])
        let second = Array(symbols[..<firstWeekdayIndex])
        return first + second
    }

    private var dayItems: [DayItem] {
        MonthGridBuilder(calendar: .current).buildMonth(for: monthAnchor)
    }

    private var eventsByDayCount: [Date: Int] {
        let calendar = Calendar.current
        return Dictionary(grouping: events, by: { calendar.startOfDay(for: $0.proposedStart) })
            .mapValues { $0.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            weekdayHeader

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(dayItems) { item in
                    if let date = item.date {
                        dayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 40)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .padding(m.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func dayCell(for date: Date) -> some View {
        let calendar = Calendar.current
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(date)
        let count = eventsByDayCount[calendar.startOfDay(for: date)] ?? 0

        Button {
            selectedDay = calendar.startOfDay(for: date)
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.subheadline.weight(isSelected ? .bold : .semibold))
                    .frame(maxWidth: .infinity)

                if count > 0 {
                    HStack(spacing: 3) {
                        ForEach(0..<min(count, 3), id: \.self) { _ in
                            Circle()
                                .frame(width: 4, height: 4)
                        }
                        if count > 3 {
                            Text("+")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(isSelected ? Color.white.opacity(0.95) : displaySettings.tintColor)
                } else {
                    Color.clear.frame(height: 6)
                }
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .background(backgroundForDayCell(isSelected: isSelected, isToday: isToday))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: date, count: count))
        .accessibilityHint("Tippe, um die Filmabende für diesen Tag zu sehen.")
    }

    @ViewBuilder
    private func backgroundForDayCell(isSelected: Bool, isToday: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(displaySettings.tintColor)
        } else if isToday {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(displaySettings.tintColor.opacity(0.14))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        }
    }

    private func accessibilityLabel(for date: Date, count: Int) -> String {
        let label = Self.dayAccessibilityFormatter.string(from: date)
        if count == 0 { return "\(label), keine Filmabende" }
        if count == 1 { return "\(label), 1 Filmabend" }
        return "\(label), \(count) Filmabende"
    }

    private static let dayAccessibilityFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .current
        df.dateStyle = .full
        df.timeStyle = .none
        return df
    }()
}

// MARK: - Month grid builder

private struct DayItem: Identifiable {
    let id = UUID()
    let date: Date?
}

private struct MonthGridBuilder {
    let calendar: Calendar

    func buildMonth(for anyDateInMonth: Date) -> [DayItem] {
        let startOfMonth = calendar.startOfMonth(for: anyDateInMonth)
        guard let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingEmpty = ((firstWeekday - calendar.firstWeekday) + 7) % 7

        var items: [DayItem] = []
        items.reserveCapacity(leadingEmpty + range.count)

        for _ in 0..<leadingEmpty {
            items.append(DayItem(date: nil))
        }

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                items.append(DayItem(date: date))
            }
        }

        // Fill trailing blanks to complete weeks (nice for stable grid height)
        let remainder = items.count % 7
        if remainder != 0 {
            for _ in 0..<(7 - remainder) {
                items.append(DayItem(date: nil))
            }
        }

        return items
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
