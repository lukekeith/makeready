//
//  SelectEnrollDatePage.swift
//  MakeReady
//
//  Calendar page for selecting enrollment date ranges for study programs.
//  Uses UIKit UICollectionView for the calendar grid (matching SplitMonthCalendar pattern).
//  Supports day-of-week filtering and blackout period selection.
//

import SwiftUI
import UIKit

// MARK: - State Management

/// Manages the enrollment date selection state
class EnrollmentDateState: ObservableObject {
    let lessonCount: Int

    @Published var startDate: Date?
    @Published var enabledDays: Set<Int> = [1, 2, 3, 4, 5]  // Mon-Fri (0=Sun, 1=Mon, ... 6=Sat)

    /// Dates that have been manually overridden by the user (long press)
    /// These dates flip their inclusion: enabled weekday becomes excluded, disabled weekday becomes included
    @Published var overriddenDates: Set<Date> = []

    private let calendar = Calendar.current

    init(lessonCount: Int) {
        self.lessonCount = lessonCount
    }

    /// Check if a date is included in the schedule (considering weekday + overrides)
    func isDateIncluded(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date) - 1
        let dayStart = calendar.startOfDay(for: date)
        let isWeekdayEnabled = enabledDays.contains(weekday)
        let isOverridden = overriddenDates.contains(dayStart)

        // Override flips the default behavior
        if isOverridden {
            return !isWeekdayEnabled  // Flip: disabled becomes included, enabled becomes excluded
        }
        return isWeekdayEnabled
    }

    /// Calculate the end date based on start date, lesson count, and schedule
    var calculatedEndDate: Date? {
        guard let start = startDate else { return nil }

        var currentDate = start
        var lessonsScheduled = 0
        let maxIterations = lessonCount * 10  // Safety limit
        var iterations = 0

        while lessonsScheduled < lessonCount && iterations < maxIterations {
            if isDateIncluded(currentDate) {
                lessonsScheduled += 1
            }

            if lessonsScheduled < lessonCount {
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }
            iterations += 1
        }

        return currentDate
    }

    /// All dates between start and calculated end that are included in the schedule
    var highlightedDates: Set<Date> {
        guard let start = startDate, let end = calculatedEndDate else { return [] }

        var dates: Set<Date> = []
        var current = start

        while current <= end {
            let dayStart = calendar.startOfDay(for: current)
            if isDateIncluded(current) {
                dates.insert(dayStart)
            }
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }

        return dates
    }

    /// All dates between start and end (for range background, including non-highlighted days)
    var rangeDates: Set<Date> {
        guard let start = startDate, let end = calculatedEndDate else { return [] }

        var dates: Set<Date> = []
        var current = start

        while current <= end {
            dates.insert(calendar.startOfDay(for: current))
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }

        return dates
    }

    /// Formatted date range string for display
    var formattedDateRange: String {
        guard let start = startDate, let end = calculatedEndDate else {
            return "SELECT START DATE"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        return "\(formatter.string(from: start).uppercased()) - \(formatter.string(from: end).uppercased())"
    }

    /// Check if a date is the start date
    func isStartDate(_ date: Date) -> Bool {
        guard let start = startDate else { return false }
        return calendar.isDate(date, inSameDayAs: start)
    }

    /// Check if a date is the end date
    func isEndDate(_ date: Date) -> Bool {
        guard let end = calculatedEndDate else { return false }
        return calendar.isDate(date, inSameDayAs: end)
    }

    /// Check if a date is within the highlighted range (included in schedule)
    func isInRange(_ date: Date) -> Bool {
        return highlightedDates.contains(calendar.startOfDay(for: date))
    }

    /// Check if a date is within the overall range (for background)
    func isInRangeBackground(_ date: Date) -> Bool {
        return rangeDates.contains(calendar.startOfDay(for: date))
    }

    /// Check if a date has been manually overridden
    func isOverridden(_ date: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        return overriddenDates.contains(dayStart)
    }

    /// Check if a weekday is enabled
    func isWeekdayEnabled(_ weekday: Int) -> Bool {
        return enabledDays.contains(weekday)
    }

    /// Select a start date
    /// - Parameters:
    ///   - date: The date to set as start
    ///   - force: If true, bypasses the inclusion check (used when user explicitly chooses from dialog)
    func selectStartDate(_ date: Date, force: Bool = false) {
        let dayStart = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())

        // Don't allow past dates
        guard dayStart >= today else { return }

        if !force {
            // Check if date would be included (considering overrides)
            // Allow selecting if weekday is enabled OR if it's been manually overridden to be included
            let weekday = calendar.component(.weekday, from: date) - 1
            let isWeekdayEnabled = enabledDays.contains(weekday)
            let isOverridden = overriddenDates.contains(dayStart)

            // Date is selectable if: (weekday enabled AND not overridden) OR (weekday disabled AND overridden)
            let isIncluded = isOverridden ? !isWeekdayEnabled : isWeekdayEnabled
            guard isIncluded else { return }
        }

        startDate = dayStart
        // Clear overrides when selecting new start
        overriddenDates.removeAll()
    }

    /// Toggle a day of week on/off
    func toggleDay(_ weekday: Int) {
        // Ensure at least one day remains enabled
        if enabledDays.contains(weekday) && enabledDays.count > 1 {
            enabledDays.remove(weekday)
        } else {
            enabledDays.insert(weekday)
        }
        // Note: overrides persist - they represent manual user choices
    }

    /// Toggle override for a specific date
    func toggleOverride(_ date: Date) {
        let dayStart = calendar.startOfDay(for: date)
        if overriddenDates.contains(dayStart) {
            overriddenDates.remove(dayStart)
        } else {
            overriddenDates.insert(dayStart)
        }
    }

    /// Calculate week highlight information for the current range
    /// Groups highlighted dates into per-week segments with column bounds
    func calculateWeekHighlights(months: [SplitCalendarMonth]) -> [WeekHighlightInfo] {
        guard startDate != nil, calculatedEndDate != nil else { return [] }

        var highlights: [WeekHighlightInfo] = []

        // Group days by section and row
        var weekGroups: [String: (section: Int, rowIndex: Int, columns: [Int])] = [:]

        for (sectionIndex, month) in months.enumerated() {
            for day in month.days {
                let dayStart = calendar.startOfDay(for: day.date)

                // Check if this day is in the range background
                guard rangeDates.contains(dayStart) else { continue }

                let key = "\(sectionIndex)-\(day.rowIndex)"
                if var group = weekGroups[key] {
                    group.columns.append(day.weekdayIndex)
                    weekGroups[key] = group
                } else {
                    weekGroups[key] = (section: sectionIndex, rowIndex: day.rowIndex, columns: [day.weekdayIndex])
                }
            }
        }

        // Convert groups to WeekHighlightInfo
        let sortedKeys = weekGroups.keys.sorted { k1, k2 in
            let parts1 = k1.split(separator: "-").compactMap { Int($0) }
            let parts2 = k2.split(separator: "-").compactMap { Int($0) }
            if parts1[0] != parts2[0] { return parts1[0] < parts2[0] }
            return parts1[1] < parts2[1]
        }

        for (index, key) in sortedKeys.enumerated() {
            guard let group = weekGroups[key],
                  let minColumn = group.columns.min(),
                  let maxColumn = group.columns.max() else { continue }

            let isFirst = (index == 0)
            let isLast = (index == sortedKeys.count - 1)

            highlights.append(WeekHighlightInfo(
                section: group.section,
                rowIndex: group.rowIndex,
                startColumn: minColumn,
                endColumn: maxColumn,
                isFirstWeekInRange: isFirst,
                isLastWeekInRange: isLast
            ))
        }

        return highlights
    }
}

// MARK: - Day Cell State

enum EnrollDayCellState {
    case normal
    case dimmed
    case startDate
    case endDate
    case inRange
    case inRangeDimmed       // In range but disabled weekday (dimmed text, has highlight)
    case overrideAdded       // Manually added to schedule (yellow text/circle)
    case overrideRemoved     // Manually removed from schedule (red text/circle)
}

enum BlackoutDragMode {
    case adding    // Adding blackout dates
    case removing  // Removing blackout dates
}

// MARK: - Week Highlight Structures

/// Direction of highlight travel animation
enum HighlightTravelDirection {
    case forward   // New date is AFTER current (shrink from left)
    case backward  // New date is BEFORE current (shrink from right)
}

