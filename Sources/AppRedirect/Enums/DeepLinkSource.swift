//
//  DeepLinkSource.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import Foundation

public enum DeepLinkSource: String, Codable, Sendable {
    case clipboard
    case api
    case universalLink
    case urlScheme
}
