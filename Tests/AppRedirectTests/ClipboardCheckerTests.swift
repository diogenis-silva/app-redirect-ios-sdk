//
//  ClipboardCheckerTests.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import Testing
import UIKit
@testable import AppRedirect

@MainActor
struct ClipboardCheckerTests {

    // App-private pasteboard per test: no iOS paste prompt, no shared global state.
    private let pasteboard = UIPasteboard.withUniqueName()

    private func payload(destination: String, clickId: String?, ageSeconds: TimeInterval = 0) -> String {
        let ts = Int((Date().timeIntervalSince1970 - ageSeconds) * 1000)
        let encoded = destination.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? destination
        var s = "appredirect://d=\(encoded)&t=\(ts)"
        if let clickId { s += "&c=\(clickId)" }
        return s
    }

    @Test func acceptsFreshPayloadAndParsesClickId() {
        let clickId = UUID().uuidString
        pasteboard.string = payload(destination: "myapp://home", clickId: clickId)

        let result = ClipboardChecker.check(maxAge: 300, pasteboard: pasteboard)

        #expect(result?.destination == "myapp://home")
        #expect(result?.clickId == clickId)
    }

    @Test func ignoresForeignClipboardContent() {
        pasteboard.string = "just some text the user copied"
        #expect(ClipboardChecker.check(maxAge: 300, pasteboard: pasteboard) == nil)
    }

    @Test func rejectsExpiredPayload() {
        pasteboard.string = payload(destination: "myapp://home", clickId: UUID().uuidString, ageSeconds: 600)
        #expect(ClipboardChecker.check(maxAge: 300, pasteboard: pasteboard) == nil)
    }

    @Test func rejectsEmptyDestination() {
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        pasteboard.string = "appredirect://d=&c=\(UUID().uuidString)&t=\(ts)"
        #expect(ClipboardChecker.check(maxAge: 300, pasteboard: pasteboard) == nil)
    }

    @Test func missingClickIdYieldsNilClickId() {
        pasteboard.string = payload(destination: "myapp://home", clickId: nil)
        let result = ClipboardChecker.check(maxAge: 300, pasteboard: pasteboard)
        #expect(result?.destination == "myapp://home")
        #expect(result?.clickId == nil)
    }

    @Test func checkDoesNotClearOnRead() {
        // The clickId must survive a read so a failed first-open can retry next launch.
        pasteboard.string = payload(destination: "myapp://home", clickId: UUID().uuidString)
        _ = ClipboardChecker.check(maxAge: 300, pasteboard: pasteboard)
        #expect(pasteboard.string?.hasPrefix("appredirect://") == true)
    }

    @Test func clearWipesOnlyOurPayload() {
        pasteboard.string = payload(destination: "myapp://home", clickId: UUID().uuidString)
        ClipboardChecker.clear(pasteboard: pasteboard)
        #expect(pasteboard.string == "")
    }

    @Test func clearPreservesForeignContent() {
        pasteboard.string = "user's important copied text"
        ClipboardChecker.clear(pasteboard: pasteboard)
        #expect(pasteboard.string == "user's important copied text")
    }
}
