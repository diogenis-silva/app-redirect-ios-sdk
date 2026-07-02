//
//  AppRedirect.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import UIKit

@MainActor
public final class AppRedirect {

    // MARK: - Singleton

    public static private(set) var shared: AppRedirect?

    /// Call once in `application(_:didFinishLaunchingWithOptions:)` before any other SDK method.
    ///
    /// Callable from any isolation context (`nonisolated`). When invoked on the main thread it runs
    /// synchronously, so `shared` is set by the time this returns; off the main thread it hops.
    ///
    /// - Parameter deferredDeepLink: attribution strategy. Defaults to `.fingerprintOnly`, which
    ///   never reads the clipboard (no iOS paste prompt). Use `.clipboardAndFingerprint` for higher
    ///   accuracy at the cost of one paste prompt on first launch.
    /// - Parameter delegate: optional runtime deep-link delegate, set atomically with configuration
    ///   so callers never touch `shared` from a non-main context.
    /// - Parameter linkDomains: App Redirect link domains (e.g. `ntxlvl.fernandagazzotto.com.br`).
    ///   A live Universal Link whose host matches one of these is resolved against the backend so
    ///   the SDK can hand back the configured destination even when the app was already installed.
    nonisolated public static func configure(
        apiKey: String,
        baseURL: URL,
        deferredDeepLink: DeferredDeepLinkMode = .fingerprintOnly,
        linkDomains: Set<String> = [],
        logLevel: LogLevel = .none,
        delegate: sending (any AppRedirectDelegate)? = nil
    ) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                _configure(apiKey: apiKey, baseURL: baseURL, deferredDeepLink: deferredDeepLink,
                           linkDomains: linkDomains, logLevel: logLevel, delegate: delegate)
            }
        } else {
            Task { @MainActor in
                _configure(apiKey: apiKey, baseURL: baseURL, deferredDeepLink: deferredDeepLink,
                           linkDomains: linkDomains, logLevel: logLevel, delegate: delegate)
            }
        }
    }

    @MainActor
    private static func _configure(
        apiKey: String,
        baseURL: URL,
        deferredDeepLink: DeferredDeepLinkMode,
        linkDomains: Set<String>,
        logLevel: LogLevel,
        delegate: sending (any AppRedirectDelegate)?
    ) {
        Logger.level = logLevel
        let config = AppRedirectConfig(
            apiKey: apiKey,
            baseURL: baseURL,
            logLevel: logLevel,
            deferredDeepLink: deferredDeepLink,
            linkDomains: linkDomains
        )
        let instance = AppRedirect(config: config)
        instance.delegate = delegate
        shared = instance
        instance.queue.flush()   // resend anything stranded from a previous session
        Logger.debug("SDK configured — baseURL: \(baseURL)")
    }

    /// Sets (or clears) the runtime deep-link delegate. `nonisolated` — hops to the main actor
    /// internally. Prefer the `delegate:` parameter of `configure` when possible.
    nonisolated public static func setDelegate(_ delegate: sending (any AppRedirectDelegate)?) {
        Task { @MainActor in shared?.delegate = delegate }
    }

    /// Clears local attribution state (e.g. on user logout). The next
    /// `checkDeferredDeepLink` will resolve attribution from scratch.
    nonisolated public static func reset() {
        Task { @MainActor in shared?.storage.reset() }
    }

    // MARK: - Public properties

    public weak var delegate: AppRedirectDelegate?

    // MARK: - Private state

    private let config: AppRedirectConfig
    private let client: any Networking
    private let storage: AppRedirectStorage
    private let queue: EventQueue
    private let pasteboard: any Pasteboard

    // In-memory de-duplication of app-open within a single foreground transition.
    private var lastAppOpenAt: Date?
    private var lastAppOpenClickId: UUID?
    private static let appOpenDebounce: TimeInterval = 2.0

    private convenience init(config: AppRedirectConfig) {
        self.init(
            config: config,
            networking: AppRedirectClient(config: config),
            storage: AppRedirectStorage()
        )
    }

    // Designated initializer — dependencies injected so the orchestration can be unit-tested.
    init(
        config: AppRedirectConfig,
        networking: any Networking,
        storage: AppRedirectStorage,
        pasteboard: any Pasteboard = UIPasteboard.general
    ) {
        self.config = config
        self.client = networking
        self.storage = storage
        self.queue = EventQueue(networking: networking)
        self.pasteboard = pasteboard
    }

    // MARK: - Deferred Deep Link

    /// Resolves the deferred deep link on first launch.
    /// Forwards the clipboard `clickId` (when present) to the backend, which validates it and
    /// returns the authoritative attribution; otherwise falls back to server-side fingerprinting.
    /// Idempotent once resolved; retries transparently on transient failure until resolved.
    nonisolated public static func checkDeferredDeepLink() async -> DeepLinkResult? {
        guard let sdk = await MainActor.run(body: { shared }) else {
            Logger.debug("checkDeferredDeepLink called before configure()")
            return nil
        }
        return await sdk.resolveDeferred()
    }

    /// Callback-based wrapper for `checkDeferredDeepLink()`.
    /// The completion is always called on the main thread.
    nonisolated public static func checkDeferredDeepLink(
        completion: @escaping @MainActor (DeepLinkResult?) -> Void
    ) {
        Task { @MainActor in
            completion(await checkDeferredDeepLink())
        }
    }

    // MARK: - App Open

    /// Call in `sceneDidBecomeActive` or `applicationDidBecomeActive` on every launch.
    nonisolated public static func trackAppOpen() {
        Task { @MainActor in
            guard let sdk = shared else { return }
            sdk.queue.flush()
            sdk.recordAppOpen(clickId: nil, deepLinkId: nil, source: nil, url: nil)
        }
    }

    // MARK: - Universal Links

    /// Call in `scene(_:willConnectTo:options:)` and `scene(_:continue:)`.
    /// `nonisolated` — the Sendable `URL` is extracted synchronously and handling is dispatched
    /// to the main actor, so callers never need a `Task { @MainActor }` wrapper.
    nonisolated public static func handleUserActivity(_ activity: NSUserActivity) {
        guard activity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = activity.webpageURL else { return }
        Task { @MainActor in shared?.handleIncoming(url: url, source: .universalLink) }
    }

    // MARK: - Custom URL Scheme

    /// Call in `application(_:open:options:)`. `nonisolated` — `URL` is `Sendable`, so handling is
    /// dispatched to the main actor without any caller-side wrapping.
    nonisolated public static func handleOpenURL(_ url: URL) {
        Task { @MainActor in shared?.handleIncoming(url: url, source: .urlScheme) }
    }

    // MARK: - Event Tracking

    /// Tracks a custom event optionally attributed to the last resolved deep link.
    /// The non-`Sendable` `[String: Any]` is converted to a `Sendable` snapshot before the hop.
    nonisolated public static func track(_ event: String, properties: [String: Any]? = nil) {
        let json = properties?.toJSONValues()
        Task { @MainActor in
            guard let sdk = shared else {
                Logger.debug("track called before configure()")
                return
            }
            sdk.fireEvent(name: event, properties: json, revenue: nil)
        }
    }

    /// Convenience overload for revenue events.
    nonisolated public static func track(_ event: String, revenue: Decimal) {
        Task { @MainActor in
            guard let sdk = shared else { return }
            sdk.fireEvent(name: event, properties: nil, revenue: revenue)
        }
    }
}

