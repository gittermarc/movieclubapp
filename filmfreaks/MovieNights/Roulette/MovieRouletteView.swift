//
//  MovieRouletteView.swift
//  filmfreaks
//
//  Created by Marc Fechner on 15.04.26.
//

internal import SwiftUI

struct MovieRouletteView: View {

    @EnvironmentObject private var movieStore: MovieStore
    @EnvironmentObject private var displaySettings: DisplaySettings
    @StateObject private var viewModel = MovieRouletteViewModel()

    private var m: DisplaySettings.LayoutMetrics { displaySettings.metrics }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                rouletteStageCard
                candidatesCard

                if let winningCandidate = viewModel.winningCandidate {
                    MovieRouletteResultCard(
                        candidate: winningCandidate,
                        groupName: viewModel.groupName,
                        onSpinAgain: viewModel.spin
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear(perform: syncFromStore)
        .onReceive(movieStore.$backlogMovies) { _ in
            syncFromStore()
        }
        .onChange(of: movieStore.currentGroupId) { _, _ in
            syncFromStore()
        }
        .onChange(of: movieStore.currentGroupName) { _, _ in
            syncFromStore()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Label {
                        Text("Filmroulette")
                            .font(.title3.weight(.semibold))
                    } icon: {
                        Image(systemName: "sparkles.tv")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(displaySettings.tintColor)
                    }

                    Text("Ein Spin aus dem Backlog von \(viewModel.groupName). Ideal, wenn ihr euch gerade nicht entscheiden könnt.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                countBadge
            }

            HStack(spacing: 8) {
                sourceBadge(title: "Quelle", value: "Backlog")
                sourceBadge(title: "Status", value: viewModel.isSpinning ? "Dreht" : "Bereit")
            }
        }
        .padding(m.cardPadding + 2)
        .background(cardBackground)
    }

    private var rouletteStageCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Marker entscheidet")
                .font(.headline)

            Text(viewModel.isSpinning ? "Das Roulette läuft gerade aus. Sobald der Strip stoppt, steht der Gewinner fest." : "Der leuchtende Marker zeigt am Ende den Gewinnerfilm an.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            MovieRouletteSpinStripView(
                displayCandidates: viewModel.displayCandidates,
                activeDisplayIndex: viewModel.activeDisplayIndex,
                isSpinning: viewModel.isSpinning,
                winningCandidateId: viewModel.winningCandidate?.id
            )
            .environmentObject(displaySettings)

            Button {
                viewModel.spin()
            } label: {
                Label(viewModel.spinButtonTitle, systemImage: viewModel.isSpinning ? "sparkles.rectangle.stack" : "play.circle.fill")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(displaySettings.tintColor)
            .disabled(viewModel.candidates.isEmpty || viewModel.isSpinning)
        }
        .padding(m.cardPadding + 2)
        .background(cardBackground)
    }

    @ViewBuilder
    private var candidatesCard: some View {
        if viewModel.candidates.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label(viewModel.emptyStateTitle, systemImage: "film.stack")
                    .font(.headline)

                Text(viewModel.emptyStateMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(m.cardPadding + 2)
            .background(cardBackground)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Im Topf", systemImage: "movieclapper")
                        .font(.headline)

                    Spacer(minLength: 12)

                    Text(viewModel.candidateCountText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                candidatePosterRow

                let previewTitles = candidatePreviewText(from: viewModel.candidates)
                if previewTitles.isEmpty == false {
                    Text(previewTitles)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(m.cardPadding + 2)
            .background(cardBackground)
        }
    }

    private var candidatePosterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(viewModel.candidates.prefix(10))) { candidate in
                    VStack(alignment: .leading, spacing: 6) {
                        GoalPosterTileView(
                            posterURL: candidate.posterURL,
                            size: .init(width: 78, height: 117),
                            cornerRadius: displaySettings.cardCornerRadius
                        )
                        Text(candidate.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)
                            .frame(width: 78, alignment: .leading)
                    }
                    .frame(width: 78, alignment: .leading)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var countBadge: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(viewModel.candidateCountText)
                .font(.headline)
            Text("im Backlog")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius, style: .continuous)
                .fill(displaySettings.tintColor.opacity(0.12))
        )
    }

    private func sourceBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .circular)
                .fill(.ultraThinMaterial)
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius, style: .continuous)
            .fill(.thinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: displaySettings.cardCornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
    }

    private func candidatePreviewText(from candidates: [MovieRouletteCandidate]) -> String {
        let previewTitles = candidates.prefix(4).map(\.title)
        guard previewTitles.isEmpty == false else { return "" }

        let joined = ListFormatter.localizedString(byJoining: previewTitles) ?? previewTitles.joined(separator: ", ")
        let remainingCount = candidates.count - previewTitles.count
        if remainingCount > 0 {
            return "Zum Beispiel: \(joined) und \(remainingCount) weitere."
        }
        return "Im Rennen: \(joined)."
    }

    private func syncFromStore() {
        viewModel.update(
            backlogMovies: movieStore.backlogMovies,
            currentGroupId: movieStore.currentGroupId,
            currentGroupName: movieStore.currentGroupName
        )
    }
}

#Preview {
    let movieStore = MovieStore.preview()
    movieStore.currentGroupId = "group-preview"
    movieStore.currentGroupName = "Friday Crew"
    movieStore.backlogMovies = [
        Movie(title: "The Big Lebowski", year: "1998", posterPath: nil, addedAt: .now, addedByName: "Marc"),
        Movie(title: "Arrival", year: "2016", posterPath: nil, addedAt: .now.addingTimeInterval(-3600), addedByName: "Marc"),
        Movie(title: "Heat", year: "1995", posterPath: nil, addedAt: .now.addingTimeInterval(-7200), addedByName: "Marc")
    ].map { movie in
        var copy = movie
        copy.groupId = "group-preview"
        copy.groupName = "Friday Crew"
        return copy
    }

    return NavigationStack {
        MovieRouletteView()
            .navigationTitle("Filmroulette")
            .navigationBarTitleDisplayMode(.inline)
    }
    .environmentObject(movieStore)
    .environmentObject(DisplaySettings())
}
