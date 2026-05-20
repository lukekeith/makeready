# Exegesis Highlight Modal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move exegesis highlighting from inline (broken by nested ScrollView) to a full-screen modal where system text selection works correctly — matching the Bible reader pattern.

**Architecture:** The preview container becomes tappable (replacing the floating highlighter button). Tapping it presents a full-screen modal via `overlayManager.presentModal()` containing ExegesisVerseView with system selection (becomeFirstResponder). ExegesisVerseView reverts to the Bible reader pattern (isSelectable toggling, no attribute-based highlight workaround). All highlight CRUD stays in EditExegesisActivityPage; the modal receives highlights and fires callbacks.

**Tech Stack:** SwiftUI, UIKit (UITextView selection), OverlayManager

---

### Task 1: Register OverlayID for Exegesis Highlight Modal

**Files:**
- Modify: `MakeReady/Services/OverlayManager.swift:122-123`

- [ ] **Step 1: Add the overlay ID**

In `OverlayManager.swift`, add after the `stylePicker` line (around line 123):

```swift
    // Exegesis highlight modal
    static let exegesisHighlightModal = "exegesisHighlightModal"
```

- [ ] **Step 2: Commit**

```bash
cd /Users/lukekeith/www/makeready/iphone
git add MakeReady/Services/OverlayManager.swift
git commit -m "feat: add OverlayID for exegesis highlight modal"
```

---

### Task 2: Revert ExegesisVerseView to System Selection (Bible Reader Pattern)

**Files:**
- Modify: `MakeReady/Components/Content/ExegesisVerseView.swift`

The current file uses attribute-based highlighting (yellow background via NSAttributedString). Revert to using system selection (becomeFirstResponder + isSelectable toggling) — the same pattern as `SelectableLockedBlockView` (Bible reader). This works because the modal won't have a nested ScrollView.

- [ ] **Step 1: Rewrite ExegesisVerseView.swift**

Replace the entire file with:

