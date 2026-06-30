//
//  ExampleApp.swift
//  ExampleApp
//
//  Created by Diógenis Silva on 12/06/26.
//

import SwiftUI
import AppRedirect

@main
struct ExampleApp: App
{
    @StateObject private var store = DeepLinkStore()
    
    var body: some Scene
    {
        WindowGroup
        {
            ContentView()
                .environmentObject(store)
                .task {
                    // Configure + resolve the deferred deep link once, on launch.
                    await store.bootstrap()
                }
                .onOpenURL { url in
                    // Custom URL scheme (e.g. exampleapp://produto/42) while running.
                    store.note("onOpenURL → \(url.absoluteString)")
                    _ = AppRedirect.handleOpenURL(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    // Universal Links while running.
                    store.note("universalLink → \(activity.webpageURL?.absoluteString ?? "?")")
                    _ = AppRedirect.handleUserActivity(activity)
                }
        }
    }
}
