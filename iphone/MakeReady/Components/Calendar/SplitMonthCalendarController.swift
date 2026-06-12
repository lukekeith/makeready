//
//  SplitMonthCalendarController.swift
//  MakeReady
//
//  UIViewController that manages the split-month calendar with page transition animation
//

import UIKit
import SwiftUI

class SplitMonthCalendarController: UIViewController {

    // MARK: - Types

    typealias DataSource = UICollectionViewDiffableDataSource<SplitMonthSection, SplitCalendarDay>
    typealias Snapshot = NSDiffableDataSourceSnapshot<SplitMonthSection, SplitCalendarDay>

    // MARK: - Properties

    private var collectionView: UICollectionView!
    private var dataSource: DataSource!
    private var layout: SplitMonthLayout!

    // Split animation views
    private var topSnapshotView: UIImageView?
    private var bottomSnapshotView: UIImageView?
    private var eventListContainer: UIView?
    private var eventListHostingController: UIHostingController<AnyView>?

    // Data
    private var loadedMonths: [SplitCalendarMonth] = []
    private var events: [String: [SplitCalendarEvent]] = [:]

    // State
    private(set) var selectedDate: Date?
    private(set) var selectedIndexPath: IndexPath?
    private(set) var isExpanded: Bool = false
    private var splitPoint: CGFloat = 0 // Y coordinate where the split happens
    private var lastNotifiedMonthId: String?

    // Callbacks
    var onDateSelected: ((Date) -> Void)?
    var onEventTap: ((SplitCalendarEvent) -> Void)?
    var onScrolledToNewMonth: ((SplitCalendarMonth) -> Void)?
    var onExpandedStateChanged: ((Bool) -> Void)?
    var onVisibleEventDateChanged: ((Date) -> Void)?

    /// Callback to request a full-view snapshot from the parent (includes SwiftUI header)
    /// Returns the snapshot image and the Y offset where the collection view starts
    var onRequestFullSnapshot: (() -> (image: UIImage, headerHeight: CGFloat)?)?

