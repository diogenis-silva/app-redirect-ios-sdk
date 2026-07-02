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

    /// App Redirect link domains (e.g. `ntxlvl.fernandagazzotto.com.br`). When a live Universal Link
    /// arrives whose host matches one of these (by suffix), the SDK resolves it against the backend
    /// to obtain the configured destination. Universal Links from other domains are left untouched.
    public let linkDomains: Set<String>

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
        linkDomains: Set<String> = [],
        clipboardMaxAge: TimeInterval = 300,
        requestTimeout: TimeInterval = 10,
        firstOpenRetryWindow: TimeInterval = 86_400
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.logLevel = logLevel
        self.deferredDeepLink = deferredDeepLink
        self.linkDomains = linkDomains
        self.clipboardMaxAge = clipboardMaxAge
        self.requestTimeout = requestTimeout
        self.firstOpenRetryWindow = firstOpenRetryWindow
    }
}