/// Information about a single week's highlight for decoration view
struct WeekHighlightInfo: Hashable {
    let section: Int           // Month section index
    let rowIndex: Int          // Week row within month (0-based)
    let startColumn: Int       // 0-6, leftmost highlighted column
    let endColumn: Int         // 0-6, rightmost highlighted column
    let isFirstWeekInRange: Bool
    let isLastWeekInRange: Bool

    var id: String { "\(section)-\(rowIndex)" }

    /// Number of highlighted columns
    var columnCount: Int {
        endColumn - startColumn + 1
    }
}

// MARK: - Highlight Animation Coordinator

/// Orchestrates the traveling highlight animation between start dates
class HighlightAnimationCoordinator {

    // MARK: - Timing Parameters

    /// Duration for each week's shrink animation
    static let perWeekDuration: TimeInterval = 0.15

    /// Delay before starting the next week's animation (overlap)
    static let overlapDelay: TimeInterval = 0.08

    // MARK: - Properties

    private weak var collectionView: UICollectionView?
    private var isAnimating: Bool = false
    private var pendingAnimation: (() -> Void)?

    init(collectionView: UICollectionView) {
        self.collectionView = collectionView
    }

    // MARK: - Animation

    /// Animate highlights traveling from old range to new range
    /// - Parameters:
    ///   - oldHighlights: Week highlights for the old start date range
    ///   - newHighlights: Week highlights for the new start date range
    ///   - direction: Whether new date is forward or backward from old
    ///   - completion: Called when animation completes
    func animateTraveling(
        from oldHighlights: [WeekHighlightInfo],
        to newHighlights: [WeekHighlightInfo],
        direction: HighlightTravelDirection,
        completion: (() -> Void)? = nil
    ) {
        guard let collectionView = collectionView,
              collectionView.collectionViewLayout is EnrollCalendarLayout else {
            completion?()
            return
        }

        // If already animating, queue this one
        if isAnimating {
            pendingAnimation = { [weak self] in
                self?.animateTraveling(from: oldHighlights, to: newHighlights, direction: direction, completion: completion)
            }
            return
        }

        isAnimating = true

        // Find weeks that need to animate out (disappear)
        let weeksToRemove = oldHighlights.filter { old in
            !newHighlights.contains { $0.id == old.id }
        }

        // Find weeks that need to animate in (appear)
        let weeksToAdd = newHighlights.filter { new in
            !oldHighlights.contains { $0.id == new.id }
        }

        // Sort based on direction
        let sortedRemove: [WeekHighlightInfo]
        let sortedAdd: [WeekHighlightInfo]

        if direction == .forward {
            // Forward: animate from start to end
            sortedRemove = weeksToRemove.sorted { $0.id < $1.id }
            sortedAdd = weeksToAdd.sorted { $0.id < $1.id }
        } else {
            // Backward: animate from end to start
            sortedRemove = weeksToRemove.sorted { $0.id > $1.id }
            sortedAdd = weeksToAdd.sorted { $0.id > $1.id }
        }

        // Total weeks to animate
        let totalWeeks = sortedRemove.count + sortedAdd.count

        guard totalWeeks > 0 else {
            isAnimating = false
            completion?()
            return
        }

        // Animate removal first, then addition
        animateWeeksOut(sortedRemove, direction: direction, index: 0) { [weak self] in
            self?.animateWeeksIn(sortedAdd, direction: direction, index: 0) {
                self?.isAnimating = false
                completion?()

                // Execute pending animation if any
                if let pending = self?.pendingAnimation {
                    self?.pendingAnimation = nil
                    pending()
                }
            }
        }
    }

    /// Animate weeks shrinking out sequentially
    private func animateWeeksOut(
        _ weeks: [WeekHighlightInfo],
        direction: HighlightTravelDirection,
        index: Int,
        completion: @escaping () -> Void
    ) {
        guard index < weeks.count else {
            completion()
            return
        }

        let week = weeks[index]
        let shrinkFromLeft = (direction == .forward)

        // Find the decoration view for this week
        if let decorationView = findDecorationView(for: week) {
            decorationView.shrinkFromLeft = shrinkFromLeft
            decorationView.animateProgress(to: 1.0, duration: Self.perWeekDuration)
        }

        // Start next week with overlap
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.overlapDelay) { [weak self] in
            self?.animateWeeksOut(weeks, direction: direction, index: index + 1, completion: completion)
        }
    }

    /// Animate weeks growing in sequentially
    private func animateWeeksIn(
        _ weeks: [WeekHighlightInfo],
        direction: HighlightTravelDirection,
        index: Int,
        completion: @escaping () -> Void
    ) {
        guard index < weeks.count else {
            completion()
            return
        }

        let week = weeks[index]
        let shrinkFromLeft = (direction == .backward)  // Reverse for growing

        // Find the decoration view for this week
        if let decorationView = findDecorationView(for: week) {
            decorationView.progress = 1.0  // Start shrunk
            decorationView.shrinkFromLeft = shrinkFromLeft
            decorationView.animateProgress(to: 0.0, duration: Self.perWeekDuration)
        }

        // Start next week with overlap
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.overlapDelay) { [weak self] in
            self?.animateWeeksIn(weeks, direction: direction, index: index + 1, completion: completion)
        }
    }

    /// Find the decoration view for a specific week by matching frame to layout attributes
    private func findDecorationView(for week: WeekHighlightInfo) -> WeekHighlightDecorationView? {
        guard let collectionView = collectionView,
              let layout = collectionView.collectionViewLayout as? EnrollCalendarLayout,
              let expectedAttributes = layout.decorationAttributes(for: week.id) else {
            return nil
        }

        let expectedFrame = expectedAttributes.frame

        // Search through visible decoration views and match by frame
        for subview in collectionView.subviews {
            if let decorationView = subview as? WeekHighlightDecorationView {
                // Match by frame with small tolerance for floating point comparison
                if abs(decorationView.frame.origin.y - expectedFrame.origin.y) < 1 {
                    return decorationView
                }
            }
        }

        return nil
    }

    /// Cancel any ongoing animation
    func cancelAnimation() {
        isAnimating = false
        pendingAnimation = nil
    }
}

// MARK: - Week Highlight Decoration View

/// Decoration view that draws a week-level highlight behind calendar cells
/// Supports animating width for traveling highlight effect
class WeekHighlightDecorationView: UICollectionReusableView {
    static let elementKind = "WeekHighlight"

    // MARK: - Properties

    private let highlightView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(Color(hex: "#3D2C8C"))
        return view
    }()

    /// The full frame bounds for this week's highlight (set externally)
    var fullFrame: CGRect = .zero

    /// Animation progress: 0.0 = full width, 1.0 = fully shrunk
    var progress: CGFloat = 0.0 {
        didSet {
            updateHighlightFrame()
        }
    }

    /// Which direction to shrink (true = shrink from left, false = shrink from right)
    var shrinkFromLeft: Bool = true {
        didSet {
            updateHighlightFrame()
        }
    }

    /// Corner radius for the highlight
    var cornerRadius: CGFloat = 22.5  // Half of circleSize (45/2)

    /// Is this the first week in the range? (round left corners)
    var isFirstWeek: Bool = false {
        didSet {
            updateCorners()
        }
    }

    /// Is this the last week in the range? (round right corners)
    var isLastWeek: Bool = false {
        didSet {
            updateCorners()
        }
    }

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        backgroundColor = .clear
        addSubview(highlightView)
    }

    // MARK: - Configuration

    func configure(info: WeekHighlightInfo, fullFrame: CGRect, cornerRadius: CGFloat) {
        self.fullFrame = fullFrame
        self.cornerRadius = cornerRadius
        self.isFirstWeek = info.isFirstWeekInRange
        self.isLastWeek = info.isLastWeekInRange
        self.progress = 0.0
        updateHighlightFrame()
        updateCorners()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        updateHighlightFrame()
        updateCorners()
    }

    private func updateHighlightFrame() {
        let totalWidth = bounds.width
        let shrinkAmount = totalWidth * progress

        var frame = bounds
        if shrinkFromLeft {
            // Shrink from left edge: move origin right, reduce width
            frame.origin.x = shrinkAmount
            frame.size.width = totalWidth - shrinkAmount
        } else {
            // Shrink from right edge: keep origin, reduce width
            frame.size.width = totalWidth - shrinkAmount
        }

        // Don't show negative or zero width
        if frame.size.width <= 0 {
            highlightView.isHidden = true
        } else {
            highlightView.isHidden = false
            highlightView.frame = frame
        }
    }

    private func updateCorners() {
        // Always round all corners at full corner radius
        // The decoration frame is already adjusted to start/end at circle centers
        highlightView.layer.cornerRadius = cornerRadius
        highlightView.layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMinXMaxYCorner,
            .layerMaxXMinYCorner,
            .layerMaxXMaxYCorner
        ]
    }

    // MARK: - Animation

    /// Animate the progress with specified duration
    func animateProgress(to targetProgress: CGFloat, duration: TimeInterval, completion: (() -> Void)? = nil) {
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: .curveEaseInOut
        ) {
            self.progress = targetProgress
        } completion: { _ in
            completion?()
        }
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        progress = 0.0
        shrinkFromLeft = true
        isFirstWeek = false
        isLastWeek = false
        highlightView.isHidden = false
        alpha = 1.0  // Reset alpha in case it was hidden during animation
    }
}

