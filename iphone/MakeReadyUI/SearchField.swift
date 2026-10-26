//
//  SearchField.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-034-search-field in d2m (§2 geometry, §3 states, §4 props).
//  Consumed by MembersHomeScreen (editable form, ui2-members-browse D19 — routed to /ui2-resolve, F3).
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
    /// A plain `String` here, not a Binding — R-01 (Controlled): the value is a prop and
    /// `onChange` beside it carries edits out, so every §3 state is reachable by props alone.
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
    /// C-034 §4 `showsClearWhenEmpty: Bool = false` — OQ-calendar-home-5 (owner): keeps the
    /// C-039 clear x visible with an empty query. Defaults off, so every other consumer
    /// renders as before; calendar-home passes true (its empty-query x dismisses search).
    let showsClearWhenEmpty: Bool
    /// D19 (ui2-members-browse): the editable form — a `TextField` drawn as §2's text run, its
    /// own focus driving `focused` (the prop is then ignored). `false` keeps the display-only
    /// render every preview and capture case uses, so every §3 state stays reachable by props.
    let editable: Bool

    /// The editable form's focus — ephemeral UI state (R-02), never a prop.
    @FocusState private var inputFocused: Bool

    init(
        text: String,
        placeholder: String,
        focused: Bool,
        onChange: @escaping (String) -> Void = { _ in },
        onClear: @escaping () -> Void = {},
        showsClearWhenEmpty: Bool = false,
        editable: Bool = false
    ) {
        self.text = text
        self.placeholder = placeholder
        self.focused = focused
        self.onChange = onChange
        self.onClear = onClear
        self.showsClearWhenEmpty = showsClearWhenEmpty
        self.editable = editable
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
        static let clearTrailing: CGFloat = 7       // §2: "trailing inset 7"; vertically CENTRED
                                                    // per OQ-C-034-4 (owner: "6/6 in the 44pt
                                                    // field"), not §2's measured top 5
    }

    // MARK: - Derived state (§4)

    // §4: "`Default` = `text.isEmpty && !focused` · `Focus` = `text.isEmpty && focused` ·
    // `Has value` = `!text.isEmpty`". The undesigned "Has value + focused" row is OQ-C-034-1's
    // ruling: `Has value` as designed plus a caret TRAILING the value — so the caret follows
    // `focused` alone, and leads the placeholder or trails the value.
    /// §4's derived `state`, computed in one place for both forms.
    enum Appearance: Equatable {
        case `default`, focus, hasValue
    }

    static func appearance(text: String, focused: Bool) -> Appearance {
        if !text.isEmpty { return .hasValue }
        return focused ? .focus : .default
    }

    /// The `focused` §4 derives from: the prop when display-only, the field's own focus when
    /// editable (D19).
    private var isFocused: Bool { editable ? inputFocused : focused }
    private var isDefault: Bool { Self.appearance(text: text, focused: isFocused) == .default }
    private var hasValue: Bool { Self.appearance(text: text, focused: isFocused) == .hasValue }

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

    // §3: value `color-input-value` in Has value. Placeholder: §3 records `color-nav-text` in
    // Default and `color-input-placeholder` in Focus, but OQ-C-034-2's ruling is "Drift: unify
    // on color-input-placeholder in both states (Figma cleanup of the unfocused symbol)" —
    // so the Default render deliberately differs from the frozen snapshot here.
    private var textColor: Color {
        hasValue ? Token.inputValue : Token.inputPlaceholder
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
            if editable { editableRow } else { contentRow }
            if hasValue || showsClearWhenEmpty { clearButton }
        }
        .frame(maxWidth: .infinity, minHeight: Geometry.height, maxHeight: Geometry.height)
        .clipped()                                  // §2: "content clipped"
        .contentShape(Rectangle())
        // D19: a tap anywhere on the field (the glyph, the inset) focuses the editable form.
        .simultaneousGesture(TapGesture().onEnded { if editable { inputFocused = true } })
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
    // displaces the text, not an overlay on top of it. With a value (OQ-C-034-1) it trails.
    private var contentRow: some View {
        HStack(spacing: 0) {
            if isFocused && !hasValue { caret }
            Text(hasValue ? text : placeholder)
                .designTextStyle(Token.TypeStyle.input)
                .foregroundColor(textColor)
                .lineLimit(1)
                // §2 draws one text run whose ROLE changes with `text` — the element map says
                // which, so a comment on it lands on the state it was made about.
                .ui2Element(hasValue ? "Value" : "Placeholder")
            if isFocused && hasValue { caret }
            Spacer(minLength: 0)
        }
        .padding(.leading, Geometry.contentLeft)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .ui2Element("Content row")
    }

    /// D19: the editable form of the content row — the same §2 placement (left edge 36,
    /// vertically centred, `type-input`) with a `TextField` in place of the drawn text. The
    /// system caret, tinted `color-accent`, stands in for the drawn 2×24 caret.
    private var editableRow: some View {
        TextField(
            "",
            text: Binding(get: { text }, set: { onChange($0) }),
            prompt: Text(placeholder).foregroundColor(Token.inputPlaceholder)
        )
        .designTextStyle(Token.TypeStyle.input)
        .foregroundColor(Token.inputValue)
        .tint(Token.accent)
        .focused($inputFocused)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.search)
        .ui2Element(hasValue ? "Value" : "Placeholder")
        .padding(.leading, Geometry.contentLeft)
        .padding(.trailing, hasValue || showsClearWhenEmpty ? Self.clearReserve : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .ui2Element("Content row")
    }

    // GAP — C-034 §2 draws no typed text long enough to reach C-039; the editable form keeps a
    // value clear of it: C-039's 32 + its trailing inset 7.
    private static let clearReserve: CGFloat = 39

    // §2: "**Caret** (`Focus` only) — 2×24, `radius-bar` (2), `color-accent`, leading the
    // content row." §2 states no caret↔text gap, so there is none on either side.
    private var caret: some View {
        RoundedRectangle(cornerRadius: Token.Radius.bar)
            .fill(Token.accent)
            .frame(width: Geometry.caretWidth, height: Geometry.caretHeight)
            .ui2Element("Caret")
    }

    // §2: "**Clear button** (`Has value` only) — C-039, 32×32, trailing inset 7" — the real
    // C-039 registry view (§5 Consumes, R-15), which owns its 32pt frame, tint, pressed dip and
    // accessibility label; `onClear` is its action. Centred vertically per OQ-C-034-4.
    private var clearButton: some View {
        ClearSearchButton(action: {
            onClear()
            if editable { inputFocused = true }     // §4: clears `text`, field **stays focused**
        })
            .padding(.trailing, Geometry.clearTrailing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .ui2Element("Clear button")
    }
}
