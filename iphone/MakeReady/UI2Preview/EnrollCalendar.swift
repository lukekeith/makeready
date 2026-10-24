//
//  EnrollCalendar.swift
//  UI2Preview
//
//  The 1.0 enrollment calendar, ported UNCHANGED from Pages/Manage/Group/SelectEnrollDatePage.swift
//  (EnrollmentDateState, the day cells, week-highlight decoration, layout, controller and representable).
//  d2m enrollment-flow design §4/§10: "the calendar body is the 1.0 calendar exactly; only the header and
//  footer change". 1.0 keeps its own copy until the 2.0 cutover (parallel-shell rule). The only edits:
//  SplitCalendar* → EnrollCalendar* (this module's own copies, below), DateFormatters.monthDay and
//  Color.brandPrimary → the local EnrollCalendarStyle values with the same definitions, debug print/NSLog lines
//  removed (project lint), and the 1.0 asyncAfter choreography + three untokened 1.0 colours baselined.
//  C-128 (DateRangePicker.swift wraps this file): the four `Date()` reads take `EnrollmentDateState.today`
//  (default `Date()`) — C-128 §1 deviation 4 / OQ-C-128-002.
//

import SwiftUI
import UIKit

// MARK: - Ported dependencies (same definitions as the app's)

enum EnrollCalendarStyle {
    /// Colors.swift `brandPrimary` — #6C47FF, the same value as the 2.0 token `accent`.
    static let brandPrimary = Token.accent
    /// Colors.swift `Color(hex:)` for the six-digit "#RRGGBB" values the calendar uses.
    static func hex(_ hex: String) -> Color {
        let v = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        return Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
    /// Date+Formatting.swift `DateFormatters.monthDay` — "MMM d".
    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    /// CalendarModels.swift `CalendarFormatters.monthYear` / `dateKey`.
    static let monthYear: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f }()
    static let monthOnly: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMMM"; return f }()
    static let dateKey: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f }()
}

struct EnrollCalendarSection: Hashable {
    let year: Int
    let month: Int

    var id: String { "\(year)-\(String(format: "%02d", month))" }
}

struct EnrollCalendarMonth: Hashable, Identifiable {
    let year: Int
    let month: Int
    var days: [EnrollCalendarDay]

    var id: String { "\(year)-\(String(format: "%02d", month))" }

    var displayName: String {
        let components = DateComponents(year: year, month: month, day: 1)
        guard let date = Calendar.current.date(from: components) else { return "\(month)/\(year)" }
        return EnrollCalendarStyle.monthYear.string(from: date)
    }

    var shortDisplayName: String {
        let components = DateComponents(year: year, month: month, day: 1)
        guard let date = Calendar.current.date(from: components) else { return "\(month)" }
        return EnrollCalendarStyle.monthOnly.string(from: date)
    }

    /// Only the month's own days — no padding from adjacent months (as SplitCalendarMonth.generate).
    static func generate(for date: Date) -> EnrollCalendarMonth {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let firstDayOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth) else {
            return EnrollCalendarMonth(year: year, month: month, days: [])
        }
        let firstWeekdayIndex = calendar.component(.weekday, from: firstDayOfMonth) - 1
        var days: [EnrollCalendarDay] = []
        for day in range {
            var dayComponents = components
            dayComponents.day = day
            let dayDate = calendar.date(from: dayComponents)!
            let dayOffset = day - 1
            days.append(EnrollCalendarDay(
                date: dayDate,
                dayNumber: day,
                isCurrentMonth: true,
                weekdayIndex: (firstWeekdayIndex + dayOffset) % 7,
                rowIndex: (firstWeekdayIndex + dayOffset) / 7
            ))
        }
        return EnrollCalendarMonth(year: year, month: month, days: days)
    }
}

struct EnrollCalendarDay: Hashable, Identifiable {
    let date: Date
    let dayNumber: Int
    let isCurrentMonth: Bool
    let weekdayIndex: Int
    let rowIndex: Int

    var id: String { Self.dateKey(for: date) }
    var isToday: Bool { Calendar.current.isDateInToday(date) }

    static func dateKey(for date: Date) -> String { EnrollCalendarStyle.dateKey.string(from: date) }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: EnrollCalendarDay, rhs: EnrollCalendarDay) -> Bool { lhs.id == rhs.id }
}

