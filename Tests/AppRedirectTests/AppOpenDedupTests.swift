//
//  AppOpenDedupTests.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//
//  Covers app-open de-duplication (item 5).

import Testing
import Foundation
@testable import AppRedirect

@MainActor
struct AppOpenDedupTests {

    private func makeSDK() -> AppRedirect {
        AppRedirect(
            config: TestEnv.config(),
            networking: MockNetworking(),
            storage: AppRedirectStorage(defaults: TestEnv.freshDefaults())
        )
    }

    @Test func firstOpenIsAlwaysAllowed() {
        let sdk = makeSDK()
        #expect(sdk.registerAppOpenIfAllowed(now: Date(), clickId: nil))
    }

    @Test func genericOpenWithinDebounceIsDeduped() {
        let sdk = makeSDK()
        let t0 = Date()

        #expect(sdk.registerAppOpenIfAllowed(now: t0, clickId: nil))
        #expect(sdk.registerAppOpenIfAllowed(now: t0.addingTimeInterval(1), clickId: nil) == false)
    }

    @Test func openAfterDebounceWindowIsAllowed() {
        let sdk = makeSDK()
        let t0 = Date()

        #expect(sdk.registerAppOpenIfAllowed(now: t0, clickId: nil))
        #expect(sdk.registerAppOpenIfAllowed(now: t0.addingTimeInterval(3), clickId: nil))
    }

    @Test func clickIdBearingOpenPassesEvenRightAfterGenericOpen() {
        // A Universal Link open must not be swallowed by a just-fired lifecycle open.
        let sdk = makeSDK()
        let t0 = Date()

        #expect(sdk.registerAppOpenIfAllowed(now: t0, clickId: nil))
        #expect(sdk.registerAppOpenIfAllowed(now: t0.addingTimeInterval(0.1), clickId: UUID()))
    }

    @Test func sameClickIdWithinDebounceIsDeduped() {
        let sdk = makeSDK()
        let clickId = UUID()
        let t0 = Date()

        #expect(sdk.registerAppOpenIfAllowed(now: t0, clickId: clickId))
        #expect(sdk.registerAppOpenIfAllowed(now: t0.addingTimeInterval(0.5), clickId: clickId) == false)
    }
}
