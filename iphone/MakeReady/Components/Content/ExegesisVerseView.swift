//
//  ExegesisVerseView.swift
//  MakeReady
//
//  Bible-reader-style verse display with verse circles, tap-to-select,
//  and highlight rendering. Used in the exegesis activity editor.
//
//  Uses VerseSelectionLogic for shared selection/parsing logic.
//  The UITextView is returned DIRECTLY from UIViewRepresentable (not
//  wrapped in a container UIView) — matching the Bible reader pattern
//  so system text selection (handles + tint highlight) works correctly.
//

import SwiftUI
import UIKit

// MARK: - SwiftUI Wrapper

struct ExegesisVerseView: UIViewRepresentable {
    let plainText: String
    let highlights: [ReadBlockSelection]
    let isSelectionEnabled: Bool
    var fontSize: CGFloat = 16
    var usePreviewHighlightStyle: Bool = false
    var selectedHighlightRange: NSRange? = nil
    /// When true, the selected highlight is scrolled into view if it is outside
    /// the visible viewport. Kept explicit so ordinary highlight taps do not
    /// reintroduce selection-related scroll jumps.
    var scrollSelectedHighlightIntoView: Bool = false
    /// When true, long-press/drag uses UITextView's native character-level
    /// selection instead of the legacy tap-a-verse selection behavior.
    var usesNativeTextSelection: Bool = false
    var onRangeSelected: ((NSRange) -> Void)? = nil
    var onHighlightTapped: ((NSRange) -> Void)? = nil
    @Binding var pendingRange: NSRange?

    func makeUIView(context: Context) -> ExegesisTextView {
        let view = ExegesisTextView()
        view.onRangeSelected = { [self] range in
            let commit = {
                if let onRangeSelected {
                    onRangeSelected(range)
                } else {
                    pendingRange = range
                }
            }
            if Thread.isMainThread {
                commit()
            } else {
                DispatchQueue.main.async(execute: commit)
            }
        }
        view.onHighlightTapped = { [self] range in
            let commit = {
                if let onHighlightTapped {
                    onHighlightTapped(range)
                } else {
                    pendingRange = nil
                    DispatchQueue.main.async { pendingRange = range }
                }
            }
            if Thread.isMainThread {
                commit()
            } else {
                DispatchQueue.main.async(execute: commit)
            }
        }
        view.configureContent(
            plainText: plainText,
            highlights: highlights,
            isSelectionEnabled: isSelectionEnabled,
            fontSize: fontSize,
            usePreviewHighlightStyle: usePreviewHighlightStyle,
            selectedHighlightRange: selectedHighlightRange,
            scrollSelectedHighlightIntoView: scrollSelectedHighlightIntoView,
            usesNativeTextSelection: usesNativeTextSelection
        )
        return view
    }

    func updateUIView(_ uiView: ExegesisTextView, context: Context) {
        uiView.configureContent(
            plainText: plainText,
            highlights: highlights,
            isSelectionEnabled: isSelectionEnabled,
            fontSize: fontSize,
            usePreviewHighlightStyle: usePreviewHighlightStyle,
            selectedHighlightRange: selectedHighlightRange,
            scrollSelectedHighlightIntoView: scrollSelectedHighlightIntoView,
            usesNativeTextSelection: usesNativeTextSelection
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ExegesisTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let result = CGSize(width: width, height: ceil(fitted.height))
        return result
    }
}

// MARK: - UITextView subclass (returned directly from UIViewRepresentable)

final class ExegesisTextView: UITextView, UITextViewDelegate, UIGestureRecognizerDelegate {

    private let circleContainer = UIView()
    private var circleViews: [Int: UIView] = [:]
    private var verseRanges: [VerseRange] = []
    private var verseNumberRanges: [(verse: Int, range: NSRange)] = []

