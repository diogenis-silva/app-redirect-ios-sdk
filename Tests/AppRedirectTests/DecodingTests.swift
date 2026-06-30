//
//  DecodingTests.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//
//  Covers the tolerant decoding (item 3): a contract drift must never wipe attribution.

import Testing
import Foundation
@testable import AppRedirect

struct FirstOpenResponseDecodingTests {

    private func decode(_ json: String) throws -> FirstOpenResponse {
        try JSONDecoder().decode(FirstOpenResponse.self, from: Data(json.utf8))
    }

    @Test func decodesFullPayload() throws {
        let r = try decode("""
        {
          "hasDeepLink": true,
          "attributionType": "deterministic",
          "confidence": 100,
          "destination": "myapp://p/1",
          "deepLinkId": "1B4E28BA-2FA1-11D2-883F-0016D3CCA427",
          "clickId": "1B4E28BA-2FA1-11D2-883F-0016D3CCA428",
          "params": { "utm_source": "ig" }
        }
        """)
        #expect(r.hasDeepLink)
        #expect(r.attributionType == "deterministic")
        #expect(r.confidence == 100)
        #expect(r.destination == "myapp://p/1")
        #expect(r.params["utm_source"] == "ig")
    }

    @Test func missingParamsDefaultsToEmptyDictionary() throws {
        let r = try decode(#"{ "hasDeepLink": false }"#)
        #expect(r.hasDeepLink == false)
        #expect(r.params.isEmpty)
        #expect(r.destination == nil)
        #expect(r.clickId == nil)
    }

    @Test func nullParamsDefaultsToEmptyDictionary() throws {
        let r = try decode(#"{ "hasDeepLink": true, "params": null }"#)
        #expect(r.params.isEmpty)
    }

    @Test func missingHasDeepLinkDefaultsToFalse() throws {
        let r = try decode("{}")
        #expect(r.hasDeepLink == false)
    }

    @Test func mapsToDeepLinkResultWithGivenSource() throws {
        let r = try decode(#"{ "hasDeepLink": true, "destination": "x://y" }"#)

        let clipboard = r.toDeepLinkResult(source: .clipboard)
        #expect(clipboard.source == .clipboard)
        #expect(clipboard.destination == "x://y")

        let api = r.toDeepLinkResult(source: .api)
        #expect(api.source == .api)
    }
}

struct DeepLinkResultDecodingTests {

    private func decode(_ json: String) throws -> DeepLinkResult {
        try JSONDecoder().decode(DeepLinkResult.self, from: Data(json.utf8))
    }

    @Test func roundTripsThroughEncodeDecode() throws {
        let original = DeepLinkResult(
            hasDeepLink: true,
            destination: "app://home",
            attributionType: "clipboard",
            confidence: 95,
            deepLinkId: UUID(),
            clickId: UUID(),
            params: ["k": "v"],
            source: .clipboard
        )
        let data = try JSONEncoder().encode(original)
        let back = try JSONDecoder().decode(DeepLinkResult.self, from: data)

        #expect(back.destination == original.destination)
        #expect(back.deepLinkId == original.deepLinkId)
        #expect(back.clickId == original.clickId)
        #expect(back.params == original.params)
        #expect(back.source == .clipboard)
    }

    @Test func toleratesMissingParamsAndSource() throws {
        // A result persisted by an older SDK that lacked these fields must still load.
        let r = try decode(#"{ "hasDeepLink": true, "destination": "app://x" }"#)
        #expect(r.hasDeepLink)
        #expect(r.params.isEmpty)
        #expect(r.source == .api)   // default
    }

    @Test func toleratesUnknownSourceByFallingBackToApi() throws {
        let r = try decode(#"{ "hasDeepLink": true, "source": "telepathy" }"#)
        #expect(r.source == .api)
    }
}
