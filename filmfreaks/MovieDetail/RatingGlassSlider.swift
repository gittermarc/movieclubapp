//
//  RatingGlassSlider.swift
//  filmfreaks
//
//  Discrete, accessible full-width slider used by the rating editor.
//

internal import SwiftUI

struct RatingGlassSlider: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unselectedValue: Int
    let unselectedText: String
    let valueText: (Int) -> String
    let accentColor: (Int) -> Color
    let spectrumColors: [Color]
    let onValueChanged: () -> Void

    init(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        unselectedValue: Int,
        unselectedText: String,
        valueText: @escaping (Int) -> String,
        accentColor: @escaping (Int) -> Color,
        spectrumColors: [Color] = [],
        onValueChanged: @escaping () -> Void
    ) {
        self.title = title
        _value = value
        self.range = range
        self.unselectedValue = unselectedValue
        self.unselectedText = unselectedText
        self.valueText = valueText
        self.accentColor = accentColor
        self.spectrumColors = spectrumColors
        self.onValueChanged = onValueChanged
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 8)

                Text(displayedValueText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isUnselected ? Color.secondary : accentColor(value))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        (isUnselected ? Color.secondary : accentColor(value))
                            .opacity(isUnselected ? 0.10 : 0.16),
                        in: Capsule()
                    )
            }

            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)

                if !spectrumColors.isEmpty {
                    LinearGradient(
                        colors: spectrumColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .opacity(0.20)
                    .clipShape(Capsule())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }

                Slider(
                    value: sliderValue,
                    in: Double(range.lowerBound)...Double(range.upperBound),
                    step: 1
                )
                .tint(accentColor(value))
                .padding(.horizontal, 6)
                .accessibilityLabel(title)
                .accessibilityValue(displayedValueText)
                .accessibilityHint("Zum Ändern nach links oder rechts streichen.")
            }
            .frame(height: 34)

            HStack(spacing: 8) {
                Text(unselectedText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Text("Tippen oder ziehen")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accentColor(value).opacity(isUnselected ? 0.08 : 0.20), lineWidth: 1)
        }
    }

    private var isUnselected: Bool {
        value == unselectedValue
    }

    private var displayedValueText: String {
        isUnselected ? unselectedText : valueText(value)
    }

    private var sliderValue: Binding<Double> {
        Binding(
            get: { Double(value) },
            set: { newValue in
                let roundedValue = Int(newValue.rounded())
                let clampedValue = min(range.upperBound, max(range.lowerBound, roundedValue))

                guard clampedValue != value else {
                    return
                }

                value = clampedValue
                onValueChanged()
            }
        )
    }
}
