//
//  HighlightableTextView.swift
//  MakeReady
//
//  THE text view every highlighting surface mounts.
//
//  Two views do this job today and they diverged in every way that matters.
//  They render the same content, in different colours, from two copies of the
//  same layout code.
//
//  What actually differs is the input model, so that is the one thing injected:
//  `mode`. Everything downstream — snapping, painting, committing — is the
//  shared service.
//
//  **Both editors now use `.nativeDrag` / `.word`** (2026-08-04, 09 §X-q).
//  `SelectableLockedBlockView` used to be `.verseTap` / `.verse` — tap a verse
//  to select it, never first responder, so UIKit drew no selection at all — and
//  a phrase inside a verse could not be highlighted there. `.verseTap` survives
//  for `ExegesisVerseView`'s non-native path (read-only previews and the capture
//  registry, where selection is disabled anyway), so the mode is still a real
//  choice and not vestigial. Per the DECIDED "wrap, don't replace" (06 §Adopting
//  surfaces), the two existing views become thin wrappers over this rather than
//  being deleted, so the capture `ViewRegistry` keeps resolving.
//
//  See docs/features/highlighting/06-iphone.md.
//

import SwiftUI
import UIKit

/// How the user makes a selection on this surface.
enum HighlightSelectionMode: Equatable {
    /// Tap a verse, tap another to extend, tap inside to commit. The text view
    /// is never first responder, so there are no grab handles to fall out of
    /// sync with the painted span (monday#12668695071).
    case verseTap
    /// UIKit's native drag selection, committed on genuine release by
    /// `TextSelectionController` (monday#12708759849).
    case nativeDrag
}

struct HighlightableTextView: UIViewRepresentable {

    // Content
    let plainText: String
    var fontSize: CGFloat = 16
    /// Scripture renders in the print-Bible style (serif, justified).
    var isScripture: Bool = true

    // What to paint
    var highlights: [HighlightRenderer.Painted] = []
    var savedAppearance: HighlightAppearance = .saved
    /// The span currently open in the style picker / note editor.
    var editingRange: NSRange?

    // How selection works here
    var mode: HighlightSelectionMode
    var granularity: HighlightGranularity
    var isSelectionEnabled: Bool = true

    /// The in-progress selection, owned by the parent so SwiftUI updates cannot
    /// wipe it (monday#12668695071).
    @Binding var liveSelection: NSRange?

    /// A finished selection, snapped to `granularity`.
    var onCommit: ((NSRange) -> Void)?
    /// A tap that landed on an existing highlight rather than starting a new
    /// selection.
    var onHighlightTapped: ((NSRange) -> Void)?

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> HighlightTextView {
        let view = HighlightTextView()
        view.isEditable = false
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.dataDetectorTypes = []
        view.linkTextAttributes = [:]
        view.adjustsFontForContentSizeCategory = false
        BibleVerseTextLayout.configureTextView(view)
        view.tintColor = HighlightAppearance.live.backgroundColor

        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.required, for: .vertical)

