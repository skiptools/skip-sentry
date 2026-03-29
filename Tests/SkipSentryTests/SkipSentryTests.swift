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
        SkipSentry.start(debug: true)
    }

}
