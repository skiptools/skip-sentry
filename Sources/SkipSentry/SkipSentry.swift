// Copyright 2023–2026 Skip
// SPDX-License-Identifier: MPL-2.0
#if !SKIP_BRIDGE
import Foundation

#if !SKIP
import Sentry
#else
import io.sentry.Sentry
import io.sentry.SentryEvent
import io.sentry.SentryLevel
import io.sentry.Breadcrumb
// SKIP INSERT: import io.sentry.protocol.User
import io.sentry.android.core.SentryAndroid
import io.sentry.android.core.SentryAndroidOptions
#endif

// MARK: - SentryLevel

/// The severity level of a Sentry event.
public enum SkipSentryLevel: String {
    case debug
    case info
    case warning
    case error
    case fatal
}

// MARK: - SkipSentry

/// Cross-platform facade over the Sentry error tracking SDK for iOS and Android.
///
/// On iOS this wraps the [Sentry Cocoa SDK](https://docs.sentry.io/platforms/apple/guides/ios/).
/// On Android this wraps the [Sentry Android SDK](https://docs.sentry.io/platforms/android/).
public class SkipSentry {

    // MARK: Initialization

    /// Initialize the Sentry SDK with a DSN and optional debug flag.
    ///
    /// Call this early in your app's lifecycle, typically in your `App.init()`.
    ///
    /// - Parameters:
    ///   - dsn: Your Sentry DSN (e.g. `"https://examplePublicKey@o0.ingest.sentry.io/0"`).
    ///   - debug: Enable debug logging for Sentry internals.
    public static func start(dsn: String? = nil, debug: Bool = false) {
        #if !SKIP
        SentrySDK.start { options in
            options.dsn = dsn
            options.debug = debug
        }
        #else
        // SKIP INSERT: SentryAndroid.init(ProcessInfo.processInfo.androidContext) { options: io.sentry.SentryOptions ->
        // SKIP INSERT:     options.dsn = dsn
        // SKIP INSERT:     options.isDebug = debug
        // SKIP INSERT: }
        #endif
    }

    /// Initialize the Sentry SDK with full configuration.
    ///
    /// - Parameter configure: A closure that receives a `SkipSentryOptions` to configure.
    public static func start(configure: (SkipSentryOptions) -> Void) {
        let opts = SkipSentryOptions()
        configure(opts)
        #if !SKIP
        SentrySDK.start { options in
            if let dsn = opts.dsn { options.dsn = dsn }
            options.debug = opts.debug
            if let env = opts.environment { options.environment = env }
            if let rel = opts.release { options.releaseName = rel }
            if let dist = opts.dist { options.dist = dist }
            if let rate = opts.sampleRate { options.sampleRate = NSNumber(value: rate) }
            options.enableAutoSessionTracking = opts.enableAutoSessionTracking
            if let interval = opts.sessionTrackingIntervalMillis {
                options.sessionTrackingIntervalMillis = UInt(interval)
            }
            options.attachStacktrace = opts.attachStacktrace
            options.enableAppHangTracking = opts.enableAppHangTracking
        }
        #else
        // SKIP INSERT: SentryAndroid.init(ProcessInfo.processInfo.androidContext) { sentryOpts: io.sentry.SentryOptions ->
        // SKIP INSERT:     sentryOpts.dsn = opts.dsn
        // SKIP INSERT:     sentryOpts.isDebug = opts.debug
        // SKIP INSERT:     opts.environment?.let { sentryOpts.environment = it }
        // SKIP INSERT:     opts.release?.let { sentryOpts.release = it }
        // SKIP INSERT:     opts.dist?.let { sentryOpts.dist = it }
        // SKIP INSERT:     opts.sampleRate?.let { sentryOpts.sampleRate = it }
        // SKIP INSERT:     sentryOpts.isEnableAutoSessionTracking = opts.enableAutoSessionTracking
        // SKIP INSERT:     opts.sessionTrackingIntervalMillis?.let { sentryOpts.sessionTrackingIntervalMillis = it.toLong() }
        // SKIP INSERT:     sentryOpts.isAttachStacktrace = opts.attachStacktrace
        // SKIP INSERT: }
        #endif
    }

    /// Whether the Sentry SDK is currently initialized and enabled.
    public static var isEnabled: Bool {
        #if !SKIP
        SentrySDK.isEnabled
        #else
        Sentry.isEnabled()
        #endif
    }

    /// Close the Sentry SDK and release resources.
    public static func close() {
        #if !SKIP
        SentrySDK.close()
        #else
        Sentry.close()
        #endif
    }

    // MARK: Capturing Events

    /// Capture an error.
    public static func capture(error: Error) {
        #if !SKIP
        SentrySDK.capture(error: error)
        #else
        // SKIP INSERT: io.sentry.Sentry.captureException(java.lang.RuntimeException(error.description))
        #endif
    }

    /// Capture a message string.
    ///
    /// - Parameters:
    ///   - message: The message to send to Sentry.
    ///   - level: The severity level. Default is `.info`.
    public static func capture(message: String, level: SkipSentryLevel = .info) {
        #if !SKIP
        SentrySDK.capture(message: message)
        #else
        let _ = Sentry.captureMessage(message, toKotlinLevel(level))
        #endif
    }

    // MARK: Breadcrumbs

    /// Add a breadcrumb to the current scope.
    ///
    /// Breadcrumbs provide a trail of events that happened prior to an error.
    ///
    /// - Parameter message: A short description of the breadcrumb.
    public static func addBreadcrumb(message: String) {
        #if !SKIP
        let crumb = Sentry.Breadcrumb(level: .info, category: "default")
        crumb.message = message
        SentrySDK.addBreadcrumb(crumb)
        #else
        Sentry.addBreadcrumb(message)
        #endif
    }

