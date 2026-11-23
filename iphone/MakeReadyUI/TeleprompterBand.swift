//
//  TeleprompterBand.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-151-teleprompterband in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-151 TeleprompterBand — "Teleprompter text band over the camera, with a panel offering Use a note."
///
/// Two surfaces through one `surface` axis (OQ-C-151-1):
/// - **band** (§2a, 212 pt): the script on a translucent plate in the top third of the preview,
///   moved up by `scrollOffset`. It never scrolls itself (R-04, R-19): the container's
///   `TeleprompterScroller` advances the offset while a segment records and holds it while paused.
/// - **panel** (§2b, 428 pt): the Teleprompter sheet's content — header with Done, the script
///   field, Use a note (C-105), and the speed (5) and text-size (3) step controls.
///
/// Controlled (R-01): `script`, `speed` and `textSize` are displayed, never held. Width-driven
/// and chrome-free (R-16): the sheet chrome and its `space-page-margin` inset are the container's.
struct TeleprompterBand: View {
    /// §4: which surface draws (§2a / §2b).
    enum Surface { case band, panel }

    /// §4: the band's type (§2a) and the panel's selected size.
    enum TextSize: CaseIterable {
        case small, medium, large

        /// §2b: the step control's segment label.
        var label: String {
            switch self {
            case .small: return "Small"
            case .medium: return "Medium"
            case .large: return "Large"
            }
        }

        /// §2a Text size table.
        // FLAGGED LITERAL — C-151 §2a / OQ-C-151-2: SF Pro Medium 20/28, 24/32, 30/40, kept as
        // literals until the owner promotes them to type-teleprompter-sm/-md/-lg.
        var style: DesignTextStyle {
            switch self {
            case .small: return DesignTextStyle(weight: .medium, size: 20, lineHeight: 28, tracking: 0)
            case .medium: return DesignTextStyle(weight: .medium, size: 24, lineHeight: 32, tracking: 0)
            case .large: return DesignTextStyle(weight: .medium, size: 30, lineHeight: 40, tracking: 0)
            }
        }
    }

    let surface: Surface
    /// §4: the script; blank → the band's empty line, the panel's placeholder.
    let script: String
    let textSize: TextSize
    /// §4: 1…5 (clamped); the panel's selected step. The band ignores it.
    let speed: Int
    /// §4: band only — points the text has moved up; clamped ≥ 0. The panel ignores it.
    var scrollOffset: CGFloat = 0
    /// §4: panel — each edit of the field; the caller stores the draft (D7).
    var onScriptChange: (String) -> Void = { _ in }
    /// §4: panel — Use a note tapped; the caller presents the Library note picker.
    var onUseNote: () -> Void = {}
    /// §4: panel — a speed segment tapped, 1…5.
    var onSpeedChange: (Int) -> Void = { _ in }
    /// §4: panel — a size segment tapped.
    var onTextSizeChange: (TextSize) -> Void = { _ in }
    /// §4: panel — ✓ tapped; the caller closes the sheet.
    var onDone: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// R-02: keyboard focus is ephemeral.
    @FocusState private var fieldFocused: Bool

    // §2 geometry: this component's own (contract: "Literals: 212 / 24 / 164 / 160 / 44 / 36 / 2 pt
    // are this component's geometry, as in C-149 and C-150").
    private static let bandHeight: CGFloat = 212
    private static let bandInset: CGFloat = 24          // text start and the fade masks
    private static let headerHeight: CGFloat = 44
    private static let doneGlyph: CGFloat = 24
    private static let fieldHeight: CGFloat = 160
    private static let controlHeight: CGFloat = 36
    private static let segmentInset: CGFloat = 2
    /// Not contract geometry: UITextView's default text-container inset (5 pt line-fragment
    /// padding, 8 pt top), which TextEditor cannot turn off; compensated so §2b's 12 pt holds.
    private static let editorInset = CGSize(width: 5, height: 8)
    /// §2b: the "Speed" / "Text size" caption box — `type-body-sm`'s 20 pt line.
    private static var captionHeight: CGFloat {
        Token.TypeStyle.bodySm.lineHeight ?? Token.TypeStyle.bodySm.size
    }
    /// §2b: 44 + 8 + 160 + 12 + 36 + 24 + 64 + 16 + 64 = 428.
    private static var panelHeight: CGFloat {
        let control = captionHeight + Token.Space.elementGap + controlHeight
        return headerHeight + Token.Space.elementGap
            + fieldHeight + Token.Space.fieldGap
            + controlHeight + Token.Space.rowGap
            + control + Token.Space.stackGap
            + control
    }