```swift
//
//  ExegesisVerseView.swift
//  MakeReady
//
//  Bible-reader-style verse display with verse circles, tap-to-select,
//  and highlight rendering. Used in the exegesis highlight modal.
//
//  Uses VerseSelectionLogic for shared selection/parsing logic.
//  Selection uses system UITextView selection (isSelectable + becomeFirstResponder)
//  matching the Bible reader (SelectableLockedBlockView) pattern.
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
    @Binding var pendingRange: NSRange?

    func makeUIView(context: Context) -> ExegesisVerseUIView {
        let view = ExegesisVerseUIView()
        view.onRangeSelected = { [self] range in
            DispatchQueue.main.async { pendingRange = range }
        }
        view.onHighlightTapped = { [self] range in
            DispatchQueue.main.async {
                pendingRange = nil
                DispatchQueue.main.async { pendingRange = range }
            }
        }
        view.configure(
            plainText: plainText,
            highlights: highlights,
            isSelectionEnabled: isSelectionEnabled,
            fontSize: fontSize,
            usePreviewHighlightStyle: usePreviewHighlightStyle,
            selectedHighlightRange: selectedHighlightRange
        )
        return view
    }

    func updateUIView(_ uiView: ExegesisVerseUIView, context: Context) {
        uiView.configure(
            plainText: plainText,
            highlights: highlights,
            isSelectionEnabled: isSelectionEnabled,
            fontSize: fontSize,
            usePreviewHighlightStyle: usePreviewHighlightStyle,
            selectedHighlightRange: selectedHighlightRange
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ExegesisVerseUIView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitted.height))
    }
}

// MARK: - UIKit Implementation

final class ExegesisVerseUIView: UIView, UITextViewDelegate, UIGestureRecognizerDelegate {

    private let textView = ExegesisTextView()
    private let circleContainer = UIView()
    private var circleViews: [Int: UIView] = [:]
    private var verseRanges: [VerseRange] = []
    private var verseNumberRanges: [(verse: Int, range: NSRange)] = []

    private let brandPurple = UIColor(red: 108.0/255, green: 71.0/255, blue: 255.0/255, alpha: 1.0)

    var onRangeSelected: ((NSRange) -> Void)?
    var onHighlightTapped: ((NSRange) -> Void)?

    private var currentHighlights: [ReadBlockSelection] = []
    private var isSelectionEnabled = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear

        textView.isEditable = false
        textView.isSelectable = false  // Toggled on per-tap like Bible reader
        textView.delegate = self
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 48, bottom: 8, right: 16)
        textView.tintColor = UIColor(red: 0xF4/255, green: 0xFF/255, blue: 0x76/255, alpha: 0.5)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)

        let tap = UITapGestureRecognizer(target: self, action: #selector(textTapped(_:)))
        tap.delegate = self
        textView.addGestureRecognizer(tap)

        addSubview(textView)

        circleContainer.backgroundColor = .clear
        circleContainer.isUserInteractionEnabled = true
        addSubview(circleContainer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = bounds
        layoutCircles()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let fitted = textView.sizeThatFits(CGSize(width: size.width, height: .greatestFiniteMagnitude))
        return CGSize(width: size.width, height: ceil(fitted.height))
    }

    // MARK: - Configure

    func configure(
        plainText: String,
        highlights: [ReadBlockSelection],
        isSelectionEnabled: Bool,
        fontSize: CGFloat,
        usePreviewHighlightStyle: Bool,
        selectedHighlightRange: NSRange? = nil
    ) {
        self.currentHighlights = highlights
        self.isSelectionEnabled = isSelectionEnabled

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

        textView.attributedText = attrText

        if !isSelectionEnabled {
            textView.selectedRange = NSRange(location: 0, length: 0)
            if textView.isFirstResponder { textView.resignFirstResponder() }
            textView.isSelectable = false
        }

        setNeedsLayout()
        DispatchQueue.main.async { [weak self] in
            self?.layoutCircles()
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
        let verseStyle = NSMutableParagraphStyle()
        verseStyle.lineSpacing = 6
        verseStyle.paragraphSpacing = 8

        let attributed = NSMutableAttributedString(
            string: plainText,
            attributes: [
                .font: UIFont.systemFont(ofSize: fontSize),
                .foregroundColor: UIColor.white,
                .paragraphStyle: verseStyle,
            ]
        )

        for entry in verseNumberRanges {
            let range = entry.range
            if range.location + range.length <= attributed.length {
                attributed.addAttribute(.foregroundColor, value: UIColor.clear, range: range)
                attributed.addAttribute(.font, value: UIFont.systemFont(ofSize: 1), range: range)
            }
        }

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
            } else if usePreviewHighlightStyle {
                attributed.addAttribute(.backgroundColor, value: UIColor.white.withAlphaComponent(0.9), range: range)
                attributed.addAttribute(.foregroundColor, value: UIColor.black, range: range)
            } else {
                attributed.addAttribute(.backgroundColor, value: brandPurple, range: range)
            }
        }

        return attributed
    }

    // MARK: - Verse Circles

    private func layoutCircles() {
        circleContainer.subviews.forEach { $0.removeFromSuperview() }
        circleViews.removeAll()

        let layoutManager = textView.layoutManager
        let inset = textView.textContainerInset

        for entry in verseRanges {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: entry.range, actualCharacterRange: nil)
            guard glyphRange.location != NSNotFound else { continue }
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)

            let circleY = lineRect.minY + inset.top
            let circleX: CGFloat = 16

            let circle = UIView(frame: CGRect(x: circleX, y: circleY, width: 24, height: 24))
            circle.layer.cornerRadius = 12
            circle.backgroundColor = UIColor(white: 1, alpha: 0.1)

            let label = UILabel()
            label.text = "\(entry.verse)"
            label.font = .systemFont(ofSize: 11, weight: .semibold)
            label.textColor = UIColor(white: 1, alpha: 0.6)
            label.textAlignment = .center
            label.frame = circle.bounds
            label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            circle.addSubview(label)

            circle.tag = entry.verse
            circle.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(circleTapped(_:)))
            circle.addGestureRecognizer(tap)

            circleContainer.addSubview(circle)
            circleViews[entry.verse] = circle
        }

        let contentHeight = textView.sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude)).height
        circleContainer.frame = CGRect(x: 0, y: 0, width: 48, height: contentHeight)
    }

    private func updateCircleHighlights() {
        let states = VerseSelectionLogic.circleStates(
            verseRanges: verseRanges,
            selection: textView.selectedRange
        )
        for (verse, state) in states {
            guard let circle = circleViews[verse] else { continue }
            let label = circle.subviews.compactMap { $0 as? UILabel }.first
            if state.isSelected {
                circle.backgroundColor = brandPurple
                label?.textColor = .white
            } else {
                circle.backgroundColor = UIColor(white: 1, alpha: 0.1)
                label?.textColor = UIColor(white: 1, alpha: 0.6)
            }
        }
    }

    // MARK: - Selection (Bible reader pattern)

    private func setSelection(_ range: NSRange) {
        if !textView.isSelectable {
            textView.isSelectable = true
        }
        if !textView.isFirstResponder {
            textView.becomeFirstResponder()
        }
        textView.selectedRange = range
        updateCircleHighlights()
    }

    private func clearSelection() {
        textView.selectedRange = NSRange(location: 0, length: 0)
        if textView.isFirstResponder { textView.resignFirstResponder() }
        updateCircleHighlights()
    }

    // MARK: - UITextViewDelegate

    func textViewDidChangeSelection(_ textView: UITextView) {
        // No-op — selection managed through tap gestures (like Bible reader)
    }

    // MARK: - Tap Handlers

    @objc private func circleTapped(_ gesture: UITapGestureRecognizer) {
        guard isSelectionEnabled, let circle = gesture.view else { return }

        if let newRange = VerseSelectionLogic.handleCircleTap(
            verseNum: circle.tag,
            currentSelection: textView.selectedRange,
            verseRanges: verseRanges
        ) {
            setSelection(newRange)
        } else {
            let sel = textView.selectedRange
            if sel.length > 0 { onRangeSelected?(sel) }
            clearSelection()
        }
    }

    @objc private func textTapped(_ gesture: UITapGestureRecognizer) {
        guard isSelectionEnabled else { return }
        let point = gesture.location(in: textView)
        let textOffset = CGPoint(
            x: point.x - textView.textContainerInset.left,
            y: point.y - textView.textContainerInset.top
        )
        let charIndex = textView.layoutManager.characterIndex(
            for: textOffset, in: textView.textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )

        if textView.selectedRange.length == 0 {
            for highlight in currentHighlights where charIndex >= highlight.start && charIndex < highlight.end {
                let range = NSRange(location: highlight.start, length: highlight.end - highlight.start)
                onHighlightTapped?(range)
                return
            }
        }

        if let newRange = VerseSelectionLogic.handleTextTap(
            charIndex: charIndex,
            currentSelection: textView.selectedRange,
            verseRanges: verseRanges
        ) {
            setSelection(newRange)
        } else {
            clearSelection()
        }
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

// MARK: - Text View Subclass

/// Matches SelectionTextView (Bible reader) — suppresses edit menu only.
private final class ExegesisTextView: UITextView {
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
```

