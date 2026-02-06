//
//  MovieSearchStickyHeaderView.swift
//  filmfreaks
//

internal import SwiftUI

struct MovieSearchStickyHeaderView: View {

    @EnvironmentObject private var displaySettings: DisplaySettings

    @Binding var query: String
    @Binding var selectedSort: MovieSearchSortOption

    let headerTopSpacer: CGFloat
    let isLoading: Bool
    let resultsCount: Int
    let totalResults: Int

    let keyboardAnimationDuration: Double
    let isSearchFieldFocused: Bool
    let focusBinding: FocusState<Bool>.Binding

    let onSubmit: () -> Void
    let onClear: () -> Void
    let onScanTap: () -> Void

    var body: some View {
        VStack(spacing: 10) {

            // ✅ Platzhalter, damit das Suchfeld beim Fokus nicht unter den Inline-Titel rutscht
            Color.clear
                .frame(height: headerTopSpacer)
                .accessibilityHidden(true)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Filmtitel suchen…", text: $query)
                        .focused(focusBinding)
                        .textFieldStyle(.plain)
                        .submitLabel(.search)
                        .onSubmit(onSubmit)

                    if !query.isEmpty {
                        Button(action: onClear) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                if isLoading {
                    ProgressView()
                        .padding(.trailing, 2)
                }
            }
            .padding(.horizontal)

            // Medium scannen Button
            HStack {
                Button(action: onScanTap) {
                    HStack(spacing: 8) {
                        Image(systemName: "text.viewfinder")
                        Text("Medium scannen")
                    }
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(displaySettings.tintSoftBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal)

            if isLoading {
                ProgressView()
                    .progressViewStyle(.linear)
                    .padding(.horizontal)
            }

            if resultsCount > 0 {
                HStack {
                    Text("\(resultsCount) von \(totalResults) Treffer")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Menu {
                        ForEach(MovieSearchSortOption.allCases) { option in
                            Button {
                                selectedSort = option
                            } label: {
                                if selectedSort == option {
                                    Label(option.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(option.rawValue)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.caption)
                            Text(selectedSort.rawValue)
                                .font(.caption)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.35)
        }
        .animation(.easeOut(duration: keyboardAnimationDuration), value: isSearchFieldFocused)
    }
}
