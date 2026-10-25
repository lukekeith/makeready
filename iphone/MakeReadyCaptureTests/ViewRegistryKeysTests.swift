import XCTest
@testable import MakeReady

final class ViewRegistryKeysTests: XCTestCase {
    /// SPEC D30: only 2.0 cases remain.
    func testOnlyUI2KeysRemain() {
        let legacy = ViewRegistry.registeredKeys.filter {
            !$0.hasPrefix("component.ui2.") && !$0.hasPrefix("screen.2.0.")
        }
        XCTAssertEqual(legacy, [], "1.0 capture cases must be retired (D30)")
        XCTAssertFalse(ViewRegistry.registeredKeys.isEmpty)
    }

    /// `registeredKeys` is hand-kept; d2m only appends a `case`. Read the source so drift fails loudly.
    func testRegisteredKeysMatchTheSwitchLabels() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("ViewRegistry.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        let regex = try NSRegularExpression(pattern: #"^    case "((?:component\.ui2\.|screen\.2\.0\.)[^"]*)""#, options: .anchorsMatchLines)
        let range = NSRange(source.startIndex..., in: source)
        let labels = Set(regex.matches(in: source, range: range).compactMap { m in
            Range(m.range(at: 1), in: source).map { String(source[$0]) }
        })
        XCTAssertFalse(labels.isEmpty)
        XCTAssertEqual(Set(ViewRegistry.registeredKeys), labels, "registeredKeys drifted from the switch labels")
    }
}