    private let brandPurple = UIColor(red: 108.0/255, green: 71.0/255, blue: 255.0/255, alpha: 1.0)
    /// Semi-transparent white for the active selection highlight (matches Figma spec)
    private let activeSelectionColor = UIColor.white.withAlphaComponent(0.25)
    /// Visible preview for native UITextView drag selection. UIKit's native
    /// selection wash is too subtle over the dark exegesis preview, so we add
    /// a temporary text attribute while the user is dragging.
    private let nativeSelectionPreviewColor = UIColor(red: 0xF4/255, green: 0xFF/255, blue: 0x76/255, alpha: 0.55)

    var onRangeSelected: ((NSRange) -> Void)?
    var onHighlightTapped: ((NSRange) -> Void)?

    private var currentHighlights: [ReadBlockSelection] = []
    private var selectionEnabled = false
    private var usesNativeSelection = false
    private var activeSelectionRange: NSRange = NSRange(location: 0, length: 0)
    private var baseAttributedText: NSAttributedString?
    private var selectionDebounceWorkItem: DispatchWorkItem?
    private var lastEmittedNativeSelectionRange = NSRange(location: NSNotFound, length: 0)
    private var nativeSelectionPreviewRange = NSRange(location: NSNotFound, length: 0)
    private var isApplyingNativeSelectionPreview = false
    private var isNativeSelectionTouchActive = false
    private var nativeSelectionScrollAnchor: CGPoint?
    private weak var nativeSelectionScrollView: UIScrollView?
    private var nativeSelectionScrollGuardWorkItems: [DispatchWorkItem] = []
    private var isCommittingNativeSelection = false
    private weak var frozenScrollView: UIScrollView?
    private var frozenScrollOffset: CGPoint?
    private var frozenScrollWasScrollEnabled: Bool?
    private var scrollFreezeDisplayLink: CADisplayLink?
    private var scrollFreezeReleaseWorkItem: DispatchWorkItem?
    private var preserveScrollWorkItems: [DispatchWorkItem] = []
    private var ignoresEmptySelectionUntilScrollFreezeRelease = false
    /// Commit shortly after the user releases a native tap-and-hold selection.
    /// Keeps highlight creation feeling responsive after finger lift while
    /// allowing UIKit a brief moment to settle the selected range.
    private let nativeSelectionTouchEndCommitDelay: TimeInterval = 0.5
    /// Debounce selection-change commits so UIKit handle adjustments can settle.
    private let nativeSelectionChangeSettleDelay: TimeInterval = 0.8

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    deinit {
        scrollFreezeReleaseWorkItem?.cancel()
        scrollFreezeDisplayLink?.invalidate()
        preserveScrollWorkItems.forEach { $0.cancel() }
        nativeSelectionScrollGuardWorkItems.forEach { $0.cancel() }
        selectionDebounceWorkItem?.cancel()
    }

    private func setup() {
        isEditable = false
        isSelectable = false  // Native selection is enabled only for character-level highlighting.
        delegate = self
        isScrollEnabled = false
        backgroundColor = .clear
        BibleVerseTextLayout.configureTextView(self)
        tintColor = UIColor(red: 0xF4/255, green: 0xFF/255, blue: 0x76/255, alpha: 1.0)
        dataDetectorTypes = []
        linkTextAttributes = [:]
        adjustsFontForContentSizeCategory = false

        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        addGestureRecognizer(tap)

        circleContainer.backgroundColor = .clear
        circleContainer.isUserInteractionEnabled = true
        addSubview(circleContainer)
    }

    private func textInteractionScrollAnchor() -> CGPoint? {
        nativeSelectionScrollAnchor ?? frozenScrollOffset
    }

