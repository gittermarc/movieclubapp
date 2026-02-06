//
//  MediaTitleScannerView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 28.12.25.
//

internal import SwiftUI
internal import VisionKit

@available(iOS 16.0, *)
struct MediaTitleScannerView: UIViewControllerRepresentable {

    var onPickText: (String) -> Void
    var onCancel: () -> Void

    // NEU: Live-Liste der erkannten Texte, damit wir danach Vorschläge machen können
    var onRecognizedTextsChanged: ([String]) -> Void = { _ in }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator

        do {
            try scanner.startScanning()
        } catch {
            // Falls startScanning fehlschlägt, behandeln wir es im Host (MovieSearchView) über "isAvailable"/Alert.
        }

        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        // nichts
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onPickText: onPickText,
            onCancel: onCancel,
            onRecognizedTextsChanged: onRecognizedTextsChanged
        )
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onPickText: (String) -> Void
        let onCancel: () -> Void
        let onRecognizedTextsChanged: ([String]) -> Void

        init(
            onPickText: @escaping (String) -> Void,
            onCancel: @escaping () -> Void,
            onRecognizedTextsChanged: @escaping ([String]) -> Void
        ) {
            self.onPickText = onPickText
            self.onCancel = onCancel
            self.onRecognizedTextsChanged = onRecognizedTextsChanged
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .text(let text):
                let raw = text.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !raw.isEmpty else { return }
                onPickText(raw)
            default:
                break
            }
        }

        func dataScannerDidCancel(_ dataScanner: DataScannerViewController) {
            onCancel()
        }

        // NEU: Wir bekommen laufend Items rein und reichen die Transkripte nach oben durch
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            publishTexts(from: allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            publishTexts(from: allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            publishTexts(from: allItems)
        }

        private func publishTexts(from items: [RecognizedItem]) {
            let texts: [String] = items.compactMap { item in
                switch item {
                case .text(let t):
                    let raw = t.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                    return raw.isEmpty ? nil : raw
                default:
                    return nil
                }
            }

            // Dedup (case-insensitive) – Reihenfolge bleibt stabil, erster gewinnt
            var seen = Set<String>()
            let unique = texts.filter { s in
                let k = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !k.isEmpty else { return false }
                if seen.contains(k) { return false }
                seen.insert(k)
                return true
            }

            onRecognizedTextsChanged(unique)
        }
    }
}
