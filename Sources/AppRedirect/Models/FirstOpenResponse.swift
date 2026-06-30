//
//  FirstOpenResponse.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import Foundation

struct FirstOpenResponse: Decodable, Sendable {
    let hasDeepLink: Bool
    let attributionType: String?
    let confidence: Double?
    let destination: String?
    let deepLinkId: UUID?
    let clickId: UUID?
    let params: [String: String]

    private enum CodingKeys: String, CodingKey {
        case hasDeepLink, attributionType, confidence, destination, deepLinkId, clickId, params
    }

    // Tolerant decoding: a missing or malformed optional field must never abort the whole
    // response and, by extension, cause us to lose attribution on a contract drift.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hasDeepLink     = (try? c.decode(Bool.self, forKey: .hasDeepLink)) ?? false
        attributionType = try? c.decodeIfPresent(String.self, forKey: .attributionType)
        confidence      = try? c.decodeIfPresent(Double.self, forKey: .confidence)
        destination     = try? c.decodeIfPresent(String.self, forKey: .destination)
        deepLinkId      = try? c.decodeIfPresent(UUID.self, forKey: .deepLinkId)
        clickId         = try? c.decodeIfPresent(UUID.self, forKey: .clickId)
        params          = (try? c.decodeIfPresent([String: String].self, forKey: .params)) ?? [:]
    }
}

extension FirstOpenResponse {
    func toDeepLinkResult(source: DeepLinkSource) -> DeepLinkResult {
        DeepLinkResult(
            hasDeepLink: hasDeepLink,
            destination: destination,
            attributionType: attributionType,
            confidence: confidence,
            deepLinkId: deepLinkId,
            clickId: clickId,
            params: params,
            source: source
        )
    }
}
