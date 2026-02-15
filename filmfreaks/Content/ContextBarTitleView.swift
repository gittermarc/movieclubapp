//
//  ContextBarTitleView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 15.02.26.
//

internal import SwiftUI

/// A small adaptive title/value stack used inside the `ContentContextBar`.
///
/// Behavior:
/// - If `label + value` fits in a single line (without truncation), it is shown inline.
/// - Otherwise it switches to a 2-line stack (label above value) so long values can wrap.
///
/// Key trick: the single-line variant is `.fixedSize(horizontal: true, ...)` so it refuses
/// to compress/truncate. That makes `ViewThatFits` pick the stacked variant when needed.
struct ContextBarTitleView: View {

    let label: String
    let value: String

    /// Max lines for the wrapped value. Keep this small to avoid a giant context bar.
    var wrappedLineLimit: Int = 2

    var body: some View {
        ViewThatFits(in: .horizontal) {
            singleLine
            stacked
        }
        .accessibilityElement(children: .combine)
    }

    private var singleLine: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        // Important: refuses to truncate, so ViewThatFits can detect when it doesn't fit.
        .fixedSize(horizontal: true, vertical: true)
    }

    private var stacked: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(wrappedLineLimit)
                .multilineTextAlignment(.leading)
        }
    }
}
