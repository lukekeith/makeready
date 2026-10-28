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

    func testSwipeDownPastTheThresholdCloses() {
        XCTAssertTrue(CoverViewerOverlay.closes(dragHeight: 81))
        XCTAssertFalse(CoverViewerOverlay.closes(dragHeight: 40))
        XCTAssertFalse(CoverViewerOverlay.closes(dragHeight: -200))
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