- [ ] **Step 2: Commit**

```bash
cd /Users/lukekeith/www/makeready/iphone
git add MakeReady/Components/Content/ExegesisVerseView.swift
git commit -m "feat: revert ExegesisVerseView to system selection (Bible reader pattern)"
```

---

### Task 3: Create ExegesisHighlightModal

**Files:**
- Create: `MakeReady/Pages/Manage/Program/ExegesisHighlightModal.swift`

This modal presents the verse content with system selection enabled, plus the highlights list. It receives data and fires callbacks — all CRUD stays in EditExegesisActivityPage.

- [ ] **Step 1: Create the modal view**

Create `MakeReady/Pages/Manage/Program/ExegesisHighlightModal.swift`:

```swift
//
//  ExegesisHighlightModal.swift
//  MakeReady
//
//  Full-screen modal for highlighting exegesis verses.
//  Uses system text selection (becomeFirstResponder) since the modal
//  has no nested ScrollView — matching the Bible reader pattern.
//

import SwiftUI

struct ExegesisHighlightModal: View {
    let plainText: String
    let highlights: [ExegesisHighlight]
    let canEdit: Bool
    let onHighlightCreated: (NSRange) -> Void
    let onHighlightTapped: (ExegesisHighlight) -> Void
    let onHighlightDeleted: (ExegesisHighlight) -> Void
    let onDismiss: () -> Void

    @State private var pendingRange: NSRange? = nil
    @State private var selectedHighlight: ExegesisHighlight? = nil

    private var derivedSelections: [ReadBlockSelection] {
        highlights.map { ReadBlockSelection(start: $0.start, end: $0.end, style: "highlight") }
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PageTitle.iconTitle(
                    title: "Highlight Passage",
                    icon: "xmark",
                    onIconTap: { onDismiss() }
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Verse content with system selection
                        ExegesisVerseView(
                            plainText: plainText,
                            highlights: derivedSelections,
                            isSelectionEnabled: canEdit,
                            fontSize: 16,
                            usePreviewHighlightStyle: false,
                            selectedHighlightRange: selectedHighlight.map {
                                NSRange(location: $0.start, length: $0.end - $0.start)
                            },
                            pendingRange: $pendingRange
                        )

                        // Highlights list
                        if !highlights.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Highlights")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)

                                ForEach(highlights) { h in
                                    highlightRow(h)
                                }
                            }
                            .padding(.top, 8)
                        }

                        Spacer().frame(height: 32)
                    }
                }
            }
        }
        .onChange(of: pendingRange) { _, newRange in
            guard let range = newRange else { return }
            handlePendingRange(range)
        }
    }

    private func handlePendingRange(_ range: NSRange) {
        defer {
            DispatchQueue.main.async { pendingRange = nil }
        }

        let start = range.location
        let end = range.location + range.length

        // If tapping an existing highlight, select it
        if let existing = highlights.first(where: { $0.start == start && $0.end == end }) {
            selectedHighlight = (selectedHighlight?.id == existing.id) ? nil : existing
            return
        }

        // New highlight
        selectedHighlight = nil
        onHighlightCreated(range)
    }

    @ViewBuilder
    private func highlightRow(_ h: ExegesisHighlight) -> some View {
        Button {
            onHighlightTapped(h)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snippet(for: h))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(h.noteMarkdown.isEmpty ? "Tap to add note" : "Note added")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if canEdit {
                    Button {
                        onHighlightDeleted(h)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(16)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    private func snippet(for highlight: ExegesisHighlight) -> String {
        let start = max(0, min(highlight.start, plainText.count))
        let end = max(0, min(highlight.end, plainText.count))
        if end <= start { return "Highlight" }
        let sIdx = plainText.index(plainText.startIndex, offsetBy: start)
        let eIdx = plainText.index(plainText.startIndex, offsetBy: end)
        return String(plainText[sIdx..<eIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

- [ ] **Step 2: Add file to Xcode project**

The file needs to be added to `project.pbxproj`. Since it's in an existing directory (`MakeReady/Pages/Manage/Program/`), Xcode should pick it up automatically if using folder references, or it needs a manual `pbxproj` entry.

- [ ] **Step 3: Commit**

```bash
cd /Users/lukekeith/www/makeready/iphone
git add MakeReady/Pages/Manage/Program/ExegesisHighlightModal.swift
git commit -m "feat: add ExegesisHighlightModal for full-screen highlighting"
```

---

### Task 4: Update EditExegesisActivityPage — Remove Inline Highlighting, Add Tappable Preview + Modal

**Files:**
- Modify: `MakeReady/Pages/Manage/Program/EditExegesisActivityPage.swift`

This is the main integration task. Changes:
1. Remove `isHighlighting` state and all references
2. Make preview container tappable to open the highlight modal
3. Remove floating highlighter button
4. Remove inline highlighting visual changes (background dimming, scroll locking, border animation)
5. Present ExegesisHighlightModal via overlayManager

- [ ] **Step 1: Remove `isHighlighting` state**

Remove this line (around line 59):
```swift
    @State private var isHighlighting = false