// MARK: - Internal implementation (also the unit-test surface)

extension AppRedirect {

    func resolveDeferred() async -> DeepLinkResult? {
        guard !storage.isFirstOpenDone else {
            Logger.debug("Deferred deep link already resolved — returning saved attribution")
            return storage.savedAttribution
        }

        // Stop retrying after the install window so a permanently offline device doesn't
        // hammer first-open forever.
        guard Date().timeIntervalSince(storage.installDate) <= config.firstOpenRetryWindow else {
            Logger.debug("first-open retry window elapsed — giving up")
            storage.isFirstOpenDone = true
            return nil
        }

        // The clipboard supplies a high-confidence clickId; the destination is never trusted here.
        // Only read it when the integrator opted in — otherwise iOS would show a paste prompt.
        let clipboard = config.deferredDeepLink == .clipboardAndFingerprint
            ? ClipboardChecker.check(maxAge: config.clipboardMaxAge, pasteboard: pasteboard)
            : nil
        let payload = DeviceInfo.collect().toPayload(
            clickId: clipboard?.clickId,
            installedAt: storage.installDate
        )

        do {
            let response = try await client.firstOpen(payload)
            let source: DeepLinkSource = clipboard?.clickId != nil ? .clipboard : .api
            let result = response.toDeepLinkResult(source: source)

            storage.savedAttribution = result
            storage.isFirstOpenDone = true            // mark done only after a real resolution
            if clipboard != nil { ClipboardChecker.clear(pasteboard: pasteboard) }

            Logger.debug("Attribution: type=\(result.attributionType ?? "none"), source=\(source.rawValue), confidence=\(result.confidence.map { String($0) } ?? "-")")
            return result
        } catch {
            // Leave isFirstOpenDone == false so the next launch retries.
            Logger.debug("first-open failed (will retry next launch): \(error)")
            return nil
        }
    }

