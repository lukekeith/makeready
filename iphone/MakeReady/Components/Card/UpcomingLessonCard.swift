//
//  UpcomingLessonCard.swift
//  MakeReady
//
//  Card showing the next upcoming lesson for a group enrollment.
//  Features: day indicator, program name, formatted date, activity icons, and cover image.
//

import SwiftUI

struct UpcomingLessonCard: View {
    let schedule: LessonSchedule
    let programName: String
    let coverImageUrl: String?
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 12) {
                // Left section: Day indicator
                dayIndicator

                // Center section: Program name, date, activity icons
                centerContent

                Spacer(minLength: 0)

                // Right section: Cover image
                coverImage
            }
            .padding(16)
            .frame(height: 106)
            .background(Color.cardBackground)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Day Indicator

    private var dayIndicator: some View {
        VStack(spacing: 2) {
            Text("DAY")
                .font(Typography.s12)
                .foregroundColor(Color.brandPrimary)
                .tracking(0.1)

            Text("\(schedule.lesson.dayNumber)")
                .font(Typography.s22)
                .foregroundColor(.white)
                .tracking(-0.1)
        }
        .frame(width: 44)
    }

    // MARK: - Center Content

    private var centerContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Program name
            Text(programName)
                .font(Typography.s15Bold)
                .foregroundColor(.white)
                .lineLimit(1)

            // Formatted date
            Text(formattedDate)
                .font(Typography.s12)
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)

            // Activity icons
            activityIcons
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formattedDate: String {
        DateFormatters.weekdayMonthDayYear.string(from: schedule.scheduledDate)
    }

    // MARK: - Activity Icons

    private var activityIcons: some View {
        HStack(spacing: 8) {
            ForEach(schedule.lesson.activities.prefix(4)) { activity in
                activityIconBox(for: activity)
            }
        }
    }

    private func activityIconBox(for activity: ScheduledActivity) -> some View {
        let brandColor = ActivityStyle.color(forRawType: activity.type)
        let isReady = activity.isConfigured

        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(isReady ? Color.white.opacity(0.1) : brandColor.opacity(0.2))
                .frame(width: 32, height: 32)

            activityIconImage(for: activity.type, size: 14)
                .foregroundColor(isReady ? .white.opacity(0.5) : brandColor)
                .frame(width: 24, height: 24)
        }
    }

    @ViewBuilder
    private func activityIconImage(for type: String, size: CGFloat) -> some View {
        let name = ActivityStyle.icon(forRawType: type)
        if name.hasPrefix("Icon") {
            Image(name)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: name)
                .font(.system(size: size))
        }
    }

    // MARK: - Cover Image

    @ViewBuilder
    private var coverImage: some View {
        if let imageUrl = coverImageUrl, !imageUrl.isEmpty {
            CachedCardImage(
                url: imageUrl.mediumImageUrl,
                fallbackUrl: imageUrl,
                width: 72,
                height: 74,
                fallback: { coverImagePlaceholder }
            )
        } else {
            coverImagePlaceholder
        }
    }

    private var coverImagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.iconContainerBackground)
            .frame(width: 72, height: 74)
            .overlay(
                Image(systemName: "book.fill")
                    .font(Typography.s24)
                    .foregroundColor(.white.opacity(0.5))
            )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 16) {
            // "NEXT LESSON" label
            HStack {
                Text("NEXT LESSON")
                    .font(Typography.s15Bold)
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.horizontal, 16)

            // Card with cover image
            UpcomingLessonCard(
                schedule: LessonSchedule(
                    id: "1",
                    enrollmentId: "e1",
                    lessonId: "l1",
                    scheduledDate: Date().addingTimeInterval(2 * 24 * 60 * 60), // 2 days from now
                    isCompleted: nil,
                    completedAt: nil,
                    lesson: LessonWithActivities(
                        id: "l1",
                        studyProgramId: "p1",
                        dayNumber: 5,
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
                            ),
                            ScheduledActivity(
                                id: "a2",
                                lessonId: "l1",
                                type: "VIDEO",
                                passageReference: nil,
                                passageText: nil,
                                videoId: "v1",
                                prayerPrompt: nil,
                                notes: nil,
                                orderNumber: 2
                            ),
                            ScheduledActivity(
                                id: "a3",
                                lessonId: "l1",
                                type: "PRAYER",
                                passageReference: nil,
                                passageText: nil,
                                videoId: nil,
                                prayerPrompt: "Pray for wisdom",
                                notes: nil,
                                orderNumber: 3
                            )
                        ]
                    )
                ),
                programName: "Foundation",
                coverImageUrl: "https://images.unsplash.com/photo-1504052434569-70ad5836ab65?w=600"
            ) {
                print("Tapped upcoming lesson")
            }
            .padding(.horizontal, 16)

            // Card without cover image
            UpcomingLessonCard(
                schedule: LessonSchedule(
                    id: "2",
                    enrollmentId: "e1",
                    lessonId: "l2",
                    scheduledDate: Date().addingTimeInterval(7 * 24 * 60 * 60), // 7 days from now
                    isCompleted: nil,
                    completedAt: nil,
                    lesson: LessonWithActivities(
                        id: "l2",
                        studyProgramId: "p1",
                        dayNumber: 12,
                        createdAt: Date(),
                        updatedAt: Date(),
                        activities: [
                            ScheduledActivity(
                                id: "a4",
                                lessonId: "l2",
                                type: "SOAP",
                                passageReference: "Romans 8:28",
                                passageText: nil,
                                videoId: nil,
                                prayerPrompt: nil,
                                notes: nil,
                                orderNumber: 1
                            )
                        ]
                    )
                ),
                programName: "Romans Deep Dive Study",
                coverImageUrl: nil
            ) {
                print("Tapped upcoming lesson 2")
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.top, 20)
    }
}
