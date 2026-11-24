//
//  UnsafeBandOverlay.swift
//  MakeReadyUI — the UI 2.0 module
//
//  Built from C-158-unsafebandoverlay in d2m (§2 geometry, §3 states, §4 props).
//  PREVIEW ONLY: referenced by no screen, route, tab or flag.
//

import SwiftUI

/// C-158 UnsafeBandOverlay — "Hatched unsafe band drawn at the frame edges while a text layer is
/// being moved."
///
/// Display-only and advisory: layers may enter it. Being in the view tree is being visible, and
/// presence is the caller's (R-01). No props, no actions, no state (§4).
///
/// §2: fills the width and height it is given, the video's frame rect. Disclosed R-16 exception:
/// an overlay has no height of its own. Square corners; the host clips to its frame's radius.
///
/// OQ-C-158-1 (owner): all four edges, the same width on each, over §2's two side edges.
struct UnsafeBandOverlay: View {
    private enum Geometry {
        /// §2 `u`: one wu is the frame's short side / 440 (video-editor §2).
        static let referenceShortSide: CGFloat = 440
        /// FLAGGED LITERAL — C-158 §2 FL-1: 28 wu band, no size token.
        static let bandWidth: CGFloat = 28
    }

    var body: some View {
        GeometryReader { proxy in
            let unit = min(proxy.size.width, proxy.size.height) / Geometry.referenceShortSide
            let width = Geometry.bandWidth * unit
            // The side bands run the full height (§2); the top and bottom bands fit between them,
            // so no corner is painted twice.
            HStack(spacing: 0) {
                band("Leading band", .leading).frame(width: width)
                VStack(spacing: 0) {
                    band("Top band", .top).frame(height: width)
                    Spacer(minLength: 0)
                    band("Bottom band", .bottom).frame(height: width)
                }
                band("Trailing band", .trailing).frame(width: width)
            }
        }
        .allowsHitTesting(false)
        .ui2Element("UnsafeBandOverlay")
        .accessibilityHidden(true)
    }

    /// §2: hatch and inner line are one shape filled once, so their crossings do not add up.
    private func band(_ name: String, _ edge: Edge) -> some View {
        UnsafeBandHatch(edge: edge)
            .fill(Token.white50)
            .clipped()
            .ui2Element(name)
    }
}

/// §2 Hatch + Inner line of one band. Every subpath winds the same way: the non-zero fill unions
/// them. Stripes overrun the band at its sides; the caller clips.
private struct UnsafeBandHatch: Shape {
    /// FLAGGED LITERAL — C-158 §2 FL-2: 3 pt stripe, 6 pt pitch across it, 45°, no token.
    private static let stripe: CGFloat = 3
    private static let pitch: CGFloat = 6
    /// FLAGGED LITERAL — C-158 §2 FL-3: 1 pt line, no token.
    private static let line: CGFloat = 1

    /// The frame edge the band sits on; the line is on the opposite, inner side.
    let edge: Edge

    func path(in rect: CGRect) -> Path {
        Path { path in
            // A 45° stripe crosses a vertical edge √2 taller than it measures across.
            let height = Self.stripe * 2.0.squareRoot()
            let step = Self.pitch * 2.0.squareRoot()
            // Falling left to right on every band; a stripe starts at the top-leading corner.
            var y = -(rect.width / step).rounded(.up) * step
            while y < rect.height {
                path.move(to: CGPoint(x: rect.minX, y: rect.minY + y))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + y + rect.width))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + y + rect.width + height))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + y + height))
                path.closeSubpath()
                y += step
            }
            path.addRect(innerLine(in: rect))
        }
    }

    private func innerLine(in rect: CGRect) -> CGRect {
        switch edge {
        case .leading:
            CGRect(x: rect.maxX - Self.line, y: rect.minY, width: Self.line, height: rect.height)
        case .trailing:
            CGRect(x: rect.minX, y: rect.minY, width: Self.line, height: rect.height)
        case .top:
            CGRect(x: rect.minX, y: rect.maxY - Self.line, width: rect.width, height: Self.line)
        case .bottom:
            CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: Self.line)
        }
    }
}
