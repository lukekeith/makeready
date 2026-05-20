//
//  InlineFontSizePicker.swift
//  MakeReady
//
//  Horizontal 5-tile font size picker (xs/s/m/lg/xl).
//  Extracted from EditBlockBackgroundPage for inline use.
//

import SwiftUI

struct InlineFontSizePicker: View {
    let selectedSize: String
    let onSizeSelected: (String) -> Void

    private static let keys: [String] = ["xs", "s", "m", "lg", "xl"]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Self.keys, id: \.self) { key in
                let isSelected = selectedSize == key
                Button {
                    onSizeSelected(key)
                } label: {
                    Text("Aa")
                        .font(.system(size: Self.pointSize(key), weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    static func pointSize(_ key: String) -> CGFloat {
        switch key {
        case "xs": return 13
        case "s":  return 16
        case "m":  return 19
        case "lg": return 23
        case "xl": return 27
        default:   return 19
        }
    }

    /// Map font size key to point size for rendering verse text in the preview container.
    static func previewPointSize(_ key: String) -> CGFloat {
        switch key {
        case "xs": return 16
        case "s":  return 19
        case "m":  return 22
        case "lg": return 27
        case "xl": return 32
        default:   return 22
        }
    }
}
