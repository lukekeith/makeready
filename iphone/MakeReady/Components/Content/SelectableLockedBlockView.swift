//
//  SelectableLockedBlockView.swift
//  MakeReady
//
//  Read-only UITextView wrapper for locked read blocks. Renders existing
//  ReadBlockSelection records as styled runs. Text selection works like the
//  Bible reader: tap a verse to select it, tap another to extend the range,
//  tap inside the selection to clear it.
//

import SwiftUI
import UIKit

struct SelectableLockedBlockView: UIViewRepresentable {
    let plainText: String
    let selections: [ReadBlockSelection]
    /// When false, the underlying UITextView refuses tap selection so
    /// the parent's drag-to-sort gesture (Dragula) handles long-press instead.
    /// Toggled on when the user enters explicit highlight mode.
    let isSelectionEnabled: Bool
    /// Range currently being edited via the style picker (if any). The matching
    /// span is rendered solid white with dark text to make it visually clear
    /// which selection the modal is acting on. nil while the picker is closed.
    let editingRange: NSRange?
    /// Set when the user finishes adjusting a non-empty selection.
    /// The parent presents the style picker on `.onChange`, then clears it.
    @Binding var pendingRange: NSRange?
    /// Font size for the verse text. Defaults to 16pt if not provided.
    var fontSize: CGFloat = 16
    /// When true, non-editing selections render as white bg with dark text
    /// (readable preview). When false, selections use purple highlight marker.
    var usePreviewHighlightStyle: Bool = false

    func makeUIView(context: Context) -> SelectionTextView {
        let view = SelectionTextView()
        view.delegate = context.coordinator
        view.isEditable = false
        view.isSelectable = false // We handle selection ourselves via taps
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        BibleVerseTextLayout.configureTextView(view)
        view.configureVerseBadges(
            verseRanges: Self.parseVerseRanges(from: plainText),
            target: context.coordinator,
            action: #selector(Coordinator.handleCircleTap(_:))
        )
        view.dataDetectorTypes = []
        view.linkTextAttributes = [:]
        view.adjustsFontForContentSizeCategory = false
        // Yellow/lime tint for active selection (matches Bible reader)
        view.tintColor = UIColor(red: 0xF4/255, green: 0xFF/255, blue: 0x76/255, alpha: 0.5)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.attributedText = makeAttributedString()

        // Build verse ranges from the plain text
        context.coordinator.verseRanges = Self.parseVerseRanges(from: plainText)

        // Single tap — select/extend/deselect verses (like Bible reader)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)
        context.coordinator.tapGesture = tap

        return view
    }

