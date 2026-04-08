//
//  ContentView+Onboarding.swift
//  filmfreaks
//
//  Extracted from ContentView to isolate onboarding tracking helpers.
//

internal import SwiftUI

extension ContentView {

    // MARK: - Onboarding Tracking

    func updateOnboardingCompletionFlag() {
        ContentOnboarding.updateCompletionFlagIfNeeded(for: onboarding)
    }

    func trackSearchOpened() {
        ContentOnboarding.trackSearchOpened(forGroupId: onboarding.groupIdForProgress)
    }
}
