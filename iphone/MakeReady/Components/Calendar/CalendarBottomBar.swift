//
//  CalendarBottomBar.swift
//  MakeReady
//
//  Floating bottom bar for the calendar with "Today" button
//

import SwiftUI

struct CalendarBottomBar: View {
    let onTodayTap: () -> Void
    var onViewModeChange: ((CalendarViewMode) -> Void)?

    @State private var selectedMode: CalendarViewMode = .month

    var body: some View {
        HStack(spacing: 0) {
            // Today button
            Button(action: onTodayTap) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(Typography.s14Semibold)
                    Text("Today")
                        .font(Typography.s14Semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            // Divider (if view mode toggles are shown)
            if onViewModeChange != nil {
                Rectangle()
                    .fill(Color.white20)
                    .frame(width: 1, height: 20)

                // View mode toggles
                HStack(spacing: 8) {
                    ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                        Button(action: {
                            selectedMode = mode
                            onViewModeChange?(mode)
                        }) {
                            Text(mode.title)
                                .font(.system(size: 13, weight: selectedMode == mode ? .semibold : .regular))
                                .foregroundColor(selectedMode == mode ? .white : .white50)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .environment(\.colorScheme, .dark)  // Force dark mode for material
    }
}

// MARK: - View Mode

enum CalendarViewMode: CaseIterable {
    case day
    case week
    case month

    var title: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        }
    }
}

// MARK: - Preview

#Preview("Bottom Bar - Today Only") {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack {
            Spacer()
            CalendarBottomBar(
                onTodayTap: {
                    print("Today tapped")
                }
            )
            .padding(.bottom, 32)
        }
    }
}

#Preview("Bottom Bar - With View Modes") {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack {
            Spacer()
            CalendarBottomBar(
                onTodayTap: {
                    print("Today tapped")
                },
                onViewModeChange: { mode in
                    print("Mode changed to: \(mode)")
                }
            )
            .padding(.bottom, 32)
        }
    }
}