    override func becomeFirstResponder() -> Bool {
        var result = false
        preservingEnclosingScrollPosition(targetOffset: textInteractionScrollAnchor()) {
            result = super.becomeFirstResponder()
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        var result = false
        preservingEnclosingScrollPosition(targetOffset: textInteractionScrollAnchor()) {
            result = super.resignFirstResponder()
        }
        return result
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if selectionEnabled, usesNativeSelection {
            isNativeSelectionTouchActive = true
            selectionDebounceWorkItem?.cancel()
            freezeEnclosingScroll(reason: "touchesBegan native text interaction")
        }
        super.touchesBegan(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        if selectionEnabled, usesNativeSelection {
            isNativeSelectionTouchActive = false
            if selectedRange.length > 0 {
                scheduleNativeSelectionCommit(reason: "touchesEnded", delay: nativeSelectionTouchEndCommitDelay)
            } else {
                extendScrollFreeze(reason: "touchesEnded without active native selection", releaseAfter: 0.2)
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        if selectionEnabled, usesNativeSelection {
            isNativeSelectionTouchActive = false
            if selectedRange.length > 0 {
                scheduleNativeSelectionCommit(reason: "touchesCancelled", delay: nativeSelectionTouchEndCommitDelay)
            } else {
                extendScrollFreeze(reason: "touchesCancelled without active native selection", releaseAfter: 0.2)
            }
        }
    }

    // Prevent auto-scroll when selection changes
    override func scrollRangeToVisible(_ range: NSRange) {
        // No-op: prevent auto-scroll when selection changes
    }

    private func enclosingScrollView() -> UIScrollView? {
        var view = superview
        while let current = view {
            if let scrollView = current as? UIScrollView {
                return scrollView
            }
            view = current.superview
        }
        return nil
    }

    private func preservingEnclosingScrollPosition(targetOffset: CGPoint? = nil, _ work: () -> Void) {
        guard let scrollView = enclosingScrollView() else {
            work()
            return
        }

        let offset = targetOffset ?? scrollView.contentOffset
        work()
        restoreScroll(scrollView, to: offset, reason: "preserveScroll immediate", allowDuringUserScroll: true)
        scheduleScrollRestores(scrollView: scrollView, offset: offset, reason: "preserveScroll")
    }

    private func restoreScroll(_ scrollView: UIScrollView, to offset: CGPoint, reason: String, allowDuringUserScroll: Bool = false) {
        if !allowDuringUserScroll,
           scrollView.isScrollEnabled,
           (scrollView.isDragging || scrollView.isDecelerating) {
            cancelPreserveScrollRestores(reason: "user scroll detected during \(reason)")
            return
        }

        guard !scrollView.isScrollEnabled || frozenScrollView === scrollView || !allowDuringUserScroll || scrollView.contentOffset != offset else {
            return
        }

        scrollView.setContentOffset(offset, animated: false)
    }

    private func scheduleScrollRestores(scrollView: UIScrollView, offset: CGPoint, reason: String) {
        let delays: [TimeInterval] = [0, 0.05, 0.2, 0.5]
        for delay in delays {
            let label = "\(reason) delay=\(String(format: "%.2f", delay))"
            let workItem = DispatchWorkItem { [weak self, weak scrollView] in
                guard let self, let scrollView else { return }
                self.restoreScroll(scrollView, to: offset, reason: label)
            }
            preserveScrollWorkItems.append(workItem)
            if delay == 0 {
                DispatchQueue.main.async(execute: workItem)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
            }
        }
    }

    private func cancelPreserveScrollRestores(reason: String) {
        guard !preserveScrollWorkItems.isEmpty else { return }
        preserveScrollWorkItems.forEach { $0.cancel() }
        preserveScrollWorkItems.removeAll()
    }

    private func freezeEnclosingScroll(reason: String, offset explicitOffset: CGPoint? = nil) {
        cancelPreserveScrollRestores(reason: "new scroll freeze reason=\(reason)")
        guard let scrollView = enclosingScrollView() else {
            return
        }

        let offset = explicitOffset ?? frozenScrollOffset ?? nativeSelectionScrollAnchor ?? scrollView.contentOffset
        if frozenScrollView == nil {
            frozenScrollWasScrollEnabled = scrollView.isScrollEnabled
        }

        frozenScrollView = scrollView
        frozenScrollOffset = offset
        scrollView.isScrollEnabled = false
        scrollView.panGestureRecognizer.isEnabled = false
        scrollView.panGestureRecognizer.isEnabled = true
        scrollView.setContentOffset(offset, animated: false)

        if scrollFreezeDisplayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(enforceScrollFreeze))
            link.add(to: .main, forMode: .common)
            scrollFreezeDisplayLink = link
        }
    }

    private func extendScrollFreeze(reason: String, releaseAfter delay: TimeInterval) {
        scrollFreezeReleaseWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.releaseScrollFreeze(reason: reason)
        }
        scrollFreezeReleaseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    @objc private func enforceScrollFreeze() {
        guard let scrollView = frozenScrollView, let offset = frozenScrollOffset else { return }
        if scrollView.contentOffset != offset {
            scrollView.setContentOffset(offset, animated: false)
        }
    }

    private func releaseScrollFreeze(reason: String) {
        scrollFreezeReleaseWorkItem?.cancel()
        scrollFreezeReleaseWorkItem = nil
        scrollFreezeDisplayLink?.invalidate()
        scrollFreezeDisplayLink = nil
        cancelPreserveScrollRestores(reason: "scrollFreeze release reason=\(reason)")
        ignoresEmptySelectionUntilScrollFreezeRelease = false

        guard let scrollView = frozenScrollView, let offset = frozenScrollOffset else { return }
        scrollView.setContentOffset(offset, animated: false)
        scrollView.isScrollEnabled = frozenScrollWasScrollEnabled ?? true
        frozenScrollView = nil
        frozenScrollOffset = nil
        frozenScrollWasScrollEnabled = nil
    }

    private func captureNativeSelectionScrollAnchorIfNeeded(reason: String) {
        guard usesNativeSelection, let scrollView = enclosingScrollView() else { return }

        if nativeSelectionScrollAnchor == nil {
            nativeSelectionScrollAnchor = scrollView.contentOffset
            nativeSelectionScrollView = scrollView
        }

        freezeEnclosingScroll(reason: "native selection \(reason)", offset: nativeSelectionScrollAnchor)
        scheduleNativeSelectionScrollGuard(reason: reason)
    }

    private func scheduleNativeSelectionScrollGuard(reason: String) {
        nativeSelectionScrollGuardWorkItems.forEach { $0.cancel() }
        nativeSelectionScrollGuardWorkItems.removeAll()

        let delays: [TimeInterval] = [0, 0.05, 0.2, 0.5, 0.75]
        for delay in delays {
            let workItem = DispatchWorkItem { [weak self] in
                self?.restoreNativeSelectionScrollAnchor(reason: "\(reason) guardDelay=\(String(format: "%.2f", delay))", requireActiveSelection: true)
            }
            nativeSelectionScrollGuardWorkItems.append(workItem)
            if delay == 0 {
                DispatchQueue.main.async(execute: workItem)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
            }
        }
    }

    private func restoreNativeSelectionScrollAnchor(reason: String, requireActiveSelection: Bool) {
        guard let anchor = nativeSelectionScrollAnchor,
              let scrollView = nativeSelectionScrollView ?? enclosingScrollView() else { return }

        if requireActiveSelection && selectedRange.length == 0 {
            return
        }

        scrollView.setContentOffset(anchor, animated: false)
    }

    private func clearNativeSelectionScrollAnchor(reason: String) {
        nativeSelectionScrollGuardWorkItems.forEach { $0.cancel() }
        nativeSelectionScrollGuardWorkItems.removeAll()
        nativeSelectionScrollAnchor = nil
        nativeSelectionScrollView = nil
    }

    private func clearAllScrollLocks(reason: String) {
        clearNativeSelectionScrollAnchor(reason: reason)
        releaseScrollFreeze(reason: reason)
    }

    // Suppress edit menu
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        false
    }

    override func buildMenu(with builder: UIMenuBuilder) {
        builder.remove(menu: .standardEdit)
        builder.remove(menu: .lookup)
        builder.remove(menu: .replace)
        builder.remove(menu: .share)
        builder.remove(menu: .format)
        super.buildMenu(with: builder)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutCircles()
    }

    // MARK: - Configure

    func configureContent(
        plainText: String,
        highlights: [ReadBlockSelection],
        isSelectionEnabled: Bool,
        fontSize: CGFloat,
        usePreviewHighlightStyle: Bool,
        selectedHighlightRange: NSRange? = nil,
        scrollSelectedHighlightIntoView: Bool = false,
        usesNativeTextSelection: Bool = false
    ) {
        let previousSelectedRange = selectedRange
        let shouldRestoreNativeSelection = isFirstResponder && usesNativeTextSelection && previousSelectedRange.length > 0

        self.currentHighlights = highlights
        self.selectionEnabled = isSelectionEnabled
        self.usesNativeSelection = usesNativeTextSelection
        isSelectable = isSelectionEnabled && usesNativeTextSelection

        if !isSelectionEnabled || !usesNativeTextSelection {
            selectedRange = NSRange(location: 0, length: 0)
            selectionDebounceWorkItem?.cancel()
            isNativeSelectionTouchActive = false
            lastEmittedNativeSelectionRange = NSRange(location: NSNotFound, length: 0)
            nativeSelectionPreviewRange = NSRange(location: NSNotFound, length: 0)
            clearAllScrollLocks(reason: "configureContent disabled native selection")
        }

        let parsed = VerseSelectionLogic.parseVersePositions(from: plainText)
        verseRanges = parsed.verseRanges
        verseNumberRanges = parsed.numberRanges

        let attrText = Self.buildAttributedText(
            plainText: plainText,
            verseNumberRanges: verseNumberRanges,
            highlights: highlights,
            fontSize: fontSize,
            usePreviewHighlightStyle: usePreviewHighlightStyle,
            selectedHighlightRange: selectedHighlightRange,
            brandPurple: brandPurple
        )

        baseAttributedText = attrText

        if !isSelectionEnabled {
            activeSelectionRange = NSRange(location: 0, length: 0)
        }

        applyActiveSelection()

        if usesNativeTextSelection,
           !shouldRestoreNativeSelection,
           selectedRange.length == 0,
           selectedRange.location == attributedText.length {
            preservingEnclosingScrollPosition {
                selectedRange = NSRange(location: 0, length: 0)
            }
        }

        if shouldRestoreNativeSelection,
           previousSelectedRange.location != NSNotFound,
           previousSelectedRange.location + previousSelectedRange.length <= attributedText.length {
            selectedRange = previousSelectedRange
            applyNativeSelectionPreview(previousSelectedRange, reason: "configureContent restore native selection")
        } else {
            nativeSelectionPreviewRange = NSRange(location: NSNotFound, length: 0)
        }

        setNeedsLayout()
        DispatchQueue.main.async { [weak self] in
            self?.layoutCircles()
            if scrollSelectedHighlightIntoView, let selectedHighlightRange {
                self?.scrollSelectedHighlightIntoViewIfNeeded(selectedHighlightRange, reason: "configureContent selectedHighlight")
            }
        }
    }

    // MARK: - Attributed Text

    private static func buildAttributedText(
        plainText: String,
        verseNumberRanges: [(verse: Int, range: NSRange)],
        highlights: [ReadBlockSelection],
        fontSize: CGFloat,
        usePreviewHighlightStyle: Bool,
        selectedHighlightRange: NSRange? = nil,
        brandPurple: UIColor
    ) -> NSAttributedString {
        let attributed = BibleVerseTextLayout.baseAttributedText(
            plainText: plainText,
            verseNumberRanges: verseNumberRanges,
            fontSize: fontSize,
            foregroundColor: UIColor.white
        )
        let defaultHighlightColor = UIColor(red: 0xF4/255, green: 0xFF/255, blue: 0x76/255, alpha: 0.35)

        let length = attributed.length
        for highlight in highlights {
            let start = max(0, highlight.start)
            let end = min(length, highlight.end)
            guard end > start else { continue }
            let range = NSRange(location: start, length: end - start)

            let isSelected = selectedHighlightRange.map {
                $0.location == start && $0.length == end - start
            } ?? false

            if isSelected {
                attributed.addAttribute(.backgroundColor, value: UIColor.white, range: range)
                attributed.addAttribute(.foregroundColor, value: UIColor.black, range: range)
            } else if ReadBlockSelectionStyle(rawValue: highlight.style) == .bold {
                attributed.addAttribute(.font, value: BibleVerseTextLayout.serifFont(size: fontSize, weight: .bold), range: range)
            } else if usePreviewHighlightStyle {
                attributed.addAttribute(.backgroundColor, value: UIColor.white.withAlphaComponent(0.9), range: range)
                attributed.addAttribute(.foregroundColor, value: UIColor.black, range: range)
            } else {
                attributed.addAttribute(.backgroundColor, value: defaultHighlightColor, range: range)
            }
        }

        return attributed
    }

    // MARK: - Verse Circles

    private func layoutCircles() {
        circleViews = BibleVerseTextLayout.layoutVerseBadges(
            in: self,
            container: circleContainer,
            verseRanges: verseRanges,
            target: self,
            action: #selector(circleTapped(_:))
        )
    }

    private func scrollSelectedHighlightIntoViewIfNeeded(_ range: NSRange, reason: String) {
        guard range.location != NSNotFound,
              range.location >= 0,
              range.length > 0,
              range.location + range.length <= attributedText.length else {
            return
        }
        guard let scrollView = enclosingScrollView(), window != nil else {
            return
        }
        guard !scrollView.isDragging, !scrollView.isDecelerating else {
            return
        }

        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        guard glyphRange.location != NSNotFound, glyphRange.length > 0 else {
            return
        }

        var highlightRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        highlightRect.origin.x += textContainerInset.left
        highlightRect.origin.y += textContainerInset.top
        highlightRect = highlightRect.insetBy(dx: -8, dy: -16)

        let highlightWindowRect = convert(highlightRect, to: nil)
        var visibleWindowRect = scrollView.convert(scrollView.bounds, to: nil)
        let topPadding: CGFloat = 16 + scrollView.adjustedContentInset.top
        let bottomPadding: CGFloat = 220 + scrollView.adjustedContentInset.bottom
        visibleWindowRect.origin.y += topPadding
        visibleWindowRect.size.height = max(80, visibleWindowRect.height - topPadding - bottomPadding)

        guard !visibleWindowRect.contains(highlightWindowRect) else {
            return
        }

        releaseScrollFreeze(reason: "selectedHighlightScroll intentional navigation")
        cancelPreserveScrollRestores(reason: "selectedHighlightScroll intentional navigation")

        var targetOffset = scrollView.contentOffset
        if highlightWindowRect.maxY > visibleWindowRect.maxY {
            targetOffset.y += highlightWindowRect.maxY - visibleWindowRect.maxY
        } else if highlightWindowRect.minY < visibleWindowRect.minY {
            targetOffset.y -= visibleWindowRect.minY - highlightWindowRect.minY
        }

        let minY = -scrollView.adjustedContentInset.top
        let maxY = max(minY, scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
        targetOffset.y = min(max(targetOffset.y, minY), maxY)

        scrollView.setContentOffset(targetOffset, animated: true)
    }

    // MARK: - Active Selection Highlight

    private func applyActiveSelection() {
        guard let base = baseAttributedText else {
            return
        }

        if activeSelectionRange.length == 0 {
            attributedText = base
            return
        }

        let mutable = NSMutableAttributedString(attributedString: base)
        let start = max(0, activeSelectionRange.location)
        let end = min(mutable.length, activeSelectionRange.location + activeSelectionRange.length)
        if end > start {
            let range = NSRange(location: start, length: end - start)
            mutable.addAttribute(.backgroundColor, value: activeSelectionColor, range: range)
        }
        attributedText = mutable
    }

    private func applyNativeSelectionPreview(_ range: NSRange, reason: String) {
        guard usesNativeSelection, let base = baseAttributedText else { return }
        let start = max(0, range.location)
        let end = min(base.length, range.location + range.length)
        guard range.location != NSNotFound, end > start else {
            clearNativeSelectionPreview(reason: "invalid preview range reason=\(reason)")
            return
        }

        let currentSelection = selectedRange
        let mutable = NSMutableAttributedString(attributedString: base)
        let previewRange = NSRange(location: start, length: end - start)
        mutable.addAttribute(.backgroundColor, value: nativeSelectionPreviewColor, range: previewRange)
        mutable.addAttribute(.foregroundColor, value: UIColor.black, range: previewRange)

        isApplyingNativeSelectionPreview = true
        textStorage.setAttributedString(mutable)
        if currentSelection.location != NSNotFound,
           currentSelection.location + currentSelection.length <= mutable.length {
            selectedRange = currentSelection
        }
        isApplyingNativeSelectionPreview = false
        nativeSelectionPreviewRange = previewRange
    }

    private func clearNativeSelectionPreview(reason: String) {
        guard nativeSelectionPreviewRange.location != NSNotFound else { return }
        let currentSelection = selectedRange
        if let base = baseAttributedText {
            isApplyingNativeSelectionPreview = true
            textStorage.setAttributedString(base)
            if currentSelection.location != NSNotFound,
               currentSelection.location + currentSelection.length <= base.length {
                selectedRange = currentSelection
            }
            isApplyingNativeSelectionPreview = false
        }
        nativeSelectionPreviewRange = NSRange(location: NSNotFound, length: 0)
    }

    private func updateCircleHighlights() {
        let states = VerseSelectionLogic.circleStates(
            verseRanges: verseRanges,
            selection: activeSelectionRange
        )
        for (verse, state) in states {
            guard let circle = circleViews[verse] else { continue }
            let label = circle.subviews.compactMap { $0 as? UILabel }.first
            // Gutter numbers carry selection state through color alone.
            if state.isSelected {
                label?.textColor = brandPurple
                label?.font = BibleVerseTextLayout.serifFont(size: 12, weight: .bold)
            } else {
                label?.textColor = BibleVerseTextLayout.verseNumberColor
                label?.font = BibleVerseTextLayout.verseNumberFont
            }
        }
    }

    // MARK: - Selection (attributed string background — wraps text tightly)

    private func setSelection(_ range: NSRange) {
        activeSelectionRange = range
        lastEmittedNativeSelectionRange = NSRange(location: NSNotFound, length: 0)
        applyActiveSelection()
        updateCircleHighlights()
    }

    private func clearSelection() {
        activeSelectionRange = NSRange(location: 0, length: 0)
        selectedRange = NSRange(location: 0, length: 0)
        lastEmittedNativeSelectionRange = NSRange(location: NSNotFound, length: 0)
        clearNativeSelectionPreview(reason: "clearSelection")
        applyActiveSelection()
        updateCircleHighlights()
    }

    // MARK: - UITextViewDelegate

    func textViewDidChangeSelection(_ textView: UITextView) {
        if isApplyingNativeSelectionPreview {
            return
        }

        let eventText = (textView.attributedText?.string ?? "") as NSString
        guard selectionEnabled, usesNativeSelection, textView.selectedRange.length > 0 else {
            if usesNativeSelection && textView.selectedRange.length == 0 {
                clearNativeSelectionPreview(reason: "selection changed to empty")
                if !isCommittingNativeSelection && !ignoresEmptySelectionUntilScrollFreezeRelease {
                    clearAllScrollLocks(reason: "selection changed to empty")
                }
            }
            return
        }

        let rawRange = textView.selectedRange
        let nsText = eventText
        guard rawRange.location != NSNotFound,
              rawRange.location >= 0,
              rawRange.location + rawRange.length <= nsText.length else {
            return
        }

        captureNativeSelectionScrollAnchorIfNeeded(reason: "selectionChanged")
        applyNativeSelectionPreview(rawRange, reason: "selectionChanged")
        scheduleNativeSelectionCommit(reason: "selectionChanged", delay: nativeSelectionChangeSettleDelay)
    }

    private func scheduleNativeSelectionCommit(reason: String, delay: TimeInterval) {
        selectionDebounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.selectionEnabled,
                  self.usesNativeSelection,
                  self.selectedRange.length > 0 else {
                self?.clearAllScrollLocks(reason: "selectionCommit skipped guard reason=\(reason)")
                return
            }

            if self.isNativeSelectionTouchActive {
                self.scheduleNativeSelectionCommit(reason: "\(reason) touch still active", delay: 0.25)
                return
            }

            let latestRange = self.selectedRange
            let latestText = (self.attributedText?.string ?? "") as NSString
            let anchorOffset = self.nativeSelectionScrollAnchor
            guard latestRange.location != NSNotFound,
                  latestRange.location >= 0,
                  latestRange.location + latestRange.length <= latestText.length else {
                self.clearAllScrollLocks(reason: "selectionCommit invalid range")
                return
            }

            let selectedRange = latestRange
            guard selectedRange.length > 0,
                  !NSEqualRanges(selectedRange, self.lastEmittedNativeSelectionRange) else {
                self.clearAllScrollLocks(reason: "selectionCommit duplicate or empty")
                return
            }

            self.lastEmittedNativeSelectionRange = selectedRange
            self.isCommittingNativeSelection = true
            self.preservingEnclosingScrollPosition(targetOffset: anchorOffset) {
                self.clearNativeSelectionPreview(reason: "selectionCommit before clear")
                self.selectedRange = NSRange(location: 0, length: 0)
                if self.isFirstResponder {
                    _ = self.resignFirstResponder()
                }
                self.onRangeSelected?(selectedRange)
            }
            self.isCommittingNativeSelection = false
            self.clearNativeSelectionScrollAnchor(reason: "selectionCommit complete")
            self.ignoresEmptySelectionUntilScrollFreezeRelease = true
            self.extendScrollFreeze(reason: "selectionCommit complete", releaseAfter: 0.35)
        }
        selectionDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    // MARK: - Tap Handlers

    @objc private func circleTapped(_ gesture: UITapGestureRecognizer) {
        guard selectionEnabled, !usesNativeSelection, let circle = gesture.view else { return }

        if let newRange = VerseSelectionLogic.handleCircleTap(
            verseNum: circle.tag,
            currentSelection: activeSelectionRange,
            verseRanges: verseRanges
        ) {
            setSelection(newRange)
        } else {
            let sel = activeSelectionRange
            if sel.length > 0 { onRangeSelected?(sel) }
            clearSelection()
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard selectionEnabled, gesture.state == .ended else { return }
        let point = gesture.location(in: self)
        let textOffset = CGPoint(
            x: point.x - textContainerInset.left,
            y: point.y - textContainerInset.top
        )
        let charIndex = layoutManager.characterIndex(
            for: textOffset, in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )

        if let scrollView = enclosingScrollView(), scrollView.isDragging || scrollView.isDecelerating {
            return
        }

        if activeSelectionRange.length == 0 {
            for highlight in currentHighlights where charIndex >= highlight.start && charIndex < highlight.end {
                let range = NSRange(location: highlight.start, length: highlight.end - highlight.start)
                let offset = enclosingScrollView()?.contentOffset
                freezeEnclosingScroll(reason: "highlight tap", offset: offset)
                ignoresEmptySelectionUntilScrollFreezeRelease = true
                preservingEnclosingScrollPosition(targetOffset: offset) {
                    selectedRange = NSRange(location: 0, length: 0)
                }
                DispatchQueue.main.async { [weak self] in
                    self?.onHighlightTapped?(range)
                }
                extendScrollFreeze(reason: "highlight tap complete", releaseAfter: 0.35)
                return
            }
        }

        guard !usesNativeSelection else {
            return
        }

        if let newRange = VerseSelectionLogic.handleTextTap(
            charIndex: charIndex,
            currentSelection: activeSelectionRange,
            verseRanges: verseRanges
        ) {
            setSelection(newRange)
        } else {
            let selection = activeSelectionRange
            if selection.length > 0 { onRangeSelected?(selection) }
            clearSelection()
        }
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        let otherName = String(describing: type(of: otherGestureRecognizer))

        if usesNativeSelection,
           otherName.contains("UIScrollViewPanGestureRecognizer"),
           frozenScrollView == nil {
            cancelPreserveScrollRestores(reason: "outer pan gesture began")
        }

        if usesNativeSelection,
           gestureRecognizer is UITapGestureRecognizer,
           (otherName.contains("UITextTapRecognizer") || otherName.contains("UIScrollViewPanGestureRecognizer")) {
            return false
        }

        return true
    }
}
