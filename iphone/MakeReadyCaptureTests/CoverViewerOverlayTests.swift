import SwiftUI
import UIKit
import XCTest
@testable import MakeReady

/// group-cover-image D8: the viewer shows the original when there is one, else the cover.
@MainActor
final class CoverViewerOverlayTests: XCTestCase {
    private func group(cover: String?, original: String?) -> UserGroup {
        UserGroup(id: "g1", code: "A", name: "G", coverImageUrl: cover, coverOriginalUrl: original,
                  isPrivate: false, allowInvites: true, memberCount: 1, creatorId: "u", createdAt: Date(), updatedAt: Date())
    }

    func testViewerShowsTheOriginalFirst() {
        XCTAssertEqual(CoverViewerOverlay.viewerURL(group: group(cover: "c", original: "o")), "o")
        XCTAssertEqual(CoverViewerOverlay.viewerURL(group: group(cover: "c", original: nil)), "c")
        XCTAssertEqual(CoverViewerOverlay.viewerURL(group: group(cover: "c", original: "")), "c")
        XCTAssertNil(CoverViewerOverlay.viewerURL(group: group(cover: nil, original: nil)))
    }

    // MARK: - image-viewer-zoom-dismiss (reference §2)

    private let viewport = CGRect(x: 0, y: 0, width: 400, height: 1000)

    /// Rule 1: aspect-fit, centred.
    func testFittedFrameIsAspectFitCentred() {
        let wide = ImageViewerMath.fittedFrame(imageSize: CGSize(width: 1600, height: 900), in: viewport)
        XCTAssertEqual(wide, CGRect(x: 0, y: 387.5, width: 400, height: 225))
        let tall = ImageViewerMath.fittedFrame(imageSize: CGSize(width: 500, height: 2000), in: viewport)
        XCTAssertEqual(tall, CGRect(x: 75, y: 0, width: 250, height: 1000))
    }

    /// Rule 6: shrinks with the downward distance only, floored at 0.5.
    func testDragScale() {
        XCTAssertEqual(ImageViewerMath.dragScale(dy: 0, height: 1000), 1)
        XCTAssertEqual(ImageViewerMath.dragScale(dy: -300, height: 1000), 1)
        XCTAssertEqual(ImageViewerMath.dragScale(dy: 250, height: 1000), 0.75, accuracy: 1e-9)
        XCTAssertEqual(ImageViewerMath.dragScale(dy: 900, height: 1000), 0.5)
    }

    /// Rule 7: the backdrop is gone by 40% of the height.
    func testBackdropFades() {
        XCTAssertEqual(ImageViewerMath.backdropOpacity(dy: 0, height: 1000), 1)
        XCTAssertEqual(ImageViewerMath.backdropOpacity(dy: 200, height: 1000), 0.5, accuracy: 1e-9)
        XCTAssertEqual(ImageViewerMath.backdropOpacity(dy: 500, height: 1000), 0)
    }

    /// Rule 8: past 15% of the height, or a downward flick, dismisses.
    func testDismissDecision() {
        XCTAssertTrue(ImageViewerMath.shouldDismiss(dy: 160, velocityY: 0, height: 1000))
        XCTAssertFalse(ImageViewerMath.shouldDismiss(dy: 100, velocityY: 300, height: 1000))
        XCTAssertTrue(ImageViewerMath.shouldDismiss(dy: 20, velocityY: 1200, height: 1000))
        XCTAssertFalse(ImageViewerMath.shouldDismiss(dy: -300, velocityY: -1500, height: 1000))
    }

    /// Rules 6 + 8: with no grab point, the fitted frame scales about its centre and moves.
    func testDraggedFrame() {
        let fitted = CGRect(x: 0, y: 400, width: 400, height: 200)
        XCTAssertEqual(ImageViewerMath.draggedFrame(fitted: fitted, translation: CGSize(width: 10, height: 100), scale: 0.5),
                       CGRect(x: 110, y: 550, width: 200, height: 100))
    }

