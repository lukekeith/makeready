//
//  EnrollmentActionMenu.swift
//  MakeReady
//
//  Two-item action menu shown when a leader taps an enrollment
//  (monday#12270302158): "Edit lessons" (the existing schedule editor) and
//  "Edit enrollment" (the edit flow). Same slide-up menu chrome + row style as
//  LessonActionMenu — presented via overlayManager.present(.enrollmentActionMenu)
//  — but purpose-built for the enrollment context (no single-lesson header,
//  no Open/Share/Delete). Kept as a sibling so LessonActionMenu's other
//  callers are untouched.
//

import SwiftUI

struct EnrollmentActionMenu: View {
    let studyName: String
    let onEditLessons: () -> Void
    let onEditEnrollment: () -> Void

    @Environment(\.dismissOverlay) private var dismissOverlay
    @Environment(OverlayManager.self) private var overlayManager

    var body: some View {
        VStack(spacing: 0) {
            // Header — which study this enrollment is for
            VStack(spacing: 4) {
                Text(studyName)
                    .font(Typography.s17Bold)
                    .foregroundColor(.white)
            }
            .padding(.vertical, 16)

            VStack(spacing: 0) {
                LessonActionMenuItem(
                    icon: "list.bullet",
                    title: "Edit lessons",
                    style: .normal
                ) {
                    // Dismiss instantly (no animation) so it doesn't flicker
                    // above the incoming screen.
                    overlayManager.dismiss(.enrollmentActionMenu)
                    onEditLessons()
                }

                LessonActionMenuItem(
                    icon: "slider.horizontal.3",
                    title: "Edit enrollment",
                    style: .normal
                ) {
                    overlayManager.dismiss(.enrollmentActionMenu)
                    onEditEnrollment()
                }
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal, 16)

            Button(action: { dismissOverlay?() }) {
                Image(systemName: "xmark")
                    .font(Typography.s20Medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack {
            Spacer()
            EnrollmentActionMenu(
                studyName: "Struggle Well",
                onEditLessons: {},
                onEditEnrollment: {}
            )
            .background(Color.cardBackground)
            .clipShape(RoundedCornersShape(corners: [.topLeft, .topRight], radius: 16))
        }
    }
}
