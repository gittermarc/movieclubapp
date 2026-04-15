//
//  MovieNightStore+RoulettePresets.swift
//  filmfreaks
//
//  Created by Marc Fechner on 15.04.26.
//

import Foundation

extension MovieNightStore {

    func roulettePresets(for groupId: String) -> [MovieRoulettePreset] {
        let trimmedGroupId = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        return MovieRoulettePreset.normalized(presetsByGroup[trimmedGroupId] ?? [], groupId: trimmedGroupId)
    }

    @discardableResult
    func saveRoulettePreset(
        groupId: String,
        presetId: UUID? = nil,
        name: String,
        movieRefs: [MovieNightMovieRef]
    ) -> MovieRoulettePreset? {
        let trimmedGroupId = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGroupId.isEmpty else { return nil }

        var list = roulettePresets(for: trimmedGroupId)
        let normalizedRefs = MovieRoulettePreset.deduplicatedMovieRefs(movieRefs)
        guard normalizedRefs.isEmpty == false else { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()

        let savedPreset: MovieRoulettePreset

        if let presetId, let index = list.firstIndex(where: { $0.id == presetId }) {
            var updated = list[index]
            updated.name = trimmedName.isEmpty ? updated.displayName : trimmedName
            updated.movieRefs = normalizedRefs
            updated.updatedAt = now
            list[index] = updated
            savedPreset = updated
        } else {
            let created = MovieRoulettePreset(
                id: presetId ?? UUID(),
                groupId: trimmedGroupId,
                name: trimmedName.isEmpty ? "Neue Auswahl" : trimmedName,
                sortIndex: list.count,
                movieRefs: normalizedRefs,
                updatedAt: now
            )
            list.append(created)
            savedPreset = created
        }

        let normalizedPresets = MovieRoulettePreset.normalized(list, groupId: trimmedGroupId)
        presetsByGroup[trimmedGroupId] = normalizedPresets

        for preset in normalizedPresets {
            queueRoulettePresetSave(preset, groupId: trimmedGroupId)
        }

        if let presetToSave = normalizedPresets.first(where: { $0.id == savedPreset.id }) {
            persist()
            return presetToSave
        }

        persist()
        return nil
    }

    func deleteRoulettePreset(groupId: String, presetId: UUID) {
        let trimmedGroupId = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGroupId.isEmpty else { return }

        var list = roulettePresets(for: trimmedGroupId)
        list.removeAll { $0.id == presetId }
        let normalizedPresets = MovieRoulettePreset.normalized(list, groupId: trimmedGroupId)
        presetsByGroup[trimmedGroupId] = normalizedPresets

        queueRoulettePresetDelete(presetId: presetId, groupId: trimmedGroupId)
        for preset in normalizedPresets {
            queueRoulettePresetSave(preset, groupId: trimmedGroupId)
        }
        persist()
    }

    func mergeRoulettePresets(_ changed: [MovieRoulettePreset], deleted: [UUID], groupId: String) {
        let trimmedGroupId = groupId.trimmingCharacters(in: .whitespacesAndNewlines)
        var byId = Dictionary(uniqueKeysWithValues: (presetsByGroup[trimmedGroupId] ?? []).map { ($0.id, $0) })

        for preset in changed {
            if let local = byId[preset.id], local.updatedAt >= preset.updatedAt {
                continue
            }
            byId[preset.id] = preset
        }

        for presetId in deleted {
            byId.removeValue(forKey: presetId)
        }

        presetsByGroup[trimmedGroupId] = MovieRoulettePreset.normalized(Array(byId.values), groupId: trimmedGroupId)
    }
}