```

- [ ] **Step 2: Update previewContainer — remove inline highlighting, make tappable**

Replace the entire `previewContainer` computed property with:

```swift
    @ViewBuilder
    private var previewContainer: some View {
        ZStack(alignment: .topTrailing) {
            // Background layers
            ZStack {
                Color(hex: "#1A1D28")

                if let url = storedImageUrl, let parsed = URL(string: url) {
                    GeometryReader { geo in
                        AsyncImage(url: parsed) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                            }
                        }
                    }
                }

                if let hex = selectedColor {
                    Color(hex: hex)
                        .opacity(storedImageUrl != nil ? effectiveOpacity : 1.0)
                }
            }

            // Verse content (preview only — not selectable)
            if let block = lockedBlock, let content = block.content, !content.isEmpty {
                ScrollView {
                    ExegesisVerseView(
                        plainText: stripBlockContentToPlain(content),
                        highlights: derivedSelections,
                        isSelectionEnabled: false,
                        fontSize: InlineFontSizePicker.previewPointSize(effectiveFontSize),
                        usePreviewHighlightStyle: true,
                        selectedHighlightRange: nil,
                        pendingRange: .constant(nil)
                    )
                }
                .scrollDisabled(true)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        // Tappable — opens highlight modal
        .contentShape(Rectangle())
        .onTapGesture {
            if hasPassage && canEdit {
                openHighlightModal()
            }
        }
    }
