//
//  CardLesson.swift
//  MakeReady
//
//  Lesson card component with day indicator and multiple display modes
//

import SwiftUI

struct CardLesson: View {
    let data: CardLessonData
    let onTap: (() -> Void)?
    let showAnimatedBorder: Bool
    let randomizeBorderStart: Bool
    let cornerRadius: CGFloat

    @State private var borderRotation: Double = 0
    @State private var hasStartedAnimation = false

    init(data: CardLessonData, onTap: (() -> Void)? = nil, showAnimatedBorder: Bool = false, randomizeBorderStart: Bool = true, cornerRadius: CGFloat = 4) {
        self.data = data
        self.onTap = onTap
        self.showAnimatedBorder = showAnimatedBorder
        self.randomizeBorderStart = randomizeBorderStart
        self.cornerRadius = cornerRadius
    }

    private var hasIncompleteActivities: Bool {
        data.activities.contains {
            if case .incomplete = $0.status { return true }
            return false
        }
    }

    var body: some View {
        Button {
            if let directOnTap = onTap {
                directOnTap()
            } else {
                data.onTap?()
            }
        } label: {
            switch data.mode {
            case .planning:
                planningContent
            case .lesson:
                lessonContent
            case .progress:
                progressContent
            case .lessonList:
                lessonListContent
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Planning Mode (existing behavior)

    private var planningBackgroundColor: Color {
        let isReady = !data.activities.isEmpty && data.activities.allSatisfy { $0.isConfigured }
        return isReady ? Color.cardBackground : Color.backgroundPurple
    }

    private var planningContent: some View {
        HStack(spacing: 8) {
            dayIndicator(labelColor: Color.brandPrimary, stretch: true)

            // Center section: Activities or "Select activities"
            if data.activities.isEmpty {
                HStack {
                    Spacer()
                    Text("Select activities")
                        .font(Typography.s12)
                        .foregroundColor(Color.brandPrimary)
                        .tracking(0.1)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(data.activities) { activity in
                        LessonActivity(data: activity, style: activity.isConfigured ? .default : .select)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Right section: Chevron
            VStack(spacing: 0) {
                Image(systemName: "chevron.right")
                    .font(Typography.s14)
                    .foregroundColor(.white50)
                    .frame(width: 20, height: 20)
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .background(planningBackgroundColor)
        .cornerRadius(8)
        .contentShape(Rectangle())
    }

    // MARK: - Lesson Mode

    private var lessonBackgroundColor: Color {
        let hasIncomplete = data.activities.contains {
            if case .incomplete = $0.status { return true }
            return false
        }
        // Released lessons (date today/past) take the brand background. The
        // legacy incomplete-activity check is preserved for non-enrollment cards.
        let highlight = data.isReleased || hasIncomplete
        if showAnimatedBorder || !highlight {
            return Color.cardBackground
        }
        return Color.backgroundPurple
    }

    private var lessonContent: some View {
        HStack(spacing: 0) {
            dayIndicator(labelColor: Color.brandPrimary)
                .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
                if let title = data.title {
                    Text(title)
                        .font(Typography.s15Bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                if let date = data.date {
                    Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year()))
                        .font(Typography.s12)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                if !data.activities.isEmpty {
                    lessonActivityIcons
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            .padding(.trailing, 16)
        }
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                lessonBackgroundColor

                if data.coverImageUrl != nil {
                    CachedBackgroundImage(
                        url: data.coverImageUrl?.thumbImageUrl,
                        fallbackUrl: data.coverImageUrl
                    )
                    .opacity(0.1)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            Group {
                if showAnimatedBorder && hasIncompleteActivities {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color.brandPrimary,
                                    Color.brandPrimary.opacity(0.2),
                                    Color.brandPrimary
                                ]),
                                center: .center,
                                angle: .degrees(borderRotation)
                            ),
                            lineWidth: 2
                        )
                }
            }
        )
        .onAppear {
            if showAnimatedBorder && hasIncompleteActivities && !hasStartedAnimation {
                let startOffset = randomizeBorderStart ? Double.random(in: 0..<360) : 0
                borderRotation = startOffset
                hasStartedAnimation = true
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    borderRotation = startOffset + 360
                }
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Progress Mode

    private var progressContent: some View {
        HStack(spacing: 0) {
            dayIndicator(labelColor: Color.brandPrimary)
                .frame(width: 60)

            VStack(alignment: .leading, spacing: 16) {
                // Title + description
                VStack(alignment: .leading, spacing: 4) {
                    if let title = data.title {
                        Text(title)
                            .font(Typography.s15Bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }

                    if let description = data.description {
                        Text(description)
                            .font(Typography.s12)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                }

                // Progress bar
                if let progress = data.progress {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white)
                                .frame(width: geometry.size.width * min(max(progress, 0), 1), height: 4)
                                .animation(Motion.standard, value: progress)
                        }
                    }
                    .frame(height: 4)
                }

                // Sections list
                if let sections = data.sections, !sections.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(sections) { section in
                            sectionRow(section)
                        }
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.trailing, 16)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(Color(red: 37/255, green: 41/255, blue: 54/255).opacity(0.9))
        .cornerRadius(cornerRadius)
        .contentShape(Rectangle())
    }

    private func sectionRow(_ section: SectionProgress) -> some View {
        HStack(spacing: 10) {
            // Circle indicator
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    .frame(width: 20, height: 20)

                if section.completedAt != nil {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)

                    Image(systemName: "checkmark")
                        .font(Typography.s10Bold)
                        .foregroundColor(Color.cardBackground)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(section.name)
                    .font(Typography.s15)
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let completedAt = section.completedAt {
                    Text(completedAt.formatted(.dateTime.month(.abbreviated).day().year().hour().minute()))
                        .font(Typography.s12)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
    }

    // MARK: - LessonList Mode

    private var lessonListDayLabelColor: Color {
        guard let status = data.status else { return Color.brandPrimary }
        switch status {
        case .complete:
            return .white.opacity(0.5)
        case .next, .upcoming:
            return Color.brandPrimary
        }
    }

    private var lessonListBackgroundColor: Color {
        guard let status = data.status else { return Color(red: 37/255, green: 41/255, blue: 54/255).opacity(0.9) }
        switch status {
        case .complete:
            return Color.white.opacity(0.1)
        case .next, .upcoming:
            return Color(red: 37/255, green: 41/255, blue: 54/255).opacity(0.9)
        }
    }

    private var lessonListContent: some View {
        HStack(spacing: 0) {
            dayIndicator(labelColor: lessonListDayLabelColor)
                .frame(width: 60)

            VStack(alignment: .leading, spacing: 8) {
                // Status badge
                if let status = data.status {
                    statusBadge(status)
                }

                // Title
                if let title = data.title {
                    Text(title)
                        .font(Typography.s15Bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 16)
            .padding(.trailing, 16)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(lessonListBackgroundColor)
        .cornerRadius(cornerRadius)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func statusBadge(_ status: CardLessonStatus) -> some View {
        switch status {
        case .complete:
            Text("COMPLETE")
                .font(Typography.s10Bold)
                .foregroundColor(.white.opacity(0.5))
                .tracking(0.5)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)

        case .next:
            Text("NEXT")
                .font(Typography.s10Bold)
                .foregroundColor(.white)
                .tracking(0.5)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.brandPrimary)
                .cornerRadius(4)

        case .upcoming(let text):
            Text(text.uppercased())
                .font(Typography.s10Bold)
                .foregroundColor(.white.opacity(0.5))
                .tracking(0.5)
        }
    }

    // MARK: - Lesson Activity Icons (max 5 + overflow counter)

    /// Shows up to 5 activity icons at a fixed 32px size in a single row.
    /// If there are more than 5 activities, a "+N" label appears after the
    /// last visible icon. Time estimate is shown on the right side.
    private var lessonActivityIcons: some View {
        let maxVisible = 5
        let visible = Array(data.activities.prefix(maxVisible))
        let overflow = data.activities.count - maxVisible

        return HStack(spacing: 4) {
            ForEach(visible) { activity in
                activityIcon(activity, size: 32)
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(Typography.s12Semibold)
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }
            Spacer()
            Text(formattedEstimate(data.estimatedMinutes ?? 0))
                .font(Typography.s12)
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private func formattedEstimate(_ minutes: Int) -> String {
        if minutes > 99 {
            return ">99 min"
        } else if minutes <= 0 {
            return "0 min"
        } else {
            return "\(minutes) min"
        }
    }

    @ViewBuilder
    private func activityIcon(_ activity: LessonActivityData, size: CGFloat? = nil) -> some View {
        let boxSize = size ?? activity.size
        let iconSize = boxSize * 0.4375 // Scale icon relative to box (14/32)
        let style = ActivityStyle.appearance(forRawType: activity.type, status: activity.status)

        ZStack {
            activity.iconImage(size: iconSize)
                .foregroundColor(style.iconColor)
                .frame(width: boxSize, height: boxSize)
                .background(style.backgroundColor)
                .cornerRadius(4)
                .overlay(
                    Group {
                        if let borderColor = style.borderColor, style.borderWidth > 0 {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(borderColor, lineWidth: style.borderWidth)
                        }
                    }
                )
        }
        .overlay {
            if activity.isLoading {
                // Replace icon with spinner during loading
                Group {
                    switch activity.status {
                    case .default:
                        Color.white.opacity(0.1)
                    case .incomplete, .percentComplete:
                        Color.brandPrimary
                    case .complete:
                        Color.white.opacity(0.2)
                    }
                }
                .frame(width: boxSize, height: boxSize)
                .cornerRadius(4)

                ActivityIconSpinner(size: boxSize * 0.4)
            }
        }
    }

    // MARK: - Shared Day Indicator

    private func dayIndicator(labelColor: Color, stretch: Bool = false) -> some View {
        VStack(spacing: 0) {
            Text("DAY")
                .font(Typography.s12)
                .foregroundColor(labelColor)
                .tracking(0.1)

            Text("\(data.day)")
                .font(Typography.s22)
                .foregroundColor(.white)
                .tracking(-0.1)
        }
        .padding(16)
        .frame(maxHeight: stretch ? .infinity : nil)
    }
}

// MARK: - Activity Icon Spinner

/// Custom spinner that renders reliably in any view context.
/// ProgressView breaks inside nested Button/SwipeableCard hierarchies.
private struct ActivityIconSpinner: View {
    let size: CGFloat
    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(Color.white.opacity(0.5), lineWidth: 2)
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Preview

#Preview("Planning Mode") {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        VStack(spacing: 8) {
            // No activities (not ready - purple bg)
            CardLesson(data: CardLessonData(id: "p1", day: 1, activities: []))

            // 1 configured activity (ready - grey bg)
            CardLesson(data: CardLessonData(
                id: "p2", day: 2,
                activities: [
                    LessonActivityData(icon: "book", type: "SOAP", title: "Romans 1:1-2")
                ]
            ))

            // 1 configured + 1 unconfigured (not ready - purple bg)
            CardLesson(data: CardLessonData(
                id: "p3", day: 3,
                activities: [
                    LessonActivityData(icon: "book", type: "SOAP", title: "Romans 1:1-2", isConfigured: true),
                    LessonActivityData(icon: "play.fill", type: "VIDEO", title: "Select video", label: "Select video", isConfigured: false)
                ]
            ))

            // 2 configured activities (ready - grey bg)
            CardLesson(data: CardLessonData(
                id: "p4", day: 5,
                activities: [
                    LessonActivityData(icon: "book", type: "SOAP", title: "Genesis 1:1-5"),
                    LessonActivityData(icon: "play.fill", type: "VIDEO", title: "Video")
                ]
            ))
        }
        .padding(20)
    }
}

#Preview("Lesson Mode") {
    ScrollView {
        VStack(spacing: 12) {
            let sampleCover = "https://images.unsplash.com/photo-1504052434569-70ad5836ab65?w=800&h=400&fit=crop"

            Group {
                // With cover image + mixed activity types + time estimate
                CardLesson(data: CardLessonData(
                    id: "l1", day: 1, mode: .lesson,
                    activities: [
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "READ"), type: "READ", title: "Read"),
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "VIDEO"), type: "VIDEO", title: "Watch"),
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "USER_INPUT"), type: "USER_INPUT", title: "Reflect")
                    ],
                    title: "Romans Study",
                    date: DateComponents(calendar: .current, year: 2026, month: 1, day: 30).date,
                    coverImageUrl: sampleCover,
                    estimatedMinutes: 15
                ))

                // Mixed status: READ complete, USER_INPUT incomplete
                CardLesson(data: CardLessonData(
                    id: "l2", day: 1, mode: .lesson,
                    activities: [
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "READ"), type: "READ", title: "Read", status: .complete),
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "USER_INPUT"), type: "USER_INPUT", title: "Observe", status: .incomplete),
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "USER_INPUT"), type: "USER_INPUT", title: "Application", status: .incomplete),
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "EXEGESIS"), type: "EXEGESIS", title: "Exegesis", status: .incomplete)
                    ],
                    estimatedMinutes: 5
                ))

