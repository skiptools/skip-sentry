// Copyright 2023–2025 Skip
// SPDX-License-Identifier: LGPL-3.0-only WITH LGPL-3.0-linking-exception
#if !SKIP_BRIDGE
import Foundation

#if !SKIP
import Sentry
#else
import io.sentry.Sentry
import io.sentry.android.core.SentryAndroid
#endif

/// Abstracts the Sentry [iOS](https://docs.sentry.io/platforms/apple/guides/ios/usage/) and [Android](https://docs.sentry.io/platforms/android/) APIs.
public class SkipSentry {
    public static func start(dsn: String? = nil, debug: Bool) {
        #if !SKIP
        // https://docs.sentry.io/platforms/apple/guides/ios/configuration/options/
        SentrySDK.start { options in
            options.dsn = dsn // e.g.: "https://examplePublicKey@o0.ingest.sentry.io/0"
            options.debug = debug // Enabled debug when first installing is always helpful
        }
        #else
        // TODO

        // https://docs.sentry.io/platforms/android/configuration/manual-init/#manual-initialization
        //SentryAndroid.`init`(ProcessInfo.processInfo.androidContext) { options in
        //    options.dsn = dsn // e.g.: "https://examplePublicKey@o0.ingest.sentry.io/0"
        //    options.debug = debug // Enabled debug when first installing is always helpful
        //}
        #endif
    }

    public static func capture(error: Error) {
        #if !SKIP
        // https://docs.sentry.io/platforms/apple/guides/ios/usage/#capturing-errors
        SentrySDK.capture(error: error)
        #else
        // TODO

        //Sentry.captureException((error as? Throwable) ?? ErrorException(e))
        #endif
    }
}

#endif
