//
//  CalendarHeaderView.swift
//  MakeReady
//
//  Supplementary views for calendar headers:
//  - MonthHeaderView: Displays month name and year
//  - WeekdayHeaderView: Fixed S M T W T F S header (pinned at top)
//

import UIKit
import SwiftUI

// MARK: - Month Header View (inline separator in scrolling calendar)

class CalendarMonthHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "CalendarMonthHeaderView"

    private let containerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let monthLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let yearLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = UIColor(Color.white50)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .clear

        containerStack.addArrangedSubview(monthLabel)
        containerStack.addArrangedSubview(yearLabel)
        addSubview(containerStack)

        NSLayoutConstraint.activate([
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }

    func configure(with month: SplitCalendarMonth) {
        // Bold month name + regular year with 4px gap
        monthLabel.text = month.shortDisplayName
        yearLabel.text = String(month.year)
    }

    func configure(monthName: String, year: Int) {
        monthLabel.text = monthName
        yearLabel.text = String(year)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        monthLabel.text = nil
        yearLabel.text = nil
    }
}

// MARK: - Weekday Header View (SwiftUI for the fixed overlay)

struct CalendarWeekdayHeader: View {
    private let days = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                Text(day)
                    .font(Typography.s12)
                    .foregroundColor(.white50)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.appBackground)
    }
}

// MARK: - UIKit Weekday Header (for supplementary view if needed)

class CalendarWeekdayHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "CalendarWeekdayHeaderView"

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let days = ["S", "M", "T", "W", "T", "F", "S"]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = UIColor(Color.appBackground)

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        for day in days {
            let label = UILabel()
            label.text = day
            label.font = .systemFont(ofSize: 12, weight: .regular)
            label.textColor = UIColor(Color.white50)
            label.textAlignment = .center
            stackView.addArrangedSubview(label)
        }
    }
}

// MARK: - Preview

#Preview("Weekday Header") {
    VStack {
        CalendarWeekdayHeader()
    }
    .background(Color.appBackground)
}
