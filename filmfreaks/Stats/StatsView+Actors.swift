//
//  StatsView+Actors.swift
//  filmfreaks
//
//  Actor interaction + popularity sorting + actor detail sheet for StatsView.
//

internal import SwiftUI

extension StatsView {

    // MARK: - Actor Filme

    var moviesForSelectedActor: [Movie] {
        guard let actor = selectedActor else { return [] }
        return filteredMovies.filter { movie in
            guard let cast = movie.cast else { return false }
            return cast.contains(where: { $0.personId == actor.personId })
        }
    }

    // MARK: - Actor Interaction

    func actorChipTapped(_ actor: ActorEntry) {
        selectedActor = actor
        selectedActorDetails = nil
        actorError = nil
        isLoadingActor = true
        showingActorSheet = true

        // ✅ Actor-Sheet lädt Details per ID (keine Suche)
        Task {
            do {
                let details = try await TMDbAPI.shared.fetchPersonDetails(id: actor.personId)
                await MainActor.run {
                    self.selectedActorDetails = details
                    self.isLoadingActor = false
                }
            } catch {
                await MainActor.run {
                    self.actorError = "Fehler beim Laden der Personendaten."
                    self.isLoadingActor = false
                }
            }
        }
    }

    @ViewBuilder
    func actorDetailSheet() -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    if isLoadingActor {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Lade Personendaten …")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)

                    } else if let error = actorError {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.top, 40)

                    } else if let details = selectedActorDetails {

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
                                    // ✅ Option A: nix abschneiden, aber trotzdem "Hero"-artig und sauber gerahmt
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

                            if let dept = details.known_for_department, !dept.isEmpty {
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
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Biografie").font(.headline)

                            if let bio = details.biography,
                               !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(bio).font(.body)
                            } else {
                                Text("Keine Biografie verfügbar.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                    } else {
                        Text("Keine Personendaten geladen.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    }

                    if let actor = selectedActor,
                       !moviesForSelectedActor.isEmpty {

                        Divider().padding(.vertical, 8)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("In eurer Gruppe gesehen")
                                .font(.headline)

                            Text("Filme im aktuell gewählten Zeitraum und Ort, in denen \(actor.name) mitspielt.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(moviesForSelectedActor) { movie in
                                movieRow(movie)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Darsteller")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { showingActorSheet = false }
                }
            }
        }
    }
}
