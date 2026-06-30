//
//  FirstOpenPayload.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import Foundation

struct FirstOpenPayload: Encodable, Sendable {
    let platform: String
    let appVersion: String?
    let osVersion: String?
    let deviceModel: String?
    let language: String?
    let timezone: String?
    let screenWidth: Int?
    let screenHeight: Int?
    let screenScale: Double?
    let idfa: String?
    let installReferrer: String?
    // Strong attribution signal lifted from the clipboard payload (iOS deferred deep link).
    // The backend validates it and returns the authoritative destination — the SDK never trusts it directly.
    let clickId: String?
    let installedAt: Date?
}
