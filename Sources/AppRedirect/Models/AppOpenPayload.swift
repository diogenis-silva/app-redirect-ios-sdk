//
//  AppOpenPayload.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import Foundation

struct AppOpenPayload: Encodable, Sendable {
    let platform: String?
    let appVersion: String?
    let deepLinkId: UUID?
    // Identifiers extracted from the link that triggered this open (re-engagement attribution).
    let clickId: UUID?
    let source: String?
    let url: String?
    let openedAt: Date?
}
