// Copyright 2023–2026 Skip
// SPDX-License-Identifier: MPL-2.0
import XCTest
import OSLog
import Foundation
@testable import SkipSentry

#if !SKIP
import Sentry
#else
import io.sentry.SentryEvent
import io.sentry.SentryLevel
import io.sentry.`protocol`.Message
import io.sentry.`protocol`.SentryException
#endif

let logger: Logger = Logger(subsystem: "SkipSentry", category: "Tests")

@available(macOS 13, *)
final class SkipSentryTests: XCTestCase {

    func testSkipSentry() throws {
        #if !SKIP
        SkipSentry.start(debug: true)
        #endif
        // On Android, start() requires a real Android context (not available in Robolectric)
    }

    func testSkipSentryLevels() throws {
        let levels: [SkipSentryLevel] = [.debug, .info, .warning, .error, .fatal]
        XCTAssertEqual(levels.count, 5)
        XCTAssertEqual(SkipSentryLevel.debug.rawValue, "debug")
        XCTAssertEqual(SkipSentryLevel.info.rawValue, "info")
        XCTAssertEqual(SkipSentryLevel.warning.rawValue, "warning")
        XCTAssertEqual(SkipSentryLevel.error.rawValue, "error")
        XCTAssertEqual(SkipSentryLevel.fatal.rawValue, "fatal")
    }

    func testSkipSentryOptions() throws {
        let opts = SkipSentryOptions()
        XCTAssertNil(opts.dsn)
        XCTAssertFalse(opts.debug)
        XCTAssertNil(opts.environment)
        XCTAssertNil(opts.release)
        XCTAssertNil(opts.dist)
        XCTAssertNil(opts.sampleRate)
        XCTAssertTrue(opts.enableAutoSessionTracking)
        XCTAssertNil(opts.sessionTrackingIntervalMillis)
        XCTAssertTrue(opts.attachStacktrace)
        XCTAssertTrue(opts.enableAppHangTracking)

        opts.dsn = "https://key@sentry.io/123"
        opts.debug = true
        opts.environment = "test"
        opts.release = "1.0.0"
        opts.dist = "1"
        opts.sampleRate = 0.5
        opts.enableAutoSessionTracking = false
        opts.sessionTrackingIntervalMillis = 30000
        opts.attachStacktrace = false
        opts.enableAppHangTracking = false
        XCTAssertNil(opts.beforeSend)

        XCTAssertEqual(opts.dsn, "https://key@sentry.io/123")
        XCTAssertTrue(opts.debug)
        XCTAssertEqual(opts.environment, "test")
        XCTAssertEqual(opts.release, "1.0.0")
        XCTAssertEqual(opts.sampleRate, 0.5)
        XCTAssertFalse(opts.enableAutoSessionTracking)
    }

    func testSkipSentryAPICompilation() throws {
        if false {
            SkipSentry.start(dsn: "https://key@sentry.io/123", debug: true)
            SkipSentry.start { opts in
                opts.dsn = "https://key@sentry.io/123"
                opts.debug = true
                opts.environment = "production"
                opts.release = "1.0.0"
                opts.sampleRate = 1.0
                opts.beforeSend = { event in
                    if event.level == .debug { return nil }
                    var text = (event.message ?? "").lowercased()
                    for value in event.exceptionValues {
                        text += " " + value.lowercased()
                    }
                    return text.contains("drop me") ? nil : event
                }
            }

            let _: Bool = SkipSentry.isEnabled
            let _: Bool? = SkipSentry.crashedLastRun

            SkipSentry.capture(error: NSError(domain: "test", code: 1))
            SkipSentry.capture(message: "Test message")
            SkipSentry.capture(message: "Test warning", level: .warning)

            SkipSentry.addBreadcrumb(message: "User tapped button")
            SkipSentry.addBreadcrumb(message: "Navigated", category: "nav")
            SkipSentry.addBreadcrumb(message: "Error", category: "http", level: .error)
            SkipSentry.clearBreadcrumbs()

            SkipSentry.setUser(id: "user-123", email: "u@e.com", username: "johndoe")
            SkipSentry.clearUser()

            SkipSentry.setTag(key: "page", value: "home")
            SkipSentry.removeTag(key: "page")
            SkipSentry.setExtra(key: "time", value: "200ms")
            SkipSentry.setLevel(.error)

            SkipSentry.flush()
            SkipSentry.flush(timeout: 10.0)
            SkipSentry.close()
        }
    }

    func testSkipSentryStartWithOptions() throws {
        #if !SKIP
        SkipSentry.start { opts in
            opts.debug = true
        }
        #endif
        // On Android, start() requires a real Android context (not available in Robolectric)
    }

    // MARK: - beforeSend event filtering

