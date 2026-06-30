//
//  ClipboardChecker.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import UIKit

/// Minimal seam over `UIPasteboard` so tests can use an app-private pasteboard
/// (`UIPasteboard.withUniqueName()`) instead of `.general`, which would trigger the
/// iOS paste-permission prompt on every read.
protocol Pasteboard: AnyObject {
    var string: String? { get set }
}

extension UIPasteboard: Pasteboard {}

enum ClipboardChecker {

    struct Payload: Sendable {
        let destination: String
        let clickId: String?
    }

    @MainActor
    static func check(maxAge: TimeInterval, pasteboard: any Pasteboard = UIPasteboard.general) -> Payload? {
        guard
            let raw = pasteboard.string,
            raw.hasPrefix(scheme)
        else { return nil }

        let params = parseQuery(String(raw.dropFirst(scheme.count)))

        guard
            let encoded     = params["d"],
            let destination = encoded.removingPercentEncoding,
            !destination.isEmpty,
            let tsStr = params["t"],
            let tsMs  = Double(tsStr)
        else { return nil }

        let writtenAt = Date(timeIntervalSince1970: tsMs / 1000)
        let age = Date().timeIntervalSince(writtenAt)
        guard age >= 0, age <= maxAge else {
            Logger.debug("Clipboard payload expired (age: \(Int(age))s)")
            return nil
        }

        // The destination is NOT trusted for navigation — only the clickId is forwarded to the
        // backend, which validates it and returns the authoritative destination. We keep the
        // string here purely for logging/diagnostics.
        let clickId = params["c"].flatMap { $0.isEmpty ? nil : $0 }
        Logger.debug("Clipboard payload accepted (age: \(Int(age))s, clickId: \(clickId ?? "-"))")
        return Payload(destination: destination, clickId: clickId)
    }

    /// Clears our payload from the pasteboard. Called only after the clickId was successfully
    /// consumed, and only if our payload is still there — never wipes user-copied content.
    @MainActor
    static func clear(pasteboard: any Pasteboard = UIPasteboard.general) {
        if pasteboard.string?.hasPrefix(scheme) == true {
            pasteboard.string = ""
        }
    }

    private static let scheme = "appredirect://"

    private static func parseQuery(_ query: String) -> [String: String] {
        query.split(separator: "&").reduce(into: [:]) { dict, pair in
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { return }
            dict[String(parts[0])] = String(parts[1])
        }
    }
}
