//
//  SelectionCommitPolicyTests.swift
//  MakeReadyCaptureTests
//
//  Phase 4.4 of docs/features/highlighting/ — the commit lifecycle.
//
//  This is the regression guard for monday#12708759849: a highlight that locked
//  itself in under the user's finger, mid-drag. The policy has no clock, so
//  "does not commit while a finger is down, at any elapsed time" is provable
//  here rather than being a matter of a well-chosen delay.
//

import XCTest
@testable import MakeReady

final class SelectionCommitPolicyTests: XCTestCase {

    private let selection = NSRange(location: 4, length: 10)

    /// Finger down, then a selection appears — the ordinary start of a drag.
    private func draggingPolicy() -> SelectionCommitPolicy {
        var policy = SelectionCommitPolicy()
        _ = policy.touchCountChanged(to: 1)
        _ = policy.selectionChanged(to: selection)
        return policy
    }

    // MARK: The bug

    func testASelectionChangeNeverSchedulesACommit() {
        var policy = SelectionCommitPolicy()
        _ = policy.touchCountChanged(to: 1)

        // However much the selection moves, nothing is ever queued.
        for length in 1...20 {
            let action = policy.selectionChanged(to: NSRange(location: 4, length: length))
            XCTAssertEqual(action, .none)
            XCTAssertFalse(policy.isCommitPending)
        }
    }

    func testDoesNotCommitWhileAFingerIsDownAtAnyElapsedTime() {
        var policy = draggingPolicy()

        // Simulate every stray hop that could possibly fire mid-gesture. There
        // is no elapsed time that turns this into a commit, because elapsed
        // time is not an input.
        for _ in 0..<50 {
            XCTAssertEqual(policy.commitHopFired(), .none)
            _ = policy.selectionChanged(to: selection)
        }
        XCTAssertEqual(policy.activeTouchCount, 1)
    }

    func testViewLevelTouchesCancelledIsInert() {
        var policy = draggingPolicy()

        // UIKit sends this the instant the text interaction claims the touch —
        // while the finger is still down. Acting on it was the bug.
        XCTAssertEqual(policy.viewReportedTouchesCancelled(), .none)
        XCTAssertEqual(policy.commitHopFired(), .none)
        XCTAssertFalse(policy.isCommitPending)
        XCTAssertEqual(policy.activeTouchCount, 1, "the observer, not the view, owns the count")
    }

    func testALiftIsOnlyAReleaseWhenEveryFingerIsGone() {
        var policy = draggingPolicy()
        _ = policy.touchCountChanged(to: 2)

        // One of two fingers lifts or is cancelled — still not a release.
        XCTAssertEqual(policy.touchCountChanged(to: 1), .cancelPendingCommit)
        XCTAssertEqual(policy.commitHopFired(), .none)

        XCTAssertEqual(policy.touchCountChanged(to: 0), .scheduleCommitHop)
    }

    // MARK: Release

    func testReleaseCommitsExactlyOnce() {
        var policy = draggingPolicy()

        XCTAssertEqual(policy.touchCountChanged(to: 0), .scheduleCommitHop)
        XCTAssertEqual(policy.commitHopFired(), .commit(selection))

        // A second hop — a duplicate dispatch, a stale work item — commits nothing.
        XCTAssertEqual(policy.commitHopFired(), .none)
        XCTAssertEqual(policy.commitHopFired(), .none)
    }

    func testARetouchDuringTheHopAbandonsTheCommit() {
        var policy = draggingPolicy()
        XCTAssertEqual(policy.touchCountChanged(to: 0), .scheduleCommitHop)

        // The finger comes back down before the hop lands.
        XCTAssertEqual(policy.touchCountChanged(to: 1), .cancelPendingCommit)
        XCTAssertEqual(policy.commitHopFired(), .none, "still live — the user is adjusting")

        // Letting go again commits normally.
        XCTAssertEqual(policy.touchCountChanged(to: 0), .scheduleCommitHop)
        XCTAssertEqual(policy.commitHopFired(), .commit(selection))
    }

    func testTheCommittedRangeIsWhicheverSelectionWasLastSeen() {
        var policy = draggingPolicy()
        let extended = NSRange(location: 4, length: 25)
        _ = policy.selectionChanged(to: extended)

        _ = policy.touchCountChanged(to: 0)
        XCTAssertEqual(policy.commitHopFired(), .commit(extended))
    }

    // MARK: Nothing selected

    func testLiftingWithNoSelectionSchedulesNothing() {
        var policy = SelectionCommitPolicy()
        _ = policy.touchCountChanged(to: 1)

        XCTAssertEqual(policy.touchCountChanged(to: 0), .none)
        XCTAssertFalse(policy.isCommitPending)
    }

