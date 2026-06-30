//
//  AppRedirectError.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import Foundation

enum AppRedirectError: Error {
    case notConfigured
    case invalidResponse
    case httpError(statusCode: Int)
}