// MARK: - Enroll Day Cell (UIKit)

/// Simplified day cell - rangeBackground is now handled by per-week decoration views
class EnrollDayCell: UICollectionViewCell {
    static let reuseIdentifier = "EnrollDayCell"

    private let circleSize: CGFloat = 45
    private let overrideCircleSize: CGFloat = 36
    private let maxDots: Int = 3
    private let dotSize: CGFloat = 5

    // MARK: - UI Elements

    private let circleView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(Color(hex: "#6c47ff"))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let overrideAddedCircle: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.borderColor = UIColor(Color(hex: "#57DB8C")).cgColor
        view.layer.borderWidth = 1
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let overrideRemovedCircle: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.borderColor = UIColor(Color(hex: "#DE3F87")).cgColor
        view.layer.borderWidth = 1
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let dayLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// Container for event dots (existing lessons indicator)
    private let eventDotsContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 3
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// Pre-created dot views for performance
    private var eventDots: [UIView] = []

    // MARK: - Properties

    var day: SplitCalendarDay?
    var cellState: EnrollDayCellState = .normal
    var hasExistingLessons: Bool = false

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

        contentView.addSubview(circleView)
        contentView.addSubview(overrideAddedCircle)
        contentView.addSubview(overrideRemovedCircle)
        contentView.addSubview(dayLabel)
        contentView.addSubview(eventDotsContainer)

        // Pre-create dot views for performance
        for _ in 0..<maxDots {
            let dot = UIView()
            dot.layer.cornerRadius = dotSize / 2
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: dotSize).isActive = true
            dot.heightAnchor.constraint(equalToConstant: dotSize).isActive = true
            dot.isHidden = true
            eventDots.append(dot)
            eventDotsContainer.addArrangedSubview(dot)
        }

        NSLayoutConstraint.activate([
            // Circle for start/end - centered
            circleView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            circleView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            circleView.widthAnchor.constraint(equalToConstant: circleSize),
            circleView.heightAnchor.constraint(equalToConstant: circleSize),

            // Override added circle (green) - smaller with border
            overrideAddedCircle.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            overrideAddedCircle.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            overrideAddedCircle.widthAnchor.constraint(equalToConstant: overrideCircleSize),
            overrideAddedCircle.heightAnchor.constraint(equalToConstant: overrideCircleSize),

            // Override removed circle (pink) - smaller with border
            overrideRemovedCircle.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            overrideRemovedCircle.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            overrideRemovedCircle.widthAnchor.constraint(equalToConstant: overrideCircleSize),
            overrideRemovedCircle.heightAnchor.constraint(equalToConstant: overrideCircleSize),

            // Day label - centered but slightly higher to make room for dots
            dayLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dayLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -3),

            // Event dots - below day label
            eventDotsContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            eventDotsContainer.topAnchor.constraint(equalTo: dayLabel.bottomAnchor, constant: 2),
            eventDotsContainer.heightAnchor.constraint(equalToConstant: 6),
        ])
    }

    // MARK: - Configuration

    func configure(with day: SplitCalendarDay, state: EnrollDayCellState, hasExistingLessons: Bool = false) {
        self.day = day
        self.cellState = state
        self.hasExistingLessons = hasExistingLessons

        // Day number
        dayLabel.text = "\(day.dayNumber)"

        // Configure event dots (show for existing lessons, but not on start/end circles)
        let showDots = hasExistingLessons && state != .startDate && state != .endDate && state != .dimmed
        configureEventDots(show: showDots)

        // Configure appearance based on state
        switch state {
        case .normal:
            dayLabel.textColor = .white
            circleView.isHidden = true
            overrideAddedCircle.isHidden = true
            overrideRemovedCircle.isHidden = true

        case .dimmed:
            dayLabel.textColor = UIColor.white.withAlphaComponent(0.2)
            circleView.isHidden = true
            overrideAddedCircle.isHidden = true
            overrideRemovedCircle.isHidden = true

        case .startDate, .endDate:
            dayLabel.textColor = .white
            circleView.isHidden = false
            overrideAddedCircle.isHidden = true
            overrideRemovedCircle.isHidden = true

        case .inRange:
            dayLabel.textColor = .white
            circleView.isHidden = true
            overrideAddedCircle.isHidden = true
            overrideRemovedCircle.isHidden = true

        case .inRangeDimmed:
            // In range but disabled weekday - dimmed text (highlight handled by decoration)
            dayLabel.textColor = UIColor.white.withAlphaComponent(0.2)
            circleView.isHidden = true
            overrideAddedCircle.isHidden = true
            overrideRemovedCircle.isHidden = true

        case .overrideAdded:
            // Manually added to schedule - green text with green border circle
            dayLabel.textColor = UIColor(Color(hex: "#57DB8C"))
            circleView.isHidden = true
            overrideAddedCircle.isHidden = false
            overrideRemovedCircle.isHidden = true

        case .overrideRemoved:
            // Manually removed from schedule - pink text with pink border circle
            dayLabel.textColor = UIColor(Color(hex: "#DE3F87"))
            circleView.isHidden = true
            overrideAddedCircle.isHidden = true
            overrideRemovedCircle.isHidden = false
        }
    }

    /// Configure event dots for existing lessons indicator
    private func configureEventDots(show: Bool) {
        // Hide all dots first
        for dot in eventDots {
            dot.isHidden = true
        }

        guard show else { return }

        // Show one purple dot for existing lessons
        if let firstDot = eventDots.first {
            firstDot.isHidden = false
            firstDot.backgroundColor = UIColor(Color(hex: "#6c47ff"))
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        circleView.layer.cornerRadius = circleSize / 2
        overrideAddedCircle.layer.cornerRadius = overrideCircleSize / 2
        overrideRemovedCircle.layer.cornerRadius = overrideCircleSize / 2
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        day = nil
        cellState = .normal
        hasExistingLessons = false
        dayLabel.text = nil
        circleView.isHidden = true
        overrideAddedCircle.isHidden = true
        overrideRemovedCircle.isHidden = true
        configureEventDots(show: false)
    }

    // MARK: - Animations

    /// Trigger a subtle bounce animation on the start/end circle
    func animateCircleBounce() {
        guard !circleView.isHidden else { return }

        // Reset any existing transform
        circleView.transform = .identity

        // Subtle bounce: scale up slightly then back to normal
        UIView.animateKeyframes(withDuration: 0.4, delay: 0, options: []) {
            // Scale up
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.3) {
                self.circleView.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            }
            // Bounce back (overshoot slightly)
            UIView.addKeyframe(withRelativeStartTime: 0.3, relativeDuration: 0.35) {
                self.circleView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }
            // Settle to normal
            UIView.addKeyframe(withRelativeStartTime: 0.65, relativeDuration: 0.35) {
                self.circleView.transform = .identity
            }
        }
    }
}

// MARK: - Enroll Month Header View

class EnrollMonthHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "EnrollMonthHeaderView"

    private let monthLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let yearLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.5)
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
        addSubview(monthLabel)
        addSubview(yearLabel)

        NSLayoutConstraint.activate([
            monthLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            monthLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            yearLabel.leadingAnchor.constraint(equalTo: monthLabel.trailingAnchor, constant: 4),
            yearLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func configure(with month: SplitCalendarMonth) {
        monthLabel.text = month.shortDisplayName
        yearLabel.text = String(month.year)
    }
}

// MARK: - Weekday Header View

class EnrollWeekdayHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "EnrollWeekdayHeaderView"

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var weekdayLabels: [UILabel] = []
    private let weekdays = ["SUN", "MON", "TUES", "WED", "THU", "FRI", "SAT"]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        for weekday in weekdays {
            let label = UILabel()
            label.text = weekday
            label.font = .systemFont(ofSize: 12, weight: .bold)
            label.textAlignment = .center
            label.textColor = UIColor.white.withAlphaComponent(0.5)
            weekdayLabels.append(label)
            stackView.addArrangedSubview(label)
        }
    }

    func configure(enabledDays: Set<Int>) {
        for (index, label) in weekdayLabels.enumerated() {
            label.textColor = UIColor.white.withAlphaComponent(enabledDays.contains(index) ? 0.5 : 0.2)
        }
    }
}

