//
//  ConfirmationOverlay.swift
//  MakeReady
//
//  Full-screen confirmation overlay with blur background and configurable icon/message.
//

import SwiftUI

// MARK: - Style Enum

/// Icon variants for the confirmation overlay
enum ConfirmationOverlayStyle {
    case success    // Green checkmark
    case error      // Red X
    case warning    // Orange warning triangle
    case info       // Blue info circle

    var iconName: String {
        switch self {
        case .success: return "checkmark"
        case .error: return "xmark"
        case .warning: return "exclamationmark.triangle"
        case .info: return "info.circle"
        }
    }

    var iconBackgroundColor: Color {
        switch self {
        case .success: return Color(hex: "#57db5d")
        case .error: return Color(hex: "#ff4444")
        case .warning: return Color(hex: "#ffaa00")
        case .info: return Color(hex: "#4a90d9")
        }
    }

    var iconForegroundColor: Color {
        Color(hex: "#0d101a")
    }
}

// MARK: - Animated Completion Circle

/// Circle that transitions from spinning border to filled circle with icon
private struct AnimatedCompletionCircle: View {
    let color: Color
    let iconName: String
    let iconColor: Color
    let isProcessing: Bool

    // Animation states
    @State private var rotation: Double = 0
    @State private var fillScale: CGFloat
    @State private var iconScale: CGFloat
    @State private var iconOpacity: Double
    @State private var borderOpacity: Double
    @State private var hasInitialized: Bool = false

    init(color: Color, iconName: String, iconColor: Color, isProcessing: Bool) {
        self.color = color
        self.iconName = iconName
        self.iconColor = iconColor
        self.isProcessing = isProcessing

        // Initialize state based on whether we start in processing mode
        if isProcessing {
            _fillScale = State(initialValue: 0)
            _iconScale = State(initialValue: 0.2)
            _iconOpacity = State(initialValue: 0)
            _borderOpacity = State(initialValue: 1)
        } else {
            // Start with completed state (no animation needed)
            _fillScale = State(initialValue: 1)
            _iconScale = State(initialValue: 1)
            _iconOpacity = State(initialValue: 1)
            _borderOpacity = State(initialValue: 0)
        }
    }

    var body: some View {
        ZStack {
            // Spinning gradient border (white during processing, fades out on completion)
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.6),
                            Color.white
                        ]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(rotation))
                .opacity(borderOpacity)

            // Filled circle (scales from center on completion)
            Circle()
                .fill(color)
                .scaleEffect(fillScale)

            // Icon (scales in with bounce after fill completes)
            Image(systemName: iconName)
                .font(.system(size: 40, weight: .medium))
                .foregroundColor(iconColor)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
        }
        .frame(width: 100, height: 100)
        .onAppear {
            // Only start spinning if we're processing
            if isProcessing {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
        }
        .onChange(of: isProcessing) { wasProcessing, nowProcessing in
            if wasProcessing && !nowProcessing {
                // Processing just completed - trigger completion animation sequence
                animateCompletion()
            }
        }
    }

    private func animateCompletion() {
        // Step 1: Fill the circle from center (0.25s)
        withAnimation(Motion.pagePushBrisk) {
            fillScale = 1.0
            borderOpacity = 0
        }

        // Step 2: After fill completes, bounce the icon in (0.4s with bounce)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5, blendDuration: 0)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
        }
    }
}

// MARK: - Confirmation Overlay

/// A full-screen confirmation overlay with blur background
///
/// Usage:
/// ```swift
/// overlayManager.present(id: OverlayID.confirmationOverlay, priority: .topLevel) {
///     ConfirmationOverlay(
///         style: .success,
///         message: AttributedString.safeMarkdown("**Group** has been enrolled in **Program**."),
///         buttonLabel: "Done",
///         isProcessing: $isProcessing,
///         processingMessage: "Processing enrollment",
///         onDismiss: {
///             overlayManager.dismiss(id: OverlayID.confirmationOverlay)
///             // Navigate back
///         }
///     )
/// }
/// ```
struct ConfirmationOverlay: View {
    let style: ConfirmationOverlayStyle
    let message: AttributedString
    let buttonLabel: String
    let onDismiss: () -> Void

    // Optional secondary button
    let secondaryButtonLabel: String?
    let onSecondaryDismiss: (() -> Void)?

    // Processing state - optional binding for parent control
    @Binding var isProcessing: Bool
    var processingMessage: String = "Processing..."

    // Animation state
    @State private var contentOpacity: Double = 0
    @State private var contentScale: CGFloat = 0.9
    @State private var blurOpacity: Double = 0

    // Init with processing support
    init(
        style: ConfirmationOverlayStyle,
        message: AttributedString,
        buttonLabel: String,
        secondaryButtonLabel: String? = nil,
        isProcessing: Binding<Bool> = .constant(false),
        processingMessage: String = "Processing...",
        onDismiss: @escaping () -> Void,
        onSecondaryDismiss: (() -> Void)? = nil
    ) {
        self.style = style
        self.message = message
        self.buttonLabel = buttonLabel
        self.secondaryButtonLabel = secondaryButtonLabel
        self._isProcessing = isProcessing
        self.processingMessage = processingMessage
        self.onDismiss = onDismiss
        self.onSecondaryDismiss = onSecondaryDismiss
    }

