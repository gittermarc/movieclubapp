//
//  MovieNightDetailSheet+Actions.swift
//  filmfreaks
//
//  P0.3: split out imperative actions.
//

import Foundation
internal import SwiftUI

extension MovieNightDetailSheet {

    func reloadGroupContextAndNightData() {
        Task {
            await groupStore.refresh()
            await movieNightStore.refreshFromCloud(groupId: groupId, force: true)
            movieNightStore.flushPendingCloudChanges()
        }
    }

    func setEventStatus(_ status: MovieNightEvent.Status, event: MovieNightEvent) {
        movieNightStore.updateEvent(
            groupId: groupId,
            eventId: event.id,
            status: status,
            actorUserId: userStore.selectedUser?.id,
            actorName: userStore.selectedUser?.name
        )
    }

    func deleteEventAndDismiss(_ event: MovieNightEvent) {
        movieNightStore.deleteEvent(
            groupId: groupId,
            eventId: event.id,
            actorUserId: userStore.selectedUser?.id,
            actorName: userStore.selectedUser?.name
        )
        dismiss()
    }
}
