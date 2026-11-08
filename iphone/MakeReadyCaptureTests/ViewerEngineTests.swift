import XCTest
@testable import MakeReady

/// text-activity D10: the viewer engine against the shared position vectors (`01` section 13). The same JSON
/// file is what a future TypeScript engine loads.
final class ViewerEngineTests: XCTestCase {
    func testEveryVectorPasses() throws {
        let url = Bundle(for: Self.self).url(forResource: "viewer-engine-vectors", withExtension: "json")!
        let cases = try JSONDecoder().decode([VectorCase].self, from: Data(contentsOf: url))
        XCTAssertGreaterThanOrEqual(cases.count, 16)
        for c in cases { XCTAssertEqual(c.run(), c.expect, c.name) }
    }

    func testSettleCurveIsCriticallyDampedWithoutOvershoot() {
        var e = ViewerEngine.fixture(pages: [956, 956], viewport: 956)
        e.touchBegan(); _ = e.touchMoved(dy: 500); _ = e.touchEnded(velocity: 0)
        var maxDrag = 0.0, ticks = 0
        while e.settle != nil, ticks < 120 { _ = e.tick(dt: 1.0 / 60); maxDrag = max(maxDrag, e.drag); ticks += 1 }
        XCTAssertNil(e.settle)
        XCTAssertLessThanOrEqual(maxDrag, 956.0001); XCTAssertEqual(e.anchor, 1)
        // Tick counts, not summed seconds: 30 ticks of 1/60 sum to 0.49999999999999994. See the vectors' F4 note.
        XCTAssertGreaterThan(ticks, 18); XCTAssertLessThanOrEqual(ticks, 30)
    }
}

extension ViewerEngine {
    static func fixture(pages: [Double], viewport: Double) -> ViewerEngine {
        ViewerEngine(viewportHeight: viewport, pageHeights: pages, anchor: 0)
    }
}

/// One row of `viewer-engine-vectors.json`: `(start, input) -> expect`. An `expect` key that is absent is not
/// checked, so `run()` returns only the keys the row names.
struct VectorCase: Decodable {
    struct Start: Decodable {
        var viewportHeight: Double?
        var pageHeights: [Double]?
        var anchor: Int?
        var drag: Double?
        var inner: [Double]?
        var owner: String?
        var momentum: Double?
        var visited: [Int]?
    }

    struct Input: Decodable {
        var kind: String
        var dy: [Double]?
        var velocity: Double?
        var ticks: Int?
        var dt: Double?
        var interrupt: Bool?
        var active: Int?
        var pageCount: Int?
        var page: Int?
    }

    struct Expect: Decodable, Equatable {
        var anchor: Int?
        var drag: Double?
        var inner: [Double]?
        var owner: String?
        var active: Int?
        var settling: Bool?
        var outputs: [String]?
        var railStart: Int?
        var railSlots: Int?
        var thumb: Double?
        var noThumb: Bool?
    }

    let name: String
    let start: Start
    let input: Input
    let expect: Expect

    func run() -> Expect {
        var e = ViewerEngine(viewportHeight: start.viewportHeight ?? 956,
                             pageHeights: start.pageHeights ?? [956],
                             anchor: start.anchor ?? 0)
        e.drag = start.drag ?? 0
        if let inner = start.inner { e.inner = inner }
        e.owner = Self.owner(start.owner ?? "none")
        e.momentum = start.momentum ?? 0
        e.visitedPages = Set(start.visited ?? [e.anchor])
        e.activePage = e.pageCoveringMidline

        var outputs: [String] = []
        var observed = Expect()
        switch input.kind {
        case "lift":
            outputs += e.touchEnded(velocity: input.velocity ?? 0).map(Self.text)
            outputs += Self.ticks(&e, input)
            if input.interrupt == true { e.touchBegan() }
        case "move":
            for dy in input.dy ?? [] { outputs += e.touchMoved(dy: dy).map(Self.text) }
        case "tick":
            outputs += Self.ticks(&e, input)
        case "rail":
            let window = ViewerEngine.railWindow(active: input.active ?? 0, pageCount: input.pageCount ?? 0)
            observed.railStart = window.start
            observed.railSlots = window.slots
        case "thumb":
            let fraction = e.thumbFraction(page: input.page ?? 0)
            observed.thumb = fraction.map(Self.rounded)
            observed.noThumb = fraction == nil
        default:
            XCTFail("unknown input kind \(input.kind) in \(name)")
        }
        observed.anchor = e.anchor
        observed.drag = Self.rounded(e.drag)
        observed.inner = e.inner.map(Self.rounded)
        observed.owner = Self.ownerName(e.owner)
        observed.active = e.activePage
        observed.settling = e.settle != nil
        observed.outputs = outputs
        return masked(observed)
    }

    /// The observed value with every key the row does not expect cleared.
    private func masked(_ observed: Expect) -> Expect {
        Expect(anchor: expect.anchor == nil ? nil : observed.anchor,
               drag: expect.drag == nil ? nil : observed.drag,
               inner: expect.inner == nil ? nil : observed.inner,
               owner: expect.owner == nil ? nil : observed.owner,
               active: expect.active == nil ? nil : observed.active,
               settling: expect.settling == nil ? nil : observed.settling,
               outputs: expect.outputs == nil ? nil : observed.outputs,
               railStart: expect.railStart == nil ? nil : observed.railStart,
               railSlots: expect.railSlots == nil ? nil : observed.railSlots,
               thumb: expect.thumb == nil ? nil : observed.thumb,
               noThumb: expect.noThumb == nil ? nil : observed.noThumb)
    }

    private static func ticks(_ e: inout ViewerEngine, _ input: Input) -> [String] {
        var out: [String] = []
        for _ in 0..<(input.ticks ?? 0) { out += e.tick(dt: input.dt ?? 1.0 / 60).map(text) }
        return out
    }

    private static func rounded(_ x: Double) -> Double { (x * 10_000).rounded() / 10_000 }

    private static func owner(_ name: String) -> ViewerEngine.Owner {
        switch name {
        case "inner": return .inner
        case "pager": return .pager
        default: return .none
        }
    }

    private static func ownerName(_ owner: ViewerEngine.Owner) -> String {
        switch owner {
        case .none: return "none"
        case .inner: return "inner"
        case .pager: return "pager"
        }
    }

    private static func text(_ output: ViewerEngine.Output) -> String {
        switch output {
        case .activeChanged(let page): return "activeChanged:\(page)"
        case .settled(let page): return "settled:\(page)"
        case .commitStarted(let page): return "commitStarted:\(page)"
        }
    }
}
