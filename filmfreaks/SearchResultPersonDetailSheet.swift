//
//  SearchResultPersonDetailSheet.swift
//  filmfreaks
//
//  Created by Marc Fechner on 17.01.26.
//

internal import SwiftUI

struct SRSelectedPerson: Identifiable {
    let id: Int
    let name: String
    let subtitle: String?
}

/// Personensheet im Stil der MovieDetailView/StatsView.
struct SRTMDbPersonDetailSheet: View {
    let personId: Int
    let fallbackName: String
    let roleOrCharacter: String?

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading: Bool = false
    @State private var errorText: String? = nil
    @State private var details: TMDbPersonDetails? = nil
    @State private var isBioExpanded: Bool = false

    private var biographyText: String? {
        let t = (details?.biography ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private var roleText: String? {
        let t = (roleOrCharacter ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Lade Personendaten …")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)

                    } else if let errorText {
                        Text(errorText)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.top, 40)

                    } else if let details {

                        if let path = details.profile_path,
                           let url = URL(string: "https://image.tmdb.org/t/p/w500\(path)") {
                            CachedAsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    Rectangle()
                                        .foregroundStyle(.gray.opacity(0.2))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 260)

                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 260)
                                        .background(Color.gray.opacity(0.08))

                                case .failure:
                                    Rectangle()
                                        .foregroundStyle(.gray.opacity(0.2))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 260)
                                        .overlay {
                                            Image(systemName: "person.crop.rectangle")
                                                .font(.largeTitle)
                                                .foregroundStyle(.secondary)
                                        }

                                @unknown default:
                                    Rectangle()
                                        .foregroundStyle(.gray.opacity(0.2))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 260)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(details.name)
                                .font(.title2.bold())

                            if let roleText {
                                Text(roleText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if let dept = details.known_for_department,
                               !dept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(dept)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 10) {
                                if let birthday = details.birthday, !birthday.isEmpty {
                                    Label(birthday, systemImage: "gift.fill")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.12))
                                        .clipShape(Capsule())
                                }

                                if let place = details.place_of_birth, !place.isEmpty {
                                    Label(place, systemImage: "mappin.and.ellipse")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.gray.opacity(0.12))
                                        .clipShape(Capsule())
                                }

                                if let popularity = details.popularity {
                                    Label(String(format: "Popularity %.1f", popularity),
                                          systemImage: "sparkles")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.yellow.opacity(0.15))
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        if let aliases = details.also_known_as, !aliases.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Auch bekannt als")
                                    .font(.subheadline.weight(.semibold))
                                Text(aliases.joined(separator: ", "))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 6)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Biografie")
                                .font(.headline)

                            if let biographyText {
                                Text(biographyText)
                                    .font(.subheadline)
                                    .lineLimit(isBioExpanded ? nil : 10)
                                    .fixedSize(horizontal: false, vertical: true)

                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isBioExpanded.toggle()
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(isBioExpanded ? "Weniger anzeigen" : "Mehr anzeigen")
                                        Image(systemName: isBioExpanded ? "chevron.up" : "chevron.down")
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color.gray.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text("Keine Biografie verfügbar.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 6)

                    } else {
                        Text("Keine Personendaten geladen.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("Darsteller")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
            .task {
                await load()
            }
        }
    }

    private func load() async {
        await MainActor.run {
            isLoading = true
            errorText = nil
            details = nil
        }

        do {
            let fetched = try await TMDbAPI.shared.fetchPersonDetails(id: personId)
            await MainActor.run {
                details = fetched
                isLoading = false
            }
        } catch TMDbError.missingAPIKey {
            await MainActor.run {
                errorText = "TMDb API-Key fehlt."
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorText = "Fehler beim Laden der Personendaten."
                isLoading = false
            }
        }
    }
}
