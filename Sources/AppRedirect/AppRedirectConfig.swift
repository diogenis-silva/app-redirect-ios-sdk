//
//  AppRedirectConfig.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import Foundation

public struct AppRedirectConfig: Sendable {
    public let apiKey: String
    public let baseURL: URL
    public let logLevel: LogLevel

    /// Deferred deep link strategy. Defaults to `.fingerprintOnly` (no clipboard, no paste prompt).
    public let deferredDeepLink: DeferredDeepLinkMode

    public let clipboardMaxAge: TimeInterval
    public let requestTimeout: TimeInterval

    /// How long after install we keep retrying `first-open` when it fails.
    /// Beyond this window the SDK gives up to avoid retrying forever.
    public let firstOpenRetryWindow: TimeInterval

    public init(
        apiKey: String,
        baseURL: URL,
        logLevel: LogLevel = .none,
        deferredDeepLink: DeferredDeepLinkMode = .fingerprintOnly,
        clipboardMaxAge: TimeInterval = 300,
        requestTimeout: TimeInterval = 10,
        firstOpenRetryWindow: TimeInterval = 86_400
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.logLevel = logLevel
        self.deferredDeepLink = deferredDeepLink
        self.clipboardMaxAge = clipboardMaxAge
        self.requestTimeout = requestTimeout
        self.firstOpenRetryWindow = firstOpenRetryWindow
    }
}
