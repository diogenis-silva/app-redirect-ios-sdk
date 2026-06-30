//
//  JSONValue.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import Foundation

// Heterogeneous JSON value — avoids external AnyCodable dependency.
enum JSONValue: Codable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .number(let v): try container.encode(v)
        case .bool(let v):   try container.encode(v)
        case .null:          try container.encodeNil()
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Bool must be checked before Double — JSON true/false would decode as 1.0/0.0 otherwise.
        if let v = try? container.decode(Bool.self)   { self = .bool(v);   return }
        if let v = try? container.decode(Double.self) { self = .number(v); return }
        if let v = try? container.decode(String.self) { self = .string(v); return }
        self = .null
    }
}

extension Dictionary where Key == String, Value == Any {
    func toJSONValues() -> [String: JSONValue] {
        compactMapValues { value in
            switch value {
            case let v as Bool:   return .bool(v)
            case let v as Int:    return .number(Double(v))
            case let v as Double: return .number(v)
            case let v as Float:  return .number(Double(v))
            case let v as String: return .string(v)
            case is NSNull:       return .null
            default:              return nil
            }
        }
    }
}
