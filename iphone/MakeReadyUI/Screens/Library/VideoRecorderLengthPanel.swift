//
//  VideoRecorderLengthPanel.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from screen video-recorder in d2m (§2d Length panel, Countdown panel's segmented choice).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// §2d Length panel: two C-047 rows; under Specify length, the typed length, C-149 and End countdown.
struct VideoRecorderLengthPanel: View {
    typealias PreRoll = VideoRecorderScreen.State.PreRoll

    let specifies: Bool
    let length: TimeInterval
    let endCountdown: PreRoll
    let onModeChange: (String) -> Void
    let onLengthChange: (TimeInterval) -> Void
    let onEndCountdownChange: (PreRoll) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// §3: the input's local draft, sent only on commit.
    @State private var draft: String
    @FocusState private var editing: Bool

    /// GAP — video-recorder §2d: the length input at the 44 pt hit height; no size token.
    private static let inputHeight: CGFloat = 44

    init(
        specifies: Bool,
        length: TimeInterval,
        endCountdown: PreRoll,
        onModeChange: @escaping (String) -> Void,
        onLengthChange: @escaping (TimeInterval) -> Void,
        onEndCountdownChange: @escaping (PreRoll) -> Void
    ) {
        self.specifies = specifies
        self.length = length
        self.endCountdown = endCountdown
        self.onModeChange = onModeChange
        self.onLengthChange = onLengthChange
        self.onEndCountdownChange = onEndCountdownChange
        _draft = State(initialValue: LengthEntry.format(Int(length.rounded())))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RadioOptionRow(
                title: "Any length (2 min cap)",
                description: "Make it as short or as long as you want, up to 2 minutes.",
                selected: !specifies,
                onSelect: { onModeChange("any") }
            )
            .ui2Element("C-047 RadioOptionRow")
            RadioOptionRow(
                title: "Specify length",
                description: "Recording stops on its own at the length you set.",
                selected: specifies,
                onSelect: { onModeChange("specify") }
            )
            .ui2Element("C-047 RadioOptionRow 2")
            if specifies {
                specifyControls
                    .padding(.top, Token.Space.elementGap)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(reduceMotion ? nil : Token.Motion.chipSelect, value: specifies)
        .sensoryFeedback(.selection, trigger: specifies)
        .sensoryFeedback(.selection, trigger: endCountdown)
        .ui2Element("Length panel")
    }

    private var specifyControls: some View {
        VStack(alignment: .leading, spacing: Token.Space.stackGap) {
            input
            LengthSlider(length: length) { seconds in
                // §3: the slider updates the input live.
                draft = LengthEntry.format(Int(seconds))
                editing = false
                onLengthChange(seconds)
            }
            .ui2Element("C-149 LengthSlider")
            VideoRecorderPreRollChoice(
                caption: "End countdown",
                selected: endCountdown,
                onSelect: onEndCountdownChange
            )
        }
    }

    /// §3: digits fill from the right; committed by the Done check, focus leaving, or the sheet closing.
    private var input: some View {
        HStack(spacing: Token.Space.fieldGap) {
            TextField("", text: $draft)
                .designTextStyle(Token.TypeStyle.timecode)
                .monospacedDigit()
                .foregroundStyle(Token.textPrimary)
                .tint(Token.accent)
                .keyboardType(.numberPad)
                .focused($editing)
                .accessibilityLabel("Length, minutes and seconds")
                .padding(.horizontal, Token.Space.fieldGap)
                .frame(maxWidth: .infinity, minHeight: Self.inputHeight)
                .background(
                    RoundedRectangle(cornerRadius: Token.Radius.card, style: .continuous).fill(Token.white5)
                )
                .contentShape(Rectangle())
                .onTapGesture { editing = true }
                .ui2Element("Length input")
            if editing {
                // The number pad has no return key: its Done is C-159, beside the input.
                DoneCheck(onTap: { editing = false })
                    .ui2Element("C-159 DoneCheck")
            }
        }
        .onChange(of: draft) { _, typed in
            let shown = LengthEntry.digits(typed)
            if shown != typed { draft = shown }
        }
        .onChange(of: editing) { _, focused in
            if !focused { commit() }
        }
        .onChange(of: length) { _, seconds in
            draft = LengthEntry.format(Int(seconds.rounded()))
        }
        .onDisappear { commit() }
    }

    private func commit() {
        let seconds = LengthEntry.commit(draft)
        draft = LengthEntry.format(seconds)
        guard seconds != Int(length.rounded()) else { return }
        onLengthChange(TimeInterval(seconds))
    }
}

/// §2d: a captioned segmented choice Off · 3 s · 10 s, in the look of C-151's step control (the
/// Countdown panel's Countdown, the Length panel's End countdown). `radius-circle` is unparsed
/// ("50%"), so the shapes are SwiftUI capsules.
struct VideoRecorderPreRollChoice: View {
    typealias PreRoll = VideoRecorderScreen.State.PreRoll

    let caption: String
    let selected: PreRoll
    let onSelect: (PreRoll) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// GAP — video-recorder §2d: the segmented choice, at C-151 §2b's step control size (36 pt
    /// capsule, selection inset 2 pt); no size token.
    private static let segmentHeight: CGFloat = 36
    private static let segmentInset: CGFloat = 2

    var body: some View {
        VStack(alignment: .leading, spacing: Token.Space.elementGap) {
            Text(caption)
                .designTextStyle(Token.TypeStyle.bodySm)
                .foregroundStyle(Token.textPrimary)
                .accessibilityHidden(true)
                .ui2Element("\(caption) label")
            control
        }
    }

    private var control: some View {
        GeometryReader { proxy in
            let options = PreRoll.allCases
            let segment = proxy.size.width / CGFloat(options.count)
            ZStack(alignment: .leading) {
                Capsule().fill(Token.white10)
                Capsule()
                    .fill(Token.accent)
                    .frame(
                        width: max(segment - 2 * Self.segmentInset, 0),
                        height: Self.segmentHeight - 2 * Self.segmentInset
                    )
                    .offset(x: CGFloat(options.firstIndex(of: selected) ?? 0) * segment + Self.segmentInset)
                HStack(spacing: 0) {
                    ForEach(options, id: \.self) { option in
                        SwiftUI.Button { onSelect(option) } label: {
                            Text(option.label)
                                .designTextStyle(Token.TypeStyle.labelEmphasis)
                                .foregroundStyle(option == selected ? Token.textPrimary : Token.textSecondary)
                                .lineLimit(1)
                                .frame(width: segment, height: Self.segmentHeight)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(caption) \(option.label)")
                        .accessibilityAddTraits(option == selected ? .isSelected : [])
                    }
                }
            }
            .animation(reduceMotion ? nil : Token.Motion.chipSelect, value: selected)
        }
        .frame(height: Self.segmentHeight)
        .ui2Element("\(caption) choice")
    }
}