// MARK: - Enroll Calendar Layout

class EnrollCalendarLayout: UICollectionViewLayout {

    static let monthHeaderKind = "MonthHeader"
    static let weekdayHeaderKind = "WeekdayHeader"
    static let weekHighlightKind = WeekHighlightDecorationView.elementKind

    // Configuration
    var cellSize: CGSize = CGSize(width: 48, height: 56)
    var monthHeaderHeight: CGFloat = 48
    var weekdayHeaderHeight: CGFloat = 32
    var horizontalPadding: CGFloat = 16
    let circleSize: CGFloat = 45  // For highlight height

    var dayDataProvider: ((IndexPath) -> SplitCalendarDay?)?

    /// Week highlight information provided externally
    var weekHighlights: [WeekHighlightInfo] = []

    // Cached attributes
    private var cachedCellAttributes: [UICollectionViewLayoutAttributes] = []
    private var cachedMonthHeaderAttributes: [Int: UICollectionViewLayoutAttributes] = [:]
    private var cachedWeekdayHeaderAttributes: [Int: UICollectionViewLayoutAttributes] = [:]
    private var cachedDecorationAttributes: [String: UICollectionViewLayoutAttributes] = [:]  // Key: section-row
    private var contentHeight: CGFloat = 0

    // Section base Y offsets for calculating decoration frames
    private var sectionBaseYOffsets: [Int: CGFloat] = [:]

    private var contentWidth: CGFloat {
        guard let collectionView = collectionView else { return 0 }
        return collectionView.bounds.width - collectionView.contentInset.left - collectionView.contentInset.right
    }

    private var cellWidth: CGFloat {
        return (contentWidth - horizontalPadding * 2) / 7
    }

    override var collectionViewContentSize: CGSize {
        return CGSize(width: contentWidth, height: contentHeight)
    }

    override func prepare() {
        guard let collectionView = collectionView else { return }

        cachedCellAttributes.removeAll()
        cachedMonthHeaderAttributes.removeAll()
        cachedWeekdayHeaderAttributes.removeAll()
        cachedDecorationAttributes.removeAll()
        sectionBaseYOffsets.removeAll()

        let numberOfSections = collectionView.numberOfSections
        guard numberOfSections > 0 else {
            contentHeight = 0
            return
        }

        var yOffset: CGFloat = 0

        for section in 0..<numberOfSections {
            let numberOfItems = collectionView.numberOfItems(inSection: section)
            guard numberOfItems > 0 else { continue }

            // Month header
            let monthHeaderAttributes = UICollectionViewLayoutAttributes(
                forSupplementaryViewOfKind: Self.monthHeaderKind,
                with: IndexPath(item: 0, section: section)
            )
            monthHeaderAttributes.frame = CGRect(
                x: horizontalPadding,
                y: yOffset,
                width: contentWidth - horizontalPadding * 2,
                height: monthHeaderHeight
            )
            cachedMonthHeaderAttributes[section] = monthHeaderAttributes
            yOffset += monthHeaderHeight

            // Weekday header
            let weekdayHeaderAttributes = UICollectionViewLayoutAttributes(
                forSupplementaryViewOfKind: Self.weekdayHeaderKind,
                with: IndexPath(item: 0, section: section)
            )
            weekdayHeaderAttributes.frame = CGRect(
                x: horizontalPadding,
                y: yOffset,
                width: contentWidth - horizontalPadding * 2,
                height: weekdayHeaderHeight
            )
            cachedWeekdayHeaderAttributes[section] = weekdayHeaderAttributes
            yOffset += weekdayHeaderHeight

            // Store section base Y offset (where day cells start)
            sectionBaseYOffsets[section] = yOffset

            // Day cells
            var maxRowIndex = 0

            for item in 0..<numberOfItems {
                let indexPath = IndexPath(item: item, section: section)
                let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)

                if let day = dayDataProvider?(indexPath) {
                    let column = day.weekdayIndex
                    let row = day.rowIndex
                    maxRowIndex = max(maxRowIndex, row)

                    let cellY = yOffset + CGFloat(row) * cellSize.height
                    let cellX = horizontalPadding + CGFloat(column) * cellWidth

                    attributes.frame = CGRect(
                        x: cellX,
                        y: cellY,
                        width: cellWidth,
                        height: cellSize.height
                    )
                } else {
                    // Fallback
                    let column = item % 7
                    let row = item / 7
                    maxRowIndex = max(maxRowIndex, row)

                    let cellY = yOffset + CGFloat(row) * cellSize.height
                    let cellX = horizontalPadding + CGFloat(column) * cellWidth

                    attributes.frame = CGRect(
                        x: cellX,
                        y: cellY,
                        width: cellWidth,
                        height: cellSize.height
                    )
                }

                cachedCellAttributes.append(attributes)
            }

            let numberOfRows = maxRowIndex + 1
            let sectionHeight = CGFloat(numberOfRows) * cellSize.height
            yOffset += sectionHeight + 16  // Add spacing between months
        }

        contentHeight = yOffset

        // Calculate decoration frames for week highlights
        prepareDecorationAttributes()
    }

    /// Calculate decoration view attributes for week highlights
    private func prepareDecorationAttributes() {
        NSLog("🔵 prepareDecorationAttributes: weekHighlights=\(weekHighlights.count)")

        for (index, info) in weekHighlights.enumerated() {
            guard let baseY = sectionBaseYOffsets[info.section] else {
                NSLog("🔴 No baseY for section \(info.section)")
                continue
            }

            // Calculate the frame for this week's highlight
            let rowY = baseY + CGFloat(info.rowIndex) * cellSize.height
            let centerY = rowY + (cellSize.height - circleSize) / 2

            // X position: from start column to end column
            let startX = horizontalPadding + CGFloat(info.startColumn) * cellWidth
            let endX = horizontalPadding + CGFloat(info.endColumn + 1) * cellWidth

            // Adjust for circle radius at edges
            // The highlight should start/end at the circle edges, not cell edges
            var highlightX = startX
            var highlightEndX = endX

            // If first week, start at left edge of circle (cell center - circle radius)
            if info.isFirstWeekInRange {
                let cellCenter = startX + cellWidth / 2
                highlightX = cellCenter - circleSize / 2
            }

            // If last week, end at right edge of circle (cell center + circle radius)
            if info.isLastWeekInRange {
                let lastCellCenter = horizontalPadding + CGFloat(info.endColumn) * cellWidth + cellWidth / 2
                highlightEndX = lastCellCenter + circleSize / 2
            }

            let highlightWidth = highlightEndX - highlightX

            let frame = CGRect(
                x: highlightX,
                y: centerY,
                width: highlightWidth,
                height: circleSize
            )

            // Create attributes for decoration view
            let indexPath = IndexPath(item: index, section: 0)  // All decorations in section 0
            let attributes = UICollectionViewLayoutAttributes(
                forDecorationViewOfKind: Self.weekHighlightKind,
                with: indexPath
            )
            attributes.frame = frame
            attributes.zIndex = -1  // Behind cells

            cachedDecorationAttributes[info.id] = attributes
            NSLog("🔵 Created decoration attributes for \(info.id): \(frame)")
        }

        NSLog("🔵 cachedDecorationAttributes count: \(cachedDecorationAttributes.count)")
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var visibleAttributes: [UICollectionViewLayoutAttributes] = []

        // Add decoration views first (behind everything)
        for (_, attributes) in cachedDecorationAttributes {
            if attributes.frame.intersects(rect) {
                visibleAttributes.append(attributes)
            }
        }

        for attributes in cachedCellAttributes {
            if attributes.frame.intersects(rect) {
                visibleAttributes.append(attributes)
            }
        }

        for (_, attributes) in cachedMonthHeaderAttributes {
            if attributes.frame.intersects(rect) {
                visibleAttributes.append(attributes)
            }
        }

        for (_, attributes) in cachedWeekdayHeaderAttributes {
            if attributes.frame.intersects(rect) {
                visibleAttributes.append(attributes)
            }
        }

        return visibleAttributes
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return cachedCellAttributes.first { $0.indexPath == indexPath }
    }

    override func layoutAttributesForSupplementaryView(
        ofKind elementKind: String,
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        switch elementKind {
        case Self.monthHeaderKind:
            return cachedMonthHeaderAttributes[indexPath.section]
        case Self.weekdayHeaderKind:
            return cachedWeekdayHeaderAttributes[indexPath.section]
        default:
            return nil
        }
    }

    override func layoutAttributesForDecorationView(
        ofKind elementKind: String,
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        guard elementKind == Self.weekHighlightKind,
              indexPath.item < weekHighlights.count else { return nil }

        let info = weekHighlights[indexPath.item]
        return cachedDecorationAttributes[info.id]
    }

    /// Get decoration attributes by highlight ID (for animation access)
    func decorationAttributes(for highlightId: String) -> UICollectionViewLayoutAttributes? {
        return cachedDecorationAttributes[highlightId]
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView = collectionView else { return false }
        return newBounds.width != collectionView.bounds.width
    }
}

