//
//  SearchField.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from docs/ui2/design-system/components/C-034-search-field.md (§2 geometry, §3 states,
//  §4 props). PREVIEW ONLY: referenced by no screen, route, tab or flag
//  (docs/ui2/preview-build.md §3 rule 1). Promoted by the ui2-shell suite (§7).
//

import SwiftUI

/// C-034 SearchField — the program's search input (glyph + text + clear).
///
/// Chrome-free and width-driven: it fills the width it is given, states its own 44pt height,
/// paints no page background and adds no outer padding. Frame, background and outer padding
/// belong to the ViewRegistry call site (preview-build.md OQ-PB-1 / OQ-PB-2); §1 deviation 2
/// records that the master symbols are 387pt wide while every specced consumer renders 408×44.
///
/// §1 deviation 3: the glyph, content row and clear button are **absolutely placed** inside a
/// fixed 44pt height with content clipped — §2 contracts that placed geometry, and the
/// container's declared `padding: 16 37` is a Figma artifact. That is why this view positions
/// rather than pads.
struct SearchField: View {

    /// C-034 §4 `text: Binding<String>` — "current query; empty → placeholder shows".
    ///
    /// A plain `String` here, not a Binding: a fixture can only set values, and the render is
    /// purely a function of the current one. Same accommodation the sibling C-045 TextInput
    /// preview makes, and the same one preview-build.md makes for `focused`.
    let text: String
    /// C-034 §4 `placeholder: String` — consumer-set prompt (§1 deviation 1: "Search" is sample
    /// content; consumers set "Search members" / "Search groups" / "Search enrollments").
    let placeholder: String
    /// C-034 §4 `focused: Bool` — "drives border + caret".
    let focused: Bool

    /// C-034 §4 `onChange: (String) -> Void` — live filtering. No render effect: emitted as a
    /// defaulted no-op so the promoted view keeps its real signature (OQ-PB-3's default).
    let onChange: (String) -> Void
    /// C-034 §4 `onClear: () -> Void` — "C-039 tap — clears `text`, field **stays focused**".
    /// No render effect; same OQ-PB-3 default.
    let onClear: () -> Void

    init(
        text: String,
        placeholder: String,
        focused: Bool,
        onChange: @escaping (String) -> Void = { _ in },
        onClear: @escaping () -> Void = {}
    ) {
        self.text = text
        self.placeholder = placeholder
        self.focused = focused
        self.onChange = onChange
        self.onClear = onClear
    }

    /// C-034 §2's placed geometry. §3 is explicit that `state` "is **not** a free variant: it is
    /// derived from `text.isEmpty × focused`", so none of these are state-switched — only the
    /// fill, border, text colour and the caret/clear presence are.
    private enum Geometry {
        static let height: CGFloat = 44             // §2: "Single-line bordered field, 44pt tall"
        static let borderWidth: CGFloat = 1         // §2: "1px border"
        static let glyphSize: CGFloat = 12          // §2: "12×12 vector (`3561:33850`)"
        static let glyphLeft: CGFloat = 16          // §2: "left 16, top 15" — NOT centred in 44
        static let glyphTop: CGFloat = 15
        static let contentLeft: CGFloat = 36        // §2: "left edge 36 (glyph 16 + 12 wide + 8 gap)"
        static let caretWidth: CGFloat = 2          // §2: "Caret (`Focus` only) — 2×24"
        static let caretHeight: CGFloat = 24
        static let clearSize: CGFloat = 32          // §2: "Clear button — C-039, 32×32"
        static let clearTrailing: CGFloat = 7       // §2: "trailing inset 7, top 5" (OQ-C-034-4:
        static let clearTop: CGFloat = 5            // deliberately not optically centred)
    }

    // MARK: - Derived state (§4)

    // §4: "`Default` = `text.isEmpty && !focused` · `Focus` = `text.isEmpty && focused` ·
    // `Has value` = `!text.isEmpty`". Note `Has value` does NOT consult `focused` — which is
    // also what makes the undesigned "Has value + focused" row (OQ-C-034-1) fall out correctly
    // as `Has value` rather than needing a rule this build would have had to invent.
    private var isDefault: Bool { text.isEmpty && !focused }
    private var showsCaret: Bool { text.isEmpty && focused }
    private var hasValue: Bool { !text.isEmpty }

    // §2: "**Fill** — `color-card-background` in `Default` only; `Focus` and `Has value` have
    // **no fill** (the page ground shows through)."
    //
    // FLAGGED LITERAL — C-034 §2: "Flagged literals (hex-equal to a token but not
    // variable-bound in the source, same pattern as C-045): fill `#1f2124` =
    // `color-card-background`, border `#2f363a` = `color-card-border`." The flag records that
    // FIGMA did not bind a variable; §2's own normative lines name the tokens, and the hexes
    // are equal to them, so the token is used and the flag carried here rather than a second
    // copy of the hex being introduced. The Figma-side fix is an OQ for the owner.
    private var fill: Color { isDefault ? Token.cardBackground : .clear }

    // §2: "**Border** — `color-card-border` in `Default`; `color-text-primary` (white) in
    // `Focus` and `Has value`." §3 note: "read as 'a field carrying text is visually active',
    // not as a second border rule." Same flagged-literal note as `fill`.
    private var border: Color { isDefault ? Token.cardBorder : Token.textPrimary }

