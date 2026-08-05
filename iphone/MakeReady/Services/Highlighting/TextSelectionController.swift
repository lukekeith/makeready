//
//  TextSelectionController.swift
//  MakeReady
//
//  ONE selection lifecycle, for every surface that highlights text.
//
//  The rule it exists to enforce (03 §5): a highlight commits on a genuine
//  finger release and at NO other moment — never on a timer, never on a
//  selection-change debounce, never on a `touchesCancelled` the view receives
//  while the finger is still down. That last one is monday#12708759849: UIKit
//  delivers `touchesCancelled` to a view the instant a gesture recognizer claims
//  the touch, which is exactly what the text-selection interaction does when a
//  long press turns into a drag. The old code read that as "the user let go" and
//  locked the highlight in under their finger.
//
//  ⚠️ **The same bug came back on 2026-08-04, through the refactor that was
//  supposed to end it, and it is worth knowing how.** The policy below was
//  correct and thoroughly tested. What broke was one line of *wiring*: the old
//  `ExegesisVerseView` set `observer.delegate = self`, and moving the observer
//  in here dropped it. Without that, UIKit cancels the observer the instant the
//  text-selection interaction claims the long press — the very moment the user's
//  word gets selected — and the observer reported its finger count falling to
//  zero while the finger was still down. Every unit test still passed, because
//  they drive the policy directly and never involve a gesture. Two things
//  changed in response: the observer now owns its delegate (nothing to forget),
//  and the policy distinguishes a cancellation from a release, so the rule holds
//  even if the wiring is wrong again.
//
//  The lifecycle is split in two on purpose:
//
//  * `SelectionCommitPolicy` — a pure state machine with no UIKit and NO CLOCK.
//    "Does not commit while a finger is down, at any elapsed time" is true of it
//    by construction rather than by a well-chosen delay, and it can be driven
//    from a unit test without a gesture.
//  * `TextSelectionController` — the UIKit half: owns the touch observer, feeds
//    the policy, snaps at the injected granularity, and drives the scroll lock.
//
//  See docs/features/highlighting/06-iphone.md §Selection lifecycle.
//

import UIKit

// MARK: - The decision core

/// Decides when a live selection becomes a committed highlight.
///
/// Deliberately has no notion of time. Every input is an event; the only route
/// to `.commit` is a hop that was scheduled by the touch count reaching zero and
/// that still sees zero touches when it runs.
struct SelectionCommitPolicy {

    enum Action: Equatable {
        /// Nothing to do.
        case none
        /// A finger is down — drop any queued commit; the selection stays live.
        case cancelPendingCommit
        /// The user let go. Hop one runloop turn so UIKit can settle
        /// `selectedRange`, then ask again.
        case scheduleCommitHop
        /// Commit this range. The only terminal action.
        case commit(NSRange)
        /// The hop ran with nothing selected — tear the scroll locks down.
        case abandon
    }

    private(set) var activeTouchCount = 0
    private(set) var selection = NSRange(location: NSNotFound, length: 0)
    private(set) var isCommitPending = false

    var hasLiveSelection: Bool {
        selection.location != NSNotFound && selection.length > 0
    }

    /// The touch observer reported a change in how many fingers are on the view.
    ///
    /// `cause` is what makes "commits on a genuine release and at no other
    /// moment" a property of this type rather than of the wiring around it. A
    /// count that reaches zero because UIKit **cancelled** the touches is not a
    /// release — the finger is typically still on the glass — so it drops any
    /// queued commit and leaves the selection live, exactly as a second finger
    /// landing would (03 §5: "never on a cancelled touch").
    ///
    /// Defaults to `.released` so the ordinary lift reads plainly at call sites
    /// and in tests.
    mutating func touchCountChanged(
        to count: Int,
        cause: TouchObserverGestureRecognizer.Cause = .released
    ) -> Action {
        let wasDown = activeTouchCount > 0
        activeTouchCount = max(0, count)

        if activeTouchCount > 0 {
            isCommitPending = false
            return .cancelPendingCommit
        }

        guard cause != .cancelled else {
            isCommitPending = false
            return .cancelPendingCommit
        }

        guard wasDown, hasLiveSelection else { return .none }
        isCommitPending = true
        return .scheduleCommitHop
    }