// MARK: - Enroll Calendar Controller

class EnrollCalendarController: UIViewController {

    // MARK: - Properties

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<SplitMonthSection, SplitCalendarDay>!
    private var months: [SplitCalendarMonth] = []

    weak var enrollmentState: EnrollmentDateState?
    var enabledDays: Set<Int> = [1, 2, 3, 4, 5]
    var existingLessonDates: Set<Date> = []  // Dates with existing lessons from active enrollments

    /// Track the previous start date to detect changes and trigger animation
    private var previousStartDate: Date?

    /// Cached week highlights for animation comparison
    private var cachedWeekHighlights: [WeekHighlightInfo] = []

    /// Animation coordinator for traveling highlights
    private var animationCoordinator: HighlightAnimationCoordinator?

    /// Track blackout drag state
    private var isBlackoutDragActive: Bool = false
    private var blackoutDragMode: BlackoutDragMode = .adding
    private var blackoutDragDates: Set<Date> = []

    var onDayTapped: ((SplitCalendarDay) -> Void)?
    var onBlackoutChanged: (() -> Void)?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupDataSource()
        generateMonths()
    }

    // MARK: - Setup

    private func setupCollectionView() {
        let layout = EnrollCalendarLayout()
        layout.dayDataProvider = { [weak self] indexPath in
            guard let self = self,
                  indexPath.section < self.months.count,
                  indexPath.item < self.months[indexPath.section].days.count else {
                return nil
            }
            return self.months[indexPath.section].days[indexPath.item]
        }

        // Register decoration view class with the layout
        layout.register(
            WeekHighlightDecorationView.self,
            forDecorationViewOfKind: EnrollCalendarLayout.weekHighlightKind
        )

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.delegate = self

        // Register cells and headers
        collectionView.register(EnrollDayCell.self, forCellWithReuseIdentifier: EnrollDayCell.reuseIdentifier)
        collectionView.register(
            EnrollMonthHeaderView.self,
            forSupplementaryViewOfKind: EnrollCalendarLayout.monthHeaderKind,
            withReuseIdentifier: EnrollMonthHeaderView.reuseIdentifier
        )
        collectionView.register(
            EnrollWeekdayHeaderView.self,
            forSupplementaryViewOfKind: EnrollCalendarLayout.weekdayHeaderKind,
            withReuseIdentifier: EnrollWeekdayHeaderView.reuseIdentifier
        )

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Add long press gesture
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.3
        collectionView.addGestureRecognizer(longPressGesture)

        // Initialize animation coordinator
        animationCoordinator = HighlightAnimationCoordinator(collectionView: collectionView)
    }

    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<SplitMonthSection, SplitCalendarDay>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, day in
            guard let self = self,
                  let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: EnrollDayCell.reuseIdentifier,
                    for: indexPath
                  ) as? EnrollDayCell else {
                return UICollectionViewCell()
            }

            let state = self.determineCellState(for: day)
            let calendar = Calendar.current
            let dayStart = calendar.startOfDay(for: day.date)
            let hasExistingLessons = self.existingLessonDates.contains(dayStart)
            cell.configure(with: day, state: state, hasExistingLessons: hasExistingLessons)

            return cell
        }

        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self = self else { return nil }

            switch kind {
            case EnrollCalendarLayout.monthHeaderKind:
                guard let header = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: EnrollMonthHeaderView.reuseIdentifier,
                    for: indexPath
                ) as? EnrollMonthHeaderView else { return nil }

                if indexPath.section < self.months.count {
                    header.configure(with: self.months[indexPath.section])
                }
                return header

            case EnrollCalendarLayout.weekdayHeaderKind:
                guard let header = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: EnrollWeekdayHeaderView.reuseIdentifier,
                    for: indexPath
                ) as? EnrollWeekdayHeaderView else { return nil }

                header.configure(enabledDays: self.enabledDays)
                return header

            default:
                return nil
            }
        }
    }

    // MARK: - Data

    private func generateMonths() {
        let calendar = Calendar.current
        var date = Date()

        for _ in 0..<12 {
            months.append(SplitCalendarMonth.generate(for: date))
            date = calendar.date(byAdding: .month, value: 1, to: date) ?? date
        }

        applySnapshot()
    }

    func applySnapshot(animatingDifferences: Bool = false) {
        var snapshot = NSDiffableDataSourceSnapshot<SplitMonthSection, SplitCalendarDay>()

        for month in months {
            let section = SplitMonthSection(year: month.year, month: month.month)
            snapshot.appendSections([section])
            snapshot.appendItems(month.days, toSection: section)
        }

        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    func reloadData() {
        // Note: Don't update week highlights here - let checkForStartDateChange handle it
        // to ensure proper animation comparison with cached highlights
        collectionView.reloadData()
        // Force layout to ensure decoration attributes are ready for animation
        collectionView.layoutIfNeeded()
    }

    /// Update week highlights in the layout
    /// - Parameter animated: If true, uses traveling animation (for start date changes)
    private func updateWeekHighlights(animated: Bool = false) {
        guard let layout = collectionView.collectionViewLayout as? EnrollCalendarLayout,
              let state = enrollmentState else {
            NSLog("🔴 updateWeekHighlights: No layout or state")
            return
        }

        let newHighlights = state.calculateWeekHighlights(months: months)

        NSLog("🔵 updateWeekHighlights: animated=\(animated), cached=\(cachedWeekHighlights.count), new=\(newHighlights.count)")

        if animated, !cachedWeekHighlights.isEmpty, !newHighlights.isEmpty {
            // Determine animation direction based on comparing start dates
            let direction: HighlightTravelDirection
            if let oldFirst = cachedWeekHighlights.first,
               let newFirst = newHighlights.first {
                // Compare section first, then row
                if newFirst.section != oldFirst.section {
                    direction = newFirst.section > oldFirst.section ? .forward : .backward
                } else if newFirst.rowIndex != oldFirst.rowIndex {
                    direction = newFirst.rowIndex > oldFirst.rowIndex ? .forward : .backward
                } else {
                    // Same week - compare columns
                    direction = newFirst.startColumn > oldFirst.startColumn ? .forward : .backward
                }
                NSLog("🔵 Direction: \(direction), old=\(oldFirst.id), new=\(newFirst.id)")
            } else {
                direction = .forward
            }

            // Animate existing decoration views BEFORE updating layout
            animateHighlightTransition(
                from: cachedWeekHighlights,
                to: newHighlights,
                direction: direction
            ) { [weak self] in
                // After animation, update layout with final state
                NSLog("🔵 Animation done, updating layout with new highlights")
                layout.weekHighlights = newHighlights
                layout.invalidateLayout()
                self?.collectionView.layoutIfNeeded()
            }

            // Cache AFTER starting animation (so animation can compare old vs new)
            cachedWeekHighlights = newHighlights
        } else {
            // No animation, just update
            NSLog("🔵 No animation, just updating layout")
            layout.weekHighlights = newHighlights
            layout.invalidateLayout()
            // Cache for next comparison
            cachedWeekHighlights = newHighlights
        }
    }

    /// Animate highlight transition using temporary overlay views
    /// Animates each week sequentially for a "traveling" effect
    /// Only animates weeks between the old start date and new start date
    private func animateHighlightTransition(
        from oldHighlights: [WeekHighlightInfo],
        to newHighlights: [WeekHighlightInfo],
        direction: HighlightTravelDirection,
        completion: @escaping () -> Void
    ) {
        guard let layout = collectionView.collectionViewLayout as? EnrollCalendarLayout else {
            NSLog("🔴 Animation: No layout found")
            completion()
            return
        }

        NSLog("🔵 Animation: oldHighlights=\(oldHighlights.count), newHighlights=\(newHighlights.count), direction=\(direction)")

        // Get the first week of old and new highlights (where start dates are)
        guard let oldFirstWeek = oldHighlights.first,
              let newFirstWeek = newHighlights.first else {
            NSLog("🔴 No first week found")
            completion()
            return
        }

        NSLog("🔵 Old start week: \(oldFirstWeek.id), New start week: \(newFirstWeek.id)")

        // Helper to compare week positions
        func weekPosition(_ w: WeekHighlightInfo) -> (Int, Int) {
            return (w.section, w.rowIndex)
        }

        func isWeekBefore(_ w1: WeekHighlightInfo, _ w2: WeekHighlightInfo) -> Bool {
            if w1.section != w2.section { return w1.section < w2.section }
            return w1.rowIndex < w2.rowIndex
        }

        func isWeekAfter(_ w1: WeekHighlightInfo, _ w2: WeekHighlightInfo) -> Bool {
            if w1.section != w2.section { return w1.section > w2.section }
            return w1.rowIndex > w2.rowIndex
        }

        // Check if old and new start are in the same week
        let sameWeek = (oldFirstWeek.section == newFirstWeek.section &&
                        oldFirstWeek.rowIndex == newFirstWeek.rowIndex)

        // For forward: we animate OLD highlights shrinking away
        // For backward: we animate NEW highlights growing into view
        let weeksToAnimate: [WeekHighlightInfo]
        let sortedWeeks: [WeekHighlightInfo]
        let isGrowingAnimation: Bool  // true = grow into view, false = shrink away

        if sameWeek {
            // Same week, different day - determine direction by column position
            if direction == .backward {
                // Going backward in same week (e.g., Dec 24 → Dec 22)
                // Highlight needs to GROW to include earlier days
                weeksToAnimate = [newFirstWeek]
                isGrowingAnimation = true
            } else {
                // Going forward in same week (e.g., Dec 22 → Dec 24)
                // Highlight needs to SHRINK, losing earlier days
                weeksToAnimate = [oldFirstWeek]
                isGrowingAnimation = false
            }
            sortedWeeks = weeksToAnimate
            NSLog("🔵 Same week animation: direction=\(direction), growing=\(isGrowingAnimation)")
        } else if direction == .forward {
            // Forward: new start is AFTER old start
            // Animate OLD weeks shrinking away (from old start up to new start)
            isGrowingAnimation = false
            weeksToAnimate = oldHighlights.filter { week in
                let isAtOrAfterOld = !isWeekBefore(week, oldFirstWeek)
                let isBeforeNew = isWeekBefore(week, newFirstWeek)
                return isAtOrAfterOld && isBeforeNew
            }
            // Sort from first to last (old start toward new start)
            sortedWeeks = weeksToAnimate.sorted { w1, w2 in
                if w1.section != w2.section { return w1.section < w2.section }
                return w1.rowIndex < w2.rowIndex
            }
        } else {
            // Backward: new start is BEFORE old start
            // Animate NEW weeks growing into view (from old start back to new start)
            isGrowingAnimation = true
            weeksToAnimate = newHighlights.filter { week in
                // Include weeks from new start up to (but not including) old start
                let isAtOrAfterNew = !isWeekBefore(week, newFirstWeek)
                let isBeforeOld = isWeekBefore(week, oldFirstWeek)
                return isAtOrAfterNew && isBeforeOld
            }
            // Sort from last to first (old start backward toward new start)
            sortedWeeks = weeksToAnimate.sorted { w1, w2 in
                if w1.section != w2.section { return w1.section > w2.section }
                return w1.rowIndex > w2.rowIndex
            }
        }

        NSLog("🔵 Weeks to animate: \(sortedWeeks.count), growing=\(isGrowingAnimation)")

        // For growing animation (backward), we need to update layout first to get new positions
        // Then IMMEDIATELY hide the decoration views that will be animated
        if isGrowingAnimation {
            // Update layout with new highlights first
            completion()
            collectionView.layoutIfNeeded()

            // Build a set of Y positions for weeks that will be animated
            var animatingYPositions: Set<CGFloat> = []
            for highlight in sortedWeeks {
                if let attrs = layout.decorationAttributes(for: highlight.id) {
                    // Round to avoid floating point issues
                    animatingYPositions.insert(round(attrs.frame.origin.y))
                }
            }

            // Hide decoration views at those Y positions
            for subview in collectionView.subviews {
                if let decorationView = subview as? WeekHighlightDecorationView {
                    let roundedY = round(decorationView.frame.origin.y)
                    if animatingYPositions.contains(roundedY) {
                        decorationView.alpha = 0
                        NSLog("🔵 Hiding decoration view at y=\(roundedY)")
                    }
                }
            }
            NSLog("🔵 Animating Y positions: \(animatingYPositions), hidden count checked")
        }

        // Create overlay views for each week (in order)
        var overlayData: [(view: UIView, highlight: WeekHighlightInfo, fullFrame: CGRect)] = []

        for highlight in sortedWeeks {
            if let attributes = layout.decorationAttributes(for: highlight.id) {
                let fullFrame = attributes.frame
                let overlay = UIView()
                overlay.backgroundColor = UIColor(Color(hex: "#3D2C8C"))
                overlay.layer.cornerRadius = 22.5

                if isGrowingAnimation {
                    // Start with zero width on the right side
                    overlay.frame = CGRect(
                        x: fullFrame.maxX,
                        y: fullFrame.origin.y,
                        width: 0,
                        height: fullFrame.height
                    )
                } else {
                    // Start at full size for shrinking
                    overlay.frame = fullFrame
                }

                // Insert overlay above decoration views but below cells
                // Find the first cell and insert below it, or add to subviews if no cells
                if let firstCell = collectionView.visibleCells.first {
                    collectionView.insertSubview(overlay, belowSubview: firstCell)
                } else {
                    collectionView.addSubview(overlay)
                    collectionView.sendSubviewToBack(overlay)
                }
                overlayData.append((view: overlay, highlight: highlight, fullFrame: fullFrame))
                NSLog("🔵 Created overlay for \(highlight.id), fullFrame: \(fullFrame), initial: \(overlay.frame)")
            } else {
                NSLog("🔴 No attributes found for highlight: \(highlight.id)")
            }
        }

        // If no overlays, complete immediately
        guard !overlayData.isEmpty else {
            NSLog("🔵 No overlays to animate, completing")
            if !isGrowingAnimation {
                completion()
            }
            collectionView.layoutIfNeeded()
            return
        }

        // Hide decoration views for shrinking animation (growing already hidden above)
        if !isGrowingAnimation {
            for subview in collectionView.subviews {
                if let decorationView = subview as? WeekHighlightDecorationView {
                    for (_, highlight, _) in overlayData {
                        if let attrs = layout.decorationAttributes(for: highlight.id),
                           abs(decorationView.frame.origin.y - attrs.frame.origin.y) < 1 {
                            decorationView.alpha = 0
                            break
                        }
                    }
                }
            }
        }

        // Animation timing
        let perWeekDuration: TimeInterval = 0.15
        let overlapDelay: TimeInterval = 0.08

        // Animate each week sequentially
        animateWeekSequentially(
            overlays: overlayData,
            index: 0,
            isGrowing: isGrowingAnimation,
            duration: perWeekDuration,
            delay: overlapDelay
        ) { [weak self] in
            guard let self = self else { return }

            NSLog("🔵 All week animations complete")

            // Remove all overlay views
            for (overlay, _, _) in overlayData {
                overlay.removeFromSuperview()
            }

            // For shrinking animation, update layout now
            if !isGrowingAnimation {
                completion()
            }

            // Force layout
            self.collectionView.layoutIfNeeded()

            // Show all decoration views
            for subview in self.collectionView.subviews {
                if subview is WeekHighlightDecorationView {
                    subview.alpha = 1
                }
            }
        }
    }

    /// Recursively animate each week's overlay in sequence
    private func animateWeekSequentially(
        overlays: [(view: UIView, highlight: WeekHighlightInfo, fullFrame: CGRect)],
        index: Int,
        isGrowing: Bool,
        duration: TimeInterval,
        delay: TimeInterval,
        completion: @escaping () -> Void
    ) {
        guard index < overlays.count else {
            // All done - wait for last animation to finish
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                completion()
            }
            return
        }

        let (overlay, highlight, fullFrame) = overlays[index]

        NSLog("🔵 Animating week \(index + 1)/\(overlays.count): \(highlight.id), growing=\(isGrowing)")

        // Start this week's animation
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: .curveEaseInOut
        ) {
            if isGrowing {
                // Grow from right to left: expand to full frame
                overlay.frame = fullFrame
                overlay.alpha = 1
            } else {
                // Shrink from left to right: move origin right, reduce width to 0
                overlay.frame = CGRect(
                    x: fullFrame.maxX,
                    y: fullFrame.origin.y,
                    width: 0,
                    height: fullFrame.height
                )
                overlay.alpha = 0
            }
        }

        // Start next week after overlap delay (before this one finishes)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.animateWeekSequentially(
                overlays: overlays,
                index: index + 1,
                isGrowing: isGrowing,
                duration: duration,
                delay: delay,
                completion: completion
            )
        }
    }

    // MARK: - State Determination

    private func determineCellState(for day: SplitCalendarDay) -> EnrollDayCellState {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayDate = calendar.startOfDay(for: day.date)

        // Past dates are dimmed
        if dayDate < today {
            return .dimmed
        }

        // Non-current month days are dimmed
        if !day.isCurrentMonth {
            return .dimmed
        }

        let weekday = calendar.component(.weekday, from: day.date) - 1
        let isWeekdayEnabled = enabledDays.contains(weekday)

        guard let state = enrollmentState else {
            // No selection yet - dim disabled weekdays
            if !isWeekdayEnabled {
                return .dimmed
            }
            return .normal
        }

        // Start date
        if state.isStartDate(day.date) {
            return .startDate
        }

        // End date
        if state.isEndDate(day.date) {
            return .endDate
        }

        // Check if in the range (between start and end)
        if state.isInRangeBackground(day.date) {
            // Manually overridden by user
            if state.isOverridden(day.date) {
                // If weekday was enabled, override removes it (red)
                // If weekday was disabled, override adds it (yellow)
                return isWeekdayEnabled ? .overrideRemoved : .overrideAdded
            }

            // Disabled weekday in range - dimmed text but has highlight
            if !isWeekdayEnabled {
                return .inRangeDimmed
            }

            // Normal day in range
            return .inRange
        }

        // Not in range - dim disabled weekdays
        if !isWeekdayEnabled {
            return .dimmed
        }

        return .normal
    }

    // MARK: - Gestures

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let point = gesture.location(in: collectionView)

        switch gesture.state {
        case .began:
            // Start blackout drag
            guard let indexPath = collectionView.indexPathForItem(at: point),
                  indexPath.section < months.count,
                  indexPath.item < months[indexPath.section].days.count else { return }

            let day = months[indexPath.section].days[indexPath.item]

            // Only allow blackout on days in range (not start date)
            guard let state = enrollmentState,
                  state.isInRangeBackground(day.date),
                  !state.isStartDate(day.date) else { return }

            let calendar = Calendar.current
            let dayDate = calendar.startOfDay(for: day.date)

            // Determine mode based on whether the day is currently part of the schedule
            // If included → removing mode (we'll exclude days)
            // If excluded → adding mode (we'll include days)
            let isCurrentlyIncluded = state.isDateIncluded(day.date)
            blackoutDragMode = isCurrentlyIncluded ? .removing : .adding

            // Toggle override for this day
            state.toggleOverride(day.date)

            isBlackoutDragActive = true
            blackoutDragDates = [dayDate]

            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()

            // Reload to show change
            reloadData()
            onBlackoutChanged?()

        case .changed:
            guard isBlackoutDragActive else { return }

            // Find day under current touch
            guard let indexPath = collectionView.indexPathForItem(at: point),
                  indexPath.section < months.count,
                  indexPath.item < months[indexPath.section].days.count else { return }

            let day = months[indexPath.section].days[indexPath.item]

            guard let state = enrollmentState,
                  state.isInRangeBackground(day.date),
                  !state.isStartDate(day.date) else { return }

            let calendar = Calendar.current
            let dayDate = calendar.startOfDay(for: day.date)

            // Skip if we've already processed this date in this drag
            guard !blackoutDragDates.contains(dayDate) else { return }

            blackoutDragDates.insert(dayDate)

            // Apply the drag mode based on current inclusion state
            let isCurrentlyIncluded = state.isDateIncluded(day.date)

            // Only toggle if the day matches our intent:
            // - Removing mode: only affect days that are currently included
            // - Adding mode: only affect days that are currently excluded
            let shouldToggle = (blackoutDragMode == .removing && isCurrentlyIncluded) ||
                               (blackoutDragMode == .adding && !isCurrentlyIncluded)

            guard shouldToggle else { return }

            state.toggleOverride(day.date)

            // Light haptic for each toggled cell
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()

            // Reload to show change
            reloadData()
            onBlackoutChanged?()

        case .ended, .cancelled:
            isBlackoutDragActive = false
            blackoutDragDates.removeAll()

        default:
            break
        }
    }

    // MARK: - Highlight Animation

    /// Check if start date changed and trigger traveling animation if so
    func checkForStartDateChange() {
        let currentStartDate = enrollmentState?.startDate

        // If start date changed and we had a previous date, trigger traveling animation
        if let current = currentStartDate, let previous = previousStartDate {
            if !Calendar.current.isDate(current, inSameDayAs: previous) {
                // Trigger traveling animation with updated highlights
                NSLog("🔵 Start date changed from \(previous) to \(current), animating...")
                updateWeekHighlights(animated: true)

                // Trigger bounce animation on the new start date circle after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.animateStartDateBounce()
                }
            } else {
                // Same date, just refresh highlights (e.g., after override changes)
                updateWeekHighlights(animated: false)
            }
        } else if currentStartDate != nil && previousStartDate == nil {
            // First selection - no animation, just update
            NSLog("🔵 First start date selection: \(currentStartDate!)")
            updateWeekHighlights(animated: false)

            // Bounce animation for first selection too
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.animateStartDateBounce()
            }
        } else if currentStartDate == nil && previousStartDate != nil {
            // Start date cleared
            updateWeekHighlights(animated: false)
        } else {
            // No start date, refresh in case enabled days changed
            updateWeekHighlights(animated: false)
        }

        previousStartDate = currentStartDate
    }

    /// Find the cell for the current start date and trigger bounce animation
    private func animateStartDateBounce() {
        guard let startDate = enrollmentState?.startDate else { return }

        // Find the cell for this date
        for (sectionIndex, month) in months.enumerated() {
            for (dayIndex, day) in month.days.enumerated() {
                if Calendar.current.isDate(day.date, inSameDayAs: startDate) {
                    let indexPath = IndexPath(item: dayIndex, section: sectionIndex)
                    if let cell = collectionView.cellForItem(at: indexPath) as? EnrollDayCell {
                        cell.animateCircleBounce()
                    }
                    return
                }
            }
        }
    }
}