    func handleIncoming(url: URL, source: DeepLinkSource) {
        let params = queryParams(from: url)
        let clickId    = uuid(params["clickId"]) ?? uuid(params["c"])
        let deepLinkId = uuid(params["deepLinkId"]) ?? uuid(params["dl"])

        // A live Universal Link for an already-installed app carries no inline identifiers and the
        // redirect web page never ran — so the destination lives only on the backend. Resolve it.
        if clickId == nil, deepLinkId == nil, isAppRedirectDomain(url) {
            Task { await resolveAndDeliver(url: url, source: source) }
            return
        }

        let result = DeepLinkResult(
            hasDeepLink: true,
            destination: url.absoluteString,
            attributionType: source.rawValue,
            confidence: nil,
            deepLinkId: deepLinkId,
            clickId: clickId,
            params: params,
            source: source
        )

        // A direct click carrying identifiers is a fresh re-engagement attribution;
        // persist it so subsequent events attribute to this link.
        if clickId != nil || deepLinkId != nil {
            storage.savedAttribution = result
        }

        delegate?.appRedirect(self, didReceiveDeepLink: result)
        recordAppOpen(clickId: clickId, deepLinkId: deepLinkId, source: source, url: url.absoluteString)
    }

    /// Resolves a live Universal Link against the backend and delivers the configured destination.
    /// On failure it logs and records a generic app-open, without routing the user to a wrong screen.
    func resolveAndDeliver(url: URL, source: DeepLinkSource) async {
        let device = DeviceInfo.collect()
        let payload = ResolvePayload(
            url: url.absoluteString,
            platform: device.platform,
            appVersion: device.appVersion,
            osVersion: device.osVersion,
            deviceModel: device.deviceModel,
            language: device.language
        )

        do {
            let response = try await client.resolve(payload)
            guard response.hasDeepLink else {
                Logger.debug("resolve: no deep link for \(url.absoluteString)")
                recordAppOpen(clickId: nil, deepLinkId: nil, source: source, url: url.absoluteString)
                return
            }

            let result = response.toDeepLinkResult(source: source)
            storage.savedAttribution = result

            recordAppOpen(clickId: result.clickId, deepLinkId: result.deepLinkId,
                          source: source, url: url.absoluteString)
            delegate?.appRedirect(self, didReceiveDeepLink: result)
        } catch {
            Logger.debug("resolve failed for \(url.absoluteString): \(error)")
            recordAppOpen(clickId: nil, deepLinkId: nil, source: source, url: url.absoluteString)
        }
    }

    /// Whether the URL host belongs to a configured App Redirect link domain (suffix match, so
    /// `www.` and other subdomains of a configured domain are also covered).
    func isAppRedirectDomain(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(), !config.linkDomains.isEmpty else { return false }
        return config.linkDomains.contains { domain in
            let d = domain.lowercased()
            return host == d || host.hasSuffix("." + d)
        }
    }

    func recordAppOpen(clickId: UUID?, deepLinkId: UUID?, source: DeepLinkSource?, url: String?) {
        guard registerAppOpenIfAllowed(now: Date(), clickId: clickId) else { return }

        let attribution = storage.savedAttribution
        let payload = AppOpenPayload(
            platform: "ios",
            appVersion: DeviceInfo.collect().appVersion,
            deepLinkId: deepLinkId ?? attribution?.deepLinkId,
            clickId: clickId ?? attribution?.clickId,
            source: source?.rawValue,
            url: url,
            openedAt: Date()
        )
        sendOrQueue(path: "mobile/v1/app-open", payload: payload)
    }

    func fireEvent(name: String, properties: [String: JSONValue]?, revenue: Decimal?) {
        let attribution = storage.savedAttribution
        let payload = TrackEventPayload(
            eventName: name,
            deepLinkId: attribution?.deepLinkId,
            clickId: attribution?.clickId,
            occurredAt: Date(),
            properties: properties,
            revenue: revenue
        )
        sendOrQueue(path: "mobile/v1/events", payload: payload)
    }

    /// Sends a payload, queuing it for retry on failure so it survives offline/crash.
    func sendOrQueue<T: Encodable>(path: String, payload: T) {
        guard let data = try? AppRedirectClient.encoder.encode(payload) else {
            Logger.debug("Failed to encode payload for \(path)")
            return
        }
        Task {
            do {
                try await client.send(path: path, bodyData: data)
            } catch {
                queue.enqueue(path: path, body: data)
            }
        }
    }

    /// Decides whether an app-open should be sent and records it if so.
    /// Skips a redundant open within the debounce window, but always lets a clickId-bearing
    /// open through so link attribution is never swallowed by a generic lifecycle open.
    @discardableResult
    func registerAppOpenIfAllowed(now: Date, clickId: UUID?) -> Bool {
        if let last = lastAppOpenAt,
           now.timeIntervalSince(last) < Self.appOpenDebounce,
           clickId == nil || clickId == lastAppOpenClickId {
            return false
        }
        lastAppOpenAt = now
        lastAppOpenClickId = clickId
        return true
    }

    func queryParams(from url: URL) -> [String: String] {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            return [:]
        }
        return items.reduce(into: [:]) { dict, item in
            if let value = item.value { dict[item.name] = value }
        }
    }

    func uuid(_ string: String?) -> UUID? {
        string.flatMap(UUID.init(uuidString:))
    }
}