```

- [ ] **Step 3: Add openHighlightModal() method**

Add this method in the `// MARK: - Highlight Actions` section:

```swift
    private func openHighlightModal() {
        guard let block = lockedBlock, let content = block.content, !content.isEmpty else { return }
        let plain = stripBlockContentToPlain(content)

        overlayManager.presentModal(id: OverlayID.exegesisHighlightModal, dismissOnTapOutside: false) {
            ExegesisHighlightModal(
                plainText: plain,
                highlights: highlights,
                canEdit: canEdit,
                onHighlightCreated: { range in
                    createHighlight(range: range)
                },
                onHighlightTapped: { highlight in
                    overlayManager.dismiss(id: OverlayID.exegesisHighlightModal)
                    editingHighlight = highlight
                    withAnimation(.easeInOut(duration: 0.3)) { showEditNote = true }
                },
                onHighlightDeleted: { highlight in
                    deleteHighlight(highlight)
                },
                onDismiss: {
                    overlayManager.dismiss(id: OverlayID.exegesisHighlightModal)
                }
            )
            .environmentObject(authManager)
        }
    }

    private func createHighlight(range: NSRange) {
        guard canEdit else { return }
        guard let rbId = readBlockId ?? lockedBlock?.id else { return }

        let start = range.location
        let end = range.location + range.length

        // Check if already exists
        if highlights.first(where: { $0.start == start && $0.end == end }) != nil {
            return
        }

        Task {
            do {
                _ = try await ProgramActions().createExegesisHighlight(
                    activityId: activity.id,
                    readBlockId: rbId,
                    start: start,
                    end: end,
                    noteMarkdown: ""
                )
                await refreshHighlights()

                if let created = highlights.first(where: { $0.start == start && $0.end == end }) {
                    // Dismiss highlight modal, open note editor
                    overlayManager.dismiss(id: OverlayID.exegesisHighlightModal)
                    editingHighlight = created
                    withAnimation(.easeInOut(duration: 0.3)) { showEditNote = true }
                }
            } catch {
                NSLog("❌ Failed to create highlight: \(error)")
            }
        }
    }
```