// MARK: - Collection View Delegate

extension EnrollCalendarController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.section < months.count,
              indexPath.item < months[indexPath.section].days.count else { return }

        let day = months[indexPath.section].days[indexPath.item]
        onDayTapped?(day)
    }
}

// MARK: - UIViewControllerRepresentable

struct EnrollCalendarRepresentable: UIViewControllerRepresentable {
    @ObservedObject var state: EnrollmentDateState
    var existingLessonDates: Set<Date> = []
    var onOverrideDayTapped: ((Date) -> Void)?
    var onRegularDayTapped: ((Date) -> Void)?

    func makeUIViewController(context: Context) -> EnrollCalendarController {
        let controller = EnrollCalendarController()
        controller.enrollmentState = state
        controller.enabledDays = state.enabledDays
        controller.existingLessonDates = existingLessonDates

        controller.onDayTapped = { day in
            // Check if this day has an override
            if state.isOverridden(day.date) && state.isInRangeBackground(day.date) {
                onOverrideDayTapped?(day.date)
            } else {
                onRegularDayTapped?(day.date)
            }
        }

        // Blackout changes trigger UI update
        controller.onBlackoutChanged = {
            // State is already updated by the controller
            // This callback can be used for additional side effects if needed
        }

        return controller
    }

    func updateUIViewController(_ controller: EnrollCalendarController, context: Context) {
        controller.enrollmentState = state
        controller.enabledDays = state.enabledDays
        controller.existingLessonDates = existingLessonDates
        controller.reloadData()
        // Check if start date changed and trigger highlight flash
        controller.checkForStartDateChange()
    }
}