    // Configuration
    private let initialMonthRange = 12 // Load 12 months before and after today
    private let loadMoreThreshold: CGFloat = 500

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Color.appBackground)
        view.clipsToBounds = true  // Prevent snapshots from extending beyond view bounds

        setupLayout()
        setupCollectionView()
        setupDataSource()
        loadInitialMonths()
    }

    // MARK: - Setup

    private func setupLayout() {
        layout = SplitMonthLayout()
        layout.mode = .collapsed

        // Provide day data for correct weekday positioning
        layout.dayDataProvider = { [weak self] indexPath in
            guard let self = self,
                  indexPath.section < self.loadedMonths.count else { return nil }
            let month = self.loadedMonths[indexPath.section]
            guard indexPath.item < month.days.count else { return nil }
            return month.days[indexPath.item]
        }
    }

    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.showsVerticalScrollIndicator = true
        collectionView.alwaysBounceVertical = true

        // Prevent automatic scroll adjustments that cause double-tap issues
        collectionView.contentInsetAdjustmentBehavior = .never

        // Register cells
        collectionView.register(
            CalendarDayCell.self,
            forCellWithReuseIdentifier: CalendarDayCell.reuseIdentifier
        )

        // Register supplementary views
        collectionView.register(
            CalendarMonthHeaderView.self,
            forSupplementaryViewOfKind: SplitMonthLayout.monthHeaderKind,
            withReuseIdentifier: CalendarMonthHeaderView.reuseIdentifier
        )

        // Note: Week separators are decoration views registered directly with the layout

        view.addSubview(collectionView)
    }

    private func setupDataSource() {
        dataSource = DataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, day in
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: CalendarDayCell.reuseIdentifier,
                for: indexPath
            ) as? CalendarDayCell else {
                return UICollectionViewCell()
            }

            let isSelected = self?.selectedIndexPath == indexPath
            cell.configure(with: day, isSelected: isSelected)

            return cell
        }

        // Supplementary view provider
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self = self else { return nil }

            switch kind {
            case SplitMonthLayout.monthHeaderKind:
                guard let header = collectionView.dequeueReusableSupplementaryView(
                    ofKind: kind,
                    withReuseIdentifier: CalendarMonthHeaderView.reuseIdentifier,
                    for: indexPath
                ) as? CalendarMonthHeaderView else {
                    return nil
                }

                if indexPath.section < self.loadedMonths.count {
                    let month = self.loadedMonths[indexPath.section]
                    header.configure(with: month)
                }

                return header

            default:
                return nil
            }
        }
    }

    // MARK: - Data Loading

    private func loadInitialMonths() {
        let calendar = Calendar.current
        let today = Date()

        // Generate months from -initialMonthRange to +initialMonthRange
        for offset in -initialMonthRange...initialMonthRange {
            if let date = calendar.date(byAdding: .month, value: offset, to: today) {
                let month = SplitCalendarMonth.generate(for: date, events: events)
                loadedMonths.append(month)
            }
        }

        // Apply snapshot
        applySnapshot(animatingDifferences: false)

        // Scroll to current month (center of the loaded range)
        DispatchQueue.main.async { [weak self] in
            self?.scrollToCurrentMonth(animated: false)
        }
    }

    private func applySnapshot(animatingDifferences: Bool = true) {
        // Guard against calling before viewDidLoad
        guard dataSource != nil else { return }

        var snapshot = Snapshot()

        for month in loadedMonths {
            let section = SplitMonthSection(year: month.year, month: month.month)
            snapshot.appendSections([section])
            snapshot.appendItems(month.days, toSection: section)
        }

        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    // MARK: - Public API

    func updateEvents(_ events: [String: [SplitCalendarEvent]]) {
        self.events = events

        // Regenerate months with new events
        loadedMonths = loadedMonths.map { month in
            let calendar = Calendar.current
            var components = DateComponents()
            components.year = month.year
            components.month = month.month
            components.day = 1
            guard let date = calendar.date(from: components) else { return month }
            return SplitCalendarMonth.generate(for: date, events: events)
        }

        applySnapshot(animatingDifferences: false)
    }

    func scrollToCurrentMonth(animated: Bool) {
        let calendar = Calendar.current
        let today = Date()
        let currentYear = calendar.component(.year, from: today)
        let currentMonth = calendar.component(.month, from: today)

        scrollToMonth(year: currentYear, month: currentMonth, animated: animated)
    }

    func scrollToMonth(year: Int, month: Int, animated: Bool) {
        guard collectionView != nil,
              let sectionIndex = loadedMonths.firstIndex(where: { $0.year == year && $0.month == month }) else {
            return
        }

        // Find first item in section
        let indexPath = IndexPath(item: 0, section: sectionIndex)
        collectionView.scrollToItem(at: indexPath, at: .top, animated: animated)
    }

    func scrollToDate(_ date: Date, animated: Bool) {
        guard collectionView != nil else { return }

        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)

        guard let sectionIndex = loadedMonths.firstIndex(where: { $0.year == year && $0.month == month }),
              let dayIndex = loadedMonths[sectionIndex].days.firstIndex(where: {
                  $0.dayNumber == day && $0.isCurrentMonth
              }) else {
            return
        }

        let indexPath = IndexPath(item: dayIndex, section: sectionIndex)
        collectionView.scrollToItem(at: indexPath, at: .top, animated: animated)
    }

    func collapse() {
        NSLog("🔵 collapse() called, isExpanded: \(isExpanded)")
        guard isExpanded else {
            NSLog("🔵 collapse() returning early - not expanded")
            return
        }

        // 1. Update state FIRST (while snapshots still cover the screen)
        // This triggers SwiftUI to show the weekday header, but it's hidden under snapshots
        self.isExpanded = false
        self.onExpandedStateChanged?(false)

        // 2. Small delay to let SwiftUI layout settle after showing header
        DispatchQueue.main.async {
            // 3. Now animate the curtains closing
            UIView.animate(
                withDuration: 0.5,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.5,
                options: .curveEaseInOut
            ) {
                // Reset transforms (bring curtains back together)
                self.topSnapshotView?.transform = .identity
                self.bottomSnapshotView?.transform = .identity
                // Fade out event list
                self.eventListContainer?.alpha = 0
            } completion: { _ in
                // Show collection view again
                self.collectionView.isHidden = false

                // Clean up snapshots and event list
                self.topSnapshotView?.removeFromSuperview()
                self.bottomSnapshotView?.removeFromSuperview()
                self.eventListHostingController?.willMove(toParent: nil)
                self.eventListHostingController?.view.removeFromSuperview()
                self.eventListHostingController?.removeFromParent()
                self.eventListContainer?.removeFromSuperview()

                self.topSnapshotView = nil
                self.bottomSnapshotView = nil
                self.eventListHostingController = nil
                self.eventListContainer = nil

                // Clear selection state
                self.selectedIndexPath = nil
                self.selectedDate = nil
            }
        }
    }

    // MARK: - Private Methods

    private func selectDay(at indexPath: IndexPath) {
        // Get the day
        guard indexPath.section < loadedMonths.count else { return }
        let month = loadedMonths[indexPath.section]
        guard indexPath.item < month.days.count else { return }
        let day = month.days[indexPath.item]

        // If tapping the same day and already expanded, collapse
        if isExpanded && selectedIndexPath == indexPath {
            collapse()
            return
        }

        // If already expanded with different day, collapse first then expand
        if isExpanded {
            collapse()
            // Delay the new expansion slightly
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.performSplitTransition(for: day, at: indexPath)
            }
            return
        }

        performSplitTransition(for: day, at: indexPath)
    }

    private func performSplitTransition(for day: SplitCalendarDay, at indexPath: IndexPath) {
        guard let attributes = collectionView.layoutAttributesForItem(at: indexPath) else {
            NSLog("⚠️ Calendar: Could not get layout attributes for tapped cell")
            return
        }

        // 1. Calculate Split Point
        let rowBottomYInContent = attributes.frame.maxY
        let currentOffset = collectionView.contentOffset.y
        let splitScreenY = rowBottomYInContent - currentOffset

        // Store for collapse
        self.splitPoint = splitScreenY

        NSLog("🔵 Split: tapped day \(day.dayNumber), splitScreenY = \(splitScreenY)")

        // 2. Snapshot
        guard let snapshotImage = getCollectionViewSnapshot() else {
            NSLog("⚠️ Calendar: Failed to create snapshot")
            return
        }

        // 3. Create Slices
        let scale = snapshotImage.scale
        let width = snapshotImage.size.width
        let totalHeight = snapshotImage.size.height
        let topHeight = splitScreenY
        let bottomHeight = totalHeight - splitScreenY

        let topRect = CGRect(x: 0, y: 0, width: width * scale, height: topHeight * scale)
        let bottomRect = CGRect(x: 0, y: topHeight * scale, width: width * scale, height: bottomHeight * scale)

        guard let topRef = snapshotImage.cgImage?.cropping(to: topRect),
              let bottomRef = snapshotImage.cgImage?.cropping(to: bottomRect) else {
            NSLog("⚠️ Calendar: Failed to crop snapshot")
            return
        }

        let topView = UIImageView(image: UIImage(cgImage: topRef, scale: scale, orientation: .up))
        let bottomView = UIImageView(image: UIImage(cgImage: bottomRef, scale: scale, orientation: .up))

        // Position slices
        let collectionViewTop = collectionView.frame.minY
        topView.frame = CGRect(x: 0, y: collectionViewTop, width: width, height: topHeight)
        bottomView.frame = CGRect(x: 0, y: collectionViewTop + topHeight, width: width, height: bottomHeight)

        // 4. Create Event List (FULL SCREEN BEHIND SNAPSHOTS)
        createEventListView(allEvents: events, selectedDate: day.date)

        // 5. Add snapshots to view hierarchy (on top of event list)
        view.addSubview(topView)
        view.addSubview(bottomView)
        self.topSnapshotView = topView
        self.bottomSnapshotView = bottomView

        // 6. Hide Collection View
        collectionView.isHidden = true

        // 7. Update State
        selectedIndexPath = indexPath
        selectedDate = day.date
        isExpanded = true
        onDateSelected?(day.date)
        onExpandedStateChanged?(true)

        // 8. Animate "Curtains" Opening
        // Calculate how far to move top slice so it's completely off-screen
        // Top slice starts at collectionViewTop and has height topHeight
        // Need to move it up by (collectionViewTop + topHeight) to clear y=0
        let topSliceOffsetY = -(collectionViewTop + topHeight + 50)  // +50 extra buffer

        UIView.animate(
            withDuration: 0.6,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5,
            options: .curveEaseInOut
        ) {
            // Move Top Slice UP completely off-screen
            self.topSnapshotView?.transform = CGAffineTransform(translationX: 0, y: topSliceOffsetY)

            // Move Bottom Slice DOWN off-screen
            self.bottomSnapshotView?.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)

            // Fade in the full-screen event list
            self.eventListContainer?.alpha = 1
        }
    }

    private func getCollectionViewSnapshot() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(bounds: collectionView.bounds)
        return renderer.image { _ in
            // drawHierarchy is faster and more reliable for screen updates than layer.render
            collectionView.drawHierarchy(in: collectionView.bounds, afterScreenUpdates: false)
        }
    }

    private func createEventListView(allEvents: [String: [SplitCalendarEvent]], selectedDate: Date) {
        // Remove old if exists
        eventListContainer?.removeFromSuperview()

        // Create container FULL SCREEN
        let container = UIView(frame: view.bounds)
        container.backgroundColor = UIColor(Color.appBackground)
        container.alpha = 0  // Start hidden
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Insert behind snapshots (index 0)
        view.insertSubview(container, at: 0)
        eventListContainer = container

        // Create SwiftUI event list content (no PageTitle - parent handles it)
        let content = ExpandedEventListView(
            allEvents: allEvents,
            selectedDate: selectedDate,
            onEventTap: { [weak self] event in
                self?.onEventTap?(event)
            },
            onVisibleDateChanged: { [weak self] date in
                self?.onVisibleEventDateChanged?(date)
            }
        )

        let hostingVC = UIHostingController(rootView: AnyView(content))
        hostingVC.view.backgroundColor = .clear
        hostingVC.view.frame = container.bounds
        hostingVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        addChild(hostingVC)
        container.addSubview(hostingVC.view)
        hostingVC.didMove(toParent: self)

        eventListHostingController = hostingVC
    }

    // MARK: - Infinite Scroll

    private func checkForInfiniteScroll() {
        let contentHeight = collectionView.contentSize.height
        let offsetY = collectionView.contentOffset.y
        let viewHeight = collectionView.bounds.height

        // Near bottom - load more future months
        if offsetY + viewHeight > contentHeight - loadMoreThreshold {
            appendMonths(count: 6)
        }

        // Near top - load more past months
        if offsetY < loadMoreThreshold {
            prependMonths(count: 6)
        }
    }

    private func appendMonths(count: Int) {
        guard let lastMonth = loadedMonths.last else { return }

        let calendar = Calendar.current
        var components = DateComponents()
        components.year = lastMonth.year
        components.month = lastMonth.month
        components.day = 1

        guard let baseDate = calendar.date(from: components) else { return }

        var newMonths: [SplitCalendarMonth] = []
        for i in 1...count {
            if let date = calendar.date(byAdding: .month, value: i, to: baseDate) {
                let month = SplitCalendarMonth.generate(for: date, events: events)
                newMonths.append(month)
            }
        }

        loadedMonths.append(contentsOf: newMonths)
        applySnapshot(animatingDifferences: false)

        // Trim old months if we have too many
        trimMonthsIfNeeded()
    }

    private func prependMonths(count: Int) {
        guard let firstMonth = loadedMonths.first else { return }

        let calendar = Calendar.current
        var components = DateComponents()
        components.year = firstMonth.year
        components.month = firstMonth.month
        components.day = 1

        guard let baseDate = calendar.date(from: components) else { return }

        // Store current offset and content height
        let oldContentHeight = collectionView.contentSize.height
        let oldOffset = collectionView.contentOffset.y

        var newMonths: [SplitCalendarMonth] = []
        for i in (1...count).reversed() {
            if let date = calendar.date(byAdding: .month, value: -i, to: baseDate) {
                let month = SplitCalendarMonth.generate(for: date, events: events)
                newMonths.append(month)
            }
        }

        loadedMonths.insert(contentsOf: newMonths, at: 0)
        applySnapshot(animatingDifferences: false)

        // Adjust content offset to maintain visual position
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let newContentHeight = self.collectionView.contentSize.height
            let heightDelta = newContentHeight - oldContentHeight
            self.collectionView.contentOffset.y = oldOffset + heightDelta
        }

        // Trim old months if we have too many
        trimMonthsIfNeeded()
    }

    private func trimMonthsIfNeeded() {
        let maxMonths = 50

        if loadedMonths.count > maxMonths {
            // Find current visible section
            let visibleRect = CGRect(
                origin: collectionView.contentOffset,
                size: collectionView.bounds.size
            )
            let visibleAttributes = layout.layoutAttributesForElements(in: visibleRect) ?? []
            let visibleSections = Set(visibleAttributes.map { $0.indexPath.section })

            // Don't trim if we'd remove visible content
            let minVisibleSection = visibleSections.min() ?? 0
            let maxVisibleSection = visibleSections.max() ?? loadedMonths.count - 1

            // Calculate how many to trim from each end
            let excess = loadedMonths.count - maxMonths
            let trimFromStart = min(excess / 2, max(0, minVisibleSection - 10))
            let trimFromEnd = min(excess - trimFromStart, max(0, loadedMonths.count - maxVisibleSection - 10))

            if trimFromStart > 0 {
                loadedMonths.removeFirst(trimFromStart)
            }
            if trimFromEnd > 0 {
                loadedMonths.removeLast(trimFromEnd)
            }

            if trimFromStart > 0 || trimFromEnd > 0 {
                applySnapshot(animatingDifferences: false)
            }
        }
    }
}

