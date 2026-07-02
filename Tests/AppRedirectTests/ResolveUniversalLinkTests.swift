//
//  ResolveUniversalLinkTests.swift
//  App Redirect
//
//  Created by Diógenis Silva on 01/07/2026.
//
//  Covers live Universal Link resolution for an already-installed app: the redirect web page
//  never runs, so the SDK must resolve the link against the backend instead of echoing the URL.
//

import Testing
import UIKit
@testable import AppRedirect

@MainActor
final class DelegateSpy: AppRedirectDelegate {
    private(set) var received: [DeepLinkResult] = []
    func appRedirect(_ sdk: AppRedirect, didReceiveDeepLink result: DeepLinkResult) {
        received.append(result)
    }
}

@MainActor
struct ResolveUniversalLinkTests {

    private let linkDomain = "ntxlvl.fernandagazzotto.com.br"

    private func makeSDK(net: MockNetworking, storage: AppRedirectStorage) -> AppRedirect {
        AppRedirect(
            config: TestEnv.config(linkDomains: [linkDomain]),
            networking: net,
            storage: storage
        )
    }

    // MARK: - Domain matching

    @Test func domainMatchingCoversHostAndSubdomains() {
        let net = MockNetworking()
        let sdk = makeSDK(net: net, storage: AppRedirectStorage(defaults: TestEnv.freshDefaults()))

        #expect(sdk.isAppRedirectDomain(URL(string: "https://\(linkDomain)/download")!))
        #expect(sdk.isAppRedirectDomain(URL(string: "https://www.\(linkDomain)/download")!))
        #expect(sdk.isAppRedirectDomain(URL(string: "https://outrodominio.com.br/download")! ) == false)
    }

    @Test func noLinkDomainsConfiguredNeverResolves() {
        let sdk = AppRedirect(
            config: TestEnv.config(linkDomains: []),
            networking: MockNetworking(),
            storage: AppRedirectStorage(defaults: TestEnv.freshDefaults())
        )
        #expect(sdk.isAppRedirectDomain(URL(string: "https://\(linkDomain)/download")!) == false)
    }

    // MARK: - Resolution delivery

    @Test func liveUniversalLinkResolvesConfiguredDestination() async {
        let deepLinkId = UUID()
        let clickId = UUID()
        let net = MockNetworking(resolve: .success(.fixture(
            destination: "myapp://product/42", deepLinkId: deepLinkId, clickId: clickId)))
        let storage = AppRedirectStorage(defaults: TestEnv.freshDefaults())
        let sdk = makeSDK(net: net, storage: storage)
        let spy = DelegateSpy()
        sdk.delegate = spy

        await sdk.resolveAndDeliver(
            url: URL(string: "https://\(linkDomain)/download")!, source: .universalLink)

        #expect(await net.resolveCount == 1)
        #expect(spy.received.count == 1)
        // The delegate must receive the CONFIGURED destination, not the raw universal link URL.
        #expect(spy.received.first?.destination == "myapp://product/42")
        #expect(spy.received.first?.deepLinkId == deepLinkId)
        #expect(spy.received.first?.clickId == clickId)
        #expect(spy.received.first?.source == .universalLink)
        #expect(storage.savedAttribution?.destination == "myapp://product/42")
    }

    @Test func resolveWithoutDeepLinkDoesNotRouteNorPersist() async {
        let net = MockNetworking(resolve: .success(.fixture(hasDeepLink: false)))
        let storage = AppRedirectStorage(defaults: TestEnv.freshDefaults())
        let sdk = makeSDK(net: net, storage: storage)
        let spy = DelegateSpy()
        sdk.delegate = spy

        await sdk.resolveAndDeliver(
            url: URL(string: "https://\(linkDomain)/download")!, source: .universalLink)

        #expect(await net.resolveCount == 1)
        #expect(spy.received.isEmpty)
        #expect(storage.savedAttribution == nil)
    }

    @Test func resolveFailureDoesNotRouteToWrongScreen() async {
        let net = MockNetworking(resolve: .failure)
        let storage = AppRedirectStorage(defaults: TestEnv.freshDefaults())
        let sdk = makeSDK(net: net, storage: storage)
        let spy = DelegateSpy()
        sdk.delegate = spy

        await sdk.resolveAndDeliver(
            url: URL(string: "https://\(linkDomain)/download")!, source: .universalLink)

        #expect(spy.received.isEmpty)
        #expect(storage.savedAttribution == nil)
    }

    // MARK: - Inline identifiers bypass resolve

    @Test func urlWithInlineClickIdUsesInlinePathNotResolve() async {
        let net = MockNetworking()
        let storage = AppRedirectStorage(defaults: TestEnv.freshDefaults())
        let sdk = makeSDK(net: net, storage: storage)
        let spy = DelegateSpy()
        sdk.delegate = spy

        let clickId = UUID()
        sdk.handleIncoming(
            url: URL(string: "https://\(linkDomain)/download?c=\(clickId.uuidString)")!,
            source: .universalLink)

        // Inline path is synchronous: delegate already fired with the raw URL, no resolve call.
        #expect(spy.received.count == 1)
        #expect(spy.received.first?.clickId == clickId)
        #expect(await net.resolveCount == 0)
    }
}
