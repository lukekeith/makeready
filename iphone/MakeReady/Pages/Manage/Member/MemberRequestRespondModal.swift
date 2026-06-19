//
//  MemberRequestRespondModal.swift
//  MakeReady
//
//  Full-screen, fade-in modal for responding to a member's request to join a
//  group. Presented via `overlayManager.present(.memberRequestRespond)` with
//  `.raw` chrome + `.topLevel` priority, so this view owns its own background
//  and animation (it fades in and fills the screen — it does NOT slide up like
//  a sheet). Pattern mirrors ConfirmationOverlay.
//

import SwiftUI

struct MemberRequestRespondModal: View {
    let memberName: String
    let groupName: String
    let requestDate: Date

    /// Each callback is responsible for dismissing the overlay (the parent owns
    /// the OverlayManager) and performing the work. The buttons animate the
    /// content out first, then invoke the callback.
    let onApprove: () -> Void
    let onReject: () -> Void
    let onCancel: () -> Void

    // Fade-in animation state (matches ConfirmationOverlay)
    @State private var contentOpacity: Double = 0
    @State private var contentScale: CGFloat = 0.9
    @State private var backgroundOpacity: Double = 0

    var body: some View {
        ZStack {
            // Full-screen fill that fades in (not a slide-up sheet).
            Color.appBackground
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture { } // Swallow taps — dismissal is via Cancel only.

            // Centered content, 32px padding all around.
            VStack(spacing: 32) {
                titleView

                VStack(spacing: 8) {
                    primaryButton(label: "Approve") { dismissThen(onApprove) }
                    secondaryButton(label: "Reject") { dismissThen(onReject) }
                    mutedButton(label: "Cancel") { dismissThen(onCancel) }
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity)
            .opacity(contentOpacity)
            .scaleEffect(contentScale)
        }
        .onAppear {
            ModalAnimations.animateContentAppear(
                scale: $contentScale,
                opacity: $contentOpacity,
                blurOpacity: $backgroundOpacity
            )
        }
    }

    // MARK: - Title

    private var titleView: some View {
        VStack(spacing: 8) {
            Text(memberName)
                .font(Typography.s24Bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(requestSentence)
                .font(Typography.s17)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var requestSentence: String {
        let date = DateFormatters.fullMonthDayYear.string(from: requestDate)
        let time = DateFormatters.time12Hour.string(from: requestDate)
        return "has submitted a request to join \(groupName) on \(date) at \(time)."
    }

    // MARK: - Buttons (full-width, 48px tall — matches ConfirmationOverlay)

    private func primaryButton(label: String, action: @escaping () -> Void) -> some View {
        responseButton(
            label: label,
            textColor: .white,
            background: Color.brandPrimary,
            action: action
        )
    }

    private func secondaryButton(label: String, action: @escaping () -> Void) -> some View {
        responseButton(
            label: label,
            textColor: .white,
            background: Color.white.opacity(0.1),
            action: action
        )
    }

    private func mutedButton(label: String, action: @escaping () -> Void) -> some View {
        responseButton(
            label: label,
            textColor: .white.opacity(0.5),
            background: Color.white.opacity(0.05),
            action: action
        )
    }

    private func responseButton(
        label: String,
        textColor: Color,
        background: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(Typography.s12Bold)
                .foregroundColor(textColor)
                .tracking(0.1)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(background)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Dismissal

    /// Animate the content out (fade + scale), then run the parent callback,
    /// which removes the overlay from the stack and performs the action.
    private func dismissThen(_ completion: @escaping () -> Void) {
        ModalAnimations.animateContentDismiss(
            scale: $contentScale,
            opacity: $contentOpacity,
            blurOpacity: $backgroundOpacity,
            targetScale: 0.9
        ) {
            completion()
        }
    }
}

#Preview {
    ZStack {
        // Background content to show the fade-in fill over the app.
        VStack(spacing: 16) {
            ForEach(0..<8, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 56)
            }
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.appBackground)

        MemberRequestRespondModal(
            memberName: "John Smith",
            groupName: "Young Professionals",
            requestDate: Date(timeIntervalSince1970: 1_750_000_000),
            onApprove: {},
            onReject: {},
            onCancel: {}
        )
    }
}