// MARK: - Main Page

/// Configuration options for SelectEnrollDatePage
struct SelectEnrollDateConfig {
    var title: String = "Select schedule"
    var leftIcon: String = "chevron.left"
    var rightButtonText: String = "Next"

    static let `default` = SelectEnrollDateConfig()

    /// Configuration for enrollment flow (Step 2)
    static let enrollmentFlow = SelectEnrollDateConfig(
        title: "Select dates",
        leftIcon: "chevron.left",
        rightButtonText: "Next"
    )
}

struct SelectEnrollDatePage: View {
    let lessonCount: Int
    let config: SelectEnrollDateConfig
    let existingLessonDates: Set<Date>  // Dates with existing lessons from active enrollments
    let onDismiss: () -> Void
    let onSelect: ((Date, Date, Set<Int>) -> Void)?

    // State management - use @ObservedObject for external state to observe changes
    @ObservedObject private var externalState: EnrollmentDateState
    @StateObject private var internalState: EnrollmentDateState
    private let useExternalState: Bool

    /// The active state (external if provided, otherwise internal)
    private var state: EnrollmentDateState {
        useExternalState ? externalState : internalState
    }

    @State private var showOverrideConfirmation = false
    @State private var tappedOverrideDate: Date?
    @State private var showOverlapConfirmation = false
    @State private var pendingStartDate: Date?

