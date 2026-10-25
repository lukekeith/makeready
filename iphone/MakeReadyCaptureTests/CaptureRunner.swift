//
//  CaptureRunner.swift
//  MakeReadyCaptureTests
//
//  Main test class that discovers fixture JSON files, renders each view
//  with mock data, and writes screenshots to capture/{workflow}/screenshots/.
//

import XCTest
import SnapshotTesting
import SwiftUI
@testable import MakeReady
@testable import MakeReadyUI

final class CaptureRunner: XCTestCase {

    override func setUp() {
        super.setUp()
        // Always generate screenshots (never compare against references)
        isRecording = true
        // Test-only: intercept URLSession.shared so fixtures can mock specific
        // network endpoints (e.g. the search screen's recents/results). Only
        // endpoints configured per-fixture are intercepted; everything else
        // falls through to the (offline) real path. See MockURLProtocol.
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    @MainActor
    func testCaptureAll() throws {
        let fixtures = try CaptureFixtureLoader.loadAll()

        guard !fixtures.isEmpty else {
            print("CAPTURE: No fixtures found. Check capture/ directory and filters.")
            return
        }

        print("CAPTURE: Found \(fixtures.count) fixture(s)")

        for (workflow, fixture) in fixtures {
            // SPEC D30: 1.0 fixtures stay on disk as reference but are no longer re-captured.
            guard ViewRegistry.registeredKeys.contains(fixture.view) else {
                print("CAPTURE: - skipped 1.0 fixture \(workflow)/\(fixture.output) (\(fixture.view))")
                continue
            }
            // Set up mock state
            setupCaptureState(from: fixture)

            // Build the view — a converted case declares its preview frame (d2m designer-live-picks D5).
            let built: CaptureCase
            do {
                built = try buildCaptureCase(for: fixture)
            } catch {
                XCTFail("CAPTURE: Unknown view '\(fixture.view)' in \(workflow)/\(fixture.output): \(error)")
                continue
            }
            let baseView = built.previewView()

            // Capture at each device size
            for deviceKey in fixture.devices {
                guard let device = CaptureDevice(rawValue: deviceKey) else {
                    XCTFail("CAPTURE: Unknown device '\(deviceKey)' in \(workflow)/\(fixture.output)")
                    continue
                }

                // Component fixtures (view == "component.*") render in isolation:
                // no device chrome/status bar, sized to the device width with the
                // component's intrinsic height — matching the web component harness.
                // A 2.0 screen preview ("screen.<era>.<slug>") renders on the DEVICE canvas
                // instead (D22, the branch below), and its parts need the element map too.
                let isComponent = fixture.view.hasPrefix("component.")
                let isScreen = fixture.view.hasPrefix("screen.")
                let view: AnyView
                let snapshotting: Snapshotting<AnyView, UIImage>
                // Collects the component's annotated parts (UI2Element.swift) DURING the
                // snapshot's own layout pass — see writeElementMap for why it has to be
                // that pass and not one of our own.
                let elementMap = UI2ElementMap()
                if isComponent {
                    // A fill capture (d2m designer-pick-width) lays out at the page's width.
                    let width = fixture.fill.map { CGFloat($0) } ?? device.config.size?.width ?? 393
                    if let frame = built.previewFrame, fixture.bare == true || fixture.fill != nil {
                        // d2m designer-live-picks D5: the BARE component — no master width, no specimen margin —
                        // offered `width` (hugging only where the case declares it intrinsic), with `__root`
                        // naming exactly its bounds: the server crops the design capture to it.
                        let rooted: AnyView = frame.intrinsic
                            ? AnyView(built.view.fixedSize().ui2Element("__root").frame(width: width, alignment: .leading))
                            : AnyView(built.view.frame(width: width).ui2Element("__root"))
                        view = AnyView(rooted.background(MakeReadyUI.Token.layoutBackground).ui2ElementMap(elementMap))
                    } else {
                        view = AnyView(
                            baseView
                                .frame(width: width)
                                // The 2.0 app background (`color-layout-background`, #030405) —
                                // not the 1.x `Color.appBackground` (#0d101a).
                                .background(MakeReadyUI.Token.layoutBackground)
                                .ui2ElementMap(elementMap)
                        )
                    }
                    snapshotting = .image(layout: .sizeThatFits, traits: device.config.traits)
                } else if isScreen {
                    // A 2.0 screen preview: the device's width × max(its height, the content's
                    // full length), content under the top safe area with the status bar drawn.
                    let size = device.config.size ?? CGSize(width: 393, height: 852)
                    // The canvas is a ZStack of the device rectangle and the content, so it
                    // measures as the union of the two: `.sizeThatFits` proposes a ZERO height,
                    // and a `.frame(minHeight:)` answers that proposal with exactly minHeight
                    // whatever its content measures (a 2,372pt screen came out 956pt).
                    view = AnyView(
                        ZStack(alignment: .top) {
                            Color.clear.frame(width: size.width, height: size.height)
                            baseView
                                .padding(.top, device.config.safeArea.top)
                                .frame(width: size.width, alignment: .top)
                        }
                            // Every page sits on `color-layout-background` (#030405) unless the
                            // screen paints its own — including the status bar and whatever
                            // length the content leaves below itself.
                            .background(MakeReadyUI.Token.layoutBackground)
                            .overlay(alignment: .top) { StatusBarView(style: device.statusBarStyle) }
                            .ui2ElementMap(elementMap)
                    )
                    snapshotting = .image(layout: .sizeThatFits, traits: device.config.traits)
                } else if let captureHeight = fixture.captureHeight {
                    // Full-content page capture: same device width, taller
                    // canvas, so the page's ScrollView lays out everything —
                    // the iPhone analogue of the web runner's fullPage shot.
                    // .fixed layout has no safe area, so synthesize the status
                    // bar inset the device layout would have provided.
                    let width = device.config.size?.width ?? 393
                    let statusBarInset: CGFloat = device.statusBarStyle == .modern ? 59 : 20
                    let insetContent = AnyView(
                        baseView.safeAreaInset(edge: .top, spacing: 0) {
                            Color.clear.frame(height: statusBarInset)
                        }
                    )
                    view = AnyView(DeviceChrome(device: device, content: insetContent))
                    snapshotting = .image(
                        drawHierarchyInKeyWindow: true,
                        layout: .fixed(width: width, height: CGFloat(captureHeight))
                    )
                } else {
                    // Wrap with device chrome (status bar)
                    view = AnyView(DeviceChrome(device: device, content: baseView))
                    snapshotting = .image(
                        drawHierarchyInKeyWindow: true,
                        layout: .device(config: device.config)
                    )
                }

                let outputDir = snapshotDirectory(workflow: workflow, device: deviceKey)
                let outputName = (fixture.output as NSString).deletingPathExtension

                // Ensure output directory exists
                try FileManager.default.createDirectory(
                    atPath: outputDir,
                    withIntermediateDirectories: true
                )

                let failure: String?
                if let settle = fixture.settle {
                    // Host the view in a real window and let it run (so .task loads from the
                    // network stubs) BEFORE the snapshot; a view that is only hosted by the
                    // snapshot never gets to load.
                    let host = UIHostingController(rootView: view)
                    let window = UIWindow(frame: UIScreen.main.bounds)
                    window.rootViewController = host
                    window.makeKeyAndVisible()
                    let loaded = XCTestExpectation(description: "settle")
                    DispatchQueue.main.asyncAfter(deadline: .now() + settle) { loaded.fulfill() }
                    _ = XCTWaiter.wait(for: [loaded], timeout: settle + 1)
                    failure = verifySnapshot(
                        of: host,
                        as: Snapshotting<UIViewController, UIImage>.image(on: device.config, drawHierarchyInKeyWindow: true),
                        named: outputName,
                        record: .all,
                        snapshotDirectory: outputDir,
                        testName: "capture"
                    )
                    window.isHidden = true
                } else {
                    failure = verifySnapshot(
                        of: view,
                        as: snapshotting,
                        named: outputName,
                        record: .all,
                        snapshotDirectory: outputDir,
                        testName: "capture"
                    )
                }
                // In record mode, verifySnapshot returns a "recorded" message (not a real failure)
                if let failure, !failure.contains("Record mode") && !failure.contains("recorded") {
                    XCTFail("CAPTURE: Snapshot failed for \(workflow)/\(fixture.output) @ \(deviceKey): \(failure)")
                }

                // The element map sits beside the PNG for component fixtures — the
                // capture browser's 2.0 hit-test oracle (UI2Element.swift). A 1.0
                // component has no annotations, so this writes nothing for it.
                if isComponent || isScreen {
                    writeElementMap(elementMap, to: "\(outputDir)/capture.\(outputName).elements.json")
                }

                let label = fixture.title ?? fixture.output
                print("CAPTURE: ✓ \(label) @ \(deviceKey)")
            }
        }
    }

    /// Writes the parts collected during the snapshot's layout pass beside its PNG.
    ///
    /// The map MUST come from the pass that rendered the image, and cannot come from a
    /// measuring pass of our own: a `UIHostingController` that is in no window is sized
    /// by `sizeThatFits` without ever running the render pass that evaluates the
    /// collecting overlay's `GeometryReader`, so the collector is simply never called.
    /// (That was the first implementation; it produced an empty map for every state.)
    /// Sharing the snapshot's pass also makes the rects and the pixels the same layout by
    /// construction, rather than two passes that have to be checked against each other.
    ///
    /// The collecting overlay is a `Color.clear` — it draws nothing and, an overlay being
    /// sized by its content, lays out nothing — so the PNG is unchanged by its presence.
    ///
    /// Rects are written as fractions of the rendered view, so they line up with the PNG
    /// at any device scale. No annotations (every 1.0 component, and any 2.0 component
    /// built before UI2Element.swift) means no file, which the browser reads as "no
    /// element highlights here" rather than an error.
    @MainActor
    private func writeElementMap(_ map: UI2ElementMap, to filePath: String) {
        let size = map.size
        guard size.width > 0, size.height > 0, !map.elements.isEmpty else {
            print("CAPTURE: (no element map for \((filePath as NSString).lastPathComponent))")
            return
        }

        let elements: [[String: Any]] = map.elements.compactMap { element in
            // Clip to the measured frame: a hit target may extend beyond its own visual
            // bounds (C-021 §2 does exactly that), and the browser hit-tests inside the
            // image, so anything outside it is not addressable.
            let clipped = element.rect.intersection(CGRect(origin: .zero, size: size))
            guard !clipped.isNull, clipped.width > 0, clipped.height > 0 else { return nil }
            return [
                "name": element.name,
                "x": Double(clipped.minX / size.width),
                "y": Double(clipped.minY / size.height),
                "w": Double(clipped.width / size.width),
                "h": Double(clipped.height / size.height),
            ]
        }

        let payload: [String: Any] = [
            "size": ["w": Double(size.width), "h": Double(size.height)],
            "elements": elements,
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(fileURLWithPath: filePath))
            print("CAPTURE: ◎ \(elements.count) element(s) mapped")
        } catch {
            print("CAPTURE: element map failed for \(filePath): \(error)")
        }
    }

