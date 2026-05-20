//
//  SplitMonthCalendar.swift
//  MakeReady
//
//  SwiftUI wrapper for the Split-Month Calendar component
//  UIViewControllerRepresentable that wraps SplitMonthCalendarController
//

import SwiftUI

// MARK: - Preference Key for Header Height

private struct HeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - View Capture Wrapper

/// Wraps SwiftUI content and captures the underlying UIView for snapshotting
private struct ViewCapture<Content: View>: UIViewRepresentable {
    let controllerHolder: ControllerHolder
    let content: Content

    init(controllerHolder: ControllerHolder, @ViewBuilder content: () -> Content) {
        self.controllerHolder = controllerHolder
        self.content = content()
    }

    func makeUIView(context: Context) -> UIView {
        // Create a container view
        let container = UIView()
        container.backgroundColor = .clear

        // Host the SwiftUI content
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: container.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        // Store reference to container for snapshotting
        controllerHolder.containerView = container

        // Keep hosting controller alive
        context.coordinator.hostingController = hostingController

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Update the hosted content
        context.coordinator.hostingController?.rootView = content
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var hostingController: UIHostingController<Content>?
    }
}

// MARK: - Main Calendar View

struct SplitMonthCalendar<CollapsedHeader: View, ExpandedHeader: View>: View {
    @Binding var selectedDate: Date?
    let events: [String: [SplitCalendarEvent]]
    let onEventTap: (SplitCalendarEvent) -> Void
    /// Header when calendar is collapsed (month grid view) - receives the current month title string
    let collapsedHeader: (String) -> CollapsedHeader
    /// Header when calendar is expanded (event list view) - receives the current month title and a collapse action
    let expandedHeader: (String, @escaping () -> Void) -> ExpandedHeader
    /// Optional: Provide an external ControllerHolder if you need to access the controller (e.g., for scrollToCurrentMonth)
    var externalControllerHolder: ControllerHolder?

    @State private var currentMonth: SplitCalendarMonth?
    @State private var isExpanded: Bool = false
    @State private var visibleEventDate: Date?  // Track visible date in event list
    @State private var headerHeight: CGFloat = 0  // Track header height for snapshots
    @StateObject private var internalControllerHolder = ControllerHolder()

    /// Returns the active controller holder (external if provided, otherwise internal)
    private var controllerHolder: ControllerHolder {
        externalControllerHolder ?? internalControllerHolder
    }

    // Month and year for PageTitle (e.g., "Dec 2025")
    private var currentMonthTitle: String {
        // When expanded, use the visible event date
        if isExpanded, let date = visibleEventDate {
            return CalendarFormatters.monthYearShort.string(from: date)
        }
        // When collapsed, use the current month from calendar scroll
        if let month = currentMonth {
            var components = DateComponents()
            components.year = month.year
            components.month = month.month
            components.day = 1
            if let date = Calendar.current.date(from: components) {
                return CalendarFormatters.monthYearShort.string(from: date)
            }
        }
        return CalendarFormatters.monthYearShort.string(from: Date())
    }

    var body: some View {
        // Wrap in ViewCapture to get UIKit view reference for snapshotting
        ViewCapture(controllerHolder: controllerHolder) {
            VStack(spacing: 0) {
                // Fixed header section - ALWAYS visible (shared between month and event views)
                VStack(spacing: 0) {
                    // PageTitle - customizable via closures
                    if isExpanded {
                        // When expanded, use expandedHeader closure with collapse action
                        expandedHeader(currentMonthTitle) { [controllerHolder] in
                            if let controller = controllerHolder.controller {
                                controller.collapse()
                            }
                        }
                    } else {
                        // When collapsed, use collapsedHeader closure
                        collapsedHeader(currentMonthTitle)
                    }

                    // Weekday header row - only show when not expanded
                    if !isExpanded {
                        CalendarWeekdayHeader()

                        // Gradient fade into scrolling content
                        LinearGradient(
                            colors: [Color.appBackground, Color.appBackground.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 8)
                    }
                }
                .background(Color.appBackground)
                .background(
                    // Measure header height
                    GeometryReader { geometry in
                        Color.clear.preference(key: HeaderHeightKey.self, value: geometry.size.height)
                    }
                )

                // Calendar collection view (scrollable) - handles split animation internally
                SplitMonthCalendarRepresentable(
                    selectedDate: $selectedDate,
                    isExpanded: $isExpanded,
                    events: events,
                    onEventTap: onEventTap,
                    onMonthChanged: { month in
                        currentMonth = month
                    },
                    onVisibleDateChanged: { date in
                        visibleEventDate = date
                    },
                    controllerHolder: controllerHolder
                )
            }
            .onPreferenceChange(HeaderHeightKey.self) { height in
                headerHeight = height
                controllerHolder.headerHeight = height
            }
        }
    }

}

// MARK: - UIViewControllerRepresentable

// Observable class to hold controller reference and snapshot provider
class ControllerHolder: ObservableObject {
    var controller: SplitMonthCalendarController?
    /// Weak reference to the container view for snapshotting
    weak var containerView: UIView?
    /// Height of the header area (PageTitle + weekday header + gradient)
    var headerHeight: CGFloat = 0
}

struct SplitMonthCalendarRepresentable: UIViewControllerRepresentable {
    @Binding var selectedDate: Date?
    @Binding var isExpanded: Bool
    let events: [String: [SplitCalendarEvent]]
    let onEventTap: (SplitCalendarEvent) -> Void
    let onMonthChanged: (SplitCalendarMonth) -> Void
    let onVisibleDateChanged: ((Date) -> Void)?
    let controllerHolder: ControllerHolder

