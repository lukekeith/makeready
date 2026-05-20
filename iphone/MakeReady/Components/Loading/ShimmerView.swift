//
//  ShimmerView.swift
//  MakeReady
//
//  Reusable shimmer animation modifier for skeleton loading states
//

import SwiftUI

/// A view modifier that adds a shimmer animation effect
/// Used for skeleton loading states
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -200

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.1),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 180)
                    .offset(x: phase)
                    .onAppear {
                        withAnimation(
                            .linear(duration: 1.2)
                            .repeatForever(autoreverses: false)
                        ) {
                            phase = geometry.size.width + 200
                        }
                    }
                }
            )
            .clipped()
    }
}

extension View {
    /// Adds a shimmer animation effect to the view
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 20) {
            // Simple rectangle with shimmer
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 100)
                .shimmer()

            // Text placeholder with shimmer
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 20)

                Spacer()

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 20)
            }
            .shimmer()
        }
        .padding(20)
    }
}
