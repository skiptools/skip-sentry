// Copyright 2023–2026 Skip
// SPDX-License-Identifier: MPL-2.0
import XCTest
import OSLog
import Foundation
@testable import SkipSentry

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
            }

            let _: Bool = SkipSentry.isEnabled
            let _: Bool = SkipSentry.crashedLastRun

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
}
