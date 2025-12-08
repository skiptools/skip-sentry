// Copyright 2023–2025 Skip
// SPDX-License-Identifier: LGPL-3.0-only WITH LGPL-3.0-linking-exception
import XCTest
import OSLog
import Foundation
@testable import SkipSentry

let logger: Logger = Logger(subsystem: "SkipSentry", category: "Tests")

@available(macOS 13, *)
final class SkipSentryTests: XCTestCase {

    func testSkipSentry() throws {
        SkipSentry.start(debug: true)
    }

}
