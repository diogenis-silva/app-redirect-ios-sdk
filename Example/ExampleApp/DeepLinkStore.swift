//
//  DeepLinkStore.swift
//  ExampleApp
//
//  Created by Diógenis Silva on 12/06/26.
//

import SwiftUI
import Combine
import AppRedirect

/// Bridges the AppRedirect SDK to SwiftUI: holds the resolved attribution, an activity log,
/// and acts as the runtime deep-link delegate.
@MainActor
final class DeepLinkStore: ObservableObject, AppRedirectDelegate {

    @Published var result: DeepLinkResult?
    @Published var status: String = "Iniciando…"
    @Published var log: [String] = []

    private static let baseURL = URL(string: "http://localhost:5129")!

    func bootstrap() async {
        AppRedirect.configure(
            apiKey: "dlk_example_replace_me",
            baseURL: Self.baseURL,
            // Troque para .fingerprintOnly para o comportamento padrão (sem prompt de colar).
            deferredDeepLink: .clipboardAndFingerprint,
            logLevel: .debug,
            delegate: self
        )
        note("configure(baseURL: \(Self.baseURL.absoluteString))")

        status = "Resolvendo deferred deep link…"
        let resolved = await AppRedirect.checkDeferredDeepLink()
        if let resolved, resolved.hasDeepLink {
            result = resolved
            status = "Atribuído via \(resolved.source.rawValue)"
            note("deferred → \(resolved.destination ?? "—") (\(resolved.source.rawValue))")
        } else {
            status = "Sem atribuição (ou já resolvido)"
            note("deferred → nenhum")
        }

        AppRedirect.trackAppOpen()
        note("trackAppOpen()")
    }

    func track(_ event: String) {
        AppRedirect.track(event, properties: ["screen": "home"])
        note("track(\(event))")
    }

    func trackRevenue() {
        AppRedirect.track("purchase", revenue: 49.90)
        note("track(purchase, revenue: 49.90)")
    }

    func reset() {
        AppRedirect.reset()
        result = nil
        status = "Atribuição resetada — relançar para reavaliar"
        note("reset()")
    }

    func note(_ message: String) {
        let stamp = Date().formatted(.dateTime.hour().minute().second())
        log.insert("\(stamp)  \(message)", at: 0)
    }

    // MARK: - AppRedirectDelegate (runtime links)

    func appRedirect(_ sdk: AppRedirect, didReceiveDeepLink result: DeepLinkResult) {
        self.result = result
        status = "Link em runtime via \(result.source.rawValue)"
        note("didReceiveDeepLink → \(result.destination ?? "—")")
    }
}
