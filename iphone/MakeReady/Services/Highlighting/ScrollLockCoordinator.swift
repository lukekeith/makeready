//
//  ScrollLockCoordinator.swift
//  MakeReady
//
//  The scroll-lock machinery, carried out of `ExegesisVerseView` so every
//  highlighting surface gets it instead of one.
//
//  **DECIDED (Luke, 2026-08-04): carry it, don't drop it.** This exists because
//  UIKit's text-selection interaction scrolls the enclosing ScrollView out from
//  under a long-press — making a selection jump away from the user's finger. It
//  is not currently reported as broken, and losing it silently while unifying
//  the surfaces would make it newly broken. It is ~10 of the 22 lifecycle state
//  variables the old view carried, and it is the least elegant part of this
//  feature by a distance.
//
//  Behaviour is carried VERBATIM from `ExegesisVerseView` (2026-08-04, phase
//  4.4): same offsets, same retry delays, same ordering. This is a move, not a
//  redesign — the delays were tuned against a real device and there is no way to
//  re-derive them from first principles.
//
//  ⚠️ The retry delays are wall-clock waits on UIKit's own asynchronous scroll
//  settling, which offers no completion callback. That is why this file is the
//  one place in new code allowed `asyncAfter` (see `.swiftlint.yml`
//  `async_after_choreography`) — every use is a UIKit settle-wait, never
//  animation choreography.
//

import UIKit

/// Pins an enclosing `UIScrollView` while a text selection is in flight.
@MainActor
final class ScrollLockCoordinator {

    /// The view whose superview chain is searched for a scroll view.
    weak var anchorView: UIView?

    /// Set while a commit is settling: an empty selection reported during this
    /// window is UIKit tidying up, not the user dismissing, so the locks stay.
    var ignoresEmptySelectionUntilRelease = false

    // The freeze: scrolling disabled and the offset re-asserted every frame.
    private weak var frozenScrollView: UIScrollView?
    private var frozenOffset: CGPoint?
    private var frozenWasScrollEnabled: Bool?
    private var freezeDisplayLink: CADisplayLink?
    private var freezeReleaseWorkItem: DispatchWorkItem?

    // The preserve path: re-assert an offset a few times while UIKit settles.
    private var preserveWorkItems: [DispatchWorkItem] = []

    // The selection anchor: where the view was when the selection started.
    private var selectionAnchor: CGPoint?
    private weak var selectionAnchorScrollView: UIScrollView?
    private var selectionGuardWorkItems: [DispatchWorkItem] = []

    deinit {
        freezeReleaseWorkItem?.cancel()
        freezeDisplayLink?.invalidate()
        preserveWorkItems.forEach { $0.cancel() }
        selectionGuardWorkItems.forEach { $0.cancel() }
    }

    /// The offset a first-responder change should be pinned to.
    var textInteractionAnchor: CGPoint? { selectionAnchor ?? frozenOffset }

    func enclosingScrollView() -> UIScrollView? {
        var view = anchorView?.superview
        while let current = view {
            if let scrollView = current as? UIScrollView { return scrollView }
            view = current.superview
        }
        return nil
    }

    // MARK: - Preserve

    /// Run `work`, then hold the scroll offset still while UIKit reacts to it.
    func preservingScrollPosition(targetOffset: CGPoint? = nil, _ work: () -> Void) {
        guard let scrollView = enclosingScrollView() else {
            work()
            return
        }

        let offset = targetOffset ?? scrollView.contentOffset
        work()
        restore(scrollView, to: offset, allowDuringUserScroll: true)
        scheduleRestores(scrollView: scrollView, offset: offset)
    }

    private func restore(_ scrollView: UIScrollView, to offset: CGPoint, allowDuringUserScroll: Bool = false) {
        if !allowDuringUserScroll,
           scrollView.isScrollEnabled,
           scrollView.isDragging || scrollView.isDecelerating {
            // The user took over. Stop fighting them.
            cancelPreserveRestores()
            return
        }

        guard !scrollView.isScrollEnabled
                || frozenScrollView === scrollView
                || !allowDuringUserScroll
                || scrollView.contentOffset != offset else { return }

        scrollView.setContentOffset(offset, animated: false)
    }

    private func scheduleRestores(scrollView: UIScrollView, offset: CGPoint) {
        for delay in Self.preserveDelays {
            let workItem = DispatchWorkItem { [weak self, weak scrollView] in
                guard let self, let scrollView else { return }
                self.restore(scrollView, to: offset)
            }
            preserveWorkItems.append(workItem)
            dispatch(workItem, after: delay)
        }
    }

    private func cancelPreserveRestores() {
        guard !preserveWorkItems.isEmpty else { return }
        preserveWorkItems.forEach { $0.cancel() }
        preserveWorkItems.removeAll()
    }

    // MARK: - Freeze

