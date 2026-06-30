//
//  AppRedirectDelegate.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import Foundation

/// `@MainActor` because the SDK always invokes the delegate on the main actor (from
/// `handleUserActivity`/`handleOpenURL`) — this lets a `@MainActor` consumer (e.g. an
/// `ObservableObject`) conform without any cross-actor hops.
@MainActor
public protocol AppRedirectDelegate: AnyObject {
    /// Called when a Universal Link or Custom URL Scheme is received while the app is already running.
    func appRedirect(_ sdk: AppRedirect, didReceiveDeepLink result: DeepLinkResult)
}