    private static let emptyLine = "Add a script in Teleprompter"
    private static let placeholder = "Type or paste your script"

    private var scriptBlank: Bool {
        script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var clampedSpeed: Int { min(max(speed, 1), 5) }
    private var animation: Animation? { reduceMotion ? nil : Token.Motion.chipSelect }

    var body: some View {
        switch surface {
        case .band: band
        case .panel: panel
        }
    }

    // MARK: - Band (§2a)

    private var band: some View {
        let shape = RoundedRectangle(cornerRadius: Token.Radius.card, style: .continuous)
        return ZStack {
            shape
                .fill(Token.black50)
                .ui2Element("Plate")
            if scriptBlank {
                // §2a Empty (OQ-C-151-4): one centred line, vertically centred, no scroll.
                Text(Self.emptyLine)
                    .designTextStyle(Token.TypeStyle.bodySm)
                    .foregroundStyle(Token.white60)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Token.Space.cardPadding)
                    .ui2Element("Empty")
            } else {
                bandText
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.bandHeight)
        .clipShape(shape)
        // §2a: not interactive — a tap falls through to the preview.
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Teleprompter")
        .accessibilityValue(scriptBlank ? Self.emptyLine : script)
        .ui2Element("TeleprompterBand")
    }

    /// §2a Text: centred lines (OQ-C-151-7), inset 16 left/right, laid out from the plate's
    /// top + 24 and moved up by `scrollOffset`; clipped to the plate under 24 pt fade masks.
    private var bandText: some View {
        Text(script)
            .designTextStyle(textSize.style)
            .foregroundStyle(Token.textPrimary)
            .multilineTextAlignment(.center)
            .designShadow(Token.Elevation.thumb)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Token.Space.cardPadding)
            .padding(.top, Self.bandInset)
            .offset(y: -max(scrollOffset, 0))
            .ui2Element("Text")
            // A fixed 212 pt box: a flexible frame would grow to the text's full height and
            // centre it, losing the top + 24 start and the fades.
            .frame(maxWidth: .infinity, minHeight: Self.bandHeight, maxHeight: Self.bandHeight, alignment: .top)
            .clipped()
            .mask(fades)
    }