        context.coordinator.attach(to: view)
        apply(to: view, context: context)
        return view
    }

    func updateUIView(_ uiView: HighlightTextView, context: Context) {
        context.coordinator.parent = self
        apply(to: uiView, context: context)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: HighlightTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitted.height))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Applying state

    private func apply(to view: HighlightTextView, context: Context) {
        let parsed = VerseSelectionLogic.parseVersePositions(from: plainText)
        context.coordinator.verseRanges = parsed.verseRanges
        context.coordinator.controller?.granularity = granularity

        // Only the drag surface hands selection to UIKit. The tap surface stays
        // non-selectable so no system handles ever appear.
        let wasSelectable = view.isSelectable
        view.isSelectable = isSelectionEnabled && mode == .nativeDrag

        // Turning selection off ends whatever was in flight — mirrors the old
        // view's reset when native selection was disabled (09 §X-p3).
        if wasSelectable, !view.isSelectable {
            context.coordinator.controller?.resetCommitDedupe()
            context.coordinator.controller?.scrollLock.releaseAll(reason: "selection disabled")
        }

        view.setBase(HighlightRenderer.attributedText(
            plainText: plainText,
            verseNumberRanges: parsed.numberRanges,
            fontSize: fontSize,
            foregroundColor: Self.textColor,
            serif: isScripture,
            justified: isScripture,
            highlights: highlights,
            savedAppearance: savedAppearance,
            editing: editingRange,
            live: mode == .verseTap && isSelectionEnabled ? liveSelection : nil
        ))

        view.configureVerseBadges(
            verseRanges: parsed.verseRanges,
            target: context.coordinator,
            action: #selector(Coordinator.handleCircleTap(_:))
        )
    }

    private static let textColor = UIColor.white.withAlphaComponent(0.85)

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {

        var parent: HighlightableTextView
        var verseRanges: [VerseRange] = []
        private(set) var controller: TextSelectionController?
        private weak var textView: HighlightTextView?

        init(parent: HighlightableTextView) {
            self.parent = parent
        }

        func attach(to view: HighlightTextView) {
            textView = view
            view.delegate = self

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.delegate = self
            view.addGestureRecognizer(tap)

            guard parent.mode == .nativeDrag else { return }

            // Freeze the enclosing scroll for the whole gesture, so the text
            // interaction cannot scroll the selection out from under the finger.
            view.onTouchesBegan = { [weak self] in
                guard self?.parent.isSelectionEnabled == true else { return }
                // A new touch sequence is unambiguously the user starting
                // something new, so a range committed earlier becomes
                // committable again. Without this the dedupe guard lives as long
                // as the view and re-highlighting a span you already highlighted
                // once does nothing at all — silently, since the commit path
                // exits through "duplicate or empty" (09 §X-p3). The old view
                // reset this in three places; the replacement had no callers.
                self?.controller?.resetCommitDedupe()
                self?.controller?.scrollLock.freeze(reason: "touchesBegan")
            }
            let releaseIfNothingSelected: () -> Void = { [weak self, weak view] in
                guard let self, let view, self.parent.isSelectionEnabled,
                      view.selectedRange.length == 0 else { return }
                self.controller?.scrollLock.extendFreeze(reason: "lifted with no selection",
                                                         releaseAfter: 0.2)
            }
            view.onTouchesEnded = releaseIfNothingSelected
            view.onTouchesCancelled = { [weak self] in
                self?.controller?.viewReportedTouchesCancelled()
                releaseIfNothingSelected()
            }

            let controller = TextSelectionController(
                granularity: parent.granularity,
                verseRangesProvider: { [weak self] in self?.verseRanges ?? [] },
                onCommit: { [weak self] range in self?.commit(range) }
            )
            controller.attach(to: view)
            self.controller = controller
        }

        /// Tear the live selection down and hand the range up.
        ///
        /// ⚠️ **The ordering here is tuned, not incidental** — it is carried from
        /// `ExegesisVerseView.selectionCommit` (pre-2026-08-04), and phase 4.4's
        /// move dropped two of its steps, which is 09 §X-p2:
        ///
        /// 1. The teardown is wrapped in `preservingScrollPosition` pinned to the
        ///    selection anchor. `resignFirstResponder()` makes UIKit scroll, and
        ///    without the pin it scrolls unopposed.
        /// 2. **`clearSelectionAnchor()` runs when the commit completes.** Without
        ///    it the anchor outlives the highlight, and the NEXT long press
        ///    freezes the scroll view at the previous highlight's offset — so
        ///    the page jumps backwards the moment the user starts their second
        ///    highlight. On the successful path nothing else clears it:
        ///    `releaseAll` is reached only from the three failure exits, and the
        ///    "selection emptied" route is deliberately suppressed here by
        ///    `ignoresEmptySelectionUntilRelease`.
        ///
        /// `onCommit` fires INSIDE the preserve, as it did before: it drives the
        /// SwiftUI state change that adds the highlight, and that relayout is
        /// part of what needs pinning.
        private func commit(_ range: NSRange) {
            parent.liveSelection = nil

            guard let view = textView, parent.mode == .nativeDrag else {
                parent.onCommit?(range)
                return
            }

            let scrollLock = controller?.scrollLock
            // Read before anything mutates: this is the offset the view was at
            // when the selection began, and the one the teardown must hold.
            let anchor = scrollLock?.textInteractionAnchor

            scrollLock?.ignoresEmptySelectionUntilRelease = true
            scrollLock?.preservingScrollPosition(targetOffset: anchor) {
                view.clearLivePreview()
                view.selectedRange = NSRange(location: 0, length: 0)
                if view.isFirstResponder { _ = view.resignFirstResponder() }
                self.parent.onCommit?(range)
            }
            scrollLock?.clearSelectionAnchor()
            scrollLock?.extendFreeze(reason: "commit settled", releaseAfter: 0.35)
        }

        // MARK: Taps

        @objc func handleCircleTap(_ gesture: UITapGestureRecognizer) {
            guard parent.isSelectionEnabled, gesture.state == .ended,
                  let circle = gesture.view else { return }
            applyVerseTap(circle.tag)
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard parent.isSelectionEnabled, gesture.state == .ended,
                  let view = gesture.view as? UITextView else { return }

            let offset = characterIndex(at: gesture.location(in: view), in: view)

            // A tap on an existing highlight opens it instead of starting a new
            // selection — but only when nothing is being selected right now.
            if parent.liveSelection == nil,
               let hit = parent.highlights.first(where: { $0.span.contains(offset: offset) }) {
                parent.onHighlightTapped?(hit.span.nsRange)
                return
            }

            guard parent.mode == .verseTap,
                  let verse = VerseTapPolicy.verse(containing: offset, verseRanges: verseRanges)
            else { return }

            applyVerseTap(verse)
        }

        private func applyVerseTap(_ verse: Int) {
            switch VerseTapPolicy.tap(verse: verse,
                                      liveSelection: parent.liveSelection,
                                      verseRanges: verseRanges) {
            case .select(let range):
                parent.liveSelection = range
            case .commit(let range):
                // Cleared synchronously so a second tap reads the new state.
                parent.liveSelection = nil
                parent.onCommit?(range)
            case .ignore:
                break
            }
        }

        private func characterIndex(at point: CGPoint, in view: UITextView) -> Int {
            let offset = CGPoint(x: point.x - view.textContainerInset.left,
                                 y: point.y - view.textContainerInset.top)
            return view.layoutManager.characterIndex(
                for: offset, in: view.textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )
        }

        // MARK: UITextViewDelegate

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard let view = textView as? HighlightTextView, !view.isApplyingPreview else { return }
            guard parent.mode == .nativeDrag, parent.isSelectionEnabled else { return }

            let range = view.selectedRange
            controller?.selectionChanged(to: range)

            guard range.length > 0 else {
                view.clearLivePreview()
                // An empty selection reported while a commit is settling is UIKit
                // tidying up, not the user dismissing — the locks stay.
                if controller?.scrollLock.ignoresEmptySelectionUntilRelease != true {
                    controller?.scrollLock.releaseAll(reason: "selection emptied")
                }
                return
            }

            controller?.scrollLock.captureSelectionAnchorIfNeeded(reason: "selectionChanged")
            view.applyLivePreview(range)
        }

        // MARK: UIGestureRecognizerDelegate

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // The touch observer only watches — it must never block or be
            // blocked. It carries its OWN delegate saying so (2026-08-04), and
            // this branch no longer has to fire for that to hold; it stays
            // because UIKit asks both recognizers' delegates and agreeing costs
            // nothing. Relying on this branch alone is what broke: the observer's
            // delegate was never set, so it was never asked.
            if gestureRecognizer is TouchObserverGestureRecognizer
                || otherGestureRecognizer is TouchObserverGestureRecognizer {
                return true
            }

            // On the drag surface our tap must not race UIKit's own text tap or
            // the enclosing scroll view's pan.
            let otherName = String(describing: type(of: otherGestureRecognizer))
            if parent.mode == .nativeDrag,
               gestureRecognizer is UITapGestureRecognizer,
               otherName.contains("UITextTapRecognizer") || otherName.contains("UIScrollViewPanGestureRecognizer") {
                return false
            }

            return true
        }
    }
}

