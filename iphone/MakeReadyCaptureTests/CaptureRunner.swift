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
@testable import UI2Preview

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
            // Set up mock state
            setupCaptureState(from: fixture)

            // Build the view
            let baseView: AnyView
            do {
                baseView = try buildCaptureView(for: fixture)
            } catch {
                XCTFail("CAPTURE: Unknown view '\(fixture.view)' in \(workflow)/\(fixture.output): \(error)")
                continue
            }

            // Capture at each device size
            for deviceKey in fixture.devices {
                guard let device = CaptureDevice(rawValue: deviceKey) else {
                    XCTFail("CAPTURE: Unknown device '\(deviceKey)' in \(workflow)/\(fixture.output)")
                    continue
                }

                // Component fixtures (view == "component.*") render in isolation:
                // no device chrome/status bar, sized to the device width with the
                // component's intrinsic height — matching the web component harness.
                let isComponent = fixture.view.hasPrefix("component.")
                let view: AnyView
                let snapshotting: Snapshotting<AnyView, UIImage>
                // Collects the component's annotated parts (UI2Element.swift) DURING the
                // snapshot's own layout pass — see writeElementMap for why it has to be
                // that pass and not one of our own.
                let elementMap = UI2ElementMap()
                if isComponent {
                    let width = device.config.size?.width ?? 393
                    view = AnyView(
                        baseView
                            .frame(width: width)
                            .background(Color.appBackground)
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

                let failure = verifySnapshot(
                    of: view,
                    as: snapshotting,
                    named: outputName,
                    record: .all,
                    snapshotDirectory: outputDir,
                    testName: "capture"
                )
                // In record mode, verifySnapshot returns a "recorded" message (not a real failure)
                if let failure, !failure.contains("Record mode") && !failure.contains("recorded") {
                    XCTFail("CAPTURE: Snapshot failed for \(workflow)/\(fixture.output) @ \(deviceKey): \(failure)")
                }

                // The element map sits beside the PNG for component fixtures — the
                // capture browser's 2.0 hit-test oracle (UI2Element.swift). A 1.0
                // component has no annotations, so this writes nothing for it.
                if isComponent {
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
