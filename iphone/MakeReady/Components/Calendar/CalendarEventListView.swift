//
//  CalendarEventListView.swift
//  MakeReady
//
//  Supplementary view that displays the list of events for a selected day
//  Appears in the "gap" when the calendar splits
//

import UIKit
import SwiftUI

// MARK: - UIKit Supplementary View

class CalendarEventListReusableView: UICollectionReusableView {
    static let reuseIdentifier = "CalendarEventListReusableView"

    private var hostingController: UIHostingController<AnyView>?
    private weak var parentViewController: UIViewController?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(Color.appBackground)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        events: [SplitCalendarEvent],
        selectedDate: Date,
        in parentVC: UIViewController,
        onEventTap: @escaping (SplitCalendarEvent) -> Void
    ) {
        // Remove existing hosting controller
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()

        // Create SwiftUI content
        let content = CalendarEventListContent(
            events: events,
            selectedDate: selectedDate,
            onEventTap: onEventTap
        )

        let hostingVC = UIHostingController(rootView: AnyView(content))
        hostingVC.view.backgroundColor = .clear
        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false

        parentVC.addChild(hostingVC)
        addSubview(hostingVC.view)
        hostingVC.didMove(toParent: parentVC)

        NSLayoutConstraint.activate([
            hostingVC.view.topAnchor.constraint(equalTo: topAnchor),
            hostingVC.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingVC.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingVC.view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        self.hostingController = hostingVC
        self.parentViewController = parentVC
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()
        hostingController = nil
    }
}

// MARK: - SwiftUI Event List Content

struct CalendarEventListContent: View {
    let events: [SplitCalendarEvent]
    let selectedDate: Date
    let onEventTap: (SplitCalendarEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Date header
            Text(CalendarFormatters.fullDateHeader.string(from: selectedDate))
                .font(Typography.s14Semibold)
                .foregroundColor(.white70)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            if events.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(Typography.s32)
                        .foregroundColor(.white30)
                    Text("No events")
                        .font(Typography.s14)
                        .foregroundColor(.white50)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                // Event list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(events) { event in
                            if let dayNumber = event.dayNumber {
                                // Lesson card for scheduled lessons
                                CardLesson(data: CardLessonData(
                                    id: event.id,
                                    day: dayNumber,
                                    mode: .lesson,
                                    activities: (event.activityIcons ?? []).map { icon in
                                        LessonActivityData(icon: icon.icon, type: icon.rawType, title: icon.label)
                                    },
                                    title: event.title,
                                    date: event.startTime,
                                    coverImageUrl: event.coverImageUrl,
                                    estimatedMinutes: event.estimatedMinutes
                                )) {
                                    onEventTap(event)
                                }
                            } else {
                                // Fallback for non-lesson events
                                CalendarEventRow(event: event)
                                    .onTapGesture {
                                        onEventTap(event)
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(Color.appBackground)
    }
}

// MARK: - Event Row

struct CalendarEventRow: View {
    let event: SplitCalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            // Color indicator bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: event.color))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                // Time
                if !event.isAllDay {
                    Text(event.timeString)
                        .font(Typography.s12)
                        .foregroundColor(.white50)
                } else {
                    Text("All day")
                        .font(Typography.s12)
                        .foregroundColor(.white50)
                }

                // Title
                Text(event.title)
                    .font(Typography.s15Semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)

                // Subtitle or location
                if let subtitle = event.subtitle ?? event.location {
                    Text(subtitle)
                        .font(Typography.s13)
                        .foregroundColor(.white50)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(Typography.s12Semibold)
                .foregroundColor(.white30)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview("Event List - Lessons") {
    let sampleCover = "https://images.unsplash.com/photo-1504052434569-70ad5836ab65?w=800&h=400&fit=crop"
    let mockEvents = [
        SplitCalendarEvent(
            id: "1",
            title: "Romans Study",
            subtitle: "Romans Study",
            startTime: Date(),
            color: "#6c47ff",
            dayNumber: 3,
            coverImageUrl: sampleCover,
            activityIcons: [
                CalendarActivityIcon(icon: "book.fill", label: "Read"),
                CalendarActivityIcon(icon: "play.fill", label: "Watch"),
                CalendarActivityIcon(icon: "hands.sparkles.fill", label: "Pray")
            ]
        ),
        SplitCalendarEvent(
            id: "2",
            title: "Genesis Study",
            subtitle: "Genesis Study",
            startTime: Date(),
            color: "#6c47ff",
            dayNumber: 7,
            activityIcons: [
                CalendarActivityIcon(icon: "book.fill", label: "Read")
            ]
        ),
        SplitCalendarEvent(
            id: "3",
            title: "Psalms Study",
            subtitle: "Psalms Study",
            startTime: Date(),
            color: "#6c47ff",
            dayNumber: 14,
            coverImageUrl: sampleCover,
            activityIcons: [
                CalendarActivityIcon(icon: "book.fill", label: "Read"),
                CalendarActivityIcon(icon: "text.bubble.fill", label: "Review")
            ]
        ),
    ]

    CalendarEventListContent(
        events: mockEvents,
        selectedDate: Date(),
        onEventTap: { _ in }
    )
    .frame(height: 400)
    .background(Color.appBackground)
}

#Preview("Empty Event List") {
    CalendarEventListContent(
        events: [],
        selectedDate: Date(),
        onEventTap: { _ in }
    )
    .frame(height: 200)
    .background(Color.appBackground)
}