    /// Formatted date for the dialog title (e.g., "Monday, December 23")
    private var formattedTappedDate: String {
        guard let date = tappedOverrideDate else { return "Override Day" }
        return CalendarFormatters.fullDateHeader.string(from: date)
    }

    /// Explanation of what the override means for this day
    private var overrideExplanation: String {
        guard let date = tappedOverrideDate else { return "" }
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) - 1
        let isWeekdayEnabled = state.enabledDays.contains(weekday)

        if isWeekdayEnabled {
            // Override removes this day from schedule
            return "This day has been manually removed from the schedule."
        } else {
            // Override adds this day to schedule
            return "This day has been manually added to the schedule."
        }
    }

    /// Handle date selection with overlap check
    private func handleDateSelection(_ date: Date) {
        // Check if selecting this date would create an overlap with existing lessons
        let potentialDates = calculatePotentialDates(startingFrom: date)
        let calendar = Calendar.current
        let overlappingDates = potentialDates.filter { potentialDate in
            let dayStart = calendar.startOfDay(for: potentialDate)
            return existingLessonDates.contains(dayStart)
        }

        if overlappingDates.isEmpty {
            // No overlap, proceed normally
            state.selectStartDate(date)
        } else {
            // Overlap detected, show confirmation
            pendingStartDate = date
            showOverlapConfirmation = true
        }
    }

    /// Calculate what dates would be included if this date is selected as start
    private func calculatePotentialDates(startingFrom startDate: Date) -> Set<Date> {
        let calendar = Calendar.current
        var dates: Set<Date> = []
        var currentDate = startDate
        var lessonsScheduled = 0

        // Safety limit to prevent infinite loops
        let maxIterations = state.lessonCount * 10

        for _ in 0..<maxIterations {
            let weekday = calendar.component(.weekday, from: currentDate) - 1
            let isWeekdayEnabled = state.enabledDays.contains(weekday)
            let dayStart = calendar.startOfDay(for: currentDate)
            let isOverridden = state.overriddenDates.contains(dayStart)

            // Determine if this date would be included
            let isIncluded = isWeekdayEnabled != isOverridden

            if isIncluded {
                dates.insert(dayStart)
                lessonsScheduled += 1

                if lessonsScheduled >= state.lessonCount {
                    break
                }
            }

            // Move to next day
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return dates
    }

    /// Standalone initializer - creates its own state
    init(
        lessonCount: Int = 30,
        config: SelectEnrollDateConfig = .default,
        existingLessonDates: Set<Date> = [],
        onDismiss: @escaping () -> Void = {},
        onSelect: ((Date, Date, Set<Int>) -> Void)? = nil
    ) {
        self.lessonCount = lessonCount
        self.config = config
        self.existingLessonDates = existingLessonDates
        self.onDismiss = onDismiss
        self.onSelect = onSelect
        self.useExternalState = false
        // Create placeholder external state (won't be used)
        self._externalState = ObservedObject(wrappedValue: EnrollmentDateState(lessonCount: lessonCount))
        self._internalState = StateObject(wrappedValue: EnrollmentDateState(lessonCount: lessonCount))
    }

    /// Embedded initializer - uses external state (for enrollment flow)
    init(
        state: EnrollmentDateState,
        config: SelectEnrollDateConfig = .enrollmentFlow,
        existingLessonDates: Set<Date> = [],
        onDismiss: @escaping () -> Void = {},
        onSelect: ((Date, Date, Set<Int>) -> Void)? = nil
    ) {
        self.lessonCount = state.lessonCount
        self.config = config
        self.existingLessonDates = existingLessonDates
        self.onDismiss = onDismiss
        self.onSelect = onSelect
        self.useExternalState = true
        self._externalState = ObservedObject(wrappedValue: state)
        // Create a placeholder internal state (won't be used)
        self._internalState = StateObject(wrappedValue: EnrollmentDateState(lessonCount: state.lessonCount))
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                PageTitle.iconTitleLink(
                    title: config.title,
                    leftIcon: config.leftIcon,
                    rightLink: config.rightButtonText,
                    rightLinkDisabled: state.startDate == nil,
                    onLeftIconTap: onDismiss,
                    onRightLinkTap: {
                        if let start = state.startDate, let end = state.calculatedEndDate {
                            onSelect?(start, end, state.enabledDays)
                        }
                    }
                )

                // UIKit Calendar
                EnrollCalendarRepresentable(
                    state: state,
                    existingLessonDates: existingLessonDates,
                    onOverrideDayTapped: { date in
                        tappedOverrideDate = date
                        showOverrideConfirmation = true
                    },
                    onRegularDayTapped: { date in
                        handleDateSelection(date)
                    }
                )

                // Bottom panel
                SelectedRangePanel(state: state)
            }
        }
        .confirmationDialog(
            formattedTappedDate,
            isPresented: $showOverrideConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Override", role: .destructive) {
                if let date = tappedOverrideDate {
                    state.toggleOverride(date)
                }
            }
            Button("Set as Start Date") {
                if let date = tappedOverrideDate {
                    state.selectStartDate(date, force: true)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(overrideExplanation)
        }
        .alert("Already enrolled", isPresented: $showOverlapConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingStartDate = nil
            }
            Button("Confirm") {
                if let date = pendingStartDate {
                    state.selectStartDate(date)
                }
                pendingStartDate = nil
            }
        } message: {
            Text("We highly recommend no more than one lesson per day per member. Please confirm")
        }
    }
}

// MARK: - Bottom Panel

struct SelectedRangePanel: View {
    @ObservedObject var state: EnrollmentDateState

    var body: some View {
        VStack(spacing: 0) {
            // Date range display
            Text(state.formattedDateRange)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.2)
                .foregroundColor(.white)
                .padding(.vertical, 10)

            // Day of week picker
            DayOfWeekPicker(state: state)
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8)
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Day of Week Picker

struct DayOfWeekPicker: View {
    @ObservedObject var state: EnrollmentDateState

    // Days starting with Sunday (S M T W T F S)
    private let days: [(index: Int, label: String)] = [
        (0, "S"),   // Sunday
        (1, "M"),   // Monday
        (2, "T"),   // Tuesday
        (3, "W"),   // Wednesday
        (4, "T"),   // Thursday
        (5, "F"),   // Friday
        (6, "S"),   // Saturday
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.index) { day in
                DayOfWeekToggle(
                    label: day.label,
                    isEnabled: state.enabledDays.contains(day.index),
                    onToggle: {
                        state.toggleDay(day.index)
                    }
                )
            }
        }
    }
}

// MARK: - Day of Week Toggle

struct DayOfWeekToggle: View {
    let label: String
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isEnabled ? Color(hex: "#0d101a") : .white.opacity(0.5))
                .frame(width: 24, height: 24)
                .background(isEnabled ? Color.white : Color.white.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Rounded Corner Shape

struct RoundedCornerShape: Shape {
    var topLeft: CGFloat = 0
    var topRight: CGFloat = 0
    var bottomLeft: CGFloat = 0
    var bottomRight: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let tl = min(topLeft, min(rect.width, rect.height) / 2)
        let tr = min(topRight, min(rect.width, rect.height) / 2)
        let bl = min(bottomLeft, min(rect.width, rect.height) / 2)
        let br = min(bottomRight, min(rect.width, rect.height) / 2)

        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
            radius: tr,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(
            center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
            radius: br,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
            radius: bl,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(
            center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
            radius: tl,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.closeSubpath()

        return path
    }
}

// MARK: - Preview

#Preview {
    SelectEnrollDatePage(
        lessonCount: 30,
        onDismiss: {},
        onSelect: nil
    )
    .preferredColorScheme(.dark)
}
