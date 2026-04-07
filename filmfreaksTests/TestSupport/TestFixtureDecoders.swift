import Foundation

enum TestFixtureDecoders {
    static func defaultDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    static func persistenceDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return decoder
    }

    static func movieNightDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
