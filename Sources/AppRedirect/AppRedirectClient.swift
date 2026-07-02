//
//  AppRedirectClient.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import Foundation

final class AppRedirectClient: Networking {

    /// Shared encoder so payloads queued for retry are encoded identically to live requests.
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let config: AppRedirectConfig
    private let session: URLSession

    init(config: AppRedirectConfig) {
        self.config = config
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest  = config.requestTimeout
        sessionConfig.timeoutIntervalForResource = config.requestTimeout * 2
        session = URLSession(configuration: sessionConfig)
    }

    // MARK: - Endpoints

    func firstOpen(_ payload: FirstOpenPayload) async throws -> FirstOpenResponse {
        let req = try makeRequest(path: "mobile/v1/first-open", body: payload)
        return try await execute(req)
    }

    func resolve(_ payload: ResolvePayload) async throws -> FirstOpenResponse {
        let req = try makeRequest(path: "mobile/v1/resolve", body: payload)
        return try await execute(req)
    }

    /// Sends a pre-encoded body. Used by the retry queue to resend stored requests.
    func send(path: String, bodyData: Data) async throws {
        var req = baseRequest(path: path)
        req.httpBody = bodyData
        try await execute(req)
    }

    // MARK: - Private

    private func baseRequest(path: String) -> URLRequest {
        let url = config.baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(config.apiKey,      forHTTPHeaderField: "X-Api-Key")
        return req
    }

    private func makeRequest<T: Encodable>(path: String, body: T) throws -> URLRequest {
        var req = baseRequest(path: path)
        req.httpBody = try Self.encoder.encode(body)
        return req
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        Logger.debug("→ POST \(request.url?.path ?? "")")
        let (data, response) = try await session.data(for: request)
        try validate(response)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func execute(_ request: URLRequest) async throws {
        Logger.debug("→ POST \(request.url?.path ?? "")")
        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AppRedirectError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            Logger.debug("← HTTP \(http.statusCode)")
            throw AppRedirectError.httpError(statusCode: http.statusCode)
        }
        Logger.debug("← HTTP \(http.statusCode)")
    }
}