// MARK: - UICollectionViewDelegate

extension SplitMonthCalendarController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectDay(at: indexPath)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        checkForInfiniteScroll()
        notifyVisibleMonth()
    }

    private func notifyVisibleMonth() {
        // Find the topmost visible month by checking near the top of visible area
        let topPoint = CGPoint(x: collectionView.bounds.midX, y: collectionView.contentOffset.y + 80)

        guard let indexPath = collectionView.indexPathForItem(at: topPoint),
              indexPath.section < loadedMonths.count else {
            return
        }

        let month = loadedMonths[indexPath.section]

        // Only notify if month changed to avoid excessive callbacks
        if month.id != lastNotifiedMonthId {
            lastNotifiedMonthId = month.id
            onScrolledToNewMonth?(month)
        }
    }
}

// MARK: - Expanded Event List View

struct ExpandedEventListView: View {
    let allEvents: [String: [SplitCalendarEvent]]
    let selectedDate: Date
    let onEventTap: (SplitCalendarEvent) -> Void
    let onVisibleDateChanged: ((Date) -> Void)?

    @State private var visibleDates: Set<Date> = []

    // Normalize selected date to start of day for consistent comparison
    private var normalizedSelectedDate: Date {
        Calendar.current.startOfDay(for: selectedDate)
    }

