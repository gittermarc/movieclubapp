//
//  MovieSearchView+Toast.swift
//  filmfreaks
//

internal import SwiftUI

extension MovieSearchView {

    // MARK: - Toast

    func showConfirmation(_ text: String) {
        toastMessage = text
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.25)) {
                showToast = false
            }
        }
    }
}
