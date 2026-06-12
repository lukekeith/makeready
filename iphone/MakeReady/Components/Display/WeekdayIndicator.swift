//
//  WeekdayIndicator.swift
//  MakeReady
//
//  Displays week days (S M T W T F S) with dots indicating enabled days
//

import SwiftUI

struct WeekdayIndicator: View {
    /// Set of enabled weekday indices (0 = Sunday, 1 = Monday, ... 6 = Saturday)
    let enabledDays: Set<Int>

    /// Size of each day circle
    var daySize: CGFloat = 24

    /// Size of the dot indicator
    var dotSize: CGFloat = 4

    /// Days starting with Sunday
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
                VStack(spacing: 4) {
                    // Day letter
                    Text(day.label)
                        .font(Typography.s13Semibold)
                        .foregroundColor(enabledDays.contains(day.index) ? .white : .white.opacity(0.3))
                        .frame(width: daySize, height: daySize)

                    // Dot indicator
                    Circle()
                        .fill(enabledDays.contains(day.index) ? Color.brandPrimary : Color.clear)
                        .frame(width: dotSize, height: dotSize)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 24) {
            Text("Mon-Fri enabled")
                .font(Typography.s13Semibold)
                .foregroundColor(.white.opacity(0.5))

            WeekdayIndicator(enabledDays: [1, 2, 3, 4, 5])

            Text("All days enabled")
                .font(Typography.s13Semibold)
                .foregroundColor(.white.opacity(0.5))

            WeekdayIndicator(enabledDays: [0, 1, 2, 3, 4, 5, 6])

            Text("Tue/Thu only")
                .font(Typography.s13Semibold)
                .foregroundColor(.white.opacity(0.5))

            WeekdayIndicator(enabledDays: [2, 4])
        }
    }
}
