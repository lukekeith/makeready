//
//  LessonActionMenu.swift
//  MakeReady
//
//  Action menu for lesson cards - presented via overlayManager.presentMenu()
//  ManagedMenuView provides: dark overlay, slide-up animation, swipe-to-dismiss
//

import SwiftUI

struct LessonActionMenu: View {
    let schedule: LessonSchedule
    let studyName: String
    let enrollmentId: String
    let onEditActivities: () -> Void
    let onOpenLesson: () -> Void
    let onShareLesson: () -> Void
    var onAddLesson: (() -> Void)? = nil
    var onEditEnrollment: (() -> Void)? = nil
    let onDelete: () -> Void

    @Environment(\.dismissOverlay) private var dismissOverlay
    @Environment(OverlayManager.self) private var overlayManager

    var body: some View {
        VStack(spacing: 0) {
            // Header with lesson info
            VStack(spacing: 4) {
                Text(studyName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                Text("Day \(schedule.lesson.dayNumber) - \(formattedDate)")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 16)

            // Action buttons
            VStack(spacing: 0) {
                LessonActionMenuItem(
                    icon: "pencil.line",
                    title: "Edit Activities",
                    style: .normal
                ) {
                    // Dismiss instantly (no animation) to avoid flickering above the incoming modal
                    overlayManager.dismiss(id: OverlayID.lessonActionMenu)
                    onEditActivities()
                }

                if let onEditEnrollment {
                    LessonActionMenuItem(
                        icon: "slider.horizontal.3",
                        title: "Edit Enrollment",
                        style: .normal
                    ) {
                        overlayManager.dismiss(id: OverlayID.lessonActionMenu)
                        onEditEnrollment()
                    }
                }

                LessonActionMenuItem(
                    icon: "safari",
                    title: "Open Lesson",
                    style: .normal
                ) {
                    dismissMenu()
                    onOpenLesson()
                }

                LessonActionMenuItem(
                    icon: "square.and.arrow.up",
                    title: "Share Lesson",
                    style: .normal
                ) {
                    dismissMenu()
                    onShareLesson()
                }

                if let onAddLesson {
                    LessonActionMenuItem(
                        icon: "plus",
                        title: "Add Lesson",
                        style: .normal
                    ) {
                        dismissMenu()
                        onAddLesson()
                    }
                }

                LessonActionMenuItem(
                    icon: "trash",
                    title: "Delete",
                    style: .destructive
                ) {
                    dismissMenu()
                    onDelete()
                }
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal, 16)

            // Close button
            Button(action: {
                dismissMenu()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: schedule.scheduledDate)
    }

    private func dismissMenu() {
        dismissOverlay?()
    }
}

// MARK: - Menu Item

enum LessonActionMenuItemStyle {
    case normal
    case destructive
}

struct LessonActionMenuItem: View {
    let icon: String
    let title: String
    let style: LessonActionMenuItemStyle
    let action: () -> Void

    private var iconColor: Color {
        switch style {
        case .normal:
            return Color(hex: "#6c47ff")
        case .destructive:
            return Color(hex: "#ff4444")
        }
    }

    private var textColor: Color {
        switch style {
        case .normal:
            return .white
        case .destructive:
            return Color(hex: "#ff4444")
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(iconColor)
                    .frame(width: 24, height: 24)

                // Title
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(textColor)

                Spacer()
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack {
            Spacer()
            LessonActionMenu(
                schedule: LessonSchedule(
                    id: "1",
                    enrollmentId: "e1",
                    lessonId: "l1",
                    scheduledDate: Date(),
                    isCompleted: nil,
                    completedAt: nil,
                    lesson: LessonWithActivities(
                        id: "l1",
                        studyProgramId: "p1",
                        dayNumber: 5,
                        createdAt: Date(),
                        updatedAt: Date(),
                        activities: []
                    )
                ),
                studyName: "Foundation Study",
                enrollmentId: "e1",
                onEditActivities: { print("Edit Activities") },
                onOpenLesson: { print("Open") },
                onShareLesson: { print("Share") },
                onAddLesson: { print("Add Lesson") },
                onDelete: { print("Delete") }
            )
            .background(Color(hex: "#252936"))
            .clipShape(RoundedCornersShape(corners: [.topLeft, .topRight], radius: 16))
        }
    }
}
