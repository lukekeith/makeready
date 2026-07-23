//
//  EnrollmentActionMenu.swift
//  MakeReady
//
//  Action menu shown when a leader taps an enrollment (monday#12270302158).
//  Two modes, keyed off whether the current leader can manage this enrollment:
//
//  • canManage → "Edit lessons" (the schedule editor) + "Edit enrollment"
//    (the edit flow) — the original two-action menu.
//  • !canManage → an FYI note explaining the study was made by another leader
//    and can't be edited here (naming them when known), plus "Preview study"
//    which opens the read-only web study preview. Any group leader in the org
//    may preview any org study, so this is always available.
//
//  Shares LessonActionMenu's row style + slide-up chrome; presented via
//  overlayManager.present(.enrollmentActionMenu).
//

import SwiftUI

struct EnrollmentActionMenu: View {
    let studyName: String
    /// Whether the current leader can edit this enrollment (server `canManage`,
    /// with the managed-groups fallback applied at the call site). Drives which
    /// of the two menu modes is shown.
    let canManage: Bool
    /// Name of the leader who created the study — shown in the FYI note when the
    /// current leader can't manage it. nil ⇒ a generic "another leader" message.
    var creatorName: String?
    let onEditLessons: () -> Void
    let onEditEnrollment: () -> Void
    /// Open the read-only study preview (any org leader may preview any org study).
    let onPreviewStudy: () -> Void

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

            if canManage {
                managedActions
            } else {
                unmanagedActions
            }

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

    // MARK: - Managed: edit actions

    private var managedActions: some View {
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

            // Preview the study read-only — available even for studies this
            // leader created, so they can see the member-facing render.
            LessonActionMenuItem(
                icon: "eye",
                title: "Preview study",
                style: .normal
            ) {
                overlayManager.dismiss(.enrollmentActionMenu)
                onPreviewStudy()
            }
        }
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }

    // MARK: - Unmanaged: FYI note + preview

    private var unmanagedActions: some View {
        VStack(spacing: 12) {
            // FYI — this study belongs to another leader and can't be edited here.
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(Typography.s18)
                    .foregroundColor(Color.brandPrimary)
                Text(fyiMessage)
                    .font(Typography.s14)
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)

            LessonActionMenuItem(
                icon: "eye",
                title: "Preview study",
                style: .normal
            ) {
                overlayManager.dismiss(.enrollmentActionMenu)
                onPreviewStudy()
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
        }
        .padding(.horizontal, 16)
    }

    private var fyiMessage: String {
        if let creatorName, !creatorName.isEmpty {
            return "This study was created by \(creatorName) and can only be edited by them. Contact \(creatorName) if changes are needed."
        }
        return "This study was created by another leader in your organization and can only be edited by them. Contact that leader if changes are needed."
    }
}

// MARK: - Study preview presentation

/// Read-only web study preview. Any group leader in the org may preview any org
/// study; `LessonPreviewWebView` mints the org-scoped preview token itself, so
/// the caller only needs the program id.
enum StudyPreview {
    static func url(programId: String) -> URL? {
        URL(string: "\(Configuration.clientBaseURL)/preview/study/\(programId)")
    }
}

extension View {
    /// Present the in-app study preview (WKWebView) as a full-screen cover when
    /// `item` is non-nil. `fullScreenCover` is the sanctioned presentation for
    /// previews (WebView content), mirroring ProgramHomePage's study preview.
    func studyPreviewCover(item: Binding<IdentifiableURL?>) -> some View {
        fullScreenCover(item: item) { presented in
            LessonPreviewModal(url: presented.url, isPresented: Binding(
                get: { item.wrappedValue != nil },
                set: { if !$0 { item.wrappedValue = nil } }
            ))
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 24) {
            // Managed — the two edit actions
            EnrollmentActionMenu(
                studyName: "Struggle Well",
                canManage: true,
                onEditLessons: {},
                onEditEnrollment: {},
                onPreviewStudy: {}
            )
            .background(Color.cardBackground)
            .clipShape(RoundedCornersShape(corners: [.topLeft, .topRight], radius: 16))

            // Unmanaged — FYI + preview
            EnrollmentActionMenu(
                studyName: "Struggle Well",
                canManage: false,
                creatorName: "Sarah Chen",
                onEditLessons: {},
                onEditEnrollment: {},
                onPreviewStudy: {}
            )
            .background(Color.cardBackground)
            .clipShape(RoundedCornersShape(corners: [.topLeft, .topRight], radius: 16))
        }
    }
}