    /// Returns the output directory for a given workflow and device.
    private func snapshotDirectory(workflow: String, device: String) -> String {
        let root = CaptureFixtureLoader.captureRootPath()
        return "\(root)/\(workflow)/screenshots/\(device)"
    }
}

/// d2m designer-live-picks D5/D10: what a ViewRegistry case declares about its preview frame.
final class CaptureCaseTests: XCTestCase {
    private func fixture(_ json: String) throws -> CaptureFixture {
        try JSONDecoder().decode(CaptureFixture.self, from: Data(json.utf8))
    }

    func testFixtureDecodesBareAndFill() throws {
        let f = try fixture(#"{"view":"component.ui2.C-035","output":"k.png","devices":["iphone-16-pro-max"],"bare":true,"fill":440,"state":{"component":{"type":"Menu","active":true,"label":"Videos"}}}"#)
        XCTAssertEqual(f.bare, true)
        XCTAssertEqual(f.fill, 440)
        XCTAssertNil(try fixture(#"{"view":"component.ui2.C-035","output":"k.png","devices":[]}"#).bare)
    }

    @MainActor func testSearchFieldDeclaresItsMasterWidth() throws {
        let built = try buildCaptureCase(for: try fixture(#"{"view":"component.ui2.C-034","output":"k.png","devices":["iphone-16-pro-max"],"state":{"component":{"placeholder":"Search","focused":false}}}"#))
        XCTAssertEqual(built.previewFrame?.width, 387)
        XCTAssertEqual(built.previewFrame?.intrinsic, false)
    }

    @MainActor func testFilterChipHugsItsLabel() throws {
        let built = try buildCaptureCase(for: try fixture(#"{"view":"component.ui2.C-035","output":"k.png","devices":["iphone-16-pro-max"],"state":{"component":{"type":"Menu","active":true,"label":"Videos"}}}"#))
        XCTAssertNil(built.previewFrame?.width)
        XCTAssertEqual(built.previewFrame?.intrinsic, true)
        XCTAssertEqual(built.previewFrame?.alignment, .leading)
    }

    @MainActor func testPageHeaderDeclaresItsFrame() throws {
        let built = try buildCaptureCase(for: try fixture(#"{"view":"component.ui2.C-040","output":"k.png","devices":["iphone-16-pro-max"],"state":{"component":{"style":"default","showTitle":true,"title":"Media"}}}"#))
        XCTAssertEqual(built.previewFrame?.width, 398)
    }

    @MainActor func testAnUnconvertedCaseIsFramed() throws {
        let built = try buildCaptureCase(for: try fixture(#"{"view":"component.ui2.C-084","output":"k.png","devices":["iphone-16-pro-max"],"state":{"component":{"selected":"home"}}}"#))
        XCTAssertNil(built.previewFrame, "D10: a case not converted yet keeps its inline frame")
    }

    /// D5: every specimen-framed component case declares its frame. Read from the source: a case body is
    /// the text from its `case "component.` to the next 4-space `case "` or `default:`; a dispatcher case
    /// (`return try buildUI2C0xx(fixture)`) is checked through its out-of-line function's body.
    func testEveryComponentCaseDeclaresItsFrame() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("ViewRegistry.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        var bodies: [String: String] = [:]
        for chunk in source.components(separatedBy: "case \"component.").dropFirst() {
            let view = "component." + String(chunk.prefix { $0 != "\"" })
            let end = chunk.range(of: "\n    case \"") ?? chunk.range(of: "\n    default:")
            var body = String(end.map { chunk[..<$0.lowerBound] } ?? chunk[...])
            if let call = body.range(of: #"return try buildUI2C\d{3}\(fixture\)"#, options: .regularExpression) {
                let name = String(body[call]).replacingOccurrences(of: "return try ", with: "").replacingOccurrences(of: "(fixture)", with: "")
                if let start = source.range(of: "func \(name)("),
                   let close = source.range(of: "\n}\n", range: start.upperBound..<source.endIndex) {
                    body = String(source[start.lowerBound..<close.lowerBound])
                }
            }
            bodies[view] = (bodies[view] ?? "") + body
        }
        // A case that cannot be bare goes here WITH its reason; nothing else does.
        let framedOnPurpose: [String: String] = [:]
        let inline = bodies.filter { view, body in
            framedOnPurpose[view] == nil && !body.contains("declareCase(") && body.contains("MakeReadyUI.Token.Space.pageMargin")
        }.keys.sorted()
        XCTAssertEqual(inline, [], "these cases still frame inline — convert each to declareCase(…), or name it in framedOnPurpose with its reason")
    }
}
