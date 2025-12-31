//
//  SafariView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 31.12.25.
//

internal import SwiftUI
import SafariServices

/// In-App Browser (SFSafariViewController) als zuverlässiger Fallback,
/// falls ein YouTube-Video im iFrame-Embed nicht abspielbar ist (Embedding disabled / Region / Consent Flow etc.).
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // no-op
    }
}
