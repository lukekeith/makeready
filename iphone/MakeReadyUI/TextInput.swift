//
//  TextInput.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-045-text-input in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-045 TextInput — the program's general text input (single, multiline and phone).
///
/// Controlled (R-01): the caller holds `text` and `focused`; the view holds no value.
/// Chrome-free and width-driven (R-16): it fills the width it is given, states its own
/// intrinsic height, paints no page background and adds no outer padding. Frame, background
/// and outer padding belong to the capture call site.
struct TextInput: View {

    /// C-045 §4 `kind: single · multi · phone` — the Figma `type` axis (R-06 / R-36).
    enum Kind: String {
        case single
        case multi
        case phone
    }

    /// C-045 §4 `alignment: leading · center` — Single and Multi only (OQ-C-046-004).
    enum Alignment: String {
        case leading
        case center
    }

    /// C-045 §4: the value as the caller holds it; empty → placeholder shows.
    /// Phone: already formatted — the component formats nothing.
    let text: String
    /// C-045 §4: shown when `text` is empty; also the accessibility label (R-17).
    let placeholder: String
    /// C-045 §4: layout, type style and keyboard.
    let kind: Kind
    /// C-045 §4: defaulted `.leading` — every Text input symbol draws leading text (R-07).
    /// Ignored by Phone, which is centred by anatomy.
    var alignment: Alignment = .leading
    /// C-045 §4: drives the white border + caret.
    let focused: Bool
    /// C-045 §4: Phone only — the prefix. Defaulted because the design shows `+1` (R-07,
    /// OQ-C-045-002).
    var countryCode: String = "+1"
    /// C-045 §4: every edit, with the new raw text (R-01, R-33). No render effect.
    var onChange: (String) -> Void = { _ in }
    /// C-045 §4: focus gained/lost; the caller owns `focused` (R-01). No render effect.
    var onFocusChange: (Bool) -> Void = { _ in }

    var body: some View {
        content
            // §2: p16 / px16 for every kind — measured INSIDE the 1px border (see
            // `borderWidth`).
            .padding(.horizontal, Self.borderWidth + Token.Space.cardPadding)
            .padding(.vertical, verticalInset)
            // §2: Single / Phone 44pt, content vertically centred · Multi 88pt MINIMUM,
            // growing with content (OQ-C-045-3), content top-aligned.
            .frame(
                maxWidth: .infinity,
                minHeight: minHeight,
                maxHeight: kind == .multi ? nil : minHeight,
                alignment: boxAlignment
            )
            .overlay(
                // §2: Border 1px `color-card-border`; focused: 1px `color-text-primary`.
                // (Error = `color-negative` is ruled by OQ-C-045-2 but §4 gives it no prop:
                // "it is not built until a consumer needs it".)
                RoundedRectangle(cornerRadius: Token.Radius.cardSm)
                    .strokeBorder(focused ? Token.textPrimary : Token.cardBorder, lineWidth: Self.borderWidth)
            )
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(placeholder)          // R-17: §4 names placeholder as the label
            .accessibilityValue(text)
            .ui2Element("TextInput")                  // capture element map — UI2Element.swift
    }

    // MARK: - Geometry

    // §2: Border 1px. The border INSETS the content — measured on the frozen snapshot, whose
    // caret (a hard-edged 2×24 rect) starts at frame + 17 horizontally and at frame + 10
    // vertically in the Multi symbols: 1 + 16 and 1 + 9, i.e. §2's p16/py9 from inside the
    // stroke.
    private static let borderWidth: CGFloat = 1

    // GAP — C-045 §2: Single/Phone 44pt and Multi 88pt minimum, no size token.
    private var minHeight: CGFloat { kind == .multi ? 88 : 44 }

    // FLAGGED LITERAL — C-045 §2: Multi py9, no spacing token (D7/D21). Single and Phone
    // state only "content vertically centred" inside 44pt, so their vertical inset is the
    // centring, not a padding value — and centring a 24pt line box in 44pt lands it at 10,
    // the same place the Multi inset puts it.
    private var verticalInset: CGFloat { kind == .multi ? Self.borderWidth + 9 : 0 }