// MARK: - The UITextView

/// `UITextView` with verse badges and no system edit menu.
///
/// Both existing surfaces subclass `UITextView` for exactly these two reasons
/// and lay their badges out with the same `BibleVerseTextLayout` helper; this is
/// that subclass, once.
final class HighlightTextView: UITextView {

    private let circleContainer = UIView()
    private var verseRanges: [VerseRange] = []
    private weak var badgeTarget: AnyObject?
    private var badgeAction: Selector?

    /// The text without any live-selection wash. The preview is painted ON TOP
    /// of this and thrown away, so a drag never accumulates.
    private var baseAttributedText: NSAttributedString?

    /// True while this view is rewriting its own storage. `textViewDidChangeSelection`
    /// fires during that, and acting on it would recurse.
    private(set) var isApplyingPreview = false

    var onTouchesBegan: (() -> Void)?
    var onTouchesEnded: (() -> Void)?
    var onTouchesCancelled: (() -> Void)?

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupBadgeContainer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupBadgeContainer()
    }

    private func setupBadgeContainer() {
        circleContainer.backgroundColor = .clear
        circleContainer.isUserInteractionEnabled = true
        addSubview(circleContainer)
    }

    func configureVerseBadges(verseRanges: [VerseRange], target: AnyObject, action: Selector) {
        self.verseRanges = verseRanges
        self.badgeTarget = target
        self.badgeAction = action
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        BibleVerseTextLayout.layoutVerseBadges(
            in: self,
            container: circleContainer,
            verseRanges: verseRanges,
            target: badgeTarget,
            action: badgeAction
        )
    }

    // MARK: Live-selection preview (native drag only)

    /// Install the rendered text, keeping any in-flight selection.
    ///
    /// Assigning `attributedText` resets `selectedRange`, so a SwiftUI update
    /// mid-drag would drop the user's selection — the crux of
    /// monday#12668695071.
    func setBase(_ attributed: NSAttributedString) {
        baseAttributedText = attributed
        withPreservedSelection { attributedText = attributed }
    }

    /// Paint the in-progress drag. UIKit's own selection wash is too subtle over
    /// the dark editor background, so the span is painted as a text attribute
    /// while the finger is down.
    func applyLivePreview(_ range: NSRange) {
        guard let base = baseAttributedText else { return }
        let mutable = NSMutableAttributedString(attributedString: base)
        guard HighlightRenderer.paint(.live, over: range, in: mutable) else { return }
        if let clamped = HighlightRenderer.clamp(range, to: mutable.length) {
            mutable.addAttribute(.foregroundColor, value: UIColor.black, range: clamped)
        }
        withPreservedSelection { textStorage.setAttributedString(mutable) }
    }

    func clearLivePreview() {
        guard let base = baseAttributedText else { return }
        withPreservedSelection { textStorage.setAttributedString(base) }
    }

    private func withPreservedSelection(_ work: () -> Void) {
        let selection = selectedRange
        isApplyingPreview = true
        work()
        if selection.location != NSNotFound,
           selection.location + selection.length <= textStorage.length {
            selectedRange = selection
        }
        isApplyingPreview = false
    }

    // MARK: Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        onTouchesBegan?()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        onTouchesEnded?()
    }

    /// UIKit delivers this while the finger is STILL DOWN once a recognizer
    /// claims the touch. It is bookkeeping only — never a release. The touch
    /// observer owns that (monday#12708759849).
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        onTouchesCancelled?()
    }

    /// Selection changes must never scroll the block into view — that is the
    /// jump the scroll lock exists to fight.
    override func scrollRangeToVisible(_ range: NSRange) {}

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool { false }

    override func buildMenu(with builder: UIMenuBuilder) {
        builder.remove(menu: .standardEdit)
        builder.remove(menu: .lookup)
        builder.remove(menu: .replace)
        builder.remove(menu: .share)
        builder.remove(menu: .format)
        super.buildMenu(with: builder)
    }
}
