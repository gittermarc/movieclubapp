import Foundation

enum FixtureLoaderError: LocalizedError {
    case fixtureNotFound(String)

    var errorDescription: String? {
        switch self {
        case .fixtureNotFound(let name):
            return "Fixture not found: \(name)"
        }
    }
}

enum FixtureLoader {
    static let fixturesRootURL: URL = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
    }()

    static func fixtureURL(named name: String) throws -> URL {
        let url = fixturesRootURL.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FixtureLoaderError.fixtureNotFound(name)
        }
        return url
    }

    static func data(named name: String) throws -> Data {
        try Data(contentsOf: fixtureURL(named: name))
    }

    static func decode<T: Decodable>(
        _ type: T.Type,
        named name: String,
        using decoder: JSONDecoder = TestFixtureDecoders.defaultDecoder()
    ) throws -> T {
        try decoder.decode(T.self, from: data(named: name))
    }
}
