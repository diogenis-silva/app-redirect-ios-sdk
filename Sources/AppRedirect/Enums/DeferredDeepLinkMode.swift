//
//  DeferredDeepLinkMode.swift
//  App Redirect
//
//  Created by Diógenis Silva on 11/06/2026.
//

import Foundation

/// Strategy used to resolve the deferred deep link on first launch.
public enum DeferredDeepLinkMode: Sendable {

    /// Probabilistic fingerprint matching only. The SDK never reads the clipboard, so iOS
    /// shows no paste prompt. Lower attribution accuracy (~80%). Default — privacy-first,
    /// matching the default behavior of AppsFlyer/Singular.
    case fingerprintOnly

    /// Reads the clipboard for a deterministic `clickId` (validated server-side), then falls
    /// back to fingerprint matching. Higher accuracy (~95%) at the cost of one iOS paste
    /// prompt on first launch. Equivalent to Branch's opt-in `checkPasteboardOnInstall`.
    case clipboardAndFingerprint
}