    func makeUIViewController(context: Context) -> SplitMonthCalendarController {
        let controller = SplitMonthCalendarController()

        controller.onDateSelected = { date in
            selectedDate = date
        }

        controller.onEventTap = onEventTap

        controller.onScrolledToNewMonth = { month in
            onMonthChanged(month)
        }

        controller.onExpandedStateChanged = { expanded in
            // Update state immediately without SwiftUI animation
            // UIKit handles all the visual animations
            isExpanded = expanded
        }

        controller.onVisibleEventDateChanged = { date in
            onVisibleDateChanged?(date)
        }

        // Set up snapshot provider - finds the parent container and snapshots it
        controller.onRequestFullSnapshot = { [weak controllerHolder] in
            guard let holder = controllerHolder,
                  let containerView = holder.containerView else {
                NSLog("🔵 Snapshot: No container view available")
                return nil
            }

            // Snapshot the entire container (includes SwiftUI header)
            let renderer = UIGraphicsImageRenderer(bounds: containerView.bounds)
            let image = renderer.image { context in
                containerView.layer.render(in: context.cgContext)
            }

            NSLog("🔵 Snapshot: Created full snapshot, size: \(image.size), headerHeight: \(holder.headerHeight)")
            return (image: image, headerHeight: holder.headerHeight)
        }

        // Store controller reference in holder for SwiftUI to access
        controllerHolder.controller = controller
        NSLog("🔵 Controller stored in holder: \(controller)")

        // Load initial events
        controller.updateEvents(events)

        return controller
    }

    func updateUIViewController(_ controller: SplitMonthCalendarController, context: Context) {
        // Update events when they change
        controller.updateEvents(events)

        // Only collapse if selectedDate was explicitly cleared externally
        // Don't interfere during the expansion process
        // The controller manages its own isExpanded state
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: SplitMonthCalendarRepresentable

        init(_ parent: SplitMonthCalendarRepresentable) {
            self.parent = parent
        }
    }
}

// MARK: - Calendar with Bottom Bar

struct SplitMonthCalendarWithBar<CollapsedHeader: View, ExpandedHeader: View>: View {
    @Binding var selectedDate: Date?
    let events: [String: [SplitCalendarEvent]]
    let onEventTap: (SplitCalendarEvent) -> Void
    /// Header when calendar is collapsed (month grid view) - receives the current month title string
    let collapsedHeader: (String) -> CollapsedHeader
    /// Header when calendar is expanded (event list view) - receives the current month title and a collapse action
    let expandedHeader: (String, @escaping () -> Void) -> ExpandedHeader

    @StateObject private var controllerHolder = ControllerHolder()
    @Environment(\.navBarVisible) private var navBarVisible

    // NavBar height: 20 top padding + 22 icon + 12 bottom padding = ~54px + safe area
    // Add some extra to ensure the Today button clears it completely
    private var bottomPadding: CGFloat {
        navBarVisible ? 80 : 16
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            SplitMonthCalendar(
                selectedDate: $selectedDate,
                events: events,
                onEventTap: onEventTap,
                collapsedHeader: collapsedHeader,
                expandedHeader: expandedHeader,
                externalControllerHolder: controllerHolder
            )

            // Floating bottom bar
            CalendarBottomBar(
                onTodayTap: {
                    selectedDate = nil
                    controllerHolder.controller?.scrollToCurrentMonth(animated: true)
                }
            )
            .padding(.leading, 16)
            .padding(.bottom, bottomPadding)
            .animation(.easeInOut(duration: 0.25), value: navBarVisible)
        }
    }
}

// MARK: - Convenience initializer for simple title-only usage

extension SplitMonthCalendarWithBar {
    /// Convenience initializer that shows just the title (no close button) - useful for main nav
    init(
        selectedDate: Binding<Date?>,
        events: [String: [SplitCalendarEvent]],
        onEventTap: @escaping (SplitCalendarEvent) -> Void
    ) where CollapsedHeader == PageTitle, ExpandedHeader == AnyView {
        self._selectedDate = selectedDate
        self.events = events
        self.onEventTap = onEventTap
        self.collapsedHeader = { title in
            PageTitle.titleOnly(title: title)
        }
        self.expandedHeader = { title, onBack in
            AnyView(PageTitle.backLinkTitle(title: title, backText: "Back", onBackTap: onBack))
        }
    }
}

// MARK: - Preview

#Preview("Split Month Calendar") {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        SplitMonthCalendar(
            selectedDate: .constant(nil),
            events: SplitCalendarEvent.mockEvents(),
            onEventTap: { event in
                print("Tapped event: \(event.title)")
            },
            collapsedHeader: { title in
                PageTitle.iconTitle(title: title, icon: "xmark", onIconTap: { print("Close") })
            },
            expandedHeader: { title, onBack in
                AnyView(PageTitle.backLinkTitle(title: title, backText: "Back", onBackTap: onBack))
            }
        )
    }
}

#Preview("Calendar with Bottom Bar - Title Only") {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        // Uses convenience initializer - title only, no close button
        SplitMonthCalendarWithBar(
            selectedDate: .constant(nil),
            events: SplitCalendarEvent.mockEvents(),
            onEventTap: { event in
                print("Tapped event: \(event.title)")
            }
        )
    }
}

#Preview("Calendar with Bottom Bar - Close Button") {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        // Custom headers with close button
        SplitMonthCalendarWithBar(
            selectedDate: .constant(nil),
            events: SplitCalendarEvent.mockEvents(),
            onEventTap: { event in
                print("Tapped event: \(event.title)")
            },
            collapsedHeader: { title in
                PageTitle.iconTitle(title: title, icon: "xmark", onIconTap: { print("Close") })
            },
            expandedHeader: { title, onBack in
                AnyView(PageTitle.backLinkTitle(title: title, backText: "Back", onBackTap: onBack))
            }
        )
    }
}
