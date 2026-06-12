//
//  FullScreenImageViewer.swift
//  MakeReady
//
//  Full-screen zoomable image viewer with pinch/pan/double-tap gestures
//

import SwiftUI

struct FullScreenImageViewer: View {
    let image: UIImage?
    @Environment(\.dismiss) var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    @GestureState private var magnifyBy: CGFloat = 1.0
    @GestureState private var dragOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0
    private let doubleTapScale: CGFloat = 2.5

    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()

            // Image with zoom/pan gestures
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale * magnifyBy)
                    .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
                    .gesture(magnificationGesture)
                    .simultaneousGesture(dragGesture)
                    .onTapGesture(count: 2, perform: handleDoubleTap)
                    .gesture(swipeDownGesture)
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(Typography.s32)
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.3), radius: 4)
                    }
                    .padding(16)
                }
                Spacer()
            }
        }
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .updating($magnifyBy) { value, state, _ in
                state = value
            }
            .onEnded { value in
                let newScale = lastScale * value
                scale = min(max(newScale, minScale), maxScale)
                lastScale = scale

                // Reset offset if zoomed out to min scale
                if scale == minScale {
                    withAnimation(.spring()) {
                        offset = .zero
                        lastOffset = .zero
                    }
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                // Only allow drag when zoomed in
                if scale > minScale {
                    state = value.translation
                }
            }
            .onEnded { value in
                if scale > minScale {
                    offset.width += value.translation.width
                    offset.height += value.translation.height
                    lastOffset = offset
                }
            }
    }

    private var swipeDownGesture: some Gesture {
        DragGesture()
            .onEnded { value in
                // Swipe down to dismiss (only when not zoomed in)
                if scale == minScale && value.translation.height > 100 {
                    dismiss()
                }
            }
    }

    private func handleDoubleTap() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if scale > minScale {
                // Zoom out to 1x
                scale = minScale
                lastScale = minScale
                offset = .zero
                lastOffset = .zero
            } else {
                // Zoom in to 2.5x
                scale = doubleTapScale
                lastScale = doubleTapScale
            }
        }
    }
}

#Preview {
    FullScreenImageViewer(image: UIImage(systemName: "photo.fill"))
        .preferredColorScheme(.dark)
}