    /// Add a breadcrumb with category and level.
    ///
    /// - Parameters:
    ///   - message: A short description of the breadcrumb.
    ///   - category: A dot-separated category string (e.g. `"ui.click"`, `"navigation"`).
    ///   - level: The severity level.
    public static func addBreadcrumb(message: String, category: String, level: SkipSentryLevel = .info) {
        #if !SKIP
        let crumb = Sentry.Breadcrumb(level: toiOSLevel(level), category: category)
        crumb.message = message
        SentrySDK.addBreadcrumb(crumb)
        #else
        let crumb = Breadcrumb()
        crumb.message = message
        crumb.category = category
        crumb.level = toKotlinLevel(level)
        Sentry.addBreadcrumb(crumb)
        #endif
    }

    /// Remove all breadcrumbs from the current scope.
    public static func clearBreadcrumbs() {
        #if !SKIP
        SentrySDK.configureScope { scope in
            scope.clearBreadcrumbs()
        }
        #else
        Sentry.clearBreadcrumbs()
        #endif
    }

    // MARK: User Context

    /// Set the current user for Sentry events.
    ///
    /// - Parameters:
    ///   - id: A unique user identifier.
    ///   - email: The user's email address.
    ///   - username: The user's display name.
    public static func setUser(id: String? = nil, email: String? = nil, username: String? = nil) {
        #if !SKIP
        let user = Sentry.User()
        user.userId = id
        user.email = email
        user.username = username
        SentrySDK.setUser(user)
        #else
        let user = User()
        user.id = id
        user.email = email
        user.username = username
        Sentry.setUser(user)
        #endif
    }

    /// Clear the current user from the Sentry scope.
    public static func clearUser() {
        #if !SKIP
        SentrySDK.setUser(nil)
        #else
        Sentry.setUser(nil)
        #endif
    }

    // MARK: Tags and Extras

    /// Set a tag on the current scope. Tags are indexed and searchable.
    ///
    /// - Parameters:
    ///   - key: The tag key.
    ///   - value: The tag value.
    public static func setTag(key: String, value: String) {
        #if !SKIP
        SentrySDK.configureScope { scope in
            scope.setTag(value: value, key: key)
        }
        #else
        Sentry.setTag(key, value)
        #endif
    }

    /// Remove a tag from the current scope.
    ///
    /// - Parameter key: The tag key to remove.
    public static func removeTag(key: String) {
        #if !SKIP
        SentrySDK.configureScope { scope in
            scope.removeTag(key: key)
        }
        #else
        Sentry.configureScope { scope in
            scope.removeTag(key)
        }
        #endif
    }

    /// Set an extra value on the current scope. Extras are not indexed but provide additional context.
    ///
    /// - Parameters:
    ///   - key: The extra key.
    ///   - value: The extra value.
    public static func setExtra(key: String, value: String) {
        #if !SKIP
        SentrySDK.configureScope { scope in
            scope.setExtra(value: value, key: key)
        }
        #else
        Sentry.setExtra(key, value)
        #endif
    }

    /// Set the severity level on the current scope.
    public static func setLevel(_ level: SkipSentryLevel) {
        #if !SKIP
        SentrySDK.configureScope { scope in
            scope.setLevel(toiOSLevel(level))
        }
        #else
        Sentry.setLevel(toKotlinLevel(level))
        #endif
    }

    // MARK: Flush

    /// Flush queued events to Sentry, blocking for up to `timeout` seconds.
    ///
    /// - Parameter timeout: Maximum time in seconds to wait. Default is 5.
    public static func flush(timeout: TimeInterval = 5.0) {
        #if !SKIP
        SentrySDK.flush(timeout: timeout)
        #else
        Sentry.flush(Long(timeout * 1000.0))
        #endif
    }

    // MARK: Crash Detection

    /// Whether the app crashed during the last run.
    public static var crashedLastRun: Bool {
        #if !SKIP
        SentrySDK.crashedLastRun
        #else
        Sentry.isCrashedLastRun() == true
        #endif
    }

    // MARK: Level Conversion Helpers

    #if !SKIP
    private static func toiOSLevel(_ level: SkipSentryLevel) -> Sentry.SentryLevel {
        switch level {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        case .fatal: return .fatal
        }
    }
    #else
    private static func toKotlinLevel(_ level: SkipSentryLevel) -> SentryLevel {
        switch level {
        case .debug: return SentryLevel.DEBUG
        case .info: return SentryLevel.INFO
        case .warning: return SentryLevel.WARNING
        case .error: return SentryLevel.ERROR
        case .fatal: return SentryLevel.FATAL
        }
    }
    #endif
}

// MARK: - SkipSentryOptions

/// Configuration options for initializing Sentry.
public class SkipSentryOptions {
    /// The Sentry DSN (Data Source Name).
    public var dsn: String?
    /// Enable debug logging.
    public var debug: Bool = false
    /// The environment name (e.g. "production", "staging").
    public var environment: String?
    /// The release version string.
    public var release: String?
    /// The distribution identifier.
    public var dist: String?
    /// Sample rate for error events (0.0 to 1.0). Default sends all events.
    public var sampleRate: Double?
    /// Whether to automatically track sessions.
    public var enableAutoSessionTracking: Bool = true
    /// Session tracking interval in milliseconds.
    public var sessionTrackingIntervalMillis: Int?
    /// Whether to attach stack traces to all events.
    public var attachStacktrace: Bool = true
    /// Whether to detect and report app hangs (iOS only).
    public var enableAppHangTracking: Bool = true

    public init() { }
}

#endif