    // FIX: Reduce past range from -30 to -1
    // LazyVStack can't estimate heights for 30 unrendered variable-height days
    // With only 1 past day, height error is negligible
    private var displayDays: [Date] {
        let calendar = Calendar.current
        let baseDate = normalizedSelectedDate
        var days: [Date] = []

        // Range: Yesterday (-1) to +60 days
        for offset in -1...60 {
            if let date = calendar.date(byAdding: .day, value: offset, to: baseDate) {
                days.append(date)
            }
        }

        return days
    }

    var body: some View {
        // Infinite scrolling day list - NO PageTitle here, parent handles it
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(displayDays, id: \.self) { date in
                        EventDaySection(
                            date: date,
                            events: eventsForDate(date),
                            onEventTap: onEventTap
                        )
                        .id(date)
                        .onAppear {
                            visibleDates.insert(date)
                            updateVisibleDate()
                        }
                        .onDisappear {
                            visibleDates.remove(date)
                            updateVisibleDate()
                        }
                    }
                }
                .padding(.bottom, 32)
            }
            .onAppear {
                // Scroll immediately without animation so it looks instant during the split
                // Use DispatchQueue.main.async to ensure the layout pass has occurred
                DispatchQueue.main.async {
                    proxy.scrollTo(normalizedSelectedDate, anchor: .top)
                    onVisibleDateChanged?(normalizedSelectedDate)
                }
            }
        }
        .background(Color.appBackground)
    }

    private func eventsForDate(_ date: Date) -> [SplitCalendarEvent] {
        let dateKey = SplitCalendarDay.dateKey(for: date)
        return allEvents[dateKey] ?? []
    }

    private func updateVisibleDate() {
        // Find the topmost visible date (earliest date that's visible)
        if let topDate = visibleDates.min() {
            onVisibleDateChanged?(topDate)
        }
    }
}