    var body: some View {
        ZStack {
            // Blur background
            Color.clear
                .background(.ultraThinMaterial)
                .opacity(blurOpacity)
                .ignoresSafeArea()
                .onTapGesture { } // Prevent tap-through

            // Content container
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    // Animated completion circle - smooth transition from spinner to filled with icon
                    AnimatedCompletionCircle(
                        color: style.iconBackgroundColor,
                        iconName: style.iconName,
                        iconColor: style.iconForegroundColor,
                        isProcessing: isProcessing
                    )

                    Spacer()
                        .frame(height: 64)

                    // Message text - shows processing message or final message
                    Group {
                        if isProcessing {
                            Text(processingMessage)
                        } else {
                            Text(message)
                        }
                    }
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .animation(Motion.micro, value: isProcessing)

                    Spacer()
                        .frame(height: 32)

                    // Action button - disabled when processing (white 10% when muted, purple when active)
                    Button(action: {
                        if !isProcessing {
                            dismissWithAnimation()
                        }
                    }) {
                        Text(buttonLabel)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isProcessing ? .white.opacity(0.3) : .white)
                            .tracking(0.1)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(isProcessing ? Color.white.opacity(0.1) : Color(hex: "#6c47ff"))
                            .cornerRadius(8)
                            .animation(Motion.standard, value: isProcessing)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isProcessing)

                    // Optional secondary button (12px gap matches DialogOverlay button spacing)
                    if let secondaryLabel = secondaryButtonLabel {
                        Spacer().frame(height: 12)

                        Button(action: {
                            if !isProcessing {
                                dismissWithAnimation(secondary: true)
                            }
                        }) {
                            Text(secondaryLabel)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(isProcessing ? .white.opacity(0.15) : .white.opacity(0.5))
                                .tracking(0.1)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(isProcessing ? Color.clear : Color.white.opacity(0.1))
                                .cornerRadius(8)
                                .animation(Motion.standard, value: isProcessing)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isProcessing)
                    }
                }
                .padding(32)
                .background(Color.appBackground)
                .cornerRadius(16)
                .padding(.horizontal, 16)

                Spacer()
            }
            .opacity(contentOpacity)
            .scaleEffect(contentScale)
        }
        .onAppear {
            // Use single animation block to prevent curve conflicts
            ModalAnimations.animateContentAppear(
                scale: $contentScale,
                opacity: $contentOpacity,
                blurOpacity: $blurOpacity
            )
        }
    }

    private func dismissWithAnimation(secondary: Bool = false) {
        // Use single animation block to prevent curve conflicts
        ModalAnimations.animateContentDismiss(
            scale: $contentScale,
            opacity: $contentOpacity,
            blurOpacity: $blurOpacity,
            targetScale: 0.9
        ) {
            if secondary, let onSecondary = onSecondaryDismiss {
                onSecondary()
            } else {
                onDismiss()
            }
        }
    }
}

// MARK: - Preview

#Preview("Processing") {
    ZStack {
        // Background content to show blur effect
        VStack(spacing: 20) {
            ForEach(0..<10) { i in
                HStack {
                    Circle()
                        .fill(Color.purple.opacity(0.3))
                        .frame(width: 50, height: 50)
                    VStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 12)
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 100, height: 12)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.appBackground)

        ConfirmationOverlay(
            style: .success,
            message: AttributedString.safeMarkdown("**Young Professionals** has been successfully enrolled in **Ephesians** starting on **January 15, 2025**."),
            buttonLabel: "Done",
            isProcessing: .constant(true),
            processingMessage: "Processing enrollment",
            onDismiss: { print("Dismissed") }
        )
    }
}

#Preview("Success") {
    ZStack {
        // Background content to show blur effect
        VStack(spacing: 20) {
            ForEach(0..<10) { i in
                HStack {
                    Circle()
                        .fill(Color.purple.opacity(0.3))
                        .frame(width: 50, height: 50)
                    VStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 12)
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 100, height: 12)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
        .background(Color.appBackground)

        ConfirmationOverlay(
            style: .success,
            message: AttributedString.safeMarkdown("**Young Professionals** has been successfully enrolled in **Ephesians** starting on **January 15, 2025**."),
            buttonLabel: "Done",
            onDismiss: { print("Dismissed") }
        )
    }
}

#Preview("Error") {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        ConfirmationOverlay(
            style: .error,
            message: AttributedString.safeMarkdown("Unable to complete enrollment. Please try again."),
            buttonLabel: "OK",
            onDismiss: { print("Dismissed") }
        )
    }
}

#Preview("Warning") {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        ConfirmationOverlay(
            style: .warning,
            message: AttributedString.safeMarkdown("**3 members** have not accepted their invitations yet."),
            buttonLabel: "Got it",
            onDismiss: { print("Dismissed") }
        )
    }
}

#Preview("Info") {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        ConfirmationOverlay(
            style: .info,
            message: AttributedString.safeMarkdown("You can invite more members from the **Members** tab."),
            buttonLabel: "Continue",
            onDismiss: { print("Dismissed") }
        )
    }
}
