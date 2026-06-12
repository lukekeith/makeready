//
//  HeatMapChart.swift
//  MakeReady
//
//  A reusable heat map chart component using Apple's Swift Charts framework.
//  GitHub contribution-style visualization for patterns over time.
//  Supports:
//  - Grid-based layout (weeks × days)
//  - Color intensity scales
//  - Compact design for mobile
//

import SwiftUI
import Charts

// MARK: - Data Structures

struct HeatMapDataPoint: Identifiable {
    let id = UUID()
    let week: Int
    let day: Int
    let value: Double
    let dayLabel: String
}

// MARK: - Main Heat Map Chart Component

struct HeatMapChart: View {
    let dataPoints: [HeatMapDataPoint]
    let colorScale: [Color]
    let showDayLabels: Bool
    let xLabels: [String]?
    let yLabels: [String]?
    let chartHeight: CGFloat

    init(
        dataPoints: [HeatMapDataPoint],
        colorScale: [Color]? = nil,
        showDayLabels: Bool = true,
        xLabels: [String]? = nil,
        yLabels: [String]? = nil,
        chartHeight: CGFloat = 120
    ) {
        self.dataPoints = dataPoints
        self.colorScale = colorScale ?? [
            Color.clear,
            Color.brandPrimary.opacity(0.3),
            Color.brandPrimary.opacity(0.6),
            Color.brandPrimary
        ]
        self.showDayLabels = showDayLabels
        self.xLabels = xLabels
        self.yLabels = yLabels
        self.chartHeight = chartHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Chart
            Chart(dataPoints) { point in
                RectangleMark(
                    xStart: .value("Week Start", point.week),
                    xEnd: .value("Week End", point.week + 1),
                    yStart: .value("Day Start", point.day),
                    yEnd: .value("Day End", point.day + 1)
                )
                .foregroundStyle(colorForValue(point.value))
            }
            .chartXAxis {
                if let xLabels = xLabels {
                    AxisMarks(position: .bottom, values: Array(0..<xLabels.count)) { value in
                        AxisValueLabel(verticalSpacing: 8) {
                            if let index = value.as(Int.self), index < xLabels.count {
                                Text(xLabels[index])
                                    .font(Typography.s10)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                }
            }
            .chartYAxis {
                if let yLabels = yLabels {
                    AxisMarks(position: .leading, values: Array(0..<yLabels.count)) { value in
                        AxisValueLabel(horizontalSpacing: 8) {
                            if let index = value.as(Int.self), index < yLabels.count {
                                Text(yLabels[index])
                                    .font(Typography.s10)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                } else if showDayLabels {
                    AxisMarks(position: .leading, values: [0, 1, 2, 3, 4, 5, 6]) { value in
                        AxisValueLabel(horizontalSpacing: 8) {
                            if let dayIndex = value.as(Int.self) {
                                Text(dayLabels[dayIndex])
                                    .font(Typography.s10)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                }
            }
            .chartLegend(.hidden)
            .chartPlotStyle { plotArea in
                plotArea.background(.clear)
            }
            .frame(height: chartHeight)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }

    private var maxValue: Double {
        dataPoints.map(\.value).max() ?? 1
    }

    private func colorForValue(_ value: Double) -> Color {
        guard value > 0, maxValue > 0 else { return .clear }
        let t = value / maxValue
        // Continuous opacity from 0.1 to 1.0 based on relative value
        let opacity = 0.1 + (t * 0.9)
        return Color.brandPrimary.opacity(opacity)
    }

    private var dayLabels: [String] {
        ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 32) {
            // Example 1: Weekly activity (GitHub-style)
            VStack(alignment: .leading, spacing: 12) {
                Text("Team Activity (Last 8 Weeks)")
                    .font(Typography.s13Semibold)
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                HeatMapChart(
                    dataPoints: generateActivityData(weeks: 8),
                    showDayLabels: true
                )

                // Legend
                HStack(spacing: 8) {
                    Text("Less")
                        .font(Typography.s11)
                        .foregroundColor(.white.opacity(0.5))

                    ForEach(0..<5) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(intensityColor(for: index))
                            .frame(width: 12, height: 12)
                    }

                    Text("More")
                        .font(Typography.s11)
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            // Example 2: Availability grid (different colors)
            VStack(alignment: .leading, spacing: 12) {
                Text("Availability (Next 4 Weeks)")
                    .font(Typography.s13Semibold)
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                HeatMapChart(
                    dataPoints: generateAvailabilityData(weeks: 4),
                    colorScale: [
                        Color.white.opacity(0.05),
                        Color(hex: "#4ade80").opacity(0.3),
                        Color(hex: "#4ade80").opacity(0.6),
                        Color(hex: "#4ade80")
                    ],
                    showDayLabels: true
                )
            }

            // Example 3: Compact view without day labels
            VStack(alignment: .leading, spacing: 12) {
                Text("Task Completion Heatmap")
                    .font(Typography.s13Semibold)
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                HeatMapChart(
                    dataPoints: generateActivityData(weeks: 12),
                    colorScale: [
                        Color.white.opacity(0.05),
                        Color(hex: "#ff6b9d").opacity(0.3),
                        Color(hex: "#ff6b9d").opacity(0.6),
                        Color(hex: "#ff6b9d")
                    ],
                    showDayLabels: false
                )
            }
        }
        .padding(16)
    }
}

// MARK: - Sample Data Generators

private func generateActivityData(weeks: Int) -> [HeatMapDataPoint] {
    var data: [HeatMapDataPoint] = []
    let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    for week in 0..<weeks {
        for day in 0..<7 {
            // Generate semi-random activity (higher on weekdays)
            let baseActivity: Double = (day == 0 || day == 6) ? 2 : 5
            let randomFactor = Double.random(in: 0...5)
            let activity = baseActivity + randomFactor

            data.append(HeatMapDataPoint(
                week: week,
                day: day,
                value: activity,
                dayLabel: dayLabels[day]
            ))
        }
    }

    return data
}

private func generateAvailabilityData(weeks: Int) -> [HeatMapDataPoint] {
    var data: [HeatMapDataPoint] = []
    let dayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    for week in 0..<weeks {
        for day in 0..<7 {
            // Generate availability (lower on weekends)
            let baseAvailability: Double = (day == 0 || day == 6) ? 1 : 8
            let randomFactor = Double.random(in: -2...2)
            let availability = max(0, baseAvailability + randomFactor)

            data.append(HeatMapDataPoint(
                week: week,
                day: day,
                value: availability,
                dayLabel: dayLabels[day]
            ))
        }
    }

    return data
}

private func intensityColor(for level: Int) -> Color {
    switch level {
    case 0:
        return Color.white.opacity(0.05)
    case 1:
        return Color.brandPrimary.opacity(0.2)
    case 2:
        return Color.brandPrimary.opacity(0.4)
    case 3:
        return Color.brandPrimary.opacity(0.7)
    case 4:
        return Color.brandPrimary
    default:
        return Color.white.opacity(0.05)
    }
}