// MARK: - Event Day Section

struct EventDaySection: View {
    let date: Date
    let events: [SplitCalendarEvent]
    let onEventTap: (SplitCalendarEvent) -> Void

    private var dayName: String {
        return CalendarFormatters.dayName.string(from: date)
    }

    private var dayDate: String {
        return CalendarFormatters.dayDate.string(from: date)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var isPast: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayStart = calendar.startOfDay(for: date)
        return dayStart < today
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Day header - bold day name + regular date with 4px gap
            HStack(spacing: 4) {
                Text(dayName)
                    .font(Typography.s16Bold)
                    .foregroundColor(isToday ? Color.brandPrimary : (isPast ? .white.opacity(0.5) : .white))

                Text(dayDate)
                    .font(Typography.s16)
                    .foregroundColor(isToday ? Color.brandPrimary.opacity(0.5) : .white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, events.isEmpty ? 8 : 12)

            // Events for this day
            if !events.isEmpty {
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
                        .opacity(isPast ? 0.5 : 1.0)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    } else {
                        // Generic event card
                        CardEvent(
                            data: CardEventData(
                                id: event.id,
                                title: event.title,
                                subtitle: event.subtitle,
                                imageStyle: imageStyleForEvent(event),
                                metadata: eventMetadata(for: event),
                                status: nil,
                                onTap: { onEventTap(event) }
                            )
                        )
                        .opacity(isPast ? 0.5 : 1.0)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
    }

    /// Returns the appropriate image style for an event - time display for timed events, date for all-day
    private func imageStyleForEvent(_ event: SplitCalendarEvent) -> CardImageStyle {
        if event.isAllDay {
            // All-day events show the date
            let dayNumber = Calendar.current.component(.day, from: date)
            let monthAbbrev = CalendarFormatters.monthAbbrev.string(from: date).uppercased()
            return .dateDisplay(day: dayNumber, month: monthAbbrev)
        } else {
            // Timed events show the time
            let time = CalendarFormatters.timeWithoutPeriod.string(from: event.startTime)
            let period = CalendarFormatters.timePeriod.string(from: event.startTime)
            return .timeDisplay(time: time, period: period)
        }
    }

    private func eventMetadata(for event: SplitCalendarEvent) -> [DataItem] {
        var items: [DataItem] = []

        // Add location if available
        if let location = event.location {
            items.append(DataItem(icon: "mappin", value: location))
        }

        // Add time
        if event.isAllDay {
            items.append(DataItem(icon: "clock", value: "All day"))
        } else {
            items.append(DataItem(icon: "clock", value: event.timeString))
        }

        return items
    }
}
