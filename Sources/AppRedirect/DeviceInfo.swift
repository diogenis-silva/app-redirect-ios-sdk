//
//  DeviceInfo.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import UIKit

struct DeviceInfo: Sendable {
    let platform: String
    let appVersion: String?
    let osVersion: String?
    let deviceModel: String?
    let language: String?
    let timezone: String?
    let screenWidth: Int?
    let screenHeight: Int?
    let screenScale: Double?

    @MainActor
    static func collect() -> DeviceInfo {
        // UIScreen.main is deprecated in iOS 16 — no scene-agnostic replacement exists
        // for SDK contexts that do not own the window hierarchy.
        let screen = UIScreen.main
        let bounds = screen.bounds

        return DeviceInfo(
            platform: "ios",
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            osVersion: UIDevice.current.systemVersion,
            deviceModel: hardwareIdentifier(),
            language: Locale.preferredLanguages.first,
            timezone: TimeZone.current.identifier,
            screenWidth: Int(bounds.width),
            screenHeight: Int(bounds.height),
            screenScale: Double(screen.scale)   // browser equivalent: window.devicePixelRatio
        )
    }

    func toPayload(
        clickId: String? = nil,
        installedAt: Date? = nil,
        idfa: String? = nil
    ) -> FirstOpenPayload {
        FirstOpenPayload(
            platform: platform,
            appVersion: appVersion,
            osVersion: osVersion,
            deviceModel: deviceModel,
            language: language,
            timezone: timezone,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
            screenScale: screenScale,
            idfa: idfa,
            installReferrer: nil,
            clickId: clickId,
            installedAt: installedAt
        )
    }

    private static func hardwareIdentifier() -> String? {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]
        #else
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        #endif
    }
}
