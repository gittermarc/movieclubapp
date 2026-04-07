import Foundation
import Testing
@testable import filmfreaks

struct TestSupportUtilitiesTests {

    @Test func temporaryDirectoryCreatesAndRemovesFiles() throws {
        let temporaryDirectory = try TemporaryDirectory()
        let fileURL = try temporaryDirectory.createFile(named: "probe.json", contents: Data("{}".utf8))

        #expect(FileManager.default.fileExists(atPath: temporaryDirectory.url.path))
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        try temporaryDirectory.remove()

        #expect(FileManager.default.fileExists(atPath: temporaryDirectory.url.path) == false)
    }

    @Test func userDefaultsSuitesAreIsolated() throws {
        let leftSuite = try TestUserDefaultsSuite()
        let rightSuite = try TestUserDefaultsSuite()

        leftSuite.defaults.set("left", forKey: "probe")
        rightSuite.defaults.set("right", forKey: "probe")

        #expect(leftSuite.defaults.string(forKey: "probe") == "left")
        #expect(rightSuite.defaults.string(forKey: "probe") == "right")

        leftSuite.clear()

        #expect(leftSuite.defaults.string(forKey: "probe") == nil)
        #expect(rightSuite.defaults.string(forKey: "probe") == "right")
    }
}