                // All complete with mixed types
                CardLesson(data: CardLessonData(
                    id: "l3", day: 1, mode: .lesson,
                    activities: [
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "READ"), type: "READ", title: "Read", status: .complete),
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "USER_INPUT"), type: "USER_INPUT", title: "Observe", status: .complete),
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "EXEGESIS"), type: "EXEGESIS", title: "Exegesis", status: .complete),
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "YOUTUBE"), type: "YOUTUBE", title: "Watch", status: .complete)
                    ],
                    estimatedMinutes: 3
                ))

                // SOAP-style: READ + USER_INPUT activities, mixed status
                CardLesson(data: CardLessonData(
                    id: "l4-soap", day: 1, mode: .lesson,
                    activities: [
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "READ"), type: "READ", title: "Scripture", status: .complete),
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "USER_INPUT"), type: "USER_INPUT", title: "Observation", status: .incomplete),
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "USER_INPUT"), type: "USER_INPUT", title: "Application", status: .incomplete),
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "USER_INPUT"), type: "USER_INPUT", title: "Prayer", status: .incomplete)
                    ],
                    title: "SOAP",
                    estimatedMinutes: 45
                ))

                // Video activity loading spinner
                CardLesson(data: CardLessonData(
                    id: "l5-loading", day: 2, mode: .lesson,
                    activities: [
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "READ"), type: "READ", title: "Read", status: .complete),
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "USER_INPUT"), type: "USER_INPUT", title: "Observe", status: .complete),
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "USER_INPUT"), type: "USER_INPUT", title: "Apply", status: .complete),
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "VIDEO"), type: "VIDEO", title: "Watch", isLoading: true, status: .incomplete)
                    ],
                    title: "SOAP + Video",
                    estimatedMinutes: 1
                ))
            }

            Group {
                // Animated border with incomplete activities
                CardLesson(data: CardLessonData(
                    id: "l6-border", day: 1, mode: .lesson,
                    activities: [
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "READ"), type: "READ", title: "Read", status: .complete),
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "USER_INPUT"), type: "USER_INPUT", title: "Observe", status: .incomplete),
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "EXEGESIS"), type: "EXEGESIS", title: "Exegesis", status: .incomplete),
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "USER_INPUT"), type: "USER_INPUT", title: "Prayer", status: .incomplete)
                    ],
                    title: "Mixed Types",
                    estimatedMinutes: 20
                ), showAnimatedBorder: true)

                // All complete with all different types
                CardLesson(data: CardLessonData(
                    id: "l7-all-types", day: 1, mode: .lesson,
                    activities: [
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "READ"), type: "READ", title: "Read", status: .complete),
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "USER_INPUT"), type: "USER_INPUT", title: "Write", status: .complete),
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "VIDEO"), type: "VIDEO", title: "Record", status: .complete),
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "YOUTUBE"), type: "YOUTUBE", title: "Watch", status: .complete),
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "EXEGESIS"), type: "EXEGESIS", title: "Exegesis", status: .complete)
                    ],
                    title: "All Activity Types",
                    estimatedMinutes: 99
                ))

                // Edge case: >99 minutes
                CardLesson(data: CardLessonData(
                    id: "l8", day: 3, mode: .lesson,
                    activities: [
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "READ"), type: "READ", title: "Read")
                    ],
                    title: "Genesis Study",
                    date: DateComponents(calendar: .current, year: 2026, month: 2, day: 5).date,
                    estimatedMinutes: 120
                ))

                // With cover image + VIDEO and YOUTUBE
                CardLesson(data: CardLessonData(
                    id: "l9", day: 7, mode: .lesson,
                    activities: [
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "VIDEO"), type: "VIDEO", title: "Record"),
                        LessonActivityData(icon: ActivityStyle.icon(forRawType: "YOUTUBE"), type: "YOUTUBE", title: "Watch")
                    ],
                    title: "Sermon on the Mount",
                    date: DateComponents(calendar: .current, year: 2026, month: 3, day: 12).date,
                    coverImageUrl: sampleCover
                ))

                // Without cover image + no activities
                CardLesson(data: CardLessonData(
                    id: "l10", day: 14, mode: .lesson,
                    title: "Psalms Study",
                    date: DateComponents(calendar: .current, year: 2026, month: 4, day: 20).date
                ))
            }
        }
        .padding(20)
    }
    .background(Color.appBackground)
}

