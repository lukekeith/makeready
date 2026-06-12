//
//  VerticalBarChart.swift
//  MakeReady
//
//  A reusable vertical bar chart component using Apple's Swift Charts framework.
//  Perfect for time-series and category comparisons.
//  Supports:
//  - Vertical bars (quantitative on Y-axis)
//  - Fixed height
//  - Solid colors or gradients
//  - Optional value labels
//

import SwiftUI
import Charts

// MARK: - Main Vertical Bar Chart Component

struct VerticalBarChart: View {
    let dataPoints: [BarChartDataPoint]
    let showValues: Bool
    let chartHeight: CGFloat

    init(
        dataPoints: [BarChartDataPoint],
        showValues: Bool = true,
        chartHeight: CGFloat = 200
    ) {
        self.dataPoints = dataPoints
        self.showValues = showValues
        self.chartHeight = chartHeight
    }

    var body: some View {
        Chart(dataPoints) { dataPoint in
            BarMark(
                x: .value("Label", dataPoint.label),
                y: .value("Value", dataPoint.value)
            )
            .foregroundStyle(dataPoint.color)
            .annotation(position: .top, alignment: .center) {
                if showValues {
                    Text(formatValue(dataPoint.value))
                        .font(Typography.s11Semibold)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 4)
                }
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom) { value in
                AxisValueLabel(verticalSpacing: 8) {
                    if let stringValue = value.as(String.self) {
                        Text(stringValue)
                            .font(Typography.s12)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel(horizontalSpacing: 8) {
                    if let doubleValue = value.as(Double.self) {
                        Text(formatAxisValue(doubleValue))
                            .font(Typography.s11)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
        .frame(height: chartHeight)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - Helper Methods

    private func formatValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        } else if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func formatAxisValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0fk", value / 1000)
        } else {
            return String(format: "%.0f", value)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 32) {
            // Example 1: Monthly revenue
            VStack(alignment: .leading, spacing: 12) {
                Text("Monthly Revenue (2024)")
                    .font(Typography.s13Semibold)
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                VerticalBarChart(
                    dataPoints: monthlyRevenueData,
                    showValues: true,
                    chartHeight: 180
                )
            }

            // Example 2: Weekly signups
            VStack(alignment: .leading, spacing: 12) {
                Text("New Signups (Last 7 Days)")
                    .font(Typography.s13Semibold)
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                VerticalBarChart(
                    dataPoints: weeklySignupsData,
                    showValues: false,
                    chartHeight: 160
                )
            }

            // Example 3: Category breakdown
            VStack(alignment: .leading, spacing: 12) {
                Text("Projects by Status")
                    .font(Typography.s13Semibold)
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                VerticalBarChart(
                    dataPoints: projectStatusData,
                    showValues: true,
                    chartHeight: 180
                )
            }
        }
        .padding(16)
    }
}

// MARK: - Sample Data

private var monthlyRevenueData: [BarChartDataPoint] {
    [
        BarChartDataPoint(label: "Jan", value: 12500, color: Color.brandPrimary),
        BarChartDataPoint(label: "Feb", value: 14200, color: Color.brandPrimary),
        BarChartDataPoint(label: "Mar", value: 13800, color: Color.brandPrimary),
        BarChartDataPoint(label: "Apr", value: 16100, color: Color.brandPrimary),
        BarChartDataPoint(label: "May", value: 18300, color: Color.brandPrimary),
        BarChartDataPoint(label: "Jun", value: 19500, color: Color.brandPrimary)
    ]
}

private var weeklySignupsData: [BarChartDataPoint] {
    [
        BarChartDataPoint(label: "Mon", value: 23, color: Color(hex: "#47d4ff")),
        BarChartDataPoint(label: "Tue", value: 31, color: Color(hex: "#47d4ff")),
        BarChartDataPoint(label: "Wed", value: 28, color: Color(hex: "#47d4ff")),
        BarChartDataPoint(label: "Thu", value: 35, color: Color(hex: "#47d4ff")),
        BarChartDataPoint(label: "Fri", value: 42, color: Color(hex: "#47d4ff")),
        BarChartDataPoint(label: "Sat", value: 18, color: Color(hex: "#47d4ff")),
        BarChartDataPoint(label: "Sun", value: 15, color: Color(hex: "#47d4ff"))
    ]
}

private var projectStatusData: [BarChartDataPoint] {
    [
        BarChartDataPoint(label: "Active", value: 12, color: Color(hex: "#4ade80")),
        BarChartDataPoint(label: "Planning", value: 5, color: Color(hex: "#ffd93d")),
        BarChartDataPoint(label: "On Hold", value: 3, color: Color(hex: "#ff6b9d")),
        BarChartDataPoint(label: "Complete", value: 28, color: Color.white.opacity(0.3))
    ]
}