    /// §2a Fades: text fades to 0 over 24 pt at the top and the bottom edge — a mask, not a paint.
    private var fades: some View {
        let edge = Self.bandInset / Self.bandHeight
        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: edge),
                .init(color: .black, location: 1 - edge),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Panel (§2b)

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .frame(height: Self.headerHeight)
                .padding(.bottom, Token.Space.elementGap)
            field
                .frame(height: Self.fieldHeight)
                .padding(.bottom, Token.Space.fieldGap)
            Button(label: "Use a note", leadingGlyph: .notebookPen, onTap: onUseNote)
                .frame(height: Self.controlHeight)
                .padding(.bottom, Token.Space.rowGap)
                .ui2Element("Use a note")
            stepGroup(
                caption: "Speed",
                labels: (1...5).map(String.init),
                selectedIndex: clampedSpeed - 1,
                accessibilityLabel: { "Speed \($0 + 1) of 5" },
                onSelect: { onSpeedChange($0 + 1) }
            )
            .padding(.bottom, Token.Space.stackGap)
            .ui2Element("Speed")
            stepGroup(
                caption: "Text size",
                labels: TextSize.allCases.map(\.label),
                selectedIndex: TextSize.allCases.firstIndex(of: textSize) ?? 1,
                accessibilityLabel: { "Text size \(TextSize.allCases[$0].label)" },
                onSelect: { onTextSizeChange(TextSize.allCases[$0]) }
            )
            .ui2Element("Text size")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.panelHeight, alignment: .top)
        .sensoryFeedback(.selection, trigger: clampedSpeed)
        .sensoryFeedback(.selection, trigger: textSize)
        .ui2Element("TeleprompterBand")
    }

    /// §2b Header: "Teleprompter" leading; Done (`check`, 24 pt) in a 44 pt hit square at the
    /// trailing edge (as C-150).
    private var header: some View {
        HStack(spacing: 0) {
            Text("Teleprompter")
                .designTextStyle(Token.TypeStyle.sectionTitle)
                .foregroundStyle(Token.textPrimary)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
                .ui2Element("Title")
            Spacer(minLength: 0)
            SwiftUI.Button(action: onDone) {
                Glyph(.check, size: .md, tint: Token.textPrimary)
                    .frame(width: Self.headerHeight, height: Self.headerHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Done")
            .ui2Element("Done")
        }
        // The glyph's trailing edge sits at the panel's edge; the hit square overhangs it.
        .padding(.trailing, -(Self.headerHeight - Self.doneGlyph) / 2)
        .ui2Element("Header")
    }

    /// §2b Script field: `color-white-5` fill, `radius-card` corners, 12 pt padding; text
    /// `type-body-sm`; placeholder in `color-input-placeholder`; scrolls inside itself.
    private var field: some View {
        let shape = RoundedRectangle(cornerRadius: Token.Radius.card, style: .continuous)
        return ZStack(alignment: .topLeading) {
            shape.fill(Token.white5)
            TextEditor(text: Binding(get: { script }, set: onScriptChange))
                .designTextStyle(Token.TypeStyle.bodySm)
                .foregroundStyle(Token.textPrimary)
                .scrollContentBackground(.hidden)
                .focused($fieldFocused)
                // §2b's 12 pt padding is measured to the glyphs; TextEditor's own text container
                // adds its inset, so the editor is pulled back by it (a framework fact, reported).
                .padding(.horizontal, Token.Space.fieldGap - Self.editorInset.width)
                .padding(.vertical, Token.Space.fieldGap - Self.editorInset.height)
                .accessibilityLabel("Script")
                .ui2Element("Value")
            if scriptBlank {
                Text(Self.placeholder)
                    .designTextStyle(Token.TypeStyle.bodySm)
                    .foregroundStyle(Token.inputPlaceholder)
                    .padding(Token.Space.fieldGap)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .ui2Element("Placeholder")
            }
        }
        .clipShape(shape)
        .ui2Element("Script field")
    }

    /// §2b Speed / Text size: the caption, 8 pt, then the step control.
    private func stepGroup(
        caption: String,
        labels: [String],
        selectedIndex: Int,
        accessibilityLabel: @escaping (Int) -> String,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Token.Space.elementGap) {
            Text(caption)
                .designTextStyle(Token.TypeStyle.bodySm)
                .foregroundStyle(Token.textSecondary)
                .frame(height: Self.captionHeight)
                .accessibilityHidden(true)
                .ui2Element("Caption")
            stepControl(
                labels: labels,
                selectedIndex: selectedIndex,
                accessibilityLabel: accessibilityLabel,
                onSelect: onSelect
            )
        }
    }

    /// §2b Step control (OQ-C-151-6): a 36 pt `color-white-10` capsule the full width, equal
    /// segments, the selected one a capsule inset 2 pt in `color-accent`; it moves over
    /// `motion-chip-select` (Reduce Motion: jumps). `radius-circle` is unparsed ("50%"), so the
    /// shapes are SwiftUI capsules.
    private func stepControl(
        labels: [String],
        selectedIndex: Int,
        accessibilityLabel: @escaping (Int) -> String,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        GeometryReader { proxy in
            let segment = proxy.size.width / CGFloat(max(labels.count, 1))
            ZStack(alignment: .leading) {
                Capsule().fill(Token.white10)
                Capsule()
                    .fill(Token.accent)
                    .frame(width: segment - 2 * Self.segmentInset,
                           height: Self.controlHeight - 2 * Self.segmentInset)
                    .offset(x: CGFloat(selectedIndex) * segment + Self.segmentInset)
                    .ui2Element("Selection")
                HStack(spacing: 0) {
                    ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                        let selected = index == selectedIndex
                        SwiftUI.Button { onSelect(index) } label: {
                            Text(label)
                                .designTextStyle(Token.TypeStyle.labelEmphasis)
                                .foregroundStyle(selected ? Token.textPrimary : Token.textSecondary)
                                .lineLimit(1)
                                .frame(width: segment, height: Self.controlHeight)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(accessibilityLabel(index))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .ui2Element("Segment \(index + 1)")
                    }
                }
            }
            .animation(animation, value: selectedIndex)
        }
        .frame(height: Self.controlHeight)
        .ui2Element("Step control")
    }
}
