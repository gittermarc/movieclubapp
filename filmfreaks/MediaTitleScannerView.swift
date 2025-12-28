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
        Coordinator(onPickText: onPickText, onCancel: onCancel)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onPickText: (String) -> Void
        let onCancel: () -> Void

        init(onPickText: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onPickText = onPickText
            self.onCancel = onCancel
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
    }
}
