//
//  TMDbAPI+Networking.swift
//  filmfreaks
//

import Foundation

extension TMDbAPI {

    static let baseURLString = "https://api.themoviedb.org/3"

    func apiKeyQueryItem() throws -> URLQueryItem {
        guard !apiKey.isEmpty else { throw TMDbError.missingAPIKey }
        return URLQueryItem(name: "api_key", value: apiKey)
    }

    func makeURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        var components = URLComponents(string: "\(TMDbAPI.baseURLString)/\(path)")
        components?.queryItems = queryItems
        guard let url = components?.url else { throw TMDbError.invalidURL }
        return url
    }

    func requestData(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw TMDbError.requestFailed
        }
        return data
    }

    func requestJSON<T: Decodable>(url: URL, type: T.Type) async throws -> T {
        let data = try await requestData(from: url)
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw TMDbError.decodingFailed
        }
    }

    func requestJSON<T: Decodable>(path: String, queryItems: [URLQueryItem], type: T.Type) async throws -> T {
        let url = try makeURL(path: path, queryItems: queryItems)
        return try await requestJSON(url: url, type: type)
    }
}
