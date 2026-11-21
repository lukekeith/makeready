//
//  NotesBottomBar.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-008-notes-bottom-bar in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-008 NotesBottomBar — the floating bottom bar of the leader's All-Notes list: a search
/// capsule (C-034 SearchField, `shape: .capsule`) and a separate compose circle.
///
/// Controlled (R-01): the bar holds no query, focus or emphasis of its own, and performs no
/// network, debounce or navigation (R-04, R-19). Chrome-free and width-driven (R-16;
/// deviation 4): it fills the width it is given at its 44pt intrinsic height and paints no
/// background, divider, scrim or outer padding — those are library-home's.
struct NotesBottomBar: View {

    /// §4 `composeEmphasis` — `prominent` = the accent-filled compose on the empty list
    /// (OQ-C-008-005). Regular is the base design (R-07).
    enum ComposeEmphasis: String, Equatable {
        case regular, prominent
    }

    /// §4 `searchText` — the query shown in the C-034 capsule (N7's `q`).
    let searchText: String
    /// §4 `searchFocused` — drives C-034's focus look and caret.
    let searchFocused: Bool
    /// §4 `searchEnabled` — `false` = the disabled capsule (OQ-C-008-004).
    var searchEnabled: Bool = true
    /// §4 `composeEmphasis`.
    var composeEmphasis: ComposeEmphasis = .regular
    /// §4 `onSearchChange` — every edit of the query. R-03 no-op default.
    var onSearchChange: (String) -> Void = { _ in }
    /// §4 `onSearchFocusChange` — the capsule gained or lost focus (C-034 `onFocusChange`).
    var onSearchFocusChange: (Bool) -> Void = { _ in }
    /// §4 `onSearchClear` — C-039 clear tapped; the screen empties `searchText`.
    var onSearchClear: () -> Void = {}
    /// §4 `onCompose` — compose tapped; the screen opens the editor with `noteId: nil`.
    var onCompose: () -> Void = {}
    /// §4: "C-034 is driven in its editable form (`editable: true`, as members-home does). Every
    /// §3 state stays reachable by props in capture (C-034 `editable: false` in the fixture)."
    /// The capture case passes `false` so `searchFocused` draws the focus look.
    var editable: Bool = true

    var body: some View {
        // §2 Container: "a horizontal stack, vertically centred, `space-button-gap` (10)".
        HStack(alignment: .center, spacing: Token.Space.buttonGap) {
            searchCapsule
            composeButton
        }
        .frame(maxWidth: .infinity)
        .ui2Element("NotesBottomBar")              // capture element map — UI2Element.swift
    }

    // MARK: - Parts (§2 anatomy)

    /// §2 Search capsule: one C-034 SearchField taking the remaining width, placeholder
    /// "Search", `shape: capsule` (OQ-C-008-001), disabled per OQ-C-008-004.
    private var searchCapsule: some View {
        SearchField(
            text: searchText,
            placeholder: "Search",
            // §4 C-034 mapping (exact): `focused: searchFocused && searchEnabled`.
            focused: searchFocused && searchEnabled,
            onChange: onSearchChange,
            onClear: onSearchClear,
            onFocusChange: onSearchFocusChange,
            editable: editable,
            shape: .capsule,
            enabled: searchEnabled
        )
        .accessibilityLabel("Search notes")        // §2 Accessibility (R-17)
        .ui2Element("Search capsule")
    }

    /// §2 Compose circle (inline part `ComposeButton`, OQ-C-008-003): 44×44 `radius-circle`,
    /// the whole circle the hit target; press feedback is the plain style's system highlight
    /// with no geometry change (OQ-C-102-5 precedent).
    private var composeButton: some View {
        SwiftUI.Button(action: onCompose) {
            Image(GlyphName.write.rawValue, bundle: .ui2Preview)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                // FLAGGED LITERAL — C-008 FL-1: glyph 18pt, the era's common action-glyph size
                // (C-102, C-085), with no token.
                .frame(width: Geometry.glyph, height: Geometry.glyph)
                .foregroundStyle(glyphColor)
                .accessibilityHidden(true)         // §2: the glyph carries no label
                .frame(width: Geometry.circle, height: Geometry.circle)
                // `radius-circle` is "50%" and emits no token member, so the circle is the shape.
                .background(Circle().fill(fill))
                .overlay {
                    if composeEmphasis == .regular {
                        // FLAGGED LITERAL — §2: "a 1 pt `color-card-border` stroke", the
                        // program-wide hairline; no stroke token.
                        Circle().strokeBorder(Token.cardBorder, lineWidth: Geometry.stroke)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New note")            // §2 Accessibility (library-home §3)
        .accessibilityAddTraits(.isButton)
        .ui2Element("ComposeButton")
    }

    /// §2: regular = `color-card-background`; prominent = `color-accent` (OQ-C-008-005).
    private var fill: Color {
        composeEmphasis == .prominent ? Token.accent : Token.cardBackground
    }

    /// §2: regular = `color-text-primary`; prominent = `color-white-100` (OQ-C-008-005).
    private var glyphColor: Color {
        composeEmphasis == .prominent ? Token.white100 : Token.textPrimary
    }

    /// §2 dimensions of a fixed-size control, not values of a token family.
    private enum Geometry {
        /// §2: "a 44×44 circle" — C-034's height.
        static let circle: CGFloat = 44
        /// FL-1: "The glyph is 18 pt, centred".
        static let glyph: CGFloat = 18
        static let stroke: CGFloat = 1
    }
}
