// DEBUG-ONLY (Phase 5.5): demo pages ship in no release binary.
#if DEBUG
//
//  CalendarDemoPage.swift
//  MakeReady
//
//  Demo page for testing the Split-Month Calendar component
//

import SwiftUI

struct CalendarDemoPage: View {
    @State private var selectedDate: Date?
    @State private var events: [String: [SplitCalendarEvent]] = SplitCalendarEvent.mockEvents()

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            // Calendar component with custom headers for modal presentation
            SplitMonthCalendarWithBar(
                selectedDate: $selectedDate,
                events: events,
                onEventTap: { event in
                    print("Tapped event: \(event.title)")
                },
                collapsedHeader: { title in
                    PageTitle.iconTitle(title: title, icon: "xmark", onIconTap: { dismiss() })
                },
                expandedHeader: { title, onBack in
                    AnyView(PageTitle.backLinkTitle(title: title, backText: "Back", onBackTap: onBack))
                }
            )
        }
    }
}

// MARK: - Preview

#Preview {
    CalendarDemoPage()
}
#endif