    /// Rule 5 (owner 2026-10-28): the point grabbed stays under the finger as the image shrinks.
    func testTheGrabbedPointStaysUnderTheFinger() {
        let fitted = CGRect(x: 0, y: 400, width: 400, height: 200)
        let grab = CGPoint(x: 300, y: 450)                      // right of centre, near the top
        let t = CGSize(width: -40, height: 250)
        let frame = ImageViewerMath.draggedFrame(fitted: fitted, translation: t, scale: 0.6, anchor: grab)
        // The grabbed point's position within the image, mapped through the dragged frame…
        let u = (grab.x - fitted.minX) / fitted.width, v = (grab.y - fitted.minY) / fitted.height
        let landed = CGPoint(x: frame.minX + u * frame.width, y: frame.minY + v * frame.height)
        // …is exactly where the finger is now.
        XCTAssertEqual(landed.x, grab.x + t.width, accuracy: 1e-9)
        XCTAssertEqual(landed.y, grab.y + t.height, accuracy: 1e-9)
        XCTAssertEqual(ImageViewerMath.unitAnchor(grab, in: viewport), UnitPoint(x: 0.75, y: 0.45))
        XCTAssertEqual(ImageViewerMath.unitAnchor(nil, in: viewport), .center)
    }

    /// Rules 1, 8, 9: from and back into the source; without one, in place and off the bottom.
    func testStartAndEndFrames() {
        let fitted = CGRect(x: 0, y: 400, width: 400, height: 200)
        let source = CGRect(x: 16, y: 120, width: 368, height: 207)
        XCTAssertEqual(ImageViewerMath.startFrame(source: source, fitted: fitted), source)
        XCTAssertEqual(ImageViewerMath.startFrame(source: nil, fitted: fitted), CGRect(x: 20, y: 410, width: 360, height: 180))
        XCTAssertEqual(ImageViewerMath.endFrame(source: source, from: fitted, viewport: viewport), source)
        XCTAssertEqual(ImageViewerMath.endFrame(source: nil, from: fitted, viewport: viewport).minY, 1000)
    }

    // MARK: - C1: stacked hosted presentations (the group page stacks delete menu, cover menu, viewer)

    /// Set by the hosted overlay's content when the shell's host actually draws it.
    private final class Shown { var value = false }

    /// Hosts `view` under the shell's `.ui2OverlayHost()` in a real window and lets SwiftUI settle
    /// (the action menu mounts its layer one update after `isPresented`).
    private func host(_ view: some View) {
        let host = UIHostingController(rootView: view.ui2OverlayHost())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 440, height: 956))
        window.rootViewController = host
        window.isHidden = false
        for _ in 0..<5 {
            host.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
        window.isHidden = true
    }

    /// C1: a closed viewer stacked OUTSIDE an open action menu must not hide the menu.
    func testAClosedViewerOutsideAnOpenMenuKeepsTheMenu() {
        let shown = Shown()
        host(Color.clear
            .actionMenuPresentation(isPresented: true, onDismiss: {}) { Color.red.onAppear { shown.value = true } }
            .actionMenuPresentation(isPresented: false, onDismiss: {}) { Color.blue }
            .coverViewerPresentation(url: nil, accessibilityLabel: "Group cover", onClose: {}))
        XCTAssertTrue(shown.value, "the open menu was overridden by a closed sibling's nil")
    }

    /// C1: the same for the filter menu's hosted form.
    func testAClosedViewerOutsideAnOpenFilterMenuKeepsTheMenu() {
        let shown = Shown()
        host(Color.clear
            .filterMenuPresentation(isPresented: true) { Color.red.onAppear { shown.value = true } }
            .coverViewerPresentation(url: nil, accessibilityLabel: "Group cover", onClose: {}))
        XCTAssertTrue(shown.value, "the open filter menu was overridden by a closed sibling's nil")
    }

    /// C1: a closed filter menu outside an open action menu keeps the action menu.
    func testAClosedFilterMenuOutsideAnOpenActionMenuKeepsTheActionMenu() {
        let shown = Shown()
        host(Color.clear
            .actionMenuPresentation(isPresented: true, onDismiss: {}) { Color.red.onAppear { shown.value = true } }
            .filterMenuPresentation(isPresented: false) { Color.blue })
        XCTAssertTrue(shown.value, "the open action menu was overridden by a closed filter menu's nil")
    }
}
