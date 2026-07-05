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
                if isComponent {
                    let width = device.config.size?.width ?? 393
                    view = AnyView(
                        baseView
                            .frame(width: width)
                            .background(Color.appBackground)
                    )
                    snapshotting = .image(layout: .sizeThatFits, traits: device.config.traits)
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

                let label = fixture.title ?? fixture.output
                print("CAPTURE: ✓ \(label) @ \(deviceKey)")
            }
        }
    }

    /// Returns the output directory for a given workflow and device.
    private func snapshotDirectory(workflow: String, device: String) -> String {
        let root = CaptureFixtureLoader.captureRootPath()
        return "\(root)/\(workflow)/screenshots/\(device)"
    }
}