#Preview("Lesson Mode - Activity Counts") {
    CardLessonStressTestPreview()
}

/// Stress-test preview for `.lesson` mode with varying activity counts.
/// Extracted into a dedicated struct so the SwiftUI type-checker doesn't choke.
private struct CardLessonStressTestPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                stressTestCard(id: "count-4", day: 1, count: 4, title: "4 Activities")
                stressTestCard(id: "count-8", day: 2, count: 8, title: "8 Activities")
                stressTestCard(id: "count-12", day: 3, count: 12, title: "12 Activities")
                stressTestCard(id: "count-20", day: 4, count: 20, title: "20 Activities")
                stressTestCard(id: "count-30", day: 5, count: 30, title: "30 Activities")
            }
            .padding(20)
        }
        .background(Color.appBackground)
    }

    @ViewBuilder
    private func stressTestCard(id: String, day: Int, count: Int, title: String) -> some View {
        let activities = stressActivities(count: count)
        let data = CardLessonData(
            id: id,
            day: day,
            mode: .lesson,
            activities: activities,
            title: title,
            date: DateComponents(calendar: .current, year: 2026, month: 1, day: day).date
        )
        CardLesson(data: data)
    }
}

/// Helper for preview: generate a realistic mix of activities for stress tests.
private func stressActivities(count: Int) -> [LessonActivityData] {
    let types: [(String, String)] = [
        ("READ", "Read"),
        ("USER_INPUT", "Observe"),
        ("VIDEO", "Watch"),
        ("YOUTUBE", "Discuss"),
        ("EXEGESIS", "Exegesis"),
        ("READ", "Review")
    ]
    let statuses: [LessonActivityStatus] = [.complete, .incomplete, .default]

    var result: [LessonActivityData] = []
    for i in 0..<count {
        let (type, title) = types[i % types.count]
        let status = statuses[i % statuses.count]
        result.append(LessonActivityData(icon: ActivityStyle.icon(forRawType: type), type: type, title: title, status: status))
    }
    return result
}

