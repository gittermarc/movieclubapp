import Foundation

enum TemporaryDirectoryError: Error {
    case unableToCreate
}

final class TemporaryDirectory {
    let url: URL

    init(prefix: String = "filmfreaks-tests") throws {
        let fileManager = FileManager.default
        let candidate = fileManager.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)

        do {
            try fileManager.createDirectory(at: candidate, withIntermediateDirectories: true, attributes: nil)
            self.url = candidate
        } catch {
            throw TemporaryDirectoryError.unableToCreate
        }
    }

    func makeSubdirectory(named name: String) throws -> URL {
        let directoryURL = url.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        return directoryURL
    }

    func createFile(named name: String, contents: Data = Data()) throws -> URL {
        let fileURL = url.appendingPathComponent(name)
        try contents.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    func remove() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    deinit {
        try? remove()
    }
}
