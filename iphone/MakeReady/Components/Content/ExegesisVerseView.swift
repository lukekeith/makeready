//
//  ExegesisVerseView.swift
//  MakeReady
//
//  The Exegesis editor's verse display. Since 2026-08-04 (highlighting phase
//  4.12) this is a THIN WRAPPER over `HighlightableTextView` — same public
//  shape, so all three call sites (`EditExegesisActivityPage`,
//  `ExegesisHighlightModal`, `ExegesisNoteEditorPage`) and the capture
//  `ViewRegistry` are unchanged.
//
//  What it used to own — ~1,000 lines of it — now lives in the service:
//  the gesture lifecycle and its touch observer (`TextSelectionController`),
//  the scroll-lock machinery (`ScrollLockCoordinator`), word snapping
//  (`HighlightSnapping`), highlight colours (`HighlightRenderer`), verse badges
//  and edit-menu suppression (`HighlightTextView`). Every one of those had a
//  second, subtly different copy in `SelectableLockedBlockView`.
//
//  Behaviour is unchanged on this surface: it already painted saved highlights
//  lime at 0.35, and the live drag at 0.55.
//

import SwiftUI
import UIKit

struct ExegesisVerseView: View {
    let plainText: String
    let highlights: [ReadBlockSelection]
    let isSelectionEnabled: Bool
    var fontSize: CGFloat = 16
    var usePreviewHighlightStyle: Bool = false
    var selectedHighlightRange: NSRange? = nil
    /// When true, the selected highlight is scrolled into view if it is outside
    /// the visible viewport. Kept explicit so ordinary highlight taps do not
    /// reintroduce selection-related scroll jumps.
    ///
    /// **Currently inert** — see the note in 13 §4.12. Retained so call sites
    /// and the capture fixtures do not change shape while the behaviour is
    /// re-established.
    var scrollSelectedHighlightIntoView: Bool = false
    /// When true, long-press/drag uses UITextView's native selection instead of
    /// the legacy tap-a-verse behaviour.
    var usesNativeTextSelection: Bool = false
    var onRangeSelected: ((NSRange) -> Void)? = nil
    var onHighlightTapped: ((NSRange) -> Void)? = nil
    @Binding var pendingRange: NSRange?
    /// Seeds an already-in-progress selection at construction. **Defaults to
    /// `nil`, so every existing call site renders exactly as before.**
    ///
    /// It exists for the capture harness (highlighting phase 6.8, 09 §G-ac):
    /// the live wash `#F4FF76 @0.55` is a normative contract value (03 §5) and
    /// had no visual regression test on either platform, because a live span
    /// only ever existed mid-gesture and a snapshot cannot perform a gesture.
    /// This surface is the one that can express it — its capture path leaves
    /// `usesNativeTextSelection` false, so it runs `.verseTap`, and
    /// `HighlightableTextView:138` paints the binding in that mode.
    var initialLiveSelection: NSRange? = nil

    /// Only the tap model keeps a live span in SwiftUI state; the drag model's
    /// preview is painted inside the text view while the finger is down.
    @State private var liveSelection: NSRange?

    var body: some View {
        HighlightableTextView(
            plainText: plainText,
            fontSize: fontSize,
            isScripture: true,
            highlights: painted,
            savedAppearance: usePreviewHighlightStyle ? .preview : .saved,
            editingRange: selectedHighlightRange,
            mode: usesNativeTextSelection ? .nativeDrag : .verseTap,
            granularity: usesNativeTextSelection ? .word : .verse,
            isSelectionEnabled: isSelectionEnabled,
            // Falls back to the seed rather than being initialised from it, so
            // no custom `init` is needed and the memberwise one every call site
            // uses keeps working. In production `initialLiveSelection` is nil,
            // which makes this binding identical to `$liveSelection`.
            liveSelection: Binding(
                get: { liveSelection ?? initialLiveSelection },
                set: { liveSelection = $0 }
            ),
            onCommit: { range in
                if let onRangeSelected {
                    onRangeSelected(range)
                } else {
                    pendingRange = range
                }
            },
            onHighlightTapped: { range in
                if let onHighlightTapped {
                    onHighlightTapped(range)
                } else {
                    // Cleared first so `.onChange` fires when the same
                    // highlight is tapped twice.
                    pendingRange = nil
                    DispatchQueue.main.async { pendingRange = range }
                }
            }
        )
    }

    private var painted: [HighlightRenderer.Painted] {
        highlights.compactMap { highlight in
            HighlightSpan(start: highlight.start, end: highlight.end)
                .map { .init(span: $0, style: highlight.style) }
        }
    }
}

// `ExegesisTextView`, `TouchObserverGestureRecognizer` and
// `snappedToWordBoundaries` all used to live below here. They are now
// `HighlightTextView`, the shared observer in `TextSelectionController.swift`,
// and `HighlightSnapping` respectively — one copy each, for every surface.