    /// The text view's selection moved.
    ///
    /// Records it and does nothing else — **this is the fix**. Scheduling a
    /// commit here is what stole the gesture mid-drag.
    mutating func selectionChanged(to range: NSRange) -> Action {
        selection = range
        return .none
    }

    /// The view was sent `touchesCancelled`.
    ///
    /// Deliberately inert. UIKit sends this while the finger is still down, so
    /// it cannot mean "released"; the touch observer is the only thing that
    /// knows. Kept as an explicit no-op rather than an absent call so the
    /// behaviour is testable and cannot be "helpfully" restored later.
    mutating func viewReportedTouchesCancelled() -> Action {
        .none
    }

    /// The scheduled hop fired.
    mutating func commitHopFired() -> Action {
        guard isCommitPending else { return .none }

        // A finger came back down during the hop — stay live, stay pending.
        guard activeTouchCount == 0 else { return .none }

        isCommitPending = false
        guard hasLiveSelection else { return .abandon }
        return .commit(selection)
    }
}

// MARK: - The other way to select

/// What a verse tap does, in the Read editor's tap-to-select model.
///
/// The sibling of `SelectionCommitPolicy`: the Exegesis editor and the Bible
/// reader select by dragging, the Read editor selects by tapping verses. Both
/// end in a committed range, and neither commits on a timer — so both live here,
/// as pure functions, rather than inside a gesture handler where they can only
/// be verified by hand.
enum VerseTapOutcome: Equatable {
    /// The live selection changed. Nothing is committed yet.
    case select(NSRange)
    /// The user tapped inside their own selection — that means "I'm done".
    case commit(NSRange)
    /// The tap landed somewhere with no verse.
    case ignore
}

enum VerseTapPolicy {

    /// Tap a verse → select it. Tap another → extend to cover both. Tap inside
    /// the selection → commit it.
    ///
    /// Extension always spans from the lowest to the highest verse touched, so
    /// tapping backwards works the same as tapping forwards.
    static func tap(
        verse: Int,
        liveSelection: NSRange?,
        verseRanges: [VerseRange]
    ) -> VerseTapOutcome {
        let selected = VerseSelectionLogic.versesOverlapping(
            liveSelection ?? NSRange(location: 0, length: 0),
            verseRanges: verseRanges
        )
        let lowest = selected.first
        let highest = selected.last

        if let lowest, let highest, verse >= lowest, verse <= highest {
            guard let range = VerseSelectionLogic.rangeForVerses(from: lowest, to: highest, verseRanges: verseRanges),
                  range.length > 0 else { return .ignore }
            return .commit(range)
        }

        let newLowest = Swift.min(lowest ?? verse, verse)
        let newHighest = Swift.max(highest ?? verse, verse)
        guard let range = VerseSelectionLogic.rangeForVerses(from: newLowest, to: newHighest, verseRanges: verseRanges)
        else { return .ignore }

        return .select(range)
    }

    /// Which verse contains a character offset, if any.
    static func verse(containing offset: Int, verseRanges: [VerseRange]) -> Int? {
        verseRanges.first {
            offset >= $0.range.location && offset < $0.range.location + $0.range.length
        }?.verse
    }
}

// MARK: - Touch observation

/// A gesture recognizer that never recognizes anything — it exists solely to
/// count the fingers on a view.
///
/// A view's own `touchesEnded`/`touchesCancelled` cannot answer "has the user
/// let go?" once UIKit's text-selection interaction is involved: the moment a
/// recognizer claims the touch, the view is sent `touchesCancelled` even though
/// the finger is still down. Gesture recognizers, by contrast, keep receiving
/// the whole touch sequence in parallel with whoever wins. Staying in
/// `.possible` forever is what keeps this one receiving them — transitioning to
/// `.failed` would stop delivery, and recognizing would steal the gesture from
/// the text view (monday#12708759849).
///
/// Moved here from `ExegesisVerseView.swift` (2026-08-04, highlighting phase
/// 4.4) unchanged, so every surface shares one copy.
final class TouchObserverGestureRecognizer: UIGestureRecognizer {

