//
//  MovieNightCalendarView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 13.02.26.
//

internal import SwiftUI

/// P1: Read-only calendar UI for Movie Nights (local data only).
/// P2: Adds propose + detail sheets (still local).
struct MovieNightCalendarView: View {

    @EnvironmentObject private var movieStore: MovieStore
    @EnvironmentObject private var movieNightStore: MovieNightStore
    @EnvironmentObject private var userStore: UserStore
    @EnvironmentObject private var displaySettings: DisplaySettings

    @State private var monthAnchor: Date = Calendar.current.startOfMonth(for: .now)
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: .now)

    @State private var isProposeSheetPresented: Bool = false
    @State private var selectedEvent: SelectedEvent? = nil

    private var m: DisplaySettings.LayoutMetrics { displaySettings.metrics }

    private var groupId: String {
        (movieStore.currentGroupId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var groupName: String {
        let raw = (movieStore.currentGroupName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? "Gruppe" : raw
    }

    private var monthTitle: String {
        Self.monthTitleFormatter.string(from: monthAnchor)
    }

    private var eventsInMonth: [MovieNightEvent] {
        let calendar = Calendar.current
        let start = calendar.startOfMonth(for: monthAnchor)
        let end = calendar.date(byAdding: DateComponents(month: 1), to: start) ?? start

        return movieNightStore
            .events(for: groupId)
            .filter { $0.proposedStart >= start && $0.proposedStart < end && $0.status != .cancelled }
    }

    private var eventsForSelectedDay: [MovieNightEvent] {
        let calendar = Calendar.current
        return eventsInMonth
            .filter { calendar.isDate($0.proposedStart, inSameDayAs: selectedDay) }
            .sorted(by: { $0.proposedStart < $1.proposedStart })
    }

    private var defaultProposedStart: Date {
        Calendar.current.defaultMovieNightStart(for: selectedDay)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    headerCard

                    MonthGridView(
                        monthAnchor: monthAnchor,
                        selectedDay: $selectedDay,
                        events: eventsInMonth
                    )

                    DayEventListView(
                        day: selectedDay,
                        groupId: groupId,
                        events: eventsForSelectedDay,
                        onSelectEvent: { event in
                            selectedEvent = SelectedEvent(id: event.id)
                        }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Kalender")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: groupId) {
                await movieNightStore.refreshFromCloud(groupId: groupId, force: false)
            }
            .onChange(of: monthAnchor) { _, newValue in
                let cal = Calendar.current
                if !cal.isDate(selectedDay, equalTo: newValue, toGranularity: .month) {
                    selectedDay = cal.startOfDay(for: cal.startOfMonth(for: newValue))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        selectedDay = Calendar.current.startOfDay(for: .now)
                        monthAnchor = Calendar.current.startOfMonth(for: .now)
                    } label: {
                        Text("Heute")
                    }
                    .disabled(
                        Calendar.current.isDate(selectedDay, inSameDayAs: .now) &&
                        Calendar.current.isDate(monthAnchor, equalTo: .now, toGranularity: .month)
                    )
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isProposeSheetPresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Filmabend vorschlagen")
                    .disabled(userStore.selectedUser == nil)

                    Button {
                        monthAnchor = Calendar.current.date(byAdding: .month, value: -1, to: monthAnchor) ?? monthAnchor
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Vorheriger Monat")

                    Button {
                        monthAnchor = Calendar.current.date(byAdding: .month, value: 1, to: monthAnchor) ?? monthAnchor
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .accessibilityLabel("Nächster Monat")
                }
            }
        }
        .sheet(isPresented: $isProposeSheetPresented) {
            ProposeMovieNightSheet(groupId: groupId, initialDate: defaultProposedStart)
                .environmentObject(movieNightStore)
                .environmentObject(userStore)
                .environmentObject(displaySettings)
        }
        .sheet(item: $selectedEvent) { selection in
            MovieNightDetailSheet(groupId: groupId, eventId: selection.id)
                .environmentObject(movieNightStore)
                .environmentObject(userStore)
                .environmentObject(displaySettings)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(monthTitle)
                        .font(.title3.weight(.semibold))
                    Text(groupName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 10)

                statusPill
            }

            if !movieNightStore.isLoaded {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Kalenderdaten werden geladen …")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            } else if eventsInMonth.isEmpty {
                Text("In diesem Monat sind noch keine Filmabende geplant.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            } else {
                Text("Tippe auf einen Eintrag, um zuzusagen oder abzusagen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
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

    private var statusPill: some View {
        let upcoming = movieNightStore.upcomingEvents(for: groupId).count
        return HStack(spacing: 6) {
            Image(systemName: "calendar")
                .symbolRenderingMode(.hierarchical)
            Text(upcoming == 1 ? "1 geplant" : "\(upcoming) geplant")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .circular)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule(style: .circular)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .foregroundStyle(.secondary)
    }

    private static let monthTitleFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return df
    }()

    private struct SelectedEvent: Identifiable {
        let id: UUID
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }

    func defaultMovieNightStart(for day: Date) -> Date {
        let base = startOfDay(for: day)
        if let candidate = date(bySettingHour: 20, minute: 0, second: 0, of: base) {
            return candidate
        }
        return day
    }
}

#Preview {
    MovieNightCalendarView()
        .environmentObject(MovieStore.preview())
        .environmentObject(MovieNightStore())
        .environmentObject(UserStore())
        .environmentObject(DisplaySettings())
}
