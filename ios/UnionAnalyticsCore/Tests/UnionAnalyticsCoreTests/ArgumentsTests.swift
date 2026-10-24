import XCTest
@_spi(Wrapper) import Union
@testable import UnionAnalyticsCore

final class ArgumentsTests: XCTestCase {
    func testPropertiesKeepStringNumberBoolAndDropTheRest() {
        let raw: [String: Any] = [
            "plan": "pro",
            "minutes": NSNumber(value: 30),
            "ratio": NSNumber(value: 0.5),
            "on": NSNumber(value: true),
            "off": NSNumber(value: false),
            "nan": NSNumber(value: Double.nan),
            "list": [1, 2],
            "null": NSNull(),
        ]
        let p = Arguments.properties(raw)
        XCTAssertEqual(p["plan"], .string("pro"))
        XCTAssertEqual(p["minutes"], .number(30))
        XCTAssertEqual(p["ratio"], .number(0.5))
        XCTAssertEqual(p["on"], .bool(true))
        XCTAssertEqual(p["off"], .bool(false))
        XCTAssertNil(p["nan"])
        XCTAssertNil(p["list"])
        XCTAssertNil(p["null"])
        XCTAssertEqual(p.count, 5)
    }

    func testBoolIsNotReadAsNumber() {
        XCTAssertEqual(Arguments.properties(["flag": NSNumber(value: true)])["flag"], .bool(true))
        XCTAssertEqual(Arguments.properties(["one": NSNumber(value: 1)])["one"], .number(1))
    }

    func testPropertiesFromGarbageIsEmpty() {
        XCTAssertTrue(Arguments.properties(nil).isEmpty)
        XCTAssertTrue(Arguments.properties("nope").isEmpty)
    }

    func testTraitsKeepOnlyStrings() {
        XCTAssertEqual(Arguments.traits(["plan": "pro", "n": NSNumber(value: 1)]), ["plan": "pro"])
    }

    func testPrivacyModeAndRole() {
        XCTAssertEqual(Arguments.privacyMode("strict_anonymous"), .strictAnonymous)
        XCTAssertEqual(Arguments.privacyMode("product_analytics"), .productAnalytics)
        XCTAssertNil(Arguments.privacyMode("other"))
        XCTAssertNil(Arguments.privacyMode(nil))
        XCTAssertEqual(Arguments.featureRole("success"), .success)
        XCTAssertEqual(Arguments.featureRole("discovery"), .discovery)
        XCTAssertNil(Arguments.featureRole("bogus"))
    }

    func testOptions() {
        let o = Arguments.options([
            "environment": "testflight",
            "logLevel": "debug",
            "crashReporting": NSNumber(value: false),
            "hangDetection": NSNumber(value: false),
        ])
        XCTAssertEqual(o.environment, .testflight)
        XCTAssertEqual(o.logLevel, .debug)
        XCTAssertFalse(o.crashReporting)
        XCTAssertFalse(o.hangDetection)
        XCTAssertFalse(o.automaticScreenTracking)
    }

    func testOptionsDefaultsWhenMissing() {
        let o = Arguments.options(["environment": NSNull(), "logLevel": NSNull()])
        XCTAssertNil(o.environment)
        XCTAssertEqual(o.logLevel, .warning)
        XCTAssertTrue(o.crashReporting)
        XCTAssertTrue(o.hangDetection)
        XCTAssertFalse(o.automaticScreenTracking)
    }

    func testFrames() {
        let frames = Arguments.frames([
            ["function": "main", "module": "my_app", "file": "package:my_app/main.dart",
             "line": NSNumber(value: 10), "column": NSNumber(value: 5), "inApp": NSNumber(value: true)],
            ["function": "_rootRun", "module": NSNull(), "file": NSNull(), "line": NSNull(), "column": NSNull(), "inApp": NSNumber(value: false)],
            ["file": "no_function.dart"],
        ])
        XCTAssertEqual(frames.count, 2)
        XCTAssertEqual(frames[0], ManagedFrame(function: "main", module: "my_app", file: "package:my_app/main.dart", line: 10, column: 5, inApp: true))
        XCTAssertEqual(frames[1], ManagedFrame(function: "_rootRun", inApp: false))
    }

    func testUrl() {
        XCTAssertEqual(Arguments.url(["url": "myapp://open/item"])?.absoluteString, "myapp://open/item")
        XCTAssertNil(Arguments.url([:]))
    }

    func testUnknownMethodIsNotImplementedAndMalformedCallsDoNotCrash() {
        let bridge = UnionBridge()
        var results: [String] = []
        bridge.handle(method: "nope", arguments: nil) { r in
            if case .notImplemented = r { results.append("notImplemented") }
        }
        bridge.handle(method: "track", arguments: "garbage") { r in
            if case .success = r { results.append("success") }
        }
        bridge.handle(method: "recordManagedError", arguments: ["type": 3]) { r in
            if case .success = r { results.append("success") }
        }
        XCTAssertEqual(results, ["notImplemented", "success", "success"])
    }
}
