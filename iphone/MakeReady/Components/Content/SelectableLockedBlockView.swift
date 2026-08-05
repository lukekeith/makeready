//
//  SelectableLockedBlockView.swift
//  MakeReady
//
//  The Read editor's locked-block view. Since 2026-08-04 (highlighting phase
//  4.11) this is a THIN WRAPPER over `HighlightableTextView` — it keeps its own
//  public shape so both call sites and the capture `ViewRegistry` are unchanged,
//  and delegates all of the behaviour it used to own.
//
//  What it used to own, and now shares: verse parsing, badge layout, the
//  tap-to-select model, highlight painting, the bounds clamp, and edit-menu
//  suppression. All of that existed here AND in `ExegesisVerseView`, in two
//  versions that disagreed.
//
//  ⚠️ One deliberate behaviour change ships with this (09 §G-o): saved spans
//  used to be painted opaque brand purple. They are now lime at 0.35, the
//  contract's colour for a saved highlight on every surface (03 §5). The
//  Exegesis editor already rendered them that way; this surface was the odd one.
//
//  ⚠️ SECOND behaviour change, 2026-08-04 (09 §X-q, requested by Luke):
//  **highlight mode now selects by tap-and-hold like the Exegesis editor, not by
//  tapping whole verses.** Until now this surface was `.verseTap` / `.verse` —
//  tap a verse to select it, tap another to extend, tap inside to commit — which
//  is what both the pre-refactor view and 03 §5's granularity table specified.
//  Word-level drag is strictly more expressive (a phrase inside a verse was
//  simply not expressible before), and it makes the two editors behave alike,
//  which is the point of the shared service.
//
//  Two things fall out, and neither is incidental:
//
//  * **Tapping a verse no longer selects it.** That capability is gone, not
//    hidden. A tap now only opens an EXISTING highlight (`onHighlightTapped`).
//    If whole-verse selection is still wanted it comes back as an explicit
//    addition, not as a leftover.
//  * **The scroll lock starts running on this surface.** `.verseTap` never
//    became first responder, so `TextSelectionController` was never even
//    constructed for it (`HighlightableTextView.Coordinator.attach` returns
//    early for that mode). Native drag makes the text view first responder
//    inside a SwipeableCard inside a ScrollView, which is exactly the situation
//    the lock exists for.
//
//  Safe because the parent already disables the competing long press: the Read
//  editor sets `canDrag = highlightingBlockId == nil` (EditReadActivityPage),
//  so drag-to-reorder is off while a block is being highlighted, and
//  `isSelectionEnabled` is true only in highlight mode — so no stray selection
//  handles appear outside it (monday#12668695071).
//

import SwiftUI
import UIKit

struct SelectableLockedBlockView: View {
    let plainText: String
    let selections: [ReadBlockSelection]
    /// When false, the underlying text view is not selectable at all, so the
    /// parent's drag-to-sort gesture handles long-press instead — and no system
    /// selection handles can appear on a block nobody is highlighting.
    /// Toggled on when the user enters explicit highlight mode, which is also
    /// when the parent turns drag-to-sort off.
    let isSelectionEnabled: Bool
    /// Range currently being edited via the style picker (if any). The matching
    /// span renders solid white with dark text to make it visually clear
    /// which selection the modal is acting on. nil while the picker is closed.
    let editingRange: NSRange?
    /// Set when the user finishes adjusting a non-empty selection.
    /// The parent presents the style picker on `.onChange`, then clears it.
    @Binding var pendingRange: NSRange?
    /// The selection the user is building right now, owned by the parent's
    /// SwiftUI state. The span is painted as a text attribute rather than left
    /// to UIKit's transient selection rendering, which `updateUIView` wiped on
    /// every SwiftUI update — leaving the system's grab handles bracketing
    /// nothing (monday#12668695071).
    ///
    /// Since the switch to `.nativeDrag` the in-progress wash is painted by
    /// `HighlightTextView.applyLivePreview` during the drag and this binding is
    /// only cleared on commit. It stays in the public shape because the parent
    /// tracks which block is live, and because the capture `ViewRegistry`
    /// depends on the memberwise initialiser.
    @Binding var liveSelection: NSRange?
    /// Font size for the verse text. Defaults to 16pt if not provided.
    var fontSize: CGFloat = 16
    /// When true, non-editing selections render as white bg with dark text
    /// (readable preview).
    var usePreviewHighlightStyle: Bool = false
    /// True when the block's content was copied in by the Bible
    /// book/chapter/verse highlight process (`sourceReferenceId != nil`).
    /// Scripture renders in the print-Bible style (Charter serif, justified);
    /// other locked blocks keep the standard system font.
    var isScripture: Bool = true

    var body: some View {
        HighlightableTextView(
            plainText: plainText,
            fontSize: fontSize,
            isScripture: isScripture,
            highlights: painted,
            savedAppearance: usePreviewHighlightStyle ? .preview : .saved,
            editingRange: editingRange,
            // CHANGED 2026-08-04 (09 §X-q): tap-and-hold word selection, the
            // same input model as the Exegesis editor. This surface selected
            // whole verses by tapping until now — see the file header.
            mode: .nativeDrag,
            granularity: .word,
            isSelectionEnabled: isSelectionEnabled,
            liveSelection: $liveSelection,
            onCommit: { range in
                // Deferred exactly as before: the parent presents the style
                // picker from `.onChange(of: pendingRange)`, and assigning it
                // inside the gesture's own turn used to land mid-update.
                DispatchQueue.main.async { pendingRange = range }
            },
            onHighlightTapped: { range in
                // Cleared first so `.onChange` fires even when the same span is
                // tapped twice — otherwise re-opening a highlight's style
                // picker silently does nothing.
                pendingRange = nil
                DispatchQueue.main.async { pendingRange = range }
            }
        )
    }

    private var painted: [HighlightRenderer.Painted] {
        selections.compactMap { selection in
            HighlightSpan(start: selection.start, end: selection.end)
                .map { .init(span: $0, style: selection.style) }
        }
    }
}

// `SelectionTextView` — the UITextView subclass that used to live here — is
// gone: `HighlightTextView` does the same two jobs (verse badges, no edit menu)
// for every surface. Nothing else referenced it.

/// Known style identifiers.
enum ReadBlockSelectionStyle: String {
    case bold
    case highlight
}
