//
//  Logger.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import Foundation

enum Logger {
    // Written once during configure() — safe before any concurrent access begins.
    nonisolated(unsafe) static var level: LogLevel = .none

    static func debug(_ message: String) {
        guard level == .debug else { return }
        print("[AppRedirect] \(message)")
    }
}