#Preview("Activity Status") {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        VStack(spacing: 12) {
            // Default status (existing look)
            CardLesson(data: CardLessonData(
                id: "s1", day: 1, mode: .lesson,
                activities: [
                    LessonActivityData(icon: ActivityStyle.icon(forRawType: "READ"), type: "READ", title: "Read", status: .default),
                    LessonActivityData(icon: ActivityStyle.icon(forRawType: "VIDEO"), type: "VIDEO", title: "Watch", status: .default),
                    LessonActivityData(icon: ActivityStyle.icon(forRawType: "USER_INPUT"), type: "USER_INPUT", title: "Reflect", status: .default)
                ],
                title: "All Default"
            ))

            // Mixed statuses with different types
            CardLesson(data: CardLessonData(
                id: "s2", day: 2, mode: .lesson,
                activities: [
                    LessonActivityData(icon: ActivityStyle.icon(forRawType: "READ"), type: "READ", title: "Read", status: .complete),
                    LessonActivityData(icon: ActivityStyle.icon(forRawType: "YOUTUBE"), type: "YOUTUBE", title: "Watch", status: .complete),
                    LessonActivityData(icon: ActivityStyle.icon(forRawType: "EXEGESIS"), type: "EXEGESIS", title: "Exegesis", status: .incomplete)
                ],
                title: "2 Complete, 1 Incomplete"
            ))

            // All complete with varied types
            CardLesson(data: CardLessonData(
                id: "s3", day: 3, mode: .lesson,
                activities: [
                    LessonActivityData(icon: ActivityStyle.icon(forRawType: "READ"), type: "READ", title: "Read", status: .complete),
                    LessonActivityData(icon: ActivityStyle.icon(forRawType: "VIDEO"), type: "VIDEO", title: "Record", status: .complete)
                ],
                title: "All Complete"
            ))

            // Custom size (48px) with different types showing each status
            CardLesson(data: CardLessonData(
                id: "s4", day: 4, mode: .lesson,
                activities: [
                    LessonActivityData(icon: ActivityStyle.icon(forRawType: "READ"), type: "READ", title: "Read", status: .complete, size: 48),
                    LessonActivityData(icon: ActivityStyle.icon(forRawType: "USER_INPUT"), type: "USER_INPUT", title: "Write", status: .incomplete, size: 48),
                    LessonActivityData(icon: ActivityStyle.icon(forRawType: "EXEGESIS"), type: "EXEGESIS", title: "Exegesis", status: .default, size: 48)
                ],
                title: "Custom Size (48px)"
            ))
        }
        .padding(20)
    }
}