    func updateUIView(_ uiView: SelectionTextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.suppressSelectionCallbacks = true
        defer { context.coordinator.suppressSelectionCallbacks = false }

        uiView.attributedText = makeAttributedString()
        let verseRanges = Self.parseVerseRanges(from: plainText)
        context.coordinator.verseRanges = verseRanges
        uiView.configureVerseBadges(
            verseRanges: verseRanges,
            target: context.coordinator,
            action: #selector(Coordinator.handleCircleTap(_:))
        )

        // Clear any active selection when leaving highlight mode
        if !isSelectionEnabled && uiView.selectedRange.length > 0 {
            uiView.selectedRange = NSRange(location: 0, length: 0)
            if uiView.isFirstResponder {
                uiView.resignFirstResponder()
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: SelectionTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitted.height))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Verse Range Parsing

    /// Parse verse numbers from plain text. Verse numbers appear as digits
    /// at the start of a line, optionally followed by a period, and the verse
    /// range extends to the next parsed verse marker.
    /// Returns an array of (verseNumber, characterRange) tuples.
    static func parseVerseRanges(from text: String) -> [(verse: Int, range: NSRange)] {
        VerseSelectionLogic.parseVersePositions(from: text).verseRanges
    }

    // MARK: - Attributed String

    private func makeAttributedString() -> NSAttributedString {
        let baseColor = UIColor.white.withAlphaComponent(0.85)

        let parsed = VerseSelectionLogic.parseVersePositions(from: plainText)
        let attributed = BibleVerseTextLayout.baseAttributedText(
            plainText: plainText,
            verseNumberRanges: parsed.numberRanges,
            fontSize: fontSize,
            foregroundColor: baseColor
        )

        let editMarker = UIColor(red: 108.0/255.0, green: 71.0/255.0, blue: 255.0/255.0, alpha: 1.0)
        let length = attributed.length
        for selection in selections {
            let start = max(0, selection.start)
            let end = min(length, selection.end)
            guard end > start else { continue }
            let range = NSRange(location: start, length: end - start)
            let isEditing = editingRange.map {
                $0.location == start && $0.length == end - start
            } ?? false
            if isEditing {
                attributed.addAttribute(.backgroundColor, value: UIColor.white, range: range)
                attributed.addAttribute(.foregroundColor, value: UIColor.black, range: range)
            } else if usePreviewHighlightStyle {
                attributed.addAttribute(.backgroundColor, value: UIColor.white.withAlphaComponent(0.9), range: range)
                attributed.addAttribute(.foregroundColor, value: UIColor.black, range: range)
            } else {
                attributed.addAttribute(.backgroundColor, value: editMarker, range: range)
            }
        }

        return attributed
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: SelectableLockedBlockView
        var suppressSelectionCallbacks = false
        weak var tapGesture: UITapGestureRecognizer?
        var verseRanges: [(verse: Int, range: NSRange)] = []

        init(parent: SelectableLockedBlockView) {
            self.parent = parent
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            // No-op — we manage selection entirely through tap gestures
        }

        @objc func handleCircleTap(_ gesture: UITapGestureRecognizer) {
            guard parent.isSelectionEnabled,
                  gesture.state == .ended,
                  let circle = gesture.view,
                  let textView = circle.superview?.superview as? UITextView else { return }
            applyVerseTap(tappedVerse: circle.tag, in: textView)
        }

        /// Tap handler — works like the Bible reader:
        /// - Tap a verse → select it
        /// - Tap another verse → extend range to include it
        /// - Tap inside current selection → clear selection
        /// - Tap an existing highlight (ReadBlockSelection) → open its editor
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard parent.isSelectionEnabled,
                  gesture.state == .ended,
                  let textView = gesture.view as? UITextView else { return }

            let location = gesture.location(in: textView)
            let textOffset = CGPoint(
                x: location.x - textView.textContainerInset.left,
                y: location.y - textView.textContainerInset.top
            )
            let charIndex = textView.layoutManager.characterIndex(
                for: textOffset, in: textView.textContainer,
                fractionOfDistanceBetweenInsertionPoints: nil
            )

            // First check: did they tap an existing highlight (ReadBlockSelection)?
            // If so, open its editor instead of starting a new selection.
            if textView.selectedRange.length == 0 {
                for selection in parent.selections where charIndex >= selection.start && charIndex < selection.end {
                    let range = NSRange(location: selection.start, length: selection.end - selection.start)
                    let parent = self.parent
                    DispatchQueue.main.async {
                        parent.pendingRange = nil
                        DispatchQueue.main.async {
                            parent.pendingRange = range
                        }
                    }
                    return
                }
            }

            // Find which verse was tapped
            guard let tappedEntry = verseRanges.first(where: {
                charIndex >= $0.range.location &&
                charIndex < $0.range.location + $0.range.length
            }) else { return }

            applyVerseTap(tappedVerse: tappedEntry.verse, in: textView)
        }

        private func applyVerseTap(tappedVerse: Int, in textView: UITextView) {
            // Current selection expressed as a contiguous verse range
            let currentSelection = versesOverlapping(textView.selectedRange)
            let currentMin = currentSelection.first
            let currentMax = currentSelection.last

            // Tapping inside current selection → clear everything
            if let minV = currentMin, let maxV = currentMax,
               tappedVerse >= minV && tappedVerse <= maxV {
                textView.selectedRange = NSRange(location: 0, length: 0)
                if textView.isFirstResponder {
                    textView.resignFirstResponder()
                }

                // Fire the completed selection if there was one
                let clearedRange = rangeForVerses(from: minV, to: maxV)
                if let range = clearedRange, range.length > 0 {
                    let parent = self.parent
                    DispatchQueue.main.async {
                        parent.pendingRange = range
                    }
                }
                return
            }

            // No current selection → select just this verse
            // Existing selection → extend range to include tapped verse
            let newMin = min(currentMin ?? tappedVerse, tappedVerse)
            let newMax = max(currentMax ?? tappedVerse, tappedVerse)

            guard let newRange = rangeForVerses(from: newMin, to: newMax) else { return }

            // Make first responder so tint color renders the selection
            if !textView.isFirstResponder {
                textView.isSelectable = true
                textView.becomeFirstResponder()
            }
            textView.selectedRange = newRange
        }

        /// Find which verses overlap the given character range
        private func versesOverlapping(_ range: NSRange) -> [Int] {
            guard range.length > 0 else { return [] }
            let rangeEnd = range.location + range.length
            return verseRanges
                .filter { entry in
                    let entryEnd = entry.range.location + entry.range.length
                    return entry.range.location < rangeEnd && entryEnd > range.location
                }
                .map(\.verse)
                .sorted()
        }

        /// Build a character range spanning from verse `from` to verse `to` (inclusive)
        private func rangeForVerses(from: Int, to: Int) -> NSRange? {
            guard let startEntry = verseRanges.first(where: { $0.verse == from }),
                  let endEntry = verseRanges.first(where: { $0.verse == to }) else { return nil }
            let loc = startEntry.range.location
            let len = (endEntry.range.location + endEntry.range.length) - loc
            return NSRange(location: loc, length: len)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

/// UITextView subclass that suppresses the system edit menu.
final class SelectionTextView: UITextView {
    private let circleContainer = UIView()
    private var verseRanges: [VerseRange] = []
    private weak var badgeTarget: AnyObject?
    private var badgeAction: Selector?

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupVerseBadgeContainer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupVerseBadgeContainer()
    }

    private func setupVerseBadgeContainer() {
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
}

/// Known style identifiers.
enum ReadBlockSelectionStyle: String {
    case bold
    case highlight
}
