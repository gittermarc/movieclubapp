//
//  MovieNightCalendarContentView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 15.04.26.
//

import Foundation
internal import SwiftUI

/// Embeddable calendar content for Movie Nights.
///
/// Kept separate from the standalone screen wrapper so the planning hub can
/// host the existing calendar behavior without taking over calendar-specific
/// state, sheets or actions.
struct MovieNightCalendarContentView: View {

    @EnvironmentObject private var movieStore: MovieStore
    @EnvironmentObject private var movieNightStore: MovieNightStore
    @EnvironmentObject private var userStore: UserStore
    @EnvironmentObject private var groupStore: CloudKitGroupStore
    @EnvironmentObject private var displaySettings: DisplaySettings

    @State private var monthAnchor: Date = Calendar.current.startOfMonth(for: .now)
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: .now)
    @State private var snapshot = MovieNightCalendarSnapshot()

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

    private var requiresGroupContext: Bool {
        UUID(uuidString: groupId) != nil
    }

    private var isGroupContextReady: Bool {
        guard !groupId.isEmpty else { return false }
        if !requiresGroupContext { return true }
        return GroupContextStore.context(forGroupId: groupId) != nil
    }

    private var defaultProposedStart: Date {
        Calendar.current.defaultMovieNightStart(for: selectedDay)
    }

    private func updateSnapshot() {
        snapshot = MovieNightCalendarSnapshotBuilder.build(
            events: movieNightStore.events(for: groupId),
            monthAnchor: monthAnchor,
            selectedDay: selectedDay
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                headerCard

                MonthGridView(
                    monthAnchor: monthAnchor,
                    selectedDay: $selectedDay,
                    events: snapshot.eventsInMonth
                )

                DayEventListView(
                    day: selectedDay,
                    groupId: groupId,
                    events: snapshot.eventsForSelectedDay,
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
        .task(id: groupId) {
            updateSnapshot()
            await movieNightStore.refreshFromCloud(groupId: groupId, force: false)
        }
        .onAppear {
            updateSnapshot()
        }
        .onChange(of: movieNightStore.eventsByGroup) { _, _ in
            updateSnapshot()
        }
        .onChange(of: groupId) { _, _ in
            updateSnapshot()
        }
        .onChange(of: monthAnchor) { _, newValue in
            let cal = Calendar.current
            if !cal.isDate(selectedDay, equalTo: newValue, toGranularity: .month) {
                selectedDay = cal.startOfDay(for: cal.startOfMonth(for: newValue))
            }
            updateSnapshot()
        }
        .onChange(of: selectedDay) { _, _ in
            updateSnapshot()
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
                .disabled(userStore.selectedUser == nil || !isGroupContextReady)

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
            } else if requiresGroupContext && !isGroupContextReady {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "icloud.and.arrow.down")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gruppe wird noch geladen …")
                            .font(.subheadline.weight(.semibold))
                        Text("Kurz warten – oder neu laden.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Button("Neu laden") {
                        Task {
                            await groupStore.refresh()
                            await movieNightStore.refreshFromCloud(groupId: groupId, force: true)
                            movieNightStore.flushPendingCloudChanges()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.top, 6)
            } else if snapshot.eventsInMonth.isEmpty {
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