    /// Why the touch count changed. A cancellation is **not** a release: UIKit
    /// tears touches away from a recognizer while the finger is still down, and
    /// reading that as "the user let go" is monday#12708759849 wearing a
    /// different hat (see `SelectionCommitPolicy.touchCountChanged`).
    enum Cause: Equatable {
        case began
        case released
        case cancelled
    }

    /// Fired whenever the number of touches on the view changes, including down
    /// to zero — which is the signal that the user genuinely released, but only
    /// when `cause` says `.released`.
    var onActiveTouchCountChanged: ((Int, Cause) -> Void)?

    private var activeTouches: Set<UITouch> = []

    /// This recognizer's own delegate, retained here because
    /// `UIGestureRecognizer.delegate` is weak.
    ///
    /// **It lives inside the recognizer on purpose (2026-08-04).** It used to be
    /// the host's job — `ExegesisVerseView` set `observer.delegate = self` — and
    /// when phase 4 moved the observer into `TextSelectionController.attach()`,
    /// that single line did not come with it. The delegate *method* did, so
    /// nothing looked missing, and the consequence was invisible in every unit
    /// test because they drive the policy directly and never involve a gesture.
    /// An invariant that depends on a caller remembering one line is not an
    /// invariant; this one now travels with the object.
    private let simultaneityDelegate = AlwaysSimultaneousDelegate()

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        delegate = simultaneityDelegate
    }

    convenience init() {
        self.init(target: nil, action: nil)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        activeTouches.formUnion(touches)
        onActiveTouchCountChanged?(activeTouches.count, .began)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        activeTouches.subtract(touches)
        onActiveTouchCountChanged?(activeTouches.count, .released)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        activeTouches.subtract(touches)
        onActiveTouchCountChanged?(activeTouches.count, .cancelled)
    }

    /// UIKit resets recognizers at the end of every touch sequence, so this also
    /// backstops any touch whose end was never delivered. A touch that vanished
    /// without an end is cancellation-shaped, so it is reported as such — never
    /// as a release.
    override func reset() {
        super.reset()
        guard !activeTouches.isEmpty else { return }
        activeTouches.removeAll()
        onActiveTouchCountChanged?(0, .cancelled)
    }
}

/// Says yes to everything, so the touch observer is never cancelled by whoever
/// wins the gesture — it only watches, and must never block or be blocked.
///
/// A recognizer that is not permitted to run simultaneously is sent
/// `touchesCancelled` the moment another recognizer recognizes. For the observer
/// that means UIKit's text-selection interaction claiming the long press — i.e.
/// the exact instant the user's word gets selected — and the observer would
/// report its finger count dropping to zero while the finger is still down.
final class AlwaysSimultaneousDelegate: NSObject, UIGestureRecognizerDelegate {

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { true }

    /// Never wait for anyone: a failure requirement would delay or suppress the
    /// touch reports the commit lifecycle depends on.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { false }

    /// And never make anyone wait for us — the observer never recognizes, so
    /// requiring its failure would stall every other gesture on the view.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { false }
}

// MARK: - The controller

/// Drives one text view's selection: observes touches, applies the policy,
/// snaps at the surface's granularity, and emits committed ranges exactly once.
///
/// The surface keeps ownership of its own text view and chrome; this owns only
/// the lifecycle.
@MainActor
final class TextSelectionController {

    /// Injected per surface — `.verse` for the Read editor, `.word` for the
    /// Exegesis editor and the Bible reader (03 §5). Never `.character`.
    var granularity: HighlightGranularity

    /// Supplies the verse map when `granularity == .verse`. A closure rather
    /// than a stored array because the surface reparses on every content change.
    var verseRangesProvider: () -> [VerseRange]

    /// Called with the snapped range, once per release.
    var onCommit: ((NSRange) -> Void)?

    /// Scroll-lock machinery, carried rather than dropped (DECIDED 2026-08-04).
    let scrollLock: ScrollLockCoordinator

