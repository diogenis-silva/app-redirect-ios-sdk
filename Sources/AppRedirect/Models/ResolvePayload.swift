//
//  ResolvePayload.swift
//  App Redirect
//
//  Created by Diógenis Silva on 01/07/2026.
//

import Foundation

/// Sent to `mobile/v1/resolve` when a live Universal Link opens an already-installed app.
/// The backend maps the URL to the configured destination and returns it (plus attribution IDs).
struct ResolvePayload: Encodable, Sendable {
    let url: String
    let platform: String
    let appVersion: String?
    let osVersion: String?
    let deviceModel: String?
    let language: String?
}
