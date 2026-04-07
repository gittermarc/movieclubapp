import Foundation

enum TestUserDefaultsSuiteError: Error {
    case unableToCreate
}

final class TestUserDefaultsSuite {
    let suiteName: String
    let defaults: UserDefaults

    init(prefix: String = "filmfreaks.tests") throws {
        self.suiteName = "\(prefix).\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TestUserDefaultsSuiteError.unableToCreate
        }
        self.defaults = defaults
        clear()
    }

    func clear() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
