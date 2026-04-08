//
//  MovieSearchView+Scanner.swift
//  filmfreaks
//

internal import SwiftUI
internal import UIKit
internal import VisionKit

extension MovieSearchView {

    // MARK: - Scanner

    func handleScanTap() {
        if #available(iOS 16.0, *) {
            guard DataScannerViewController.isSupported else {
                scannerError = "Scanner wird auf diesem Gerät nicht unterstützt."
                showScannerError = true
                return
            }
            guard DataScannerViewController.isAvailable else {
                scannerError = "Scanner ist gerade nicht verfügbar (Kamera/Permission?)."
                showScannerError = true
                return
            }

            // Kandidaten zurücksetzen, damit kein „Altbestand“ reinfunkt
            scannerCandidates = []
            candidatePickerItems = []
            lastTappedScanText = nil

            showScanner = true
        } else {
            scannerError = "„Medium scannen“ benötigt iOS 16 oder neuer."
            showScannerError = true
        }
    }
}
