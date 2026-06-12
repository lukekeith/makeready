//
//  HorizontalBarChart.swift
//  MakeReady
//
//  A reusable horizontal bar chart component using Apple's Swift Charts framework.
//  Perfect for rankings and comparisons on mobile screens.
//  Supports:
//  - Horizontal bars (quantitative on X-axis)
//  - Dynamic height based on data count
//  - Solid colors or gradients
//  - Optional value labels
//

import SwiftUI
import Charts

// MARK: - Data Structures

struct BarChartDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

// MARK: - Main Horizontal Bar Chart Component

struct HorizontalBarChart: View {
    let dataPoints: [BarChartDataPoint]
    let showValues: Bool
    let barHeight: CGFloat

    init(
        dataPoints: [BarChartDataPoint],
        showValues: Bool = true,
        barHeight: CGFloat = 32
    ) {
        self.dataPoints = dataPoints
        self.showValues = showValues
        self.barHeight = barHeight
    }

    var body: some View {
        Chart(dataPoints) { dataPoint in
            BarMark(
                x: .value("Value", dataPoint.value),
                y: .value("Label", dataPoint.label)
            )
            .foregroundStyle(dataPoint.color)
            .annotation(position: .trailing, alignment: .leading) {
                if showValues {
                    Text(formatValue(dataPoint.value))
                        .font(Typography.s12Semibold)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.leading, 8)
                }
            }
        }
        .chartXAxis {
            AxisMarks(position: .bottom) { value in
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(formatAxisValue(doubleValue))
                            .font(Typography.s11)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let stringValue = value.as(String.self) {
                        Text(stringValue)
                            .font(Typography.s13)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
        }
        .frame(height: CGFloat(dataPoints.count) * barHeight + 40)
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
            // Example 1: Member activity rankings
            VStack(alignment: .leading, spacing: 12) {
                Text("Top Members (This Month)")
                    .font(Typography.s13Semibold)
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                HorizontalBarChart(
                    dataPoints: memberActivityData,
                    showValues: true
                )
            }

            // Example 2: Task completion by category
            VStack(alignment: .leading, spacing: 12) {
                Text("Tasks by Category")
                    .font(Typography.s13Semibold)
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                HorizontalBarChart(
                    dataPoints: tasksByCategoryData,
                    showValues: true,
                    barHeight: 36
                )
            }

            // Example 3: Revenue by region (with gradients)
            VStack(alignment: .leading, spacing: 12) {
                Text("Revenue by Region")
                    .font(Typography.s13Semibold)
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                HorizontalBarChart(
                    dataPoints: revenueByRegionData,
                    showValues: true
                )
            }
        }
        .padding(16)
    }
}

// MARK: - Sample Data

private var memberActivityData: [BarChartDataPoint] {
    [
        BarChartDataPoint(label: "Sarah J.", value: 145, color: Color.brandPrimary),
        BarChartDataPoint(label: "Mike T.", value: 132, color: Color.brandPrimary.opacity(0.8)),
        BarChartDataPoint(label: "Emma W.", value: 118, color: Color.brandPrimary.opacity(0.6)),
        BarChartDataPoint(label: "John D.", value: 95, color: Color.brandPrimary.opacity(0.4)),
        BarChartDataPoint(label: "Lisa K.", value: 87, color: Color.brandPrimary.opacity(0.3))
    ]
}

private var tasksByCategoryData: [BarChartDataPoint] {
    [
        BarChartDataPoint(label: "Development", value: 42, color: Color(hex: "#47d4ff")),
        BarChartDataPoint(label: "Design", value: 28, color: Color(hex: "#ff6b9d")),
        BarChartDataPoint(label: "Marketing", value: 19, color: Color(hex: "#ffd93d")),
        BarChartDataPoint(label: "Operations", value: 12, color: Color(hex: "#4ade80"))
    ]
}

private var revenueByRegionData: [BarChartDataPoint] {
    [
        BarChartDataPoint(label: "North America", value: 8500, color: Color.brandPrimary),
        BarChartDataPoint(label: "Europe", value: 6200, color: Color(hex: "#47d4ff")),
        BarChartDataPoint(label: "Asia Pacific", value: 4800, color: Color(hex: "#ff6b9d")),
        BarChartDataPoint(label: "Latin America", value: 2100, color: Color(hex: "#ffd93d"))
    ]
}
