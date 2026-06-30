//
//  AppRedirectStorage.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import Foundation

final class AppRedirectStorage {

    private let defaults: UserDefaults

    // Double optional: `.none` means "not loaded yet", `.some(nil)` means "loaded, no attribution".
    // Avoids decoding from UserDefaults on every access.
    private var cachedAttribution: DeepLinkResult??

    private enum Keys {
        static let isFirstOpenDone  = "ar.isFirstOpenDone"
        static let savedAttribution = "ar.savedAttribution"
        static let installDate      = "ar.installDate"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Keys.installDate) == nil {
            defaults.set(Date(), forKey: Keys.installDate)
        }
    }

    var isFirstOpenDone: Bool {
        get { defaults.bool(forKey: Keys.isFirstOpenDone) }
        set { defaults.set(newValue, forKey: Keys.isFirstOpenDone) }
    }

    var installDate: Date {
        defaults.object(forKey: Keys.installDate) as? Date ?? Date()
    }

    var savedAttribution: DeepLinkResult? {
        get {
            if let cached = cachedAttribution { return cached }
            let value: DeepLinkResult?
            if let data = defaults.data(forKey: Keys.savedAttribution) {
                value = try? JSONDecoder().decode(DeepLinkResult.self, from: data)
            } else {
                value = nil
            }
            cachedAttribution = .some(value)
            return value
        }
        set {
            cachedAttribution = .some(newValue)
            guard let value = newValue,
                  let data = try? JSONEncoder().encode(value) else {
                defaults.removeObject(forKey: Keys.savedAttribution)
                return
            }
            defaults.set(data, forKey: Keys.savedAttribution)
        }
    }

    /// Clears attribution state (e.g. on logout). Keeps `installDate`.
    func reset() {
        defaults.removeObject(forKey: Keys.isFirstOpenDone)
        defaults.removeObject(forKey: Keys.savedAttribution)
        cachedAttribution = .some(nil)
    }
}
