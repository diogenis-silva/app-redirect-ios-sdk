//
//  Networking.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import Foundation

/// Seam over the HTTP layer so the orchestrator and the retry queue can be tested
/// against a mock instead of a live `URLSession`.
protocol Networking: Sendable {
    func firstOpen(_ payload: FirstOpenPayload) async throws -> FirstOpenResponse
    func resolve(_ payload: ResolvePayload) async throws -> FirstOpenResponse
    func send(path: String, bodyData: Data) async throws
}