    func freeze(reason: String, offset explicitOffset: CGPoint? = nil) {
        cancelPreserveRestores()
        guard let scrollView = enclosingScrollView() else { return }

        let offset = explicitOffset ?? frozenOffset ?? selectionAnchor ?? scrollView.contentOffset
        if frozenScrollView == nil {
            frozenWasScrollEnabled = scrollView.isScrollEnabled
        }

        frozenScrollView = scrollView
        frozenOffset = offset
        scrollView.isScrollEnabled = false
        // Bouncing the pan recognizer cancels any in-flight drag on the spot.
        scrollView.panGestureRecognizer.isEnabled = false
        scrollView.panGestureRecognizer.isEnabled = true
        scrollView.setContentOffset(offset, animated: false)

        if freezeDisplayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(enforceFreeze))
            link.add(to: .main, forMode: .common)
            freezeDisplayLink = link
        }
    }

    func extendFreeze(reason: String, releaseAfter delay: TimeInterval) {
        freezeReleaseWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.releaseFreeze(reason: reason)
        }
        freezeReleaseWorkItem = workItem
        dispatch(workItem, after: delay)
    }

    @objc private func enforceFreeze() {
        guard let scrollView = frozenScrollView, let offset = frozenOffset else { return }
        if scrollView.contentOffset != offset {
            scrollView.setContentOffset(offset, animated: false)
        }
    }

    /// Let the scroll view go.
    ///
    /// **This also drops the selection anchor (2026-08-04, 09 §X-p2).** The
    /// anchor exists to hold the view still *while a selection is in flight*, so
    /// an anchor that outlives the freeze is by definition stale — and a stale
    /// one is actively harmful, because `freeze` prefers it over the view's
    /// actual offset, so the next long press yanks the page back to wherever the
    /// previous selection happened. That is exactly what shipped: the commit
    /// path was supposed to call `clearSelectionAnchor()` and, after the phase-4
    /// move, no longer did. Tying the anchor's lifetime to the freeze's makes
    /// the invariant structural instead of a step a caller has to remember —
    /// which is the same lesson as §X-p, one file over.
    func releaseFreeze(reason: String) {
        freezeReleaseWorkItem?.cancel()
        freezeReleaseWorkItem = nil
        freezeDisplayLink?.invalidate()
        freezeDisplayLink = nil
        cancelPreserveRestores()
        clearSelectionAnchor()
        ignoresEmptySelectionUntilRelease = false

        guard let scrollView = frozenScrollView, let offset = frozenOffset else { return }
        scrollView.setContentOffset(offset, animated: false)
        scrollView.isScrollEnabled = frozenWasScrollEnabled ?? true
        frozenScrollView = nil
        frozenOffset = nil
        frozenWasScrollEnabled = nil
    }

    // MARK: - Selection anchor

    /// Remember where the view was when the selection began, and hold it there.
    func captureSelectionAnchorIfNeeded(reason: String) {
        guard let scrollView = enclosingScrollView() else { return }

        if selectionAnchor == nil {
            selectionAnchor = scrollView.contentOffset
            selectionAnchorScrollView = scrollView
        }

        freeze(reason: "selection \(reason)", offset: selectionAnchor)
        scheduleSelectionGuard(hasLiveSelection: { [weak self] in
            (self?.anchorView as? UITextView)?.selectedRange.length ?? 0 > 0
        })
    }

    private func scheduleSelectionGuard(hasLiveSelection: @escaping () -> Bool) {
        selectionGuardWorkItems.forEach { $0.cancel() }
        selectionGuardWorkItems.removeAll()

        for delay in Self.selectionGuardDelays {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self, hasLiveSelection() else { return }
                self.restoreSelectionAnchor()
            }
            selectionGuardWorkItems.append(workItem)
            dispatch(workItem, after: delay)
        }
    }

    private func restoreSelectionAnchor() {
        guard let anchor = selectionAnchor,
              let scrollView = selectionAnchorScrollView ?? enclosingScrollView() else { return }
        scrollView.setContentOffset(anchor, animated: false)
    }

    func clearSelectionAnchor() {
        selectionGuardWorkItems.forEach { $0.cancel() }
        selectionGuardWorkItems.removeAll()
        selectionAnchor = nil
        selectionAnchorScrollView = nil
    }

    /// Everything down: the anchor, the freeze, every queued restore.
    ///
    /// Since `releaseFreeze` now drops the anchor itself this is the same thing,
    /// and it is kept because the failure exits read better saying what they
    /// mean. The redundancy is deliberate: it is what makes the two spellings
    /// safe to use interchangeably, which they previously were not.
    func releaseAll(reason: String) {
        clearSelectionAnchor()
        releaseFreeze(reason: reason)
    }

    // MARK: - Timing

    /// Retry points for the preserve path, in seconds. UIKit settles a
    /// first-responder scroll over several frames with no completion callback,
    /// so the offset is re-asserted across that window.
    private static let preserveDelays: [TimeInterval] = [0, 0.05, 0.2, 0.5]

    /// Retry points while a selection is live. One step longer than the
    /// preserve path — the text interaction keeps adjusting after the caret
    /// settles.
    private static let selectionGuardDelays: [TimeInterval] = [0, 0.05, 0.2, 0.5, 0.75]

    private func dispatch(_ workItem: DispatchWorkItem, after delay: TimeInterval) {
        if delay == 0 {
            DispatchQueue.main.async(execute: workItem)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }
}
