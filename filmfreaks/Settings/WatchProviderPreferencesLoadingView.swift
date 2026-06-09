//
//  WatchProviderPreferencesLoadingView.swift
//  filmfreaks
//

internal import SwiftUI

struct WatchProviderPreferencesLoadingView: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Lade Anbieter …")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}
