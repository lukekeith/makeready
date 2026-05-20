//
//  CalendarDayCell.swift
//  MakeReady
//
//  UICollectionViewCell for displaying a calendar day
//

import UIKit
import SwiftUI

class CalendarDayCell: UICollectionViewCell {
    static let reuseIdentifier = "CalendarDayCell"

    // MARK: - UI Elements

    private let dayLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let todayCircle: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(Color.brandPrimary)
        // Corner radius will be set dynamically in layoutSubviews to be half the width (perfect circle)
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let selectionRing: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.borderColor = UIColor(Color.brandPrimary).cgColor
        view.layer.borderWidth = 2
        // Corner radius will be set dynamically in layoutSubviews to be half the width (perfect circle)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let eventDotsContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 3
        stack.alignment = .center
        stack.distribution = .equalSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // Pre-create dot views for performance
    private var eventDots: [UIView] = []
    private let maxDots = 3

    // MARK: - Properties

    var day: SplitCalendarDay?
    var isSelectedDay: Bool = false {
        didSet {
            selectionRing.isHidden = !isSelectedDay
            // Re-render dots so they become white on selected purple background
            if let day = day {
                configureEventDots(count: day.eventCount, events: day.events, isToday: day.isToday, isSelected: isSelectedDay)
            }
        }
    }

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupViews() {
        contentView.backgroundColor = .clear

        // Add views
        contentView.addSubview(todayCircle)
        contentView.addSubview(selectionRing)
        contentView.addSubview(dayLabel)
        contentView.addSubview(eventDotsContainer)

        // Create reusable dots
        for _ in 0..<maxDots {
            let dot = UIView()
            dot.layer.cornerRadius = 2.5
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 5).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 5).isActive = true
            dot.isHidden = true
            eventDots.append(dot)
            eventDotsContainer.addArrangedSubview(dot)
        }

        // Constraints
        NSLayoutConstraint.activate([
            // Today circle - perfect circle that fits within cell width, centered
            todayCircle.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            todayCircle.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            todayCircle.widthAnchor.constraint(equalTo: contentView.widthAnchor),
            todayCircle.heightAnchor.constraint(equalTo: todayCircle.widthAnchor),  // Square for perfect circle

            // Selection ring - same position and size as today circle
            selectionRing.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            selectionRing.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            selectionRing.widthAnchor.constraint(equalTo: contentView.widthAnchor),
            selectionRing.heightAnchor.constraint(equalTo: selectionRing.widthAnchor),

            // Day label - centered
            dayLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dayLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -4),

            // Event dots - below day label
            eventDotsContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            eventDotsContainer.topAnchor.constraint(equalTo: dayLabel.bottomAnchor, constant: 2),
            eventDotsContainer.heightAnchor.constraint(equalToConstant: 6),
        ])
    }

    // MARK: - Configuration

    func configure(with day: SplitCalendarDay, isSelected: Bool = false) {
        self.day = day
        self.isSelectedDay = isSelected

        // Day number
        dayLabel.text = "\(day.dayNumber)"

        // Text color based on state
        if day.isCurrentMonth {
            dayLabel.textColor = .white
        } else {
            dayLabel.textColor = UIColor(Color.white50)
        }

        // Today indicator
        todayCircle.isHidden = !day.isToday

        // Selection state
        selectionRing.isHidden = !isSelected

        // Configure event dots
        configureEventDots(count: day.eventCount, events: day.events, isToday: day.isToday, isSelected: isSelected)
    }

    private func configureEventDots(count: Int, events: [SplitCalendarEvent], isToday: Bool, isSelected: Bool) {
        // Hide all dots first
        for dot in eventDots {
            dot.isHidden = true
        }

        // Show dots based on event count (max 3)
        let dotsToShow = min(count, maxDots)
        for i in 0..<dotsToShow {
            eventDots[i].isHidden = false

            // Use white dots when today or selected (visible on purple background)
            // Otherwise use event color if available, or default to brand purple
            if isToday || isSelected {
                eventDots[i].backgroundColor = .white
            } else if i < events.count {
                eventDots[i].backgroundColor = UIColor(Color(hex: events[i].color))
            } else {
                eventDots[i].backgroundColor = UIColor(Color.brandPrimary)
            }
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        // Force layout to get correct bounds
        todayCircle.layoutIfNeeded()
        selectionRing.layoutIfNeeded()

        // Set corner radius to half the width for a perfect circle
        let circleSize = todayCircle.bounds.width
        if circleSize > 0 {
            todayCircle.layer.cornerRadius = circleSize / 2
            selectionRing.layer.cornerRadius = circleSize / 2
        }
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        day = nil
        isSelectedDay = false
        dayLabel.text = nil
        todayCircle.isHidden = true
        selectionRing.isHidden = true
        for dot in eventDots {
            dot.isHidden = true
        }
    }
}

// MARK: - Preview

#Preview {
    let today = Date()
    let mockEvents = [
        SplitCalendarEvent(
            id: "1",
            title: "Meeting",
            subtitle: nil,
            startTime: today,
            endTime: nil,
            color: "#6C47FF",
            location: nil
        ),
        SplitCalendarEvent(
            id: "2",
            title: "Lunch",
            subtitle: nil,
            startTime: today,
            endTime: nil,
            color: "#5680ff",
            location: nil
        )
    ]

    let mockDay = SplitCalendarDay(
        date: today,
        dayNumber: 15,
        isCurrentMonth: true,
        weekdayIndex: 3,
        rowIndex: 2,
        events: mockEvents
    )

    let cell = CalendarDayCell(frame: CGRect(x: 0, y: 0, width: 48, height: 48))
    cell.configure(with: mockDay, isSelected: false)
    cell.backgroundColor = UIColor(Color.appBackground)

    return UIViewPreviewWrapper(view: cell)
        .frame(width: 48, height: 48)
        .background(Color.appBackground)
}

// Helper for UIKit previews in SwiftUI
struct UIViewPreviewWrapper: UIViewRepresentable {
    let view: UIView

    func makeUIView(context: Context) -> UIView {
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
