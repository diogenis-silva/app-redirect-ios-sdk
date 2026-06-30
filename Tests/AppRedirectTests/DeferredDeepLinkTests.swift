//
//  DeferredDeepLinkTests.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//
//  Covers first-open reliability (item 1) and clipboard → server validation (item 2).

import Testing
import UIKit
@testable import AppRedirect

@MainActor
struct DeferredDeepLinkTests {

    private func makeSDK(
        net: MockNetworking,
        storage: AppRedirectStorage,
        pasteboard: UIPasteboard,
        mode: DeferredDeepLinkMode = .fingerprintOnly,
        clipboardMaxAge: TimeInterval = 300,
        window: TimeInterval = 86_400
    ) -> AppRedirect {
        AppRedirect(
            config: TestEnv.config(deferredDeepLink: mode, clipboardMaxAge: clipboardMaxAge, firstOpenRetryWindow: window),
            networking: net,
            storage: storage,
            pasteboard: pasteboard
        )
    }

    private func clipboardPayload(clickId: UUID) -> String {
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        return "appredirect://d=myapp%3A%2F%2Fhome&c=\(clickId.uuidString)&t=\(ts)"
    }

    // MARK: - Item 1: reliability

    @Test func successfulFirstOpenSavesAttributionAndMarksDone() async {
        let net = MockNetworking(firstOpen: .success(.fixture(attributionType: "probabilistic")))
        let storage = AppRedirectStorage(defaults: TestEnv.freshDefaults())
        let sdk = makeSDK(net: net, storage: storage, pasteboard: TestEnv.pasteboard())

        let result = await sdk.resolveDeferred()

        #expect(result?.source == .api)
        #expect(result?.attributionType == "probabilistic")
        #expect(storage.isFirstOpenDone)
        #expect(storage.savedAttribution != nil)
        #expect(await net.firstOpenCount == 1)
    }

    @Test func failedFirstOpenDoesNotMarkDoneSoItRetries() async {
        let net = MockNetworking(firstOpen: .failure)
        let storage = AppRedirectStorage(defaults: TestEnv.freshDefaults())
        let sdk = makeSDK(net: net, storage: storage, pasteboard: TestEnv.pasteboard())

        let first = await sdk.resolveDeferred()
        #expect(first == nil)
        #expect(storage.isFirstOpenDone == false)   // <- the core fix: not lost on network failure
        #expect(storage.savedAttribution == nil)

        // Network recovers on the next launch → attribution is resolved.
        await net.setFirstOpen(.success(.fixture()))
        let second = await sdk.resolveDeferred()
        #expect(second != nil)
        #expect(storage.isFirstOpenDone)
        #expect(await net.firstOpenCount == 2)
    }

    @Test func alreadyResolvedReturnsSavedWithoutHittingNetwork() async {
        let net = MockNetworking()
        let storage = AppRedirectStorage(defaults: TestEnv.freshDefaults())
        storage.isFirstOpenDone = true
        let saved = DeepLinkResult(
            hasDeepLink: true, destination: "app://saved", attributionType: "deterministic",
            confidence: 100, deepLinkId: UUID(), clickId: UUID(), params: [:], source: .api
        )
        storage.savedAttribution = saved
        let sdk = makeSDK(net: net, storage: storage, pasteboard: TestEnv.pasteboard())

        let result = await sdk.resolveDeferred()

        #expect(result?.destination == "app://saved")
        #expect(await net.firstOpenCount == 0)
    }

    @Test func givesUpAfterRetryWindowElapses() async {
        let net = MockNetworking()
        let defaults = TestEnv.freshDefaults()
        defaults.set(Date.distantPast, forKey: "ar.installDate")   // install far in the past
        let storage = AppRedirectStorage(defaults: defaults)
        let sdk = makeSDK(net: net, storage: storage, pasteboard: TestEnv.pasteboard(), window: 86_400)

        let result = await sdk.resolveDeferred()

        #expect(result == nil)
        #expect(storage.isFirstOpenDone)            // stop retrying forever
        #expect(await net.firstOpenCount == 0)      // never even called the network
    }

    // MARK: - Item 2: clipboard validated server-side (opt-in mode)

    @Test func clipboardClickIdIsForwardedAndClearedOnSuccess() async {
        let clickId = UUID()
        let pasteboard = TestEnv.pasteboard()
        pasteboard.string = clipboardPayload(clickId: clickId)

        let net = MockNetworking(firstOpen: .success(.fixture()))
        let storage = AppRedirectStorage(defaults: TestEnv.freshDefaults())
        let sdk = makeSDK(net: net, storage: storage, pasteboard: pasteboard, mode: .clipboardAndFingerprint)

        let result = await sdk.resolveDeferred()

        #expect(result?.source == .clipboard)
        #expect(await net.lastFirstOpenPayload?.clickId == clickId.uuidString)
        #expect(pasteboard.string?.hasPrefix("appredirect://") != true)   // cleared after success
    }

    @Test func clipboardSurvivesFailedFirstOpenForRetry() async {
        let clickId = UUID()
        let pasteboard = TestEnv.pasteboard()
        pasteboard.string = clipboardPayload(clickId: clickId)

        let net = MockNetworking(firstOpen: .failure)
        let storage = AppRedirectStorage(defaults: TestEnv.freshDefaults())
        let sdk = makeSDK(net: net, storage: storage, pasteboard: pasteboard, mode: .clipboardAndFingerprint)

        let result = await sdk.resolveDeferred()

        #expect(result == nil)
        #expect(storage.isFirstOpenDone == false)
        #expect(pasteboard.string?.hasPrefix("appredirect://") == true)   // not cleared
    }

    @Test func fingerprintOnlyModeNeverReadsClipboard() async {
        // Default mode: a payload is present but must be ignored — no clickId forwarded,
        // source is .api, and the clipboard is left untouched (no read, no prompt, no clear).
        let pasteboard = TestEnv.pasteboard()
        pasteboard.string = clipboardPayload(clickId: UUID())

        let net = MockNetworking(firstOpen: .success(.fixture()))
        let storage = AppRedirectStorage(defaults: TestEnv.freshDefaults())
        let sdk = makeSDK(net: net, storage: storage, pasteboard: pasteboard, mode: .fingerprintOnly)

        let result = await sdk.resolveDeferred()

        #expect(result?.source == .api)
        #expect(await net.lastFirstOpenPayload?.clickId == nil)
        #expect(pasteboard.string?.hasPrefix("appredirect://") == true)   // untouched
    }
}
