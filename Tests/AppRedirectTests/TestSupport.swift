//
//  TestSupport.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import Foundation
import UIKit
@testable import AppRedirect

// MARK: - Network mock

/// In-memory `Networking` double. An actor so its recorded state is race-free under Swift 6.
actor MockNetworking: Networking {

    enum Mode: Sendable {
        case success(FirstOpenResponse)
        case failure
    }

    private(set) var firstOpenCount = 0
    private(set) var lastFirstOpenPayload: FirstOpenPayload?
    private(set) var sentPaths: [String] = []

    private var firstOpenMode: Mode
    private var sendShouldFail: Bool

    init(firstOpen: Mode = .success(.fixture()), sendShouldFail: Bool = false) {
        self.firstOpenMode = firstOpen
        self.sendShouldFail = sendShouldFail
    }

    func setFirstOpen(_ mode: Mode) { firstOpenMode = mode }
    func setSendShouldFail(_ value: Bool) { sendShouldFail = value }

    func firstOpen(_ payload: FirstOpenPayload) async throws -> FirstOpenResponse {
        firstOpenCount += 1
        lastFirstOpenPayload = payload
        switch firstOpenMode {
        case .success(let response): return response
        case .failure:               throw AppRedirectError.invalidResponse
        }
    }

    func send(path: String, bodyData: Data) async throws {
        if sendShouldFail { throw AppRedirectError.invalidResponse }
        sentPaths.append(path)
    }
}

// MARK: - Fixtures

extension FirstOpenResponse {
    /// Builds a response by decoding JSON, since the custom `init(from:)` suppresses the memberwise init.
    static func fixture(
        hasDeepLink: Bool = true,
        attributionType: String = "deterministic",
        confidence: Double = 100,
        destination: String = "myapp://home",
        deepLinkId: UUID = UUID(),
        clickId: UUID = UUID()
    ) -> FirstOpenResponse {
        let json = """
        {
          "hasDeepLink": \(hasDeepLink),
          "attributionType": "\(attributionType)",
          "confidence": \(confidence),
          "destination": "\(destination)",
          "deepLinkId": "\(deepLinkId.uuidString)",
          "clickId": "\(clickId.uuidString)",
          "params": { "utm_source": "instagram" }
        }
        """
        return try! JSONDecoder().decode(FirstOpenResponse.self, from: Data(json.utf8))
    }
}

enum TestEnv {
    /// A throwaway UserDefaults suite, cleared on creation.
    static func freshDefaults() -> UserDefaults {
        let suite = "ar.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    /// An app-private pasteboard — reading it does not trigger the iOS paste prompt,
    /// and each test gets its own, so no `.serialized` is needed.
    @MainActor
    static func pasteboard() -> UIPasteboard {
        UIPasteboard.withUniqueName()
    }

    /// A unique temp directory for queue persistence tests.
    static func tempDirectory() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ar-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static let baseURL = URL(string: "https://api.test.local")!

    static func config(deferredDeepLink: DeferredDeepLinkMode = .fingerprintOnly,
                       clipboardMaxAge: TimeInterval = 300,
                       firstOpenRetryWindow: TimeInterval = 86_400) -> AppRedirectConfig {
        AppRedirectConfig(
            apiKey: "dlk_test",
            baseURL: baseURL,
            deferredDeepLink: deferredDeepLink,
            clipboardMaxAge: clipboardMaxAge,
            firstOpenRetryWindow: firstOpenRetryWindow
        )
    }
}
