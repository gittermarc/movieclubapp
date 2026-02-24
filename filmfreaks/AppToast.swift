//
//  AppToast.swift
//  filmfreaks
//
//  Lightweight toast/banner to give user feedback without blocking the UI.
//

import Foundation
internal import SwiftUI
import Combine

enum ToastStyle: Equatable {
    case progress
    case success
    case error
    case info

    var iconSystemName: String {
        switch self {
        case .progress: return "arrow.triangle.2.circlepath"
        case .success:  return "checkmark.circle.fill"
        case .error:    return "exclamationmark.triangle.fill"
        case .info:     return "info.circle.fill"
        }
    }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let style: ToastStyle
    let title: String
    let message: String?
}

@MainActor
final class ToastCenter: ObservableObject {
    static let shared = ToastCenter()
    private init() {}

    @Published private(set) var current: Toast?

    private var autoDismissTask: Task<Void, Never>?

    func show(_ toast: Toast, autoHideAfter seconds: TimeInterval? = nil) {
        autoDismissTask?.cancel()
        autoDismissTask = nil

        withAnimation(.spring(response: 0.35, dampingFraction: 0.92)) {
            current = toast
        }

        if let seconds {
            autoDismissTask = Task {
                let ns = UInt64(max(0.2, seconds) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
                dismiss()
            }
        }
    }

    func dismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = nil

        withAnimation(.spring(response: 0.35, dampingFraction: 0.92)) {
            current = nil
        }
    }
}

extension Toast {
    static func progress(title: String, message: String? = nil) -> Toast {
        Toast(style: .progress, title: title, message: message)
    }

    static func success(title: String, message: String? = nil) -> Toast {
        Toast(style: .success, title: title, message: message)
    }

    static func error(title: String, message: String? = nil) -> Toast {
        Toast(style: .error, title: title, message: message)
    }

    static func info(title: String, message: String? = nil) -> Toast {
        Toast(style: .info, title: title, message: message)
    }
}

struct ToastHost: View {
    @ObservedObject private var center = ToastCenter.shared

    var body: some View {
        Group {
            if let toast = center.current {
                ToastView(toast: toast) {
                    center.dismiss()
                }
                .padding(.top, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .top)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityElement(children: .contain)
            }
        }
    }
}

private struct ToastView: View {
    let toast: Toast
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if toast.style == .progress {
                ProgressView()
                    .progressViewStyle(.circular)
            } else {
                Image(systemName: toast.style.iconSystemName)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                if let message = toast.message, !message.isEmpty {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            Spacer(minLength: 0)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Toast schließen")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 10)
    }
}