// MARK: - Ported from SelectEnrollDatePage.swift (lines 14–2134), unchanged but for the renames above


/// Manages the enrollment date selection state
class EnrollmentDateState: ObservableObject {
    let lessonCount: Int

    @Published var startDate: Date?
    @Published var enabledDays: Set<Int> = [1, 2, 3, 4, 5]  // Mon-Fri (0=Sun, 1=Mon, ... 6=Sat)

    /// Dates that have been manually overridden by the user (long press)
    /// These dates flip their inclusion: enabled weekday becomes excluded, disabled weekday becomes included
    @Published var overriddenDates: Set<Date> = []

    private let calendar = Calendar.current

    /// The reference day — C-128 §4 `today` (OQ-C-128-002, deviation 4) in place of the port's `Date()`
    /// reads. Defaults to `Date()`, so behaviour is unchanged when the caller passes the current day.
    var today = Date()

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

        let formatter = EnrollCalendarStyle.monthDay

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
        let today = calendar.startOfDay(for: self.today)

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
    func calculateWeekHighlights(months: [EnrollCalendarMonth]) -> [WeekHighlightInfo] {
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

/// Ghost fill drawn behind a day to show the enrollment's *current* schedule
/// while picking a new one, so the leader can see what's there today.
enum ScheduleGhostKind {
    case none
    /// Today or later: this lesson WILL be moved by the reschedule → soft white.
    case future
    /// Before today: already delivered, will NOT be moved → distinct yellow.
    case past
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
        view.backgroundColor = UIColor(EnrollCalendarStyle.hex("#3D2C8C"))
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
    private let ghostSize: CGFloat = 40
    private let maxDots: Int = 3
    private let dotSize: CGFloat = 5

    // MARK: - UI Elements

    /// Ghost fill behind the day showing the enrollment's CURRENT schedule while
    /// a new one is being picked (persists regardless of the new selection).
    private let scheduleGhostView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let circleView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(EnrollCalendarStyle.brandPrimary)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let overrideAddedCircle: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.borderColor = UIColor(EnrollCalendarStyle.hex("#57DB8C")).cgColor
        view.layer.borderWidth = 1
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let overrideRemovedCircle: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.borderColor = UIColor(EnrollCalendarStyle.hex("#DE3F87")).cgColor
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

    var day: EnrollCalendarDay?
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

        // Added first → sits behind the circles, label, and dots.
        contentView.addSubview(scheduleGhostView)
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
            // Schedule ghost - centered rounded square behind everything
            scheduleGhostView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            scheduleGhostView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            scheduleGhostView.widthAnchor.constraint(equalToConstant: ghostSize),
            scheduleGhostView.heightAnchor.constraint(equalToConstant: ghostSize),

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

    func configure(
        with day: EnrollCalendarDay,
        state: EnrollDayCellState,
        hasExistingLessons: Bool = false,
        scheduleGhost: ScheduleGhostKind = .none
    ) {
        self.day = day
        self.cellState = state
        self.hasExistingLessons = hasExistingLessons

        // Current-schedule ghost (behind everything). Stays put regardless of
        // the new selection so the leader can see the existing schedule; past
        // lessons get a distinct color since they won't be moved.
        switch scheduleGhost {
        case .none:
            scheduleGhostView.isHidden = true
        case .future:
            scheduleGhostView.isHidden = false
            scheduleGhostView.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        case .past:
            scheduleGhostView.isHidden = false
            scheduleGhostView.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.22)
        }

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
            dayLabel.textColor = UIColor(EnrollCalendarStyle.hex("#57DB8C"))
            circleView.isHidden = true
            overrideAddedCircle.isHidden = false
            overrideRemovedCircle.isHidden = true

        case .overrideRemoved:
            // Manually removed from schedule - pink text with pink border circle
            dayLabel.textColor = UIColor(EnrollCalendarStyle.hex("#DE3F87"))
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
            firstDot.backgroundColor = UIColor(EnrollCalendarStyle.brandPrimary)
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        circleView.layer.cornerRadius = circleSize / 2
        overrideAddedCircle.layer.cornerRadius = overrideCircleSize / 2
        overrideRemovedCircle.layer.cornerRadius = overrideCircleSize / 2
        scheduleGhostView.layer.cornerRadius = ghostSize / 2
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        day = nil
        cellState = .normal
        hasExistingLessons = false
        dayLabel.text = nil
        scheduleGhostView.isHidden = true
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

    func configure(with month: EnrollCalendarMonth) {
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

    var dayDataProvider: ((IndexPath) -> EnrollCalendarDay?)?

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

        for (index, info) in weekHighlights.enumerated() {
            guard let baseY = sectionBaseYOffsets[info.section] else {
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
        }

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
    private var dataSource: UICollectionViewDiffableDataSource<EnrollCalendarSection, EnrollCalendarDay>!
    private var months: [EnrollCalendarMonth] = []

    weak var enrollmentState: EnrollmentDateState?
    var enabledDays: Set<Int> = [1, 2, 3, 4, 5]
    var existingLessonDates: Set<Date> = []  // Dates with existing lessons from active enrollments
    /// This enrollment's CURRENT scheduled lesson dates, rendered as a ghost so
    /// the leader can see the existing schedule while picking a new one.
    var currentScheduleDates: Set<Date> = []

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

    var onDayTapped: ((EnrollCalendarDay) -> Void)?
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
        dataSource = UICollectionViewDiffableDataSource<EnrollCalendarSection, EnrollCalendarDay>(
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
            // Classify the current-schedule ghost: past lessons won't be moved.
            let ghost: ScheduleGhostKind
            if self.currentScheduleDates.contains(dayStart) {
                ghost = dayStart < calendar.startOfDay(for: self.enrollmentState?.today ?? Date()) ? .past : .future
            } else {
                ghost = .none
            }
            cell.configure(with: day, state: state, hasExistingLessons: hasExistingLessons, scheduleGhost: ghost)

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
        var date = enrollmentState?.today ?? Date()

        for _ in 0..<12 {
            months.append(EnrollCalendarMonth.generate(for: date))
            date = calendar.date(byAdding: .month, value: 1, to: date) ?? date
        }

        applySnapshot()
    }

    func applySnapshot(animatingDifferences: Bool = false) {
        var snapshot = NSDiffableDataSourceSnapshot<EnrollCalendarSection, EnrollCalendarDay>()

        for month in months {
            let section = EnrollCalendarSection(year: month.year, month: month.month)
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
            return
        }

        let newHighlights = state.calculateWeekHighlights(months: months)


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
                layout.weekHighlights = newHighlights
                layout.invalidateLayout()
                self?.collectionView.layoutIfNeeded()
            }

            // Cache AFTER starting animation (so animation can compare old vs new)
            cachedWeekHighlights = newHighlights
        } else {
            // No animation, just update
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
            completion()
            return
        }


        // Get the first week of old and new highlights (where start dates are)
        guard let oldFirstWeek = oldHighlights.first,
              let newFirstWeek = newHighlights.first else {
            completion()
            return
        }


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
                    }
                }
            }
        }

        // Create overlay views for each week (in order)
        var overlayData: [(view: UIView, highlight: WeekHighlightInfo, fullFrame: CGRect)] = []

        for highlight in sortedWeeks {
            if let attributes = layout.decorationAttributes(for: highlight.id) {
                let fullFrame = attributes.frame
                let overlay = UIView()
                overlay.backgroundColor = UIColor(EnrollCalendarStyle.hex("#3D2C8C"))
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
            } else {
            }
        }

        // If no overlays, complete immediately
        guard !overlayData.isEmpty else {
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

    private func determineCellState(for day: EnrollCalendarDay) -> EnrollDayCellState {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: enrollmentState?.today ?? Date())
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
    var currentScheduleDates: Set<Date> = []
    var onOverrideDayTapped: ((Date) -> Void)?
    var onRegularDayTapped: ((Date) -> Void)?

    func makeUIViewController(context: Context) -> EnrollCalendarController {
        let controller = EnrollCalendarController()
        controller.enrollmentState = state
        controller.enabledDays = state.enabledDays
        controller.existingLessonDates = existingLessonDates
        controller.currentScheduleDates = currentScheduleDates

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
        controller.currentScheduleDates = currentScheduleDates
        controller.reloadData()
        // Check if start date changed and trigger highlight flash
        controller.checkForStartDateChange()
    }
}

// MARK: - Main Page

/// Configuration options for SelectEnrollDatePage
