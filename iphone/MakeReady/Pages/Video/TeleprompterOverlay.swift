//
//  TeleprompterOverlay.swift
//  MakeReady
//
//  Scrolling text overlay for teleprompter mode during video recording
//

import SwiftUI

struct TeleprompterOverlay: View {
    let text: String
    let isScrolling: Bool
    let scrollSpeed: Double

    @State private var offset: CGFloat = 0
    @State private var textHeight: CGFloat = 0
    @State private var containerHeight: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.5))

                // Scrolling text
                ScrollView(.vertical, showsIndicators: false) {
                    Text(text)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 40)
                        .background(
                            GeometryReader { textGeometry in
                                Color.clear
                                    .onAppear {
                                        textHeight = textGeometry.size.height
                                    }
                                    .onChange(of: text) { _, _ in
                                        textHeight = textGeometry.size.height
                                    }
                            }
                        )
                        .offset(y: -offset)
                }
                .disabled(true) // Disable manual scrolling
                .onAppear {
                    containerHeight = geometry.size.height
                }

                // Top gradient fade
                VStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.5),
                            Color.black.opacity(0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)

                    Spacer()

                    // Bottom gradient fade
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0),
                            Color.black.opacity(0.5)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(height: 200)
        .onChange(of: isScrolling) { _, scrolling in
            if scrolling {
                startScrolling()
            } else {
                stopScrolling()
            }
        }
    }

    // MARK: - Scrolling Animation

    private func startScrolling() {
        // Calculate total scroll distance
        let totalDistance = max(0, textHeight - containerHeight + 80)
        guard totalDistance > 0 else { return }

        // Calculate duration based on speed (higher speed = faster)
        let baseDuration = Double(totalDistance) / 30.0 // ~30 points per second base
        let adjustedDuration = baseDuration / scrollSpeed

        withAnimation(.linear(duration: adjustedDuration)) {
            offset = totalDistance
        }
    }

    private func stopScrolling() {
        // Keep current position when stopped
        withAnimation(Motion.pagePush) {
            // Optionally reset or keep position
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack {
            TeleprompterOverlay(
                text: """
                Welcome to MakeReady! Today we're going to talk about how to create amazing video content.

                First, let's discuss the importance of good lighting. Natural light is always best, but if you're indoors, try to use soft, diffused lighting.

                Next, consider your background. A clean, uncluttered background helps keep the focus on you.

                Remember to speak clearly and maintain eye contact with the camera. This helps create a connection with your audience.

                Finally, don't be afraid to make mistakes! The best content often comes from authentic moments.

                Thanks for watching!
                """,
                isScrolling: true,
                scrollSpeed: 1.0
            )
            .padding(.horizontal, 32)
        }
    }
}
