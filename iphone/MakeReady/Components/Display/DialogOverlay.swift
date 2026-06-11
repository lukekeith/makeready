//
//  DialogOverlay.swift
//  MakeReady
//
//  Reusable centered dialog with blurred overlay and configurable buttons.
//  Any view can present this dialog with custom button labels and styles.
//

import SwiftUI

// MARK: - Button Configuration

enum DialogButtonStyle {
    /// Purple background, white text (brand primary)
    case primary
    /// White 10% background, muted text
    case secondary
}

struct DialogButtonConfig {
    let label: String
    let style: DialogButtonStyle
    let action: () -> Void

    init(_ label: String, style: DialogButtonStyle = .primary, action: @escaping () -> Void) {
        self.label = label
        self.style = style
        self.action = action
    }
}

// MARK: - Dialog Overlay

struct DialogOverlay: View {
    @Binding var isPresented: Bool
    var title: String? = nil
    var message: String? = nil
    let buttons: [DialogButtonConfig]

    @State private var visible = false

    var body: some View {
        if isPresented {
            ZStack {
                // Blurred dark background
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                    Color.black.opacity(0.5)
                }
                .opacity(visible ? 1 : 0)
                .onTapGesture { dismiss() }

                // Content stack
                VStack(spacing: 20) {
                    if title != nil || message != nil {
                        VStack(spacing: 8) {
                            if let title {
                                Text(title)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            }
                            if let message {
                                Text(message)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }

                    VStack(spacing: 12) {
                        ForEach(Array(buttons.enumerated()), id: \.offset) { _, button in
                            Button {
                                dismiss()
                                button.action()
                            } label: {
                                Text(button.label)
                                    .font(.system(size: 15, weight: button.style == .primary ? .semibold : .regular))
                                    .foregroundColor(button.style == .primary ? .white : .white.opacity(0.5))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(
                                        button.style == .primary
                                            ? Color(hex: "#6c47ff")
                                            : Color.white.opacity(0.1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 40)
                .scaleEffect(visible ? 1 : 0.85)
                .opacity(visible ? 1 : 0)
            }
            .onAppear {
                withAnimation(Motion.settle) {
                    visible = true
                }
            }
        }
    }

    private func dismiss() {
        withAnimation(Motion.exitFast) {
            visible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isPresented = false
        }
    }
}

// MARK: - Previews

#Preview("Call Dialog") {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        Text("Background content")
            .foregroundColor(.white)

        DialogOverlay(isPresented: .constant(true), buttons: [
            DialogButtonConfig("Call: 213.862.3686", style: .primary) {},
            DialogButtonConfig("Cancel", style: .secondary) {}
        ])
    }
}

#Preview("Multiple Actions") {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        Text("Background content")
            .foregroundColor(.white)

        DialogOverlay(isPresented: .constant(true), buttons: [
            DialogButtonConfig("Call: 213.862.3686", style: .primary) {},
            DialogButtonConfig("Text: 213.862.3686", style: .primary) {},
            DialogButtonConfig("Cancel", style: .secondary) {}
        ])
    }
}
