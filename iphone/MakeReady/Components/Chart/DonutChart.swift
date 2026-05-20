//
//  DonutChart.swift
//  MakeReady
//
//  A reusable donut/pie chart component using Apple's Swift Charts framework.
//  Supports:
//  - Pie and donut chart modes
//  - Custom colors per slice
//  - Center label for totals
//  - Configurable slice spacing
//

import SwiftUI
import Charts

// MARK: - Data Structures

struct DonutChartDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

// MARK: - Main Donut Chart Component

struct DonutChart: View {
    let dataPoints: [DonutChartDataPoint]
    let innerRadiusRatio: CGFloat
    let showCenterLabel: Bool
    let centerLabelText: String?
    let centerLabelSubtext: String?

    init(
        dataPoints: [DonutChartDataPoint],
        innerRadiusRatio: CGFloat = 0.75,
        showCenterLabel: Bool = true,
        centerLabelText: String? = nil,
        centerLabelSubtext: String? = nil
    ) {
        self.dataPoints = dataPoints
        self.innerRadiusRatio = innerRadiusRatio
        self.showCenterLabel = showCenterLabel
        self.centerLabelText = centerLabelText
        self.centerLabelSubtext = centerLabelSubtext
    }

    var body: some View {
        ZStack {
            // Chart
            Chart(dataPoints) { dataPoint in
                SectorMark(
                    angle: .value("Value", dataPoint.value),
                    innerRadius: .ratio(innerRadiusRatio),
                    angularInset: 0
                )
                .foregroundStyle(dataPoint.color)
                .opacity(0.9)
            }
            .chartLegend(.hidden)

            // Center label
            if showCenterLabel {
                VStack(spacing: 4) {
                    if let centerText = centerLabelText {
                        Text(centerText)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text(totalFormatted)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }

                    if let subtext = centerLabelSubtext {
                        Text(subtext)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                    } else {
                        Text("Total")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var total: Double {
        dataPoints.reduce(0) { $0 + $1.value }
    }

    private var totalFormatted: String {
        if total >= 1000 {
            return String(format: "%.1fk", total / 1000)
        } else if total.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", total)
        } else {
            return String(format: "%.1f", total)
        }
    }
}

// MARK: - Legend Component

struct DonutChartLegend: View {
    let dataPoints: [DonutChartDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(dataPoints) { dataPoint in
                HStack(spacing: 12) {
                    // Color indicator
                    RoundedRectangle(cornerRadius: 3)
                        .fill(dataPoint.color)
                        .frame(width: 12, height: 12)

                    // Label
                    Text(dataPoint.label)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.9))

                    Spacer()

                    // Value
                    Text(formatValue(dataPoint.value))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    // Percentage
                    Text(formatPercentage(dataPoint.value))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
    }

    private var total: Double {
        dataPoints.reduce(0) { $0 + $1.value }
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        } else if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func formatPercentage(_ value: Double) -> String {
        let percentage = (value / total) * 100
        return String(format: "%.0f%%", percentage)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 32) {
            // Example 1: Budget breakdown with legend
            VStack(alignment: .leading, spacing: 16) {
                Text("Budget Breakdown")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                HStack(spacing: 24) {
                    DonutChart(
                        dataPoints: budgetData,
                        innerRadiusRatio: 0.6,
                        centerLabelText: "$12.5k",
                        centerLabelSubtext: "Budget"
                    )
                    .frame(width: 180, height: 180)

                    DonutChartLegend(dataPoints: budgetData)
                }
            }

            // Example 2: Task status (simple)
            VStack(alignment: .leading, spacing: 16) {
                Text("Task Status")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                HStack(spacing: 24) {
                    DonutChart(
                        dataPoints: taskData,
                        innerRadiusRatio: 0.65,
                        centerLabelSubtext: "Tasks"
                    )
                    .frame(width: 160, height: 160)

                    DonutChartLegend(dataPoints: taskData)
                }
            }

            // Example 3: Pie chart (no center hole)
            VStack(alignment: .leading, spacing: 16) {
                Text("Team Roles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                HStack(spacing: 24) {
                    DonutChart(
                        dataPoints: teamRolesData,
                        innerRadiusRatio: 0.0,  // Pie chart (no hole)
                        showCenterLabel: false
                    )
                    .frame(width: 160, height: 160)

                    DonutChartLegend(dataPoints: teamRolesData)
                }
            }
        }
        .padding(16)
    }
}

// MARK: - Sample Data

private var budgetData: [DonutChartDataPoint] {
    [
        DonutChartDataPoint(label: "Marketing", value: 4500, color: Color(hex: "#6c47ff")),
        DonutChartDataPoint(label: "Development", value: 3500, color: Color(hex: "#47d4ff")),
        DonutChartDataPoint(label: "Design", value: 2000, color: Color(hex: "#ff6b9d")),
        DonutChartDataPoint(label: "Operations", value: 1500, color: Color(hex: "#ffd93d")),
        DonutChartDataPoint(label: "Other", value: 1000, color: Color.white.opacity(0.3))
    ]
}

private var taskData: [DonutChartDataPoint] {
    [
        DonutChartDataPoint(label: "Completed", value: 145, color: Color(hex: "#4ade80")),
        DonutChartDataPoint(label: "In Progress", value: 32, color: Color(hex: "#6c47ff")),
        DonutChartDataPoint(label: "Pending", value: 18, color: Color.white.opacity(0.3))
    ]
}

private var teamRolesData: [DonutChartDataPoint] {
    [
        DonutChartDataPoint(label: "Developers", value: 8, color: Color(hex: "#6c47ff")),
        DonutChartDataPoint(label: "Designers", value: 3, color: Color(hex: "#ff6b9d")),
        DonutChartDataPoint(label: "Managers", value: 2, color: Color(hex: "#47d4ff")),
        DonutChartDataPoint(label: "QA", value: 2, color: Color(hex: "#ffd93d"))
    ]
}