    func testAHopThatFindsTheSelectionGoneTearsTheLocksDown() {
        var policy = draggingPolicy()
        XCTAssertEqual(policy.touchCountChanged(to: 0), .scheduleCommitHop)

        // UIKit cleared the selection between the lift and the hop.
        _ = policy.selectionChanged(to: NSRange(location: 4, length: 0))
        XCTAssertEqual(policy.commitHopFired(), .abandon)
        XCTAssertFalse(policy.isCommitPending)
    }

    func testAnUnsetSelectionIsNotALiveOne() {
        var policy = SelectionCommitPolicy()
        XCTAssertFalse(policy.hasLiveSelection)

        _ = policy.selectionChanged(to: NSRange(location: NSNotFound, length: 0))
        XCTAssertFalse(policy.hasLiveSelection)

        _ = policy.selectionChanged(to: NSRange(location: 0, length: 1))
        XCTAssertTrue(policy.hasLiveSelection)
    }

    func testANegativeTouchCountIsClampedRatherThanTrusted() {
        var policy = draggingPolicy()
        _ = policy.touchCountChanged(to: -1)
        XCTAssertEqual(policy.activeTouchCount, 0)
    }

    // MARK: The bug, second time around (2026-08-04)

    // Everything above passed while the Exegesis editor was committing a
    // highlight under the user's finger on the first long press. The tests were
    // not wrong — they were driving the policy directly, and what had broken was
    // the gesture wiring that decides which events reach it. UIKit cancels a
    // recognizer that is not allowed to run simultaneously, so the observer's
    // touch count fell to zero the moment the text interaction claimed the long
    // press, and the policy dutifully read that as a release.
    //
    // Both halves of the fix are pinned here: the policy must reject a
    // cancellation, and the recognizer must carry the delegate that stops the
    // cancellation happening in the first place.

    func testACancelledSequenceNeverCommits() {
        var policy = draggingPolicy()

        // UIKit tears the touches away while the finger is still down.
        XCTAssertEqual(policy.touchCountChanged(to: 0, cause: .cancelled), .cancelPendingCommit)
        XCTAssertFalse(policy.isCommitPending)
        XCTAssertEqual(policy.commitHopFired(), .none,
                       "a cancellation is not a release — 03 §5")
    }

    func testACancelledSequenceLeavesTheSelectionLiveForARealRelease() {
        var policy = draggingPolicy()
        _ = policy.touchCountChanged(to: 0, cause: .cancelled)

        // The selection survives, so the user's drag is uninterrupted...
        XCTAssertTrue(policy.hasLiveSelection)

        // ...and a genuine lift still commits it.
        XCTAssertEqual(policy.touchCountChanged(to: 1), .cancelPendingCommit)
        XCTAssertEqual(policy.touchCountChanged(to: 0, cause: .released), .scheduleCommitHop)
        XCTAssertEqual(policy.commitHopFired(), .commit(selection))
    }

    func testACancellationDropsACommitAlreadyQueued() {
        var policy = draggingPolicy()
        XCTAssertEqual(policy.touchCountChanged(to: 0), .scheduleCommitHop)

        // A finger returns, then the sequence is cancelled rather than lifted.
        _ = policy.touchCountChanged(to: 1)
        XCTAssertEqual(policy.touchCountChanged(to: 0, cause: .cancelled), .cancelPendingCommit)
        XCTAssertEqual(policy.commitHopFired(), .none)
    }

    func testTheTouchObserverCarriesItsOwnSimultaneityDelegate() {
        // THE regression guard for the dropped line. `ExegesisVerseView` used to
        // set `observer.delegate = self`; the phase-4 move lost it, and nothing
        // failed. The delegate now travels with the recognizer, so a host cannot
        // forget it — and `delegate` is weak, so this also proves the recognizer
        // retains it rather than letting it deallocate.
        let observer = TouchObserverGestureRecognizer()
        guard let delegate = observer.delegate else {
            return XCTFail("the touch observer must carry its own delegate")
        }

        let other = UILongPressGestureRecognizer()
        XCTAssertTrue(
            delegate.gestureRecognizer?(observer, shouldRecognizeSimultaneouslyWith: other) ?? false,
            "the observer must never be cancelled by whoever wins the gesture"
        )
        XCTAssertFalse(
            delegate.gestureRecognizer?(observer, shouldRequireFailureOf: other) ?? true,
            "the observer must not wait on anyone"
        )
        XCTAssertFalse(
            delegate.gestureRecognizer?(observer, shouldBeRequiredToFailBy: other) ?? true,
            "and nothing may wait on the observer, which never recognizes"
        )
    }

    // NOT TESTED HERE, deliberately: that UIKit actually delivers
    // `touchesEnded` rather than `touchesCancelled` to the observer during a
    // real long press. Driving that would mean synthesizing `UITouch`/`UIEvent`
    // objects and calling through UIKit's own superclass implementations with
    // them, which is exactly the kind of test that passes by luck or crashes the
    // suite. **It is the device check** — and its absence is the reason this bug
    // reached a human. Said out loud rather than papered over.
}
