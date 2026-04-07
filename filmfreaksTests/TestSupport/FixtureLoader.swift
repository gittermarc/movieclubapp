import Foundation

enum FixtureLoaderError: LocalizedError {
    case fixtureNotFound(String, searchedRoots: [String])

    var errorDescription: String? {
        switch self {
        case let .fixtureNotFound(name, searchedRoots):
            let roots = searchedRoots.isEmpty ? "none" : searchedRoots.joined(separator: ", ")
            return "Fixture not found: \(name). Searched roots: \(roots)"
        }
    }
}

enum FixtureLoader {
    static let fixturesRootURL: URL = resolvedFixturesRootURL()

    static var availableFixtureNames: [String] {
        let diskFixtures = availableDiskFixtureNames()
        return Array(Set(diskFixtures).union(EmbeddedFixtureCatalog.contentsByName.keys)).sorted()
    }

    static func fixtureURL(named name: String) throws -> URL {
        let searchedRoots = candidateFixturesRootURLs().map(\.path)

        for root in candidateFixturesRootURLs() {
            let url = root.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        throw FixtureLoaderError.fixtureNotFound(name, searchedRoots: searchedRoots)
    }

    static func data(named name: String) throws -> Data {
        if let url = try? fixtureURL(named: name) {
            return try Data(contentsOf: url)
        }

        if let embedded = EmbeddedFixtureCatalog.contentsByName[name] {
            return Data(embedded.utf8)
        }

        let searchedRoots = candidateFixturesRootURLs().map(\.path)
        throw FixtureLoaderError.fixtureNotFound(name, searchedRoots: searchedRoots)
    }

    static func decode<T: Decodable>(
        _ type: T.Type,
        named name: String,
        using decoder: JSONDecoder = TestFixtureDecoders.defaultDecoder()
    ) throws -> T {
        try decoder.decode(T.self, from: data(named: name))
    }

    private static func resolvedFixturesRootURL() -> URL {
        candidateFixturesRootURLs().first(where: { FileManager.default.fileExists(atPath: $0.path) })
            ?? defaultFixturesRootURL()
    }

    private static func candidateFixturesRootURLs(filePath: String = #filePath) -> [URL] {
        let fileURL = URL(fileURLWithPath: filePath)
        let startDirectory = fileURL.deletingLastPathComponent()
        var currentDirectory = startDirectory
        var candidates: [URL] = []
        var seenPaths = Set<String>()

        for _ in 0..<6 {
            let directFixtures = currentDirectory.appendingPathComponent("Fixtures", isDirectory: true)
            let nestedFixtures = currentDirectory
                .appendingPathComponent("filmfreaksTests", isDirectory: true)
                .appendingPathComponent("Fixtures", isDirectory: true)

            for candidate in [directFixtures, nestedFixtures] {
                if seenPaths.insert(candidate.path).inserted {
                    candidates.append(candidate)
                }
            }

            let parent = currentDirectory.deletingLastPathComponent()
            if parent.path == currentDirectory.path {
                break
            }
            currentDirectory = parent
        }

        let bundleResourceCandidates = Bundle.allBundles.compactMap { bundle -> URL? in
            guard let resourceURL = bundle.resourceURL else { return nil }
            return resourceURL.appendingPathComponent("Fixtures", isDirectory: true)
        }

        for candidate in bundleResourceCandidates where seenPaths.insert(candidate.path).inserted {
            candidates.append(candidate)
        }

        return candidates
    }

    private static func defaultFixturesRootURL(filePath: String = #filePath) -> URL {
        URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
    }

    private static func availableDiskFixtureNames() -> [String] {
        let manager = FileManager.default

        for root in candidateFixturesRootURLs() where manager.fileExists(atPath: root.path) {
            guard let enumerator = manager.enumerator(at: root, includingPropertiesForKeys: nil) else {
                continue
            }

            return enumerator.compactMap { item in
                guard let url = item as? URL else { return nil }
                guard url.hasDirectoryPath == false else { return nil }
                return url.path.replacingOccurrences(of: root.path + "/", with: "")
            }
            .sorted()
        }

        return []
    }
}
