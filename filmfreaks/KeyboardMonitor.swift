//
//  KeyboardMonitor.swift
//  filmfreaks
//

import Combine
import Foundation
import CoreGraphics
internal import UIKit

// MARK: - Keyboard Monitor (verhindert „Jump“ beim Fokus)

final class KeyboardMonitor: ObservableObject {
    @Published var height: CGFloat = 0
    @Published var animationDuration: Double = 0.25

    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default

        observers.append(
            center.addObserver(
                forName: UIResponder.keyboardWillChangeFrameNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                self?.handleWillChangeFrame(note)
            }
        )

        observers.append(
            center.addObserver(
                forName: UIResponder.keyboardWillHideNotification,
                object: nil,
                queue: .main
            ) { [weak self] note in
                self?.handleWillHide(note)
            }
        )
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private var keyWindow: UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let active = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        return active?.windows.first(where: { $0.isKeyWindow }) ?? active?.windows.first
    }

    private var safeAreaBottomInset: CGFloat {
        keyWindow?.safeAreaInsets.bottom ?? 0
    }

    private func handleWillChangeFrame(_ note: Notification) {
        guard let userInfo = note.userInfo else { return }

        let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .zero

        animationDuration = duration

        let window = keyWindow
        let windowHeight = window?.bounds.height ?? endFrame.maxY
        let endFrameInWindow = window?.convert(endFrame, from: nil) ?? endFrame
        let raw = windowHeight - endFrameInWindow.minY
        let adjusted = max(0, raw - safeAreaBottomInset)

        height = adjusted
    }

    private func handleWillHide(_ note: Notification) {
        let duration = (note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        animationDuration = duration
        height = 0
    }
}