- [ ] **Step 4: Update mainContent — remove isHighlighting references**

In the `mainContent` computed property:

1. Remove the `.scrollDisabled(isHighlighting)` on the outer ScrollView (line ~200) — replace with just removing the modifier entirely or keeping `.scrollDisabled(false)`.

2. Remove the `.onChange(of: isHighlighting)` block (lines ~201-207).

3. Remove the purple border `.opacity(isHighlighting ? 1 : 0)` on the preview container overlay (lines ~188-191). Replace with a static border:
```swift
.overlay(
    RoundedRectangle(cornerRadius: 12)
        .stroke(Color.white.opacity(0.06), lineWidth: 1)
)
```

4. Remove the floating highlighter button from the preview container.

- [ ] **Step 5: Update handlePendingRange**

The `handlePendingRange` method (line ~540) can be simplified since it's only used from the modal's callbacks now. You may keep it for the `onChange(of: pendingRange)` if other flows still use it, or remove the `onChange(of: pendingRange)` entirely since the modal handles its own pending range.

Remove the `.onChange(of: pendingRange)` block from the body (lines ~131-134) since the modal handles this internally.

- [ ] **Step 6: Clean up unused isHighlighting references**

Search for any remaining `isHighlighting` references and remove them. The state variable was removed in Step 1, so the compiler will flag these.

- [ ] **Step 7: Commit**

```bash
cd /Users/lukekeith/www/makeready/iphone
git add MakeReady/Pages/Manage/Program/EditExegesisActivityPage.swift
git commit -m "feat: replace inline highlighting with tappable preview + full-screen modal"
```

---

### Task 5: Add ExegesisHighlightModal.swift to Xcode Project

**Files:**
- Modify: `MakeReady.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add PBXBuildFile, PBXFileReference, PBXGroup, and PBXSourcesBuildPhase entries**

Find the existing entries for `EditExegesisActivityPage.swift` in `project.pbxproj` and add parallel entries for `ExegesisHighlightModal.swift` using a new unique UUID. The file goes in the same group (`MakeReady/Pages/Manage/Program/`).

- [ ] **Step 2: Build and verify**

Build the project to confirm no compilation errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/lukekeith/www/makeready/iphone
git add MakeReady.xcodeproj/project.pbxproj
git commit -m "chore: add ExegesisHighlightModal to Xcode project"
```

---

### Task 6: Test End-to-End

- [ ] **Step 1: Test opening highlight modal**
- Navigate to a program → lesson → exegesis activity
- Tap the preview container (verse text area)
- Verify: full-screen modal opens with verse content and "Highlight Passage" header

- [ ] **Step 2: Test verse selection**
- In the modal, tap a verse number circle
- Verify: system selection appears (yellow handles + tinted background)
- Tap another verse to extend selection
- Verify: selection extends

- [ ] **Step 3: Test highlight creation**
- With verses selected, tap inside the selection (confirms it)
- Verify: highlight is created, note editor opens

- [ ] **Step 4: Test tapping existing highlight**
- Open modal again, tap on highlighted text
- Verify: note editor opens for that highlight

- [ ] **Step 5: Test no scroll jump**
- Select various verses by tapping circles
- Verify: no auto-scroll occurs within the modal

- [ ] **Step 6: Test dismiss**
- Tap X button in header
- Verify: modal dismisses, preview shows updated highlights