    private var boxAlignment: SwiftUI.Alignment {
        switch kind {
        case .phone: return .center                   // §2: centred by anatomy
        case .single: return alignment == .center ? .center : .leading
        case .multi: return alignment == .center ? .top : .topLeading
        }
    }

    private var textAlignment: TextAlignment { alignment == .center ? .center : .leading }

    // MARK: - Content

    @ViewBuilder private var content: some View {
        if kind == .phone {
            phoneRow
        } else {
            textRun
        }
    }

    /// Single / Multi: one text run whose ROLE changes with `text`.
    private var textRun: some View {
        lineBoxed(
            Text(text.isEmpty ? placeholder : text)
                // §2: Single/Multi text — Regular 14/24 `type-input`.
                .designTextStyle(Token.TypeStyle.input)
                // §2: placeholder `color-input-placeholder`, value `color-input-value`.
                .foregroundColor(text.isEmpty ? Token.inputPlaceholder : Token.inputValue)
                // §2: Single — one line · Multi — wrapping, each line per `alignment`.
                .lineLimit(kind == .single ? 1 : nil)
                .multilineTextAlignment(textAlignment),
            style: Token.TypeStyle.input
        )
        // §2 draws one text run whose role changes with `text` — the element map says which.
        .ui2Element(text.isEmpty ? "Placeholder" : "Value")
        // §2: Caret (focused only): at the content's leading edge — under `alignment:
        // center`, the leading edge of the centred run. An OVERLAY, not a row item: the
        // snapshot's focused and unfocused symbols place the text at the identical x.
        .overlay(alignment: kind == .single ? .leading : .topLeading) {
            if focused { caret }
        }
    }

    /// Phone: prefix + number entry, the group centred both ways (§2).
    private var phoneRow: some View {
        ZStack(alignment: .leading) {
            lineBoxed(
                Text(countryCode)
                    // §2: prefix always `color-text-primary`, Regular 18/24 `type-action-item`.
                    .designTextStyle(Token.TypeStyle.actionItem)
                    .foregroundColor(Token.textPrimary)
                    .lineLimit(1),
                style: Token.TypeStyle.actionItem
            )
            .ui2Element("Prefix")

            lineBoxed(
                Text(text.isEmpty ? placeholder : text)
                    // §2: placeholder `color-input-placeholder`; value `color-text-primary`
                    // (white — unlike Single/Multi). Type `type-action-item`.
                    .designTextStyle(Token.TypeStyle.actionItem)
                    .foregroundColor(text.isEmpty ? Token.inputPlaceholder : Token.textPrimary)
                    .lineLimit(1),
                style: Token.TypeStyle.actionItem
            )
            .ui2Element(text.isEmpty ? "Placeholder" : "Value")
            // §2: Caret at the insertion point — the number entry's leading edge when
            // empty, its trailing edge when valued (symbols 4639:41648 / 4639:41666).
            .overlay(alignment: text.isEmpty ? .leading : .trailing) {
                if focused {
                    caret.alignmentGuide(.trailing) { $0[.leading] }
                }
            }
            // FLAGGED LITERAL — C-045 §2: the number entry's leading edge sits 24pt after the
            // prefix's leading edge (Figma 4639:41623 x = 24), no spacing token.
            .padding(.leading, 24)
        }
        .fixedSize()
    }

    /// §2: Regular 14/24 and 18/24 — glyphs sit centred in a 24pt line box. SwiftUI has no
    /// line-height: `designTextStyle` spells it as lineSpacing, applied only BETWEEN lines,
    /// so the first line would otherwise sit high. Centring the run in an explicit line box
    /// restores the half-leading above it.
    private func lineBoxed(_ text: some View, style: DesignTextStyle) -> some View {
        text
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: style.lineHeight ?? style.size)
    }

    /// §2: Caret — 2×24, r2, `color-accent`.
    private var caret: some View {
        RoundedRectangle(cornerRadius: Token.Radius.bar)
            .fill(Token.accent)
            // GAP — C-045 §2: caret 2×24, no size token.
            .frame(width: 2, height: 24)
            .ui2Element("Caret")
    }
}
