//
//  OptimizedShadow.swift
//  MakeReady
//
//  Performance-optimized shadow modifier with pre-computed rectangular path.
//
//  Problem:
//  Standard .shadow() forces the GPU to compute the shadow path from the view's
//  alpha channel on every frame. On complex shapes or during animations, this
//  causes jitter and dropped frames.
//
//  Solution:
//  Use a simple pre-computed shape (RoundedRectangle) for the shadow path,
//  placed in the background. This allows the GPU to cache the shadow rendering.
//
//  Usage:
//  ```swift
//  VStack { ... }
//      .optimizedShadow(color: .black.opacity(0.3), radius: 20, y: -5, cornerRadius: 24)
//  ```
//

import SwiftUI

/// Performance-optimized shadow modifier with pre-computed path
struct OptimizedShadow: ViewModifier {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.clear)
                    .shadow(color: color, radius: radius, x: x, y: y)
            )
    }
}

extension View {
    /// Apply optimized shadow with pre-computed rectangular path
    ///
    /// - Parameters:
    ///   - color: Shadow color (default: black at 25% opacity)
    ///   - radius: Blur radius (default: 10)
    ///   - x: Horizontal offset (default: 0)
    ///   - y: Vertical offset (default: 4)
    ///   - cornerRadius: Corner radius for shadow shape (should match view's corner radius)
    func optimizedShadow(
        color: Color = .black.opacity(0.25),
        radius: CGFloat = 10,
        x: CGFloat = 0,
        y: CGFloat = 4,
        cornerRadius: CGFloat = 16
    ) -> some View {
        self.modifier(OptimizedShadow(
            color: color,
            radius: radius,
            x: x,
            y: y,
            cornerRadius: cornerRadius
        ))
    }
}
