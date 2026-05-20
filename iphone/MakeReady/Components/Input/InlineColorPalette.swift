//
//  InlineColorPalette.swift
//  MakeReady
//
//  Color palette grid with opacity slider, presented as a modal.
//  Extracted from EditBlockBackgroundPage for inline use.
//

import SwiftUI

struct InlineColorPalette: View {
    let selectedColor: String?
    let hasImage: Bool
    let opacity: Double
    let onColorSelected: (String) -> Void
    let onOpacityChanged: (Double) -> Void
    let onClear: () -> Void
    let onDismiss: () -> Void

    @State private var localOpacity: Double = 0.8

    private static let palette: [String] = [
        "#18181B", "#3F3F46", "#71717A", "#A1A1AA",
        "#7F1D1D", "#DC2626", "#BE185D", "#F472B6",
        "#9A3412", "#EA580C", "#B45309", "#FBBF24",
        "#854D0E", "#CA8A04", "#65A30D", "#84CC16",
        "#14532D", "#16A34A", "#064E3B", "#34D399",
        "#134E4A", "#0D9488", "#0891B2", "#06B6D4",
        "#1E3A8A", "#2563EB", "#1D4ED8", "#60A5FA",
        "#4C1D95", "#7C3AED", "#9333EA", "#C026D3",
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                PageTitle.linkTitleLink(
                    title: "Color Overlay",
                    leftLink: "",
                    rightLink: "Done",
                    onLeftLinkTap: {},
                    onRightLinkTap: { onDismiss() }
                )

                ScrollView {
                    VStack(spacing: 16) {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(Self.palette, id: \.self) { hex in
                                Button {
                                    onColorSelected(hex)
                                } label: {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(hex: hex))
                                        .aspectRatio(1, contentMode: .fit)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .strokeBorder(
                                                    selectedColor?.caseInsensitiveCompare(hex) == .orderedSame
                                                        ? Color.white
                                                        : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if hasImage && selectedColor != nil {
                            HStack(spacing: 12) {
                                Image(systemName: "circle.lefthalf.filled")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))

                                Slider(value: $localOpacity, in: 0...1)
                                    .tint(Color(hex: "#6c47ff"))

                                Text("\(Int(round(localOpacity * 100)))%")
                                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                    .foregroundColor(.white.opacity(0.85))
                                    .frame(width: 40, alignment: .trailing)
                            }
                            .onChange(of: localOpacity) { _, newValue in
                                onOpacityChanged(newValue)
                            }
                        }

                        if selectedColor != nil {
                            Button {
                                onClear()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "xmark.circle")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Clear color")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundColor(.white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 32)
                }
            }
        }
        .onAppear { localOpacity = opacity }
    }
}
