//
//  AppRedirectStorageTests.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import Testing
import Foundation
@testable import AppRedirect

struct AppRedirectStorageTests {

    private func sample() -> DeepLinkResult {
        DeepLinkResult(
            hasDeepLink: true,
            destination: "app://home",
            attributionType: "deterministic",
            confidence: 100,
            deepLinkId: UUID(),
            clickId: UUID(),
            params: ["utm_source": "ig"],
            source: .api
        )
    }

    @Test func isFirstOpenDoneDefaultsToFalseAndPersists() {
        let defaults = TestEnv.freshDefaults()
        let storage = AppRedirectStorage(defaults: defaults)

        #expect(storage.isFirstOpenDone == false)
        storage.isFirstOpenDone = true
        #expect(storage.isFirstOpenDone)

        // A new storage over the same defaults sees the persisted flag.
        #expect(AppRedirectStorage(defaults: defaults).isFirstOpenDone)
    }

    @Test func savedAttributionRoundTrips() {
        let defaults = TestEnv.freshDefaults()
        let storage = AppRedirectStorage(defaults: defaults)
        let value = sample()

        storage.savedAttribution = value
        let loaded = AppRedirectStorage(defaults: defaults).savedAttribution

        #expect(loaded?.deepLinkId == value.deepLinkId)
        #expect(loaded?.clickId == value.clickId)
        #expect(loaded?.params == value.params)
    }

    @Test func settingNilRemovesAttribution() {
        let defaults = TestEnv.freshDefaults()
        let storage = AppRedirectStorage(defaults: defaults)

        storage.savedAttribution = sample()
        storage.savedAttribution = nil

        #expect(storage.savedAttribution == nil)
        #expect(AppRedirectStorage(defaults: defaults).savedAttribution == nil)
    }

    @Test func installDateIsStableAcrossInstances() {
        let defaults = TestEnv.freshDefaults()
        let first = AppRedirectStorage(defaults: defaults).installDate
        let second = AppRedirectStorage(defaults: defaults).installDate

        #expect(first == second)   // set once, never overwritten
    }

    @Test func resetClearsAttributionAndFlagButKeepsInstallDate() {
        let defaults = TestEnv.freshDefaults()
        let storage = AppRedirectStorage(defaults: defaults)
        let installDate = storage.installDate

        storage.isFirstOpenDone = true
        storage.savedAttribution = sample()

        storage.reset()

        #expect(storage.isFirstOpenDone == false)
        #expect(storage.savedAttribution == nil)
        #expect(storage.installDate == installDate)
    }
}