#Preview("Progress Mode") {
    ScrollView {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 8) {
                // ProgressMode: 60%
                CardLesson(data: CardLessonData(
                    id: "pr1", day: 3, mode: .progress,
                    title: "Jan 22, 2026",
                    description: "Welcome to day 3 of the 30 day study.",
                    progress: 0.6
                ))

                // ProgressModeComplete: 100%
                CardLesson(data: CardLessonData(
                    id: "pr2", day: 30, mode: .progress,
                    title: "Final Day",
                    description: "Congratulations on completing the study!",
                    progress: 1.0
                ))

                // ProgressModeJustStarted: 3%
                CardLesson(data: CardLessonData(
                    id: "pr3", day: 1, mode: .progress,
                    title: "Day 1",
                    description: "Welcome to the beginning of your journey.",
                    progress: 0.03
                ))

                // ProgressModeNoProgress: 0%
                CardLesson(data: CardLessonData(
                    id: "pr4", day: 1, mode: .progress,
                    title: "Getting Started",
                    description: "Begin your study today.",
                    progress: 0.0
                ))

                // Progress with sections (completion tracking)
                CardLesson(data: CardLessonData(
                    id: "pr5", day: 3, mode: .progress,
                    title: "Jan 22, 2026",
                    description: "Welcome to day 3 of the 30 day study.",
                    progress: 0.66,
                    sections: [
                        SectionProgress(name: "Read", completedAt: DateComponents(calendar: .current, year: 2026, month: 6, day: 1, hour: 17, minute: 32).date),
                        SectionProgress(name: "Watch", completedAt: DateComponents(calendar: .current, year: 2026, month: 6, day: 1, hour: 18, minute: 15).date),
                        SectionProgress(name: "Discuss")
                    ]
                ))
            }
            .padding(20)
        }
    }
    .background(Color.appBackground)
}

#Preview("Lesson List Mode") {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        // LessonListAll: matches client story exactly
        VStack(spacing: 4) {
            CardLesson(data: CardLessonData(
                id: "ll1", day: 1, mode: .lessonList,
                title: "Romans 1:6-10",
                status: .complete
            ))

            CardLesson(data: CardLessonData(
                id: "ll2", day: 2, mode: .lessonList,
                title: "Romans 1:6-10",
                status: .next
            ))

            CardLesson(data: CardLessonData(
                id: "ll3", day: 3, mode: .lessonList,
                title: "Romans 1:6-10",
                status: .upcoming("Thursday")
            ))

            CardLesson(data: CardLessonData(
                id: "ll4", day: 4, mode: .lessonList,
                title: "Romans 1:6-10",
                status: .upcoming("Friday")
            ))
        }
        .padding(20)
    }
}