    private weak var textView: UITextView?
    private var policy = SelectionCommitPolicy()
    private var observer: TouchObserverGestureRecognizer?
    private var commitHop: DispatchWorkItem?
    private var lastEmittedRange = NSRange(location: NSNotFound, length: 0)

    init(
        granularity: HighlightGranularity,
        verseRangesProvider: @escaping () -> [VerseRange] = { [] },
        onCommit: ((NSRange) -> Void)? = nil
    ) {
        self.granularity = granularity
        self.verseRangesProvider = verseRangesProvider
        self.onCommit = onCommit
        self.scrollLock = ScrollLockCoordinator()
    }

    deinit {
        commitHop?.cancel()
    }

    /// Attach to a text view: installs the touch observer and takes over the
    /// scroll lock's view reference. The view keeps its own delegate — it
    /// forwards selection changes via `selectionChanged(to:)`.
    func attach(to textView: UITextView) {
        self.textView = textView
        scrollLock.anchorView = textView

        let observer = TouchObserverGestureRecognizer()
        observer.cancelsTouchesInView = false
        observer.delaysTouchesBegan = false
        observer.delaysTouchesEnded = false
        observer.onActiveTouchCountChanged = { [weak self] count, cause in
            self?.touchCountChanged(to: count, cause: cause)
        }
        textView.addGestureRecognizer(observer)
        self.observer = observer
    }

    // A `touchObserver` accessor used to sit here, documented as existing "so a
    // host can allow it to run simultaneously with everything else". No host
    // ever called it, and the observer was consequently cancelled by UIKit on
    // every long press. It now carries its own delegate, so there is nothing for
    // a host to do — and the accessor is gone rather than left as a standing
    // invitation to re-create the same dependency (2026-08-04).

    // MARK: Events in

    func touchCountChanged(
        to count: Int,
        cause: TouchObserverGestureRecognizer.Cause = .released
    ) {
        apply(policy.touchCountChanged(to: count, cause: cause))
    }

    func selectionChanged(to range: NSRange) {
        apply(policy.selectionChanged(to: range))
    }

    func viewReportedTouchesCancelled() {
        apply(policy.viewReportedTouchesCancelled())
    }

    /// Forget the last committed range so an identical selection commits again
    /// — call after the surface consumes or discards a highlight.
    func resetCommitDedupe() {
        lastEmittedRange = NSRange(location: NSNotFound, length: 0)
    }

    // MARK: Actions out

    private func apply(_ action: SelectionCommitPolicy.Action) {
        switch action {
        case .none:
            break

        case .cancelPendingCommit:
            commitHop?.cancel()
            commitHop = nil

        case .scheduleCommitHop:
            scheduleCommitHop()

        case .abandon:
            scrollLock.releaseAll(reason: "commit abandoned — nothing selected")

        case .commit(let range):
            commit(range)
        }
    }

    /// One runloop turn, so UIKit can settle `selectedRange` after the lift.
    ///
    /// Not a wall-clock wait: `DispatchQueue.main.async` yields exactly once and
    /// the policy re-checks the touch count when it lands, so a finger back on
    /// the glass abandons it. A timed `asyncAfter` here would be the very bug
    /// this file exists to prevent.
    private func scheduleCommitHop() {
        commitHop?.cancel()
        let hop = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.commitHop = nil
            self.apply(self.policy.commitHopFired())
        }
        commitHop = hop
        DispatchQueue.main.async(execute: hop)
    }

    private func commit(_ range: NSRange) {
        guard let textView else { return }
        let text = (textView.attributedText?.string ?? textView.text ?? "") as NSString

        guard range.location != NSNotFound,
              range.location >= 0,
              range.location + range.length <= text.length else {
            scrollLock.releaseAll(reason: "commit range out of bounds")
            return
        }

        let snapped = HighlightSnapping.snap(
            range, in: text,
            granularity: granularity,
            verseRanges: granularity == .verse ? verseRangesProvider() : []
        )

        guard snapped.length > 0, !NSEqualRanges(snapped, lastEmittedRange) else {
            scrollLock.releaseAll(reason: "commit duplicate or empty")
            return
        }

        lastEmittedRange = snapped
        onCommit?(snapped)
    }
}
