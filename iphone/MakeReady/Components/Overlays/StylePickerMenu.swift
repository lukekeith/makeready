//
//  StylePickerMenu.swift
//  MakeReady
//
//  Bottom-sheet menu shown after the user finishes a tap-and-hold selection
//  inside a locked read block, or taps an existing styled span. Presented via
//  overlayManager.presentMenu().
//

import SwiftUI

struct StylePickerMenu: View {
    @Environment(\.dismissOverlay) private var dismissOverlay

    let snippet: String
    /// The style currently applied to this range, if any. The matching row
    /// is rendered with a checkmark and a brand-colored label.
    let currentStyle: ReadBlockSelectionStyle?
    /// nil → remove existing style; non-nil → apply this style.
    let onSelect: (ReadBlockSelectionStyle?) -> Void
    /// Fires when the menu disappears for any reason (style picked, remove
    /// pressed, cancel tapped, scrim tap-outside). Used by the parent to
    /// clear the "currently editing" highlight on the underlying span.
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Snippet preview so the user sees what they're styling.
            Text("\u{201C}\(snippet)\u{201D}")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                StylePickerRow(
                    label: "Bold",
                    sample: "Bold",
                    sampleFont: .system(size: 17, weight: .bold),
                    isSelected: currentStyle == .bold
                ) {
                    if currentStyle != .bold { onSelect(.bold) }
                    dismissOverlay?()
                }

                StylePickerRow(
                    label: "Highlight",
                    sample: "Highlight",
                    sampleBackground: Color(hex: "#6c47ff").opacity(0.35),
                    isSelected: currentStyle == .highlight
                ) {
                    if currentStyle != .highlight { onSelect(.highlight) }
                    dismissOverlay?()
                }
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal, 16)

            if currentStyle != nil {
                Button {
                    onSelect(nil)
                    dismissOverlay?()
                } label: {
                    Text("Remove style")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "#ff5d5d"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            Button {
                dismissOverlay?()
            } label: {
                Text("Cancel")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .onDisappear {
            onDismiss?()
        }
    }
}

private struct StylePickerRow: View {
    let label: String
    let sample: String
    var sampleFont: Font = .system(size: 17, weight: .regular)
    var sampleColor: Color = .white
    var sampleBackground: Color = .clear
    var sampleUnderline: Bool = false
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(isSelected ? Color(hex: "#6c47ff") : .white.opacity(0.25))
                    .frame(width: 22, height: 22)

                Text(label)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isSelected ? Color(hex: "#6c47ff") : .white)

                Spacer()

                Text(sample)
                    .font(sampleFont)
                    .foregroundColor(sampleColor)
                    .underline(sampleUnderline, color: .yellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(sampleBackground)
                    .cornerRadius(4)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        VStack {
            Spacer()
            StylePickerMenu(
                snippet: "In the beginning was the Word",
                currentStyle: .highlight,
                onSelect: { _ in }
            )
        }
    }
}
