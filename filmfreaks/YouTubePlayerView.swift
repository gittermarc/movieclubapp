//
//  YouTubePlayerView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 31.12.25.
//

internal import SwiftUI
import WebKit

/// Inline-YouTube-Player via WKWebView (iFrame-Embed).
///
/// Warum iFrame?
/// - Die mobile Watch-Seite (m.youtube.com) bringt in der EU oft Consent-/Cookie-Flows,
///   die in einem 16:9 Inline-WebView in Portrait schlecht bedienbar sind.
/// - Das iFrame-Embed zeigt i. d. R. keinen großen Cookie-Banner-Flow im Player selbst
///   (oder zumindest wesentlich seltener/kleiner).
///
/// Wichtiger Hinweis:
/// - Manche YouTube-Videos sind „Embedding disabled“ (dann zeigt YouTube im Player „Video nicht verfügbar“).
///   Für diese Fälle bietet deine UI zusätzlich „In App öffnen“ (SFSafariViewController) + „In YouTube öffnen“.
struct YouTubePlayerView: UIViewRepresentable {
    let videoId: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // YouTube-Embed braucht JS.
        if #available(iOS 14.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        } else {
            config.preferences.javaScriptEnabled = true
        }

        // Inline Playback
        config.allowsInlineMediaPlayback = true

        // Keine extra Hürden: Play ist ohnehin user-initiiert im Player.
        if #available(iOS 10.0, *) {
            config.mediaTypesRequiringUserActionForPlayback = []
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.allowsBackForwardNavigationGestures = false

        // Safari-ähnlicher UserAgent kann YouTube-Kompatibilität erhöhen.
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastVideoId != videoId else { return }
        context.coordinator.lastVideoId = videoId

        // Wichtig: baseURL != nil (Referrer/Origin in WKWebView sind sonst oft „komisch“ -> YouTube 153 o.ä.)
        let baseURL = URL(string: "https://www.youtube.com")!

        // playsinline=1 -> inline (wenn möglich)
        // rel=0/modestbranding=1 -> best effort
        // origin=... -> hilft YouTube beim Validieren des Embeds
        let html = """
        <!doctype html>
        <html>
          <head>
            <meta name="viewport" content="initial-scale=1.0, maximum-scale=1.0">
            <meta name="referrer" content="strict-origin-when-cross-origin">
            <style>
              html, body { margin:0; padding:0; background:transparent; height:100%; }
              .wrap { position:relative; width:100%; height:100%; }
              iframe { position:absolute; top:0; left:0; width:100%; height:100%; border:0; }
            </style>
          </head>
          <body>
            <div class="wrap">
              <iframe
                src="https://www.youtube-nocookie.com/embed/\(videoId)?playsinline=1&rel=0&modestbranding=1&origin=https://www.youtube.com"
                referrerpolicy="strict-origin-when-cross-origin"
                allow="accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                allowfullscreen>
              </iframe>
            </div>
          </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: baseURL)
    }

    final class Coordinator {
        var lastVideoId: String?
    }
}
