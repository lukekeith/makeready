//
//  ScheduledLessonCard.swift
//  MakeReady
//
//  Lesson card for enrollment schedules showing MM/DD format instead of day number.
//  Displays scheduled date with activities list.
//

import SwiftUI

struct ScheduledLessonCard: View {
    let schedule: LessonSchedule
    var onTap: (() -> Void)?

    /// Whether this lesson is in the completed state (completed or in the past)
    private var isCompleted: Bool {
        // Check if explicitly marked completed, or if the scheduled date is in the past
        if schedule.isCompleted == true {
            return true
        }
        // Consider lessons with past dates as completed
        return schedule.scheduledDate < Date()
    }

    private var backgroundColor: Color {
        if isCompleted {
            return Color(hex: "#103E34")  // Green completed background
        }
        // Purple if no configured activities, default/dark if has configured activities
        return schedule.lesson.hasConfiguredActivities ? Color.cardBackground : Color.backgroundPurple
    }

    /// Accent color - green for completed, purple for active
    private var accentColor: Color {
        isCompleted ? Color.success : Color.brandPrimary
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 8) {
                // Left section: Date indicator (MM/DD)
                dateIndicator

                // Center section: Activities
                centerContent

                // Right section: Chevron
                chevron
            }
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(backgroundColor)
            .cornerRadius(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date Indicator

    private var dateIndicator: some View {
        VStack(spacing: 0) {
            Text(schedule.monthAbbrev)
                .font(Typography.s12)
                .foregroundColor(accentColor)
                .tracking(0.1)

            Text(schedule.dayOfMonth)
                .font(Typography.s22)
                .foregroundColor(.white)
                .tracking(-0.1)
        }
        .padding(16)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Center Content

    @ViewBuilder
    private var centerContent: some View {
        if schedule.lesson.activities.isEmpty {
            // No activities
            HStack {
                Spacer()
                Text("No activities")
                    .font(Typography.s12)
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(0.1)
            }
        } else {
            // Show activities list
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(schedule.lesson.activities.prefix(3))) { activity in
                    activityRow(activity)
                }

                // If more than 3 activities, show count
                if schedule.lesson.activities.count > 3 {
                    Text("+\(schedule.lesson.activities.count - 3) more")
                        .font(Typography.s11)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func activityRow(_ activity: ScheduledActivity) -> some View {
        HStack(spacing: 6) {
            // Activity icon - checkmark for completed, type icon for active
            Image(systemName: isCompleted ? "checkmark" : ActivityStyle.icon(forRawType: activity.type))
                .font(Typography.s12)
                .foregroundColor(isCompleted ? .white : ActivityStyle.color(forRawType: activity.type))
                .frame(width: 14, height: 14)

            // Activity type
            Text(activity.title ?? activityTypeLabel(for: activity.type))
                .font(Typography.s11Semibold)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.1)

            // Activity title/reference
            if let title = activity.title, !title.isEmpty {
                Text(title)
                    .font(Typography.s12)
                    .foregroundColor(.white)
                    .lineLimit(1)
            } else if let reference = activity.passageReference {
                Text(reference)
                    .font(Typography.s12)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
    }

    private func activityTypeLabel(for type: String) -> String {
        switch type {
        case "SCRIPTURE":
            return "Read"
        case "SOAP":
            return "SOAP"
        case "VIDEO":
            return "Video"
        case "PRAYER":
            return "Pray"
        case "REFLECTION":
            return "Review"
        default:
            return type
        }
    }

    // MARK: - Chevron

    private var chevron: some View {
        VStack(spacing: 0) {
            Image(systemName: "chevron.right")
                .font(Typography.s14)
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 20, height: 20)
        }
        .padding(8)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 16) {
            // Future lesson with scripture activity
            ScheduledLessonCard(
                schedule: LessonSchedule(
                    id: "1",
                    enrollmentId: "e1",
                    lessonId: "l1",
                    scheduledDate: Date().addingTimeInterval(7 * 24 * 60 * 60), // 7 days from now
                    isCompleted: nil,
                    completedAt: nil,
                    lesson: LessonWithActivities(
                        id: "l1",
                        studyProgramId: "p1",
                        dayNumber: 1,
                        createdAt: Date(),
                        updatedAt: Date(),
                        activities: [
                            ScheduledActivity(
                                id: "a1",
                                lessonId: "l1",
                                type: "SCRIPTURE",
                                passageReference: "Genesis 1:1-5",
                                passageText: nil,
                                videoId: nil,
                                prayerPrompt: nil,
                                notes: nil,
                                orderNumber: 1
                            )
                        ]
                    )
                )
            ) {
                print("Tapped lesson 1")
            }

            // Today's lesson with multiple activities
            ScheduledLessonCard(
                schedule: LessonSchedule(
                    id: "2",
                    enrollmentId: "e1",
                    lessonId: "l2",
                    scheduledDate: Date(),
                    isCompleted: nil,
                    completedAt: nil,
                    lesson: LessonWithActivities(
                        id: "l2",
                        studyProgramId: "p1",
                        dayNumber: 2,
                        createdAt: Date(),
                        updatedAt: Date(),
                        activities: [
                            ScheduledActivity(
                                id: "a2",
                                lessonId: "l2",
                                type: "SCRIPTURE",
                                passageReference: "Genesis 1:6-13",
                                passageText: nil,
                                videoId: nil,
                                prayerPrompt: nil,
                                notes: nil,
                                orderNumber: 1
                            ),
                            ScheduledActivity(
                                id: "a3",
                                lessonId: "l2",
                                type: "VIDEO",
                                passageReference: nil,
                                passageText: nil,
                                videoId: "v1",
                                prayerPrompt: nil,
                                notes: nil,
                                orderNumber: 2
                            )
                        ]
                    )
                )
            ) {
                print("Tapped lesson 2")
            }

            // Completed past lesson (green background, checkmarks)
            ScheduledLessonCard(
                schedule: LessonSchedule(
                    id: "3",
                    enrollmentId: "e1",
                    lessonId: "l3",
                    scheduledDate: Date().addingTimeInterval(-7 * 24 * 60 * 60), // 7 days ago
                    isCompleted: true,
                    completedAt: Date().addingTimeInterval(-6 * 24 * 60 * 60),
                    lesson: LessonWithActivities(
                        id: "l3",
                        studyProgramId: "p1",
                        dayNumber: 1,
                        createdAt: Date(),
                        updatedAt: Date(),
                        activities: [
                            ScheduledActivity(
                                id: "a4",
                                lessonId: "l3",
                                type: "SOAP",
                                passageReference: "Romans 1:1-2",
                                passageText: nil,
                                videoId: nil,
                                prayerPrompt: nil,
                                notes: nil,
                                orderNumber: 1
                            ),
                            ScheduledActivity(
                                id: "a5",
                                lessonId: "l3",
                                type: "VIDEO",
                                passageReference: nil,
                                passageText: nil,
                                videoId: "v1",
                                prayerPrompt: nil,
                                notes: nil,
                                orderNumber: 2
                            ),
                            ScheduledActivity(
                                id: "a6",
                                lessonId: "l3",
                                type: "REFLECTION",
                                passageReference: nil,
                                passageText: nil,
                                videoId: nil,
                                prayerPrompt: nil,
                                notes: "Daily reflection",
                                orderNumber: 3
                            )
                        ]
                    )
                )
            ) {
                print("Tapped completed lesson")
            }
        }
        .padding(20)
    }
}
