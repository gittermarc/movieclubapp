//
//  ContentSyncStatusLineView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 05.02.26.
//

internal import SwiftUI

/// Subtile Sync-Status-Zeile, die nur erscheint, wenn es wirklich etwas zu zeigen gibt.
///
/// Ziel: ContentView schlank halten und Sync-/Netzwerk-Status konsistent darstellen.
struct ContentSyncStatusLineView: View {

    let isConnected: Bool
    let isSyncing: Bool
    let pendingChangesCount: Int
    let lastError: String?

    private var shouldShow: Bool {
        if !isConnected { return true }
        if isSyncing { return true }
        if pendingChangesCount > 0 { return true }
        if let err = lastError, !err.isEmpty { return true }
        return false
    }

    private var iconName: String {
        if !isConnected { return "wifi.slash" }
        if isSyncing { return "arrow.triangle.2.circlepath" }
        if let err = lastError, !err.isEmpty { return "exclamationmark.triangle" }
        if pendingChangesCount > 0 { return "clock.arrow.circlepath" }
        return "checkmark.circle"
    }

    private var labelText: String {
        if !isConnected {
            return "Offline – Änderungen werden später synchronisiert"
        }
        if isSyncing {
            return "Synchronisiere …"
        }
        if pendingChangesCount > 0 {
            let c = pendingChangesCount
            return c == 1 ? "1 Änderung ausstehend" : "\(c) Änderungen ausstehend"
        }
        if let err = lastError, !err.isEmpty {
            return "Sync-Problem – Details in Einstellungen"
        }
        return ""
    }

    var body: some View {
        if shouldShow {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                Text(labelText)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.bottom, 6)
            .accessibilityLabel(labelText)
        }
    }
}
