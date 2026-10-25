import SwiftUI
import XCTest
@testable import MakeReady

final class HomeDashboardContainerTests: XCTestCase {
    func testSessionRangesAreTheClosedList() {
        XCTAssertEqual(HomeDashboardContainer.sessionRanges, ["All time", "Year", "Month", "Week"])
    }
}

/// SPEC D24: the container's first analytics query waits for the shell's initial load.
@MainActor
final class SharedOnceTaskTests: XCTestCase {
    func testSecondCallerWaitsForTheFirstRunAndWorkRunsOnce() async {
        let once = SharedOnceTask()
        var runs = 0
        var finished = false
        let (gate, open) = AsyncStream<Void>.makeStream()

        let first = Task { @MainActor in
            await once.run {
                runs += 1
                for await _ in gate { break }   // held until the test opens the gate
                finished = true
            }
        }
        await Task.yield()
        let second = Task { @MainActor in
            await once.run { runs += 1 }
            return finished                     // must observe the first run's completion
        }
        await Task.yield()
        open.yield(())
        await first.value
        let secondSawCompletion = await second.value

        XCTAssertTrue(secondSawCompletion)
        XCTAssertEqual(runs, 1)
    }

    func testResetAllowsANewRun() async {
        let once = SharedOnceTask()
        var runs = 0
        await once.run { runs += 1 }
        once.reset()
        await once.run { runs += 1 }
        XCTAssertEqual(runs, 2)
    }
}

/// HomeSectionLayout: the TopNav row's host inset and the 16pt gap, measured on a render.
@MainActor
final class HomeSectionLayoutTests: XCTestCase {
    private static let width: CGFloat = 440    // the home-dashboard frame width

    /// First column whose pixel is near-white in the label band — the first tab label's ink.
    private func firstLabelInkX(expansion: Double) throws -> Int {
        var model = UI2ShellModel()
        model.expansion = expansion
        let view = HomeSectionLayout(model: .constant(model)) { Color.clear }
            .frame(width: Self.width, height: 200)
            .background(Color.black)
        let bitmap = try XCTUnwrap(Bitmap(view))
        let band = expansion < 0.5 ? 0..<32 : 0..<96
        for x in 0..<bitmap.width {
            for y in band where bitmap.isNearWhite(x: x, y: y) { return x }
        }
        XCTFail("no label ink found"); return -1
    }

    // The label's text box sits at x=16; "H" draws its first full-ink column ~2pt in (side
    // bearing + antialiasing). The frozen frame (440pt, downsampled) shows the same: a faint
    // column at 16.0 and the first full-ink column at 17.3; a host inset of 8 would put it at ~26.
    func testFirstLabelSitsAt16Collapsed() throws {
        XCTAssertEqual(try firstLabelInkX(expansion: 0), 16 + 2, accuracy: 1)
    }

    func testExpandedLabelSitsOneFurtherInsideTheCardBorder() throws {
        // C-069: expanded label = 16 padding inside the card's 1px border (component-owned),
        // so the expanded label is the collapsed one + 1 — no lateral jump from the host.
        XCTAssertEqual(try firstLabelInkX(expansion: 1), try firstLabelInkX(expansion: 0) + 1)
    }

    func testContentStartsSixteenBelowTheCollapsedRow() throws {
        let view = HomeSectionLayout(model: .constant(UI2ShellModel())) { Color(red: 1, green: 0, blue: 0) }
            .frame(width: Self.width, height: 200)
            .background(Color.black)
        let bitmap = try XCTUnwrap(Bitmap(view))
        let firstRed = (0..<bitmap.height).first { bitmap.isRed(x: Int(Self.width) - 2, y: $0) }
        XCTAssertEqual(firstRed, 32 + 16)
    }

    func testOffHomeTheRowAndGapCollapseToZero() throws {
        var model = UI2ShellModel()
        model.apply(.tab(.search))
        let view = HomeSectionLayout(model: .constant(model)) { Color(red: 1, green: 0, blue: 0) }
            .frame(width: Self.width, height: 200)
            .background(Color.black)
        let bitmap = try XCTUnwrap(Bitmap(view))
        XCTAssertTrue(bitmap.isRed(x: 2, y: 0))
    }
}

/// A 1x RGBA render of a view, for measuring layout in points.
@MainActor
private struct Bitmap {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    /// Rendered through a real window: ImageRenderer draws no UIKit-backed view (TopNav's
    /// horizontal ScrollView came out blank), `drawHierarchy` does.
    init?(_ view: some View, size: CGSize = CGSize(width: 440, height: 200)) {
        let host = UIHostingController(rootView: view)
        host.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            _ = host.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        window.isHidden = true
        guard let cg = image.cgImage else { return nil }
        width = cg.width
        height = cg.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        guard let ctx = CGContext(
            data: &buffer, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        bytes = buffer
    }

    private func rgb(_ x: Int, _ y: Int) -> (Int, Int, Int) {
        let i = (y * width + x) * 4
        return (Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2]))
    }

    func isNearWhite(x: Int, y: Int) -> Bool {
        let (r, g, b) = rgb(x, y)
        return r > 200 && g > 200 && b > 200
    }

    func isRed(x: Int, y: Int) -> Bool {
        let (r, g, b) = rgb(x, y)
        return r > 200 && g < 60 && b < 60
    }
}
