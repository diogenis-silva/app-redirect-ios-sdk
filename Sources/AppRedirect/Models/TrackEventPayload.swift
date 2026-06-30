//
//  TrackEventPayload.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import Foundation

struct TrackEventPayload: Encodable, Sendable {
    let eventName: String
    let deepLinkId: UUID?
    let clickId: UUID?
    let occurredAt: Date?
    let properties: [String: JSONValue]?
    let revenue: Decimal?
}