    // §3: placeholder `color-nav-text` in Default, `color-input-placeholder` in Focus (§3: it
    // "deliberately **changes colour**… it darkens" — OQ-C-034-2 asks the owner to confirm
    // intent); value `color-input-value` in Has value.
    private var textColor: Color {
        if hasValue { return Token.inputValue }
        return focused ? Token.inputPlaceholder : Token.navText
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Token.Radius.cardSm)
                .fill(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: Token.Radius.cardSm)
                        .strokeBorder(border, lineWidth: Geometry.borderWidth)
                )

            searchGlyph
            contentRow
            if hasValue { clearButton }
        }
        .frame(maxWidth: .infinity, minHeight: Geometry.height, maxHeight: Geometry.height)
        .clipped()                                  // §2: "content clipped"
        .ui2Element("SearchField")
    }

    // MARK: - Parts (§2 anatomy)

    // §2: "**Search glyph** — 12×12 vector (`3561:33850`), left 16, top 15. Present in **all
    // three states**." Exported 2026-09-09 from that node to
    // docs/ui2/design-system/components/assets/C-034-search-glyph.svg.
    //
    // NOT C-021's `search` glyph, and the export proves §5's claim that they are different
    // artwork rather than the same icon at two sizes: this vector is stroke-2 on a 14 box
    // (ratio 0.143), C-021's is stroke-2 on a 24 box (0.083) — proportionally 1.7× lighter.
    // Substituting it would have rendered a visibly thinner glyph.
    private var searchGlyph: some View {
        Image("c034-search-glyph", bundle: .ui2Preview)
            // Template-rendered like every glyph in this catalog, so the vector is a mask and
            // the tint below is the whole of its colour.
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            // The exported box is 14×14 because a stroke-2 path centred on the 12×12 icon
            // bleeds 1pt on every side. Rendering it at 12 would shrink the icon to 10.3 and
            // thin its stroke to 1.71 — so the BOX gets 14 and its origin backs off by that
            // 1pt bleed, which lands §2's 12×12 icon exactly on left 16 / top 15.
            .frame(width: Self.glyphBox, height: Self.glyphBox)
            // GAP — C-034 §2 states no colour for the glyph. The source vector strokes
            // `white` and the frozen snapshot renders it white, which is `color-text-primary`;
            // taken from the design, but §2 should say so.
            .foregroundStyle(Token.textPrimary)
            .offset(x: Geometry.glyphLeft - Self.glyphBleed, y: Geometry.glyphTop - Self.glyphBleed)
            .ui2Element("Search glyph")
    }

    /// The exported artwork's box, and the stroke bleed that makes it wider than §2's icon.
    private static let glyphBox: CGFloat = 14
    private static let glyphBleed: CGFloat = 1

    // §2: "**Content row** — left edge 36…, vertically centred. Text `type-input` (SF Pro
    // Regular 14 / 24)." §1 deviation 4 contracts the focused reading as "one content row
    // starting at **36**, caret leading the placeholder" — so the caret is a row item that
    // displaces the text, not an overlay on top of it.
    private var contentRow: some View {
        HStack(spacing: 0) {
            if showsCaret {
                // §2: "**Caret** (`Focus` only) — 2×24, `radius-bar` (2), `color-accent`,
                // leading the content row." §2 states no caret↔text gap, so there is none.
                RoundedRectangle(cornerRadius: Token.Radius.bar)
                    .fill(Token.accent)
                    .frame(width: Geometry.caretWidth, height: Geometry.caretHeight)
                    .ui2Element("Caret")
            }
            Text(hasValue ? text : placeholder)
                .designTextStyle(Token.TypeStyle.input)
                .foregroundColor(textColor)
                .lineLimit(1)
                // §2 draws one text run whose ROLE changes with `text` — the element map says
                // which, so a comment on it lands on the state it was made about.
                .ui2Element(hasValue ? "Value" : "Placeholder")
            Spacer(minLength: 0)
        }
        .padding(.leading, Geometry.contentLeft)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .ui2Element("Content row")
    }

    // §2: "**Clear button** (`Has value` only) — C-039, 32×32, trailing inset 7, top 5."
    //
    // C-039 ClearSearchButton still has no contract file of its own — its registry "Defined
    // in" points back at C-034 §5, one line, so the ROW is unspecced. What changed is the
    // artwork: the 14pt close vector is exported (2026-09-09, node `4029:40373`, which is
    // `button=Clear` in the C-021 icon frame `3499:27547`) to
    // docs/ui2/design-system/components/assets/C-039-clear-icon.svg. The registry's "14pt
    // close vector, inset 9" matches it exactly — 14 centred in 32 leaves 9 a side.
    //
    // Still owed by /ui2-component: C-039's own contract (props, states, hit target), and a
    // ruling on whether this vector is C-021's tenth glyph or C-039's own artwork.
    private var clearButton: some View {
        Image("c039-clear-icon", bundle: .ui2Preview)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            // Registry C-039: "14pt close vector, inset 9" inside the 32pt button.
            .frame(width: Self.clearVector, height: Self.clearVector)
            // GAP — neither §2 nor the registry row states the tint. The sheet symbol fills
            // `Purple/100%`, but C-034's own instance renders it white in both the frozen
            // snapshot and the live Figma symbol, so the consumer overrides it.
            .foregroundStyle(Token.textPrimary)
            .frame(width: Geometry.clearSize, height: Geometry.clearSize)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, Geometry.clearTrailing)
            .offset(y: Geometry.clearTop)
            .ui2Element("Clear button")
    }

    /// Registry C-039: the close vector inside the 32pt button.
    private static let clearVector: CGFloat = 14
}
