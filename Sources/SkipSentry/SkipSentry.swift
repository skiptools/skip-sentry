// Copyright 2023–2026 Skip
// SPDX-License-Identifier: MPL-2.0

// Sentry Cocoa is a binary xcframework with no Android slice, so on a native
// (non-transpiled) Android build there is nothing to wrap and the module is empty.
#if !SKIP_BRIDGE
import Foundation

#if !SKIP
@preconcurrency import Sentry
#else
import io.sentry.Sentry
import io.sentry.SentryEvent
import io.sentry.SentryLevel
import io.sentry.Breadcrumb
import io.sentry.SentryLogLevel
import io.sentry.metrics.SentryMetricsParameters
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

/// The severity level of a structured Sentry log entry.
public enum SkipSentryLogLevel: String {
    case trace
    case debug
    case info
    case warn
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
        initSentryAndroid(dsn: dsn, debug: debug)
        #endif
    }

    /// Initialize the Sentry SDK with full configuration.
    ///
    /// - Parameter configure: A closure that receives a `SkipSentryOptions` to configure.
    public static func start(configure: @escaping (SkipSentryOptions) -> Void) {
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
            if let tracesRate = opts.tracesSampleRate { options.tracesSampleRate = NSNumber(value: tracesRate) }
            options.enableAutoSessionTracking = opts.enableAutoSessionTracking
            if let interval = opts.sessionTrackingIntervalMillis {
                options.sessionTrackingIntervalMillis = UInt(interval)
            }
            options.attachStacktrace = opts.attachStacktrace
            options.enableAppHangTracking = opts.enableAppHangTracking
            options.enableNetworkBreadcrumbs = opts.enableNetworkBreadcrumbs
            options.enableLogs = opts.enableLogs
            options.enableMetrics = opts.enableMetrics
            if let targets = opts.tracePropagationTargets { options.tracePropagationTargets = targets }
            let droppedHosts = opts.droppedFailedRequestHosts
            if !droppedHosts.isEmpty || opts.beforeSend != nil {
                options.beforeSend = { event in
                    if isDroppedFailedRequest(
                        exceptionType: event.exceptions?.first?.type,
                        requestURL: event.request?.url,
                        droppedHosts: droppedHosts
                    ) {
                        return nil
                    }
                    return Self.applyBeforeSend(opts, event)
                }
            }
        }
        #else
        initSentryAndroid(opts: opts)
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
    ///
    /// On Android, the error is converted to a Java `Throwable` using Skip's
    /// standard error bridging. If the error is already a `Throwable` (as is the
    /// case for most transpiled errors), it is used directly. Otherwise, it is
    /// wrapped with a descriptive message.
    ///
    /// - Parameters:
    ///   - error: The error to report.
    ///   - fingerprint: Optional stable grouping key. When non-nil, the event is
    ///     pinned to a dedicated Sentry issue via a single-element fingerprint,
    ///     so semantically-distinct failures that share a *generic* bridged
    ///     throwable (e.g. `SwiftJNI.ThrowableError`) get their own issue instead
    ///     of collapsing together — and repeated occurrences of the same failure
    ///     stay in one issue instead of fanning out. Mirrors iOS
    ///     `SentrySDK.capture(error:) { $0.setFingerprint([...]) }` and Android
    ///     `Sentry.captureException(t) { it.fingerprint = listOf(...) }`.
    public static func capture(error: Error, fingerprint: String? = nil) {
        #if !SKIP
        if let fingerprint {
            SentrySDK.capture(error: error) { scope in
                scope.setFingerprint([fingerprint])
            }
        } else {
            SentrySDK.capture(error: error)
        }
        #else
        // In Skip Lite, errors that originate from Java/Kotlin are already Throwable.
        // For pure Swift errors, we wrap in an Exception with the description.
        // SKIP INSERT: val throwable: Throwable = if (error is Throwable) error else Exception(error.localizedDescription)
        // SKIP INSERT: if (fingerprint != null) {
        // SKIP INSERT:     io.sentry.Sentry.captureException(throwable) { scope -> scope.setFingerprint(listOf(fingerprint)) }
        // SKIP INSERT: } else {
        // SKIP INSERT:     io.sentry.Sentry.captureException(throwable)
        // SKIP INSERT: }
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

    /// Capture a message event with per-event tags, extras and an explicit grouping fingerprint.
    ///
    /// - Parameters:
    ///   - message: The event message. Keep it free of dynamic values so events group together.
    ///   - level: The severity level.
    ///   - tags: Indexed, searchable key/values (keep them low-cardinality).
    ///   - extras: Non-indexed key/values shown on the event.
    ///   - fingerprint: Grouping fingerprint. Empty keeps Sentry's default grouping.
    public static func capture(
        message: String,
        level: SkipSentryLevel,
        tags: [String: String],
        extras: [String: String],
        fingerprint: [String]
    ) {
        #if !SKIP
        let event = Sentry.Event(level: toiOSLevel(level))
        event.message = SentryMessage(formatted: message)
        event.tags = tags
        event.extra = extras
        if !fingerprint.isEmpty { event.fingerprint = fingerprint }
        SentrySDK.capture(event: event)
        #else
        let kotlinLevel = toKotlinLevel(level)
        let hasFingerprint = !fingerprint.isEmpty
        // SKIP INSERT: val evt = io.sentry.SentryEvent()
        // SKIP INSERT: val msg = io.sentry.protocol.Message()
        // SKIP INSERT: msg.formatted = message
        // SKIP INSERT: evt.message = msg
        // SKIP INSERT: evt.level = kotlinLevel
        // SKIP INSERT: for ((k, v) in tags.kotlin(nocopy = true)) { evt.setTag(k as String, v as String) }
        // SKIP INSERT: for ((k, v) in extras.kotlin(nocopy = true)) { evt.setExtra(k as String, v as String) }
        // SKIP INSERT: if (hasFingerprint) { evt.fingerprints = fingerprint.kotlin(nocopy = true).map { it as String } }
        // SKIP INSERT: io.sentry.Sentry.captureEvent(evt)
        #endif
    }

    // MARK: Logs

    /// Send a structured log entry to Sentry Logs.
    ///
    /// No-op unless ``SkipSentryOptions/enableLogs`` was set at start.
    ///
    /// - Parameters:
    ///   - message: The log body.
    ///   - level: The log severity.
    ///   - attributes: Searchable key/values attached to the log entry.
    public static func log(_ message: String, level: SkipSentryLogLevel, attributes: [String: String] = [:]) {
        #if !SKIP
        let attrs: [String: Any] = attributes
        let logger = SentrySDK.logger
        switch level {
        case .trace: logger.trace(message, attributes: attrs)
        case .debug: logger.debug(message, attributes: attrs)
        case .info: logger.info(message, attributes: attrs)
        case .warn: logger.warn(message, attributes: attrs)
        case .error: logger.error(message, attributes: attrs)
        case .fatal: logger.fatal(message, attributes: attrs)
        }
        #else
        let kotlinLevel = toKotlinLogLevel(level)
        // SKIP INSERT: val map = java.util.HashMap<String, Any>()
        // SKIP INSERT: for ((k, v) in attributes.kotlin(nocopy = true)) { map[k as String] = v as String }
        // SKIP INSERT: val params = io.sentry.logger.SentryLogParameters.create(io.sentry.SentryAttributes.fromMap(map))
        // SKIP INSERT: io.sentry.Sentry.logger().log(kotlinLevel, params, message)
        #endif
    }

    // MARK: Metrics

    /// Increment a counter metric.
    ///
    /// - Parameters:
    ///   - key: The metric name.
    ///   - value: The amount to add. Negative values are clamped to 0.
    ///   - attributes: Key/values to slice the metric by.
    public static func count(_ key: String, value: Int = 1, attributes: [String: String] = [:]) {
        let amount = max(0, value)
        #if !SKIP
        SentrySDK.metrics.count(key: key, value: UInt(amount), attributes: nativeAttributes(attributes))
        #else
        let doubleAmount = Double(amount)
        // SKIP INSERT: io.sentry.Sentry.metrics().count(key, doubleAmount, null, metricParameters(attributes))
        #endif
    }

    /// Record one sample of a distribution metric.
    ///
    /// - Parameters:
    ///   - key: The metric name.
    ///   - value: The sample value.
    ///   - unit: A Sentry unit name such as `"millisecond"` or `"byte"`; `nil` for unitless.
    ///   - attributes: Key/values to slice the metric by.
    public static func distribution(_ key: String, value: Double, unit: String? = nil, attributes: [String: String] = [:]) {
        #if !SKIP
        SentrySDK.metrics.distribution(
            key: key,
            value: value,
            unit: unit.flatMap { SentryUnit(rawValue: $0) },
            attributes: nativeAttributes(attributes)
        )
        #else
        // SKIP INSERT: io.sentry.Sentry.metrics().distribution(key, value, unit, metricParameters(attributes))
        #endif
    }

    /// Record the current value of a gauge metric.
    ///
    /// - Parameters:
    ///   - key: The metric name.
    ///   - value: The current value.
    ///   - unit: A Sentry unit name such as `"millisecond"` or `"byte"`; `nil` for unitless.
    ///   - attributes: Key/values to slice the metric by.
    public static func gauge(_ key: String, value: Double, unit: String? = nil, attributes: [String: String] = [:]) {
        #if !SKIP
        SentrySDK.metrics.gauge(
            key: key,
            value: value,
            unit: unit.flatMap { SentryUnit(rawValue: $0) },
            attributes: nativeAttributes(attributes)
        )
        #else
        // SKIP INSERT: io.sentry.Sentry.metrics().gauge(key, value, unit, metricParameters(attributes))
        #endif
    }

    // MARK: Failed-request filtering

    /// Exception types the SDKs give their automatic failed-HTTP-request events
    /// (`SentryNetworkTracker` on iOS, the OkHttp integration on Android).
    static let failedRequestExceptionTypes: Set<String> = ["HTTPClientError", "SentryHttpClientException"]

    /// Whether an event is an automatic failed-request report for one of `droppedHosts` (or a subdomain).
    static func isDroppedFailedRequest(exceptionType: String?, requestURL: String?, droppedHosts: [String]) -> Bool {
        guard let exceptionType, failedRequestExceptionTypes.contains(exceptionType),
              let requestURL, let host = URL(string: requestURL)?.host else {
            return false
        }
        return droppedHosts.contains { host == $0 || host.hasSuffix("." + $0) }
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

    /// Add a breadcrumb with category, level, and structured data.
    ///
    /// - Parameters:
    ///   - message: A short description of the breadcrumb.
    ///   - category: A dot-separated category string (e.g. `"ui.click"`, `"navigation"`).
    ///   - level: The severity level.
    ///   - data: Additional key/value context attached to the breadcrumb.
    public static func addBreadcrumb(message: String, category: String, level: SkipSentryLevel = .info, data: [String: String]) {
        #if !SKIP
        let crumb = Sentry.Breadcrumb(level: toiOSLevel(level), category: category)
        crumb.message = message
        crumb.data = data
        SentrySDK.addBreadcrumb(crumb)
        #else
        let crumb = Breadcrumb()
        crumb.message = message
        crumb.category = category
        crumb.level = toKotlinLevel(level)
        for (key, value) in data {
            crumb.setData(key, value)
        }
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
    public static var crashedLastRun: Bool? {
        #if !SKIP
        SentrySDK.lastRunStatus == .didCrash ? true : SentrySDK.lastRunStatus == .didNotCrash ? false : nil
        #else
        Sentry.isCrashedLastRun()
        #endif
    }

    // MARK: - Private Helpers

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

    private static func nativeAttributes(_ attributes: [String: String]) -> [String: SentryAttributeValue] {
        var result: [String: SentryAttributeValue] = [:]
        for (key, value) in attributes { result[key] = value }
        return result
    }

    private static func fromiOSLevel(_ level: Sentry.SentryLevel) -> SkipSentryLevel? {
        switch level {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        case .fatal: return .fatal
        default: return nil // .none / unknown
        }
    }

    /// Map a native Cocoa `Event` into the bridgeable ``SkipSentryEvent`` wrapper,
    /// invoke the consumer's `beforeSend` hook, and either keep the original native
    /// event (hook returned non-nil) or drop it (hook returned nil). Wired into
    /// `Options.beforeSend` in `start(configure:)`.
    static func applyBeforeSend(_ opts: SkipSentryOptions, _ event: Sentry.Event) -> Sentry.Event? {
        guard let beforeSend = opts.beforeSend else { return event }
        var exceptions: [SkipSentryException] = []
        for exception in event.exceptions ?? [] {
            exceptions.append(SkipSentryException(type: exception.type, value: exception.value))
        }
        let wrapper = SkipSentryEvent(message: event.message?.formatted, level: fromiOSLevel(event.level), exceptions: exceptions)
        return beforeSend(wrapper) == nil ? nil : event
    }
    #else
    private static func toKotlinLogLevel(_ level: SkipSentryLogLevel) -> SentryLogLevel {
        switch level {
        case .trace: return SentryLogLevel.TRACE
        case .debug: return SentryLogLevel.DEBUG
        case .info: return SentryLogLevel.INFO
        case .warn: return SentryLogLevel.WARN
        case .error: return SentryLogLevel.ERROR
        case .fatal: return SentryLogLevel.FATAL
        }
    }

    private static func metricParameters(_ attributes: [String: String]) -> SentryMetricsParameters {
        // SKIP INSERT: val map = java.util.HashMap<String, Any>()
        // SKIP INSERT: for ((k, v) in attributes.kotlin(nocopy = true)) { map[k as String] = v as String }
        // SKIP INSERT: return io.sentry.metrics.SentryMetricsParameters.create(io.sentry.SentryAttributes.fromMap(map))
    }

    private static func toKotlinLevel(_ level: SkipSentryLevel) -> SentryLevel {
        switch level {
        case .debug: return SentryLevel.DEBUG
        case .info: return SentryLevel.INFO
        case .warning: return SentryLevel.WARNING
        case .error: return SentryLevel.ERROR
        case .fatal: return SentryLevel.FATAL
        }
    }

    private static func fromKotlinLevel(_ level: SentryLevel?) -> SkipSentryLevel? {
        guard let level = level else { return nil }
        if level == SentryLevel.DEBUG { return .debug }
        if level == SentryLevel.INFO { return .info }
        if level == SentryLevel.WARNING { return .warning }
        if level == SentryLevel.ERROR { return .error }
        if level == SentryLevel.FATAL { return .fatal }
        return nil
    }

    /// Map a native Android `SentryEvent` into the bridgeable ``SkipSentryEvent``
    /// wrapper, invoke the consumer's `beforeSend` hook, and either keep the
    /// original native event (hook returned non-nil) or drop it (hook returned nil).
    /// Wired into `SentryOptions.setBeforeSend` in `initSentryAndroid(opts:)`.
    static func applyBeforeSend(_ opts: SkipSentryOptions, _ event: SentryEvent) -> SentryEvent? {
        guard let beforeSend = opts.beforeSend else { return event }
        var exceptions: [SkipSentryException] = []
        for exception in event.exceptions ?? [] {
            exceptions.append(SkipSentryException(type: exception.type, value: exception.value))
        }
        let wrapper = SkipSentryEvent(message: event.message?.formatted, level: fromKotlinLevel(event.level), exceptions: exceptions)
        return beforeSend(wrapper) == nil ? nil : event
    }

    /// Convert a Swift Error to a Java Throwable using Skip's standard error bridging.
    /// In Skip Lite, Error types that originate from Java exceptions are already Throwable.
    /// For pure Swift errors, we wrap them in an Exception with the error description.
    /// Initialize SentryAndroid with simple DSN and debug options.
    /// This is a helper because `SentryAndroid.init` uses a Kotlin keyword
    /// that cannot be called directly from transpiled Swift.
    private static func initSentryAndroid(dsn: String?, debug: Bool) {
        // SKIP INSERT: SentryAndroid.init(ProcessInfo.processInfo.androidContext) { options ->
        // SKIP INSERT:     options.dsn = dsn
        // SKIP INSERT:     options.isDebug = debug
        // SKIP INSERT: }
    }

    /// Initialize SentryAndroid with full SkipSentryOptions.
    private static func initSentryAndroid(opts: SkipSentryOptions) {
        let droppedHosts = opts.droppedFailedRequestHosts
        let hasDroppedHosts = !droppedHosts.isEmpty
        // SKIP INSERT: SentryAndroid.init(ProcessInfo.processInfo.androidContext) { options ->
        // SKIP INSERT:     options.dsn = opts.dsn
        // SKIP INSERT:     options.isDebug = opts.debug
        // SKIP INSERT:     opts.environment?.let { options.environment = it }
        // SKIP INSERT:     opts.release?.let { options.release = it }
        // SKIP INSERT:     opts.dist?.let { options.dist = it }
        // SKIP INSERT:     opts.sampleRate?.let { options.sampleRate = it }
        // SKIP INSERT:     opts.tracesSampleRate?.let { options.tracesSampleRate = it }
        // SKIP INSERT:     options.isEnableAutoSessionTracking = opts.enableAutoSessionTracking
        // SKIP INSERT:     opts.sessionTrackingIntervalMillis?.let { options.sessionTrackingIntervalMillis = it.toLong() }
        // SKIP INSERT:     options.isAttachStacktrace = opts.attachStacktrace
        // SKIP INSERT:     options.isReportHistoricalTombstones = opts.isReportHistoricalTombstones
        // SKIP INSERT:     options.logs.isEnabled = opts.enableLogs
        // SKIP INSERT:     options.metrics.isEnabled = opts.enableMetrics
        // SKIP INSERT:     opts.tracePropagationTargets?.let { options.setTracePropagationTargets(it.kotlin(nocopy = true).map { t -> t as String }) }
        // SKIP INSERT:     if (hasDroppedHosts || opts.beforeSend != null) {
        // SKIP INSERT:         options.setBeforeSend { event, _ ->
        // SKIP INSERT:             if (isDroppedFailedRequest(event.exceptions?.firstOrNull()?.type, event.request?.url, droppedHosts)) null else applyBeforeSend(opts, event)
        // SKIP INSERT:         }
        // SKIP INSERT:     }
        // SKIP INSERT: }
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
    /// Sample rate for performance/tracing transactions (0.0 to 1.0). `nil`
    /// leaves tracing disabled. Mirrors iOS `Options.tracesSampleRate` and
    /// Android `SentryOptions.tracesSampleRate`.
    public var tracesSampleRate: Double?
    /// Whether to automatically track sessions.
    public var enableAutoSessionTracking: Bool = true
    /// Session tracking interval in milliseconds.
    public var sessionTrackingIntervalMillis: Int?
    /// Whether to attach stack traces to all events.
    public var attachStacktrace: Bool = true
    /// Whether to detect and report app hangs (iOS only).
    public var enableAppHangTracking: Bool = true
    /// Whether to record a breadcrumb for each HTTP request (iOS only). Each breadcrumb carries the request URL,
    /// so turn this off when your URLs can contain keys, tokens or other identifiers: ``beforeSend`` can only drop
    /// a whole event, not remove a breadcrumb from it. Mirrors iOS `Options.enableNetworkBreadcrumbs`. Android's SDK
    /// records no request breadcrumbs unless the app installs Sentry's OkHttp integration, so it has no effect there.
    public var enableNetworkBreadcrumbs: Bool = true
    /// Whether to report tombstones captured before the SDK was initialized (Android 12+ only).
    public var isReportHistoricalTombstones: Bool = true
    /// Whether to send structured logs (``SkipSentry/log(_:level:attributes:)``) to Sentry.
    public var enableLogs: Bool = false
    /// Whether to send metrics (``SkipSentry/count(_:value:attributes:)`` and friends) to Sentry.
    public var enableMetrics: Bool = true
    /// URLs (substring or regex) that receive `sentry-trace` / `baggage` headers. `nil` keeps the SDK default.
    public var tracePropagationTargets: [String]?
    /// Hosts whose automatic failed-HTTP-request events are dropped before sending.
    ///
    /// Matches the host itself and any subdomain, so `"cloudfunctions.net"` also drops
    /// `europe-west1-project.cloudfunctions.net`. Use for endpoints whose failures the app
    /// already reports itself, so Sentry doesn't receive a second, unstructured copy.
    public var droppedFailedRequestHosts: [String] = []

    /// A hook invoked for each event just before it is sent to Sentry, letting you
    /// inspect the event and decide whether to drop it (client-side noise filtering).
    /// Return the event to send it, or `nil` to drop it.
    ///
    /// The closure receives a lightweight, read-only ``SkipSentryEvent`` — a
    /// cross-platform projection of the native event — because the native event
    /// types (`Sentry.Event` on iOS, `io.sentry.SentryEvent` on Android) are
    /// platform-specific and cannot cross the Skip bridge. The hook can therefore
    /// decide keep-or-drop but does not mutate the outgoing event.
    ///
    /// Mirrors iOS `Options.beforeSend` and Android `SentryOptions.setBeforeSend`.
    ///
    /// ```swift
    /// let noise = ["network request failed", "request was cancelled"]
    /// SkipSentry.start { options in
    ///     options.dsn = "https://key@sentry.io/123"
    ///     options.beforeSend = { event in
    ///         var text = (event.message ?? "").lowercased()
    ///         for value in event.exceptionValues {
    ///             text += " " + value.lowercased()
    ///         }
    ///         return noise.contains(where: { text.contains($0) }) ? nil : event
    ///     }
    /// }
    /// ```
    public var beforeSend: ((SkipSentryEvent) -> SkipSentryEvent?)?

    public init() { }
}

// MARK: - SkipSentryEvent

/// A lightweight, cross-platform, read-only projection of a Sentry event,
/// passed to ``SkipSentryOptions/beforeSend`` so you can inspect an event and
/// decide whether to drop it before it is sent.
///
/// The underlying native event types (`Sentry.Event` on iOS,
/// `io.sentry.SentryEvent` on Android) are platform-specific and cannot cross
/// the Skip bridge, so `beforeSend` works with this wrapper. It carries the
/// fields needed for client-side noise filtering; it cannot mutate the event.
public struct SkipSentryEvent {
    /// The event's formatted message, if any. Present for message events (e.g.
    /// `SkipSentry.capture(message:)`); typically `nil` for pure exception events.
    public var message: String?
    /// The severity level of the event, if known.
    public var level: SkipSentryLevel?
    /// The exceptions attached to the event. Empty for pure message events.
    public var exceptions: [SkipSentryException]

    /// Convenience accessor for the non-nil `value` strings of all attached exceptions.
    public var exceptionValues: [String] {
        exceptions.compactMap { $0.value }
    }

    public init(message: String? = nil, level: SkipSentryLevel? = nil, exceptions: [SkipSentryException] = []) {
        self.message = message
        self.level = level
        self.exceptions = exceptions
    }
}

// MARK: - SkipSentryException

/// A lightweight, read-only projection of a single exception within a
/// ``SkipSentryEvent``.
public struct SkipSentryException {
    /// The exception type / class name (e.g. `"NSURLErrorDomain"`), if known.
    public var type: String?
    /// The exception value / message, if known.
    public var value: String?

    public init(type: String? = nil, value: String? = nil) {
        self.type = type
        self.value = value
    }
}

#endif
