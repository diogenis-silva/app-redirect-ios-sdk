//
//  JSONValueTests.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import Testing
import Foundation
@testable import AppRedirect

struct JSONValueTests {

    @Test func encodesEachCaseAsAJSONScalar() throws {
        let dict: [String: JSONValue] = [
            "s": .string("hi"),
            "n": .number(42),
            "b": .bool(true),
            "z": .null
        ]
        let data = try JSONEncoder().encode(dict)
        let back = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(back["s"] as? String == "hi")
        #expect(back["n"] as? Double == 42)
        #expect(back["b"] as? Bool == true)
        #expect(back["z"] is NSNull)
    }

    @Test func decodesBoolBeforeNumber() throws {
        // The critical ordering bug: JSON `true` must not decode as 1.0.
        let data = Data(#"{"v": true}"#.utf8)
        let decoded = try JSONDecoder().decode([String: JSONValue].self, from: data)
        guard case .bool(let value)? = decoded["v"] else {
            Issue.record("expected .bool, got \(String(describing: decoded["v"]))")
            return
        }
        #expect(value == true)
    }

    @Test func toJSONValuesMapsSupportedScalarTypes() {
        let input: [String: Any] = [
            "str": "x",
            "int": 7,
            "dbl": 1.5,
            "flt": Float(2.0),
            "bool": false,
            "null": NSNull()
        ]
        let out = input.toJSONValues()

        #expect(out.count == 6)
        if case .number(let n)? = out["int"] { #expect(n == 7) } else { Issue.record("int") }
        if case .number(let n)? = out["flt"] { #expect(n == 2.0) } else { Issue.record("flt") }
        if case .bool? = out["bool"] {} else { Issue.record("bool") }
        if case .null? = out["null"] {} else { Issue.record("null") }
    }

    @Test func toJSONValuesDropsUnsupportedTypes() {
        let input: [String: Any] = ["ok": "x", "bad": Date()]
        let out = input.toJSONValues()

        #expect(out.count == 1)
        #expect(out["bad"] == nil)
    }
}
