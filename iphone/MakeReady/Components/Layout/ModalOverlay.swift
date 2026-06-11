//
//  ModalOverlay.swift
//  MakeReady
//
//  A reusable modal overlay component that provides consistent presentation
//  and animation for full-screen modal pages.
//

import SwiftUI

// MARK: - Main Modal Component

struct ModalOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    let content: Content

    // Animation state
    @State private var offset: CGFloat = 1000
    @State private var overlayOpacity: Double = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDismissing = false

    // Customization options
    var cornerRadius: CGFloat
    var overlayColor: Color
    var overlayMaxOpacity: Double
    var dismissOnTapOutside: Bool
    var springResponse: Double
    var springDamping: Double

    init(
        isPresented: Binding<Bool>,
        cornerRadius: CGFloat = 16,
        overlayColor: Color = .black,
        overlayMaxOpacity: Double = 0.5,
        dismissOnTapOutside: Bool = true,
        springResponse: Double = 0.4,
        springDamping: Double = 0.8,
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self.cornerRadius = cornerRadius
        self.overlayColor = overlayColor
        self.overlayMaxOpacity = overlayMaxOpacity
        self.dismissOnTapOutside = dismissOnTapOutside
        self.springResponse = springResponse
        self.springDamping = springDamping
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dark overlay background
            overlayColor.opacity(overlayOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    if dismissOnTapOutside {
                        dismiss()
                    }
                }

            // Full-screen modal (bottom-aligned)
            VStack(spacing: 0) {
                Spacer()

                content
                    .frame(maxWidth: .infinity)
                    .background(Color.appBackground)
                    .clipShape(RoundedCornersShape(corners: [.topLeft, .topRight], radius: cornerRadius))
                    .offset(y: offset + dragOffset)
                    .gesture(dragGesture)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onAppear {
            // Set initial offset to screen height
            offset = Screen.bounds.height

            withAnimation(Motion.pagePush) {
                overlayOpacity = overlayMaxOpacity
            }
            withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                offset = 0
            }
        }
        .onChange(of: isPresented) { oldValue, newValue in
            if oldValue && !newValue && !isDismissing {
                isDismissing = true
                animateDismiss()
            }
        }
    }

    // Swipe-to-dismiss gesture
    var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height > 0 {
                    dragOffset = value.translation.height
                }
            }
            .onEnded { value in
                if value.translation.height > 100 {
                    dismiss()
                } else {
                    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        animateDismiss()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if isPresented {
                isPresented = false
            }
        }
    }

    private func animateDismiss() {
        withAnimation(Motion.pageDismiss) {
            overlayOpacity = 0
        }
        withAnimation(.spring(response: 0.3, dampingFraction: springDamping)) {
            offset = Screen.bounds.height
            dragOffset = 0
        }
    }
}

// MARK: - View Extension for Easy Usage

extension View {
    /// Presents a full-screen modal overlay when the binding is true
    func modalOverlay<Content: View>(
        isPresented: Binding<Bool>,
        cornerRadius: CGFloat = 16,
        overlayColor: Color = .black,
        overlayMaxOpacity: Double = 0.5,
        dismissOnTapOutside: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        ModalOverlayWrapper(
            isPresented: isPresented,
            cornerRadius: cornerRadius,
            overlayColor: overlayColor,
            overlayMaxOpacity: overlayMaxOpacity,
            dismissOnTapOutside: dismissOnTapOutside,
            content: content,
            wrappedView: self
        )
    }
}

// MARK: - Wrapper for Animation Management

private struct ModalOverlayWrapper<Content: View, WrappedView: View>: View {
    @Binding var isPresented: Bool
    let cornerRadius: CGFloat
    let overlayColor: Color
    let overlayMaxOpacity: Double
    let dismissOnTapOutside: Bool
    let content: () -> Content
    let wrappedView: WrappedView

    @State private var shouldShowModal = false

    var body: some View {
        ZStack {
            wrappedView

            if shouldShowModal {
                ModalOverlay(
                    isPresented: $isPresented,
                    cornerRadius: cornerRadius,
                    overlayColor: overlayColor,
                    overlayMaxOpacity: overlayMaxOpacity,
                    dismissOnTapOutside: dismissOnTapOutside,
                    content: content
                )
            }
        }
        .onChange(of: isPresented) { oldValue, newValue in
            if newValue {
                shouldShowModal = true
            } else if oldValue && !newValue {
                // Wait for dismiss animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    shouldShowModal = false
                }
            }
        }
        .onAppear {
            if isPresented { shouldShowModal = true }
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewContainer: View {
        @State var showModal = false

        var body: some View {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Main Application Content")
                        .font(.headline)
                        .foregroundColor(.white)

                    Button("Show Modal") {
                        showModal = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .modalOverlay(isPresented: $showModal) {
                VStack(spacing: 20) {
                    Text("Full Screen Modal")
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.top, 30)

                    Text("Swipe down or tap outside to dismiss")
                        .foregroundColor(.white.opacity(0.7))

                    Spacer()

                    Button("Close") {
                        showModal = false
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    return PreviewContainer()
}