    /// Verifies the full `beforeSend` bridge end-to-end on each platform: a native
    /// event is mapped into `SkipSentryEvent`, the consumer hook runs, and the
    /// keep/drop decision is honored. This exercises the exact `applyBeforeSend`
    /// code path that `start(configure:)` wires into the native SDK's `beforeSend`,
    /// so a `nil` return really drops the event and a non-nil return passes the
    /// original native event through unchanged.
    func testBeforeSendDropsNoiseKeepsRealEvents() throws {
        let opts = SkipSentryOptions()
        // Consumer filter: drop any event whose message or exception values contain "noise".
        opts.beforeSend = { event in
            var text = (event.message ?? "").lowercased()
            for value in event.exceptionValues {
                text += " " + value.lowercased()
            }
            return text.contains("noise") ? nil : event
        }

        #if !SKIP
        // Message event that matches the noise filter -> dropped (nil).
        let noisyMessage = Event(level: .error)
        noisyMessage.message = SentryMessage(formatted: "this is NOISE we don't want")
        XCTAssertNil(SkipSentry.applyBeforeSend(opts, noisyMessage), "nil from beforeSend must drop the event")

        // Exception event that matches the noise filter (via exception value) -> dropped.
        let noisyException = Event(level: .error)
        noisyException.exceptions = [Exception(value: "some NOISE happened", type: "NSError")]
        XCTAssertNil(SkipSentry.applyBeforeSend(opts, noisyException))

        // Genuine exception event -> kept, and the original native event passes through.
        let realEvent = Event(level: .error)
        realEvent.exceptions = [Exception(value: "genuine unexpected failure", type: "NSError")]
        let kept = SkipSentry.applyBeforeSend(opts, realEvent)
        XCTAssertNotNil(kept, "non-nil from beforeSend must keep the event")
        XCTAssertTrue(kept === realEvent, "the original native event must pass through unchanged")
        #else
        // Message event that matches the noise filter -> dropped (null).
        let noisyMessage = SentryEvent()
        let message = Message()
        message.formatted = "this is NOISE we don't want"
        noisyMessage.message = message
        XCTAssertNil(SkipSentry.applyBeforeSend(opts, noisyMessage), "null from beforeSend must drop the event")

        // Exception event that matches the noise filter (via exception value) -> dropped.
        let noisyException = SentryEvent()
        let noisyExc = SentryException()
        noisyExc.value = "some NOISE happened"
        noisyExc.type = "RuntimeException"
        // The Android SDK's setExceptions expects a Kotlin List, so build one directly.
        // SKIP INSERT: noisyException.exceptions = listOf(noisyExc)
        XCTAssertNil(SkipSentry.applyBeforeSend(opts, noisyException))

        // Genuine exception event -> kept.
        let realEvent = SentryEvent()
        let realExc = SentryException()
        realExc.value = "genuine unexpected failure"
        realExc.type = "RuntimeException"
        // SKIP INSERT: realEvent.exceptions = listOf(realExc)
        XCTAssertNotNil(SkipSentry.applyBeforeSend(opts, realEvent), "non-null from beforeSend must keep the event")
        #endif
    }

    /// Without a `beforeSend` hook configured, `applyBeforeSend` must always keep the event.
    func testBeforeSendAbsentKeepsEvent() throws {
        let opts = SkipSentryOptions()
        #if !SKIP
        let event = Event(level: .error)
        event.message = SentryMessage(formatted: "anything at all")
        XCTAssertNotNil(SkipSentry.applyBeforeSend(opts, event))
        #else
        let event = SentryEvent()
        let message = Message()
        message.formatted = "anything at all"
        event.message = message
        XCTAssertNotNil(SkipSentry.applyBeforeSend(opts, event))
        #endif
    }

    /// The `level` is projected onto the wrapper so a hook can filter on it.
    func testBeforeSendCanFilterOnLevel() throws {
        let opts = SkipSentryOptions()
        // Drop debug-level events, keep everything else.
        opts.beforeSend = { event in
            event.level == .debug ? nil : event
        }

        #if !SKIP
        let debugEvent = Event(level: .debug)
        debugEvent.message = SentryMessage(formatted: "chatty debug line")
        XCTAssertNil(SkipSentry.applyBeforeSend(opts, debugEvent))

        let errorEvent = Event(level: .error)
        errorEvent.message = SentryMessage(formatted: "real error")
        XCTAssertNotNil(SkipSentry.applyBeforeSend(opts, errorEvent))
        #else
        let debugEvent = SentryEvent()
        debugEvent.level = SentryLevel.DEBUG
        let debugMessage = Message()
        debugMessage.formatted = "chatty debug line"
        debugEvent.message = debugMessage
        XCTAssertNil(SkipSentry.applyBeforeSend(opts, debugEvent))

        let errorEvent = SentryEvent()
        errorEvent.level = SentryLevel.ERROR
        let errorMessage = Message()
        errorMessage.formatted = "real error"
        errorEvent.message = errorMessage
        XCTAssertNotNil(SkipSentry.applyBeforeSend(opts, errorEvent))
        #endif
    }
}
