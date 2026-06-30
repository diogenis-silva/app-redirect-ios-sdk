//
//  DeepLinkResult.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import Foundation

public struct DeepLinkResult: Codable, Sendable {
    public let hasDeepLink: Bool
    public let destination: String?
    public let attributionType: String?
    /// Attribution confidence on a 0–100 scale, as returned by the backend.
    public let confidence: Double?
    public let deepLinkId: UUID?
    public let clickId: UUID?
    public let params: [String: String]
    public let source: DeepLinkSource

    public init(
        hasDeepLink: Bool,
        destination: String?,
        attributionType: String?,
        confidence: Double?,
        deepLinkId: UUID?,
        clickId: UUID?,
        params: [String: String],
        source: DeepLinkSource
    ) {
        self.hasDeepLink = hasDeepLink
        self.destination = destination
        self.attributionType = attributionType
        self.confidence = confidence
        self.deepLinkId = deepLinkId
        self.clickId = clickId
        self.params = params
        self.source = source
    }

    // Tolerant decoding so a persisted result from an older SDK version still loads
    // instead of silently resolving to nil when the schema evolves.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hasDeepLink     = (try? c.decode(Bool.self, forKey: .hasDeepLink)) ?? false
        destination     = try? c.decodeIfPresent(String.self, forKey: .destination)
        attributionType = try? c.decodeIfPresent(String.self, forKey: .attributionType)
        confidence      = try? c.decodeIfPresent(Double.self, forKey: .confidence)
        deepLinkId      = try? c.decodeIfPresent(UUID.self, forKey: .deepLinkId)
        clickId         = try? c.decodeIfPresent(UUID.self, forKey: .clickId)
        params          = (try? c.decodeIfPresent([String: String].self, forKey: .params)) ?? [:]
        source          = (try? c.decodeIfPresent(DeepLinkSource.self, forKey: .source)) ?? .api
    }
}
