//
//  LineChart.swift
//  MakeReady
//
//  A reusable line chart component using Apple's Swift Charts framework.
//  Supports:
//  - Multiple trend lines
//  - Solid colors or gradients
//  - Auto or fixed Y-axis scaling
//  - Time-based X-axis (hours, days, weeks, months, years)
//  - Interactive tap to show values
//  - Smooth animations
//

import SwiftUI
import Charts

// MARK: - Data Structures

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct TrendLine: Identifiable {
    let id = UUID()
    let dataPoints: [ChartDataPoint]
    let color: ChartColor
    let lineWidth: CGFloat

    init(dataPoints: [ChartDataPoint], color: ChartColor, lineWidth: CGFloat = 2.0) {
        self.dataPoints = dataPoints
        self.color = color
        self.lineWidth = lineWidth
    }
}

enum ChartColor {
    case solid(Color)
    case gradient(colors: [Color], angle: Double) // angle in degrees (0-360)

    func toGradient() -> LinearGradient {
        switch self {
        case .solid(let color):
            return LinearGradient(colors: [color], startPoint: .leading, endPoint: .trailing)
        case .gradient(let colors, let angle):
            let (start, end) = angleToPoints(angle)
            return LinearGradient(colors: colors, startPoint: start, endPoint: end)
        }
    }

    func toColor() -> Color {
        switch self {
        case .solid(let color):
            return color
        case .gradient(let colors, _):
            // For Swift Charts, use the first color when a solid color is needed
            return colors.first ?? .purple
        }
    }

    func toAreaGradient() -> LinearGradient {
        let topColor: Color
        switch self {
        case .solid(let color):
            topColor = color
        case .gradient(let colors, _):
            topColor = colors.first ?? .purple
        }
        return LinearGradient(
            colors: [topColor.opacity(0.3), topColor.opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func angleToPoints(_ degrees: Double) -> (UnitPoint, UnitPoint) {
        let radians = degrees * .pi / 180.0
        let x = cos(radians)
        let y = sin(radians)

        let startX = 0.5 - x / 2
        let startY = 0.5 - y / 2
        let endX = 0.5 + x / 2
        let endY = 0.5 + y / 2

        return (
            UnitPoint(x: startX, y: startY),
            UnitPoint(x: endX, y: endY)
        )
    }
}

enum TimeScale {
    case hours
    case days
    case weeks
    case months
    case years

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        switch self {
        case .hours:
            formatter.dateFormat = "ha"
            return formatter.string(from: date).lowercased()
        case .days:
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        case .weeks:
            let calendar = Calendar.current
            let weekOfYear = calendar.component(.weekOfYear, from: date)
            return "W\(weekOfYear)"
        case .months:
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
        case .years:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: date)
        }
    }
}

enum YAxisScale {
    case auto
    case fixed(min: Double, max: Double)
}

enum ChartInterpolationMethod {
    case linear      // Straight lines between points
    case monotone    // Smooth curves without overshooting (best for accuracy)
    case catmullRom  // Smooth flowing curves (best for aesthetics)

    var swiftChartsMethod: Charts.InterpolationMethod {
        switch self {
        case .linear:
            return .linear
        case .monotone:
            return .monotone
        case .catmullRom:
            return .catmullRom
        }
    }
}

// MARK: - Main Chart Component

struct LineChart: View {
    let trendLines: [TrendLine]
    let timeScale: TimeScale
    let yAxisScale: YAxisScale
    let interactive: Bool
    let animated: Bool
    let showArea: Bool
    let interpolationMethod: ChartInterpolationMethod

    @State private var selectedDate: Date?
    @State private var selectedValue: Double?

    init(
        trendLines: [TrendLine],
        timeScale: TimeScale = .days,
        yAxisScale: YAxisScale = .auto,
        interactive: Bool = true,
        animated: Bool = true,
        showArea: Bool = false,
        interpolationMethod: ChartInterpolationMethod = .monotone
    ) {
        self.trendLines = trendLines
        self.timeScale = timeScale
        self.yAxisScale = yAxisScale
        self.interactive = interactive
        self.animated = animated
        self.showArea = showArea
        self.interpolationMethod = interpolationMethod
    }

    // Convenience init for single line
    init(
        dataPoints: [ChartDataPoint],
        color: ChartColor,
        lineWidth: CGFloat = 2.0,
        timeScale: TimeScale = .days,
        yAxisScale: YAxisScale = .auto,
        interactive: Bool = true,
        animated: Bool = true,
        showArea: Bool = false,
        interpolationMethod: ChartInterpolationMethod = .monotone
    ) {
        self.trendLines = [TrendLine(dataPoints: dataPoints, color: color, lineWidth: lineWidth)]
        self.timeScale = timeScale
        self.yAxisScale = yAxisScale
        self.interactive = interactive
        self.animated = animated
        self.showArea = showArea
        self.interpolationMethod = interpolationMethod
    }

    var body: some View {
        VStack(spacing: 0) {
            // Chart
            Chart {
                ForEach(trendLines) { trendLine in
                    ForEach(trendLine.dataPoints) { point in
                        // Area fill (if enabled)
                        if showArea {
                            AreaMark(
                                x: .value("Time", point.date),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(trendLine.color.toAreaGradient())
                            .interpolationMethod(interpolationMethod.swiftChartsMethod)
                        }

                        // Line
                        LineMark(
                            x: .value("Time", point.date),
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(trendLine.color.toGradient())
                        .lineStyle(StrokeStyle(lineWidth: trendLine.lineWidth, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(interpolationMethod.swiftChartsMethod)

                        // Interactive point indicator
                        if interactive, let selectedDate = selectedDate, Calendar.current.isDate(point.date, equalTo: selectedDate, toGranularity: .second) {
                            PointMark(
                                x: .value("Time", point.date),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(trendLine.color.toColor())
                            .symbolSize(100)
                        }
                    }
                }

                // Rule mark for selected value
                if let selectedDate = selectedDate {
                    RuleMark(x: .value("Selected", selectedDate))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .annotation(position: .top, spacing: 8) {
                            if let selectedValue = selectedValue {
                                VStack(spacing: 4) {
                                    Text(String(format: "%.1f", selectedValue))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.black.opacity(0.8))
                                )
                            }
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(timeScale.formatDate(date))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    if let doubleValue = value.as(Double.self) {
                        AxisValueLabel {
                            Text(formatYAxisValue(doubleValue))
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
            }
            .chartYScale(domain: yAxisDomain)
            .chartXSelection(value: $selectedDate)
            .frame(height: 120)
            .onChange(of: selectedDate) { oldValue, newValue in
                updateSelectedValue()
            }
        }
    }

    // MARK: - Computed Properties

    private var yAxisDomain: ClosedRange<Double> {
        switch yAxisScale {
        case .auto:
            let allValues = trendLines.flatMap { $0.dataPoints.map { $0.value } }
            let minValue = allValues.min() ?? 0
            let maxValue = allValues.max() ?? 100
            // Round to nice numbers
            let min = floor(minValue / 10) * 10
            let max = ceil(maxValue / 10) * 10
            return min...max
        case .fixed(let min, let max):
            return min...max
        }
    }

    // MARK: - Helper Methods

    private func formatYAxisValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0fk", value / 1000)
        } else if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func updateSelectedValue() {
        guard let selectedDate = selectedDate else {
            selectedValue = nil
            return
        }

        // Find closest data point to selected date
        var closestPoint: ChartDataPoint?
        var closestDistance: TimeInterval = .infinity

        for trendLine in trendLines {
            for point in trendLine.dataPoints {
                let distance = abs(point.date.timeIntervalSince(selectedDate))
                if distance < closestDistance {
                    closestDistance = distance
                    closestPoint = point
                }
            }
        }

        selectedValue = closestPoint?.value
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 32) {
            // Example 1: Single line with gradient (matching Figma)
            VStack(alignment: .leading, spacing: 8) {
                Text("Growth Chart (Gradient)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                LineChart(
                    dataPoints: sampleData2023to2025,
                    color: .gradient(
                        colors: [Color(hex: "#6c47ff"), Color(hex: "#47d4ff")],
                        angle: 90
                    ),
                    lineWidth: 3,
                    timeScale: .years,
                    showArea: true
                )
            }

            // Example 2: Solid color line
            VStack(alignment: .leading, spacing: 8) {
                Text("Revenue Chart (Solid)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                LineChart(
                    dataPoints: sampleDataDays,
                    color: .solid(Color.brandPrimary),
                    lineWidth: 2,
                    timeScale: .days,
                    animated: true
                )
            }

            // Example 3: Multiple trend lines
            VStack(alignment: .leading, spacing: 8) {
                Text("Multiple Trends")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                LineChart(
                    trendLines: [
                        TrendLine(
                            dataPoints: sampleDataMonths1,
                            color: .solid(Color.brandPrimary),
                            lineWidth: 2
                        ),
                        TrendLine(
                            dataPoints: sampleDataMonths2,
                            color: .solid(Color(hex: "#47d4ff")),
                            lineWidth: 2
                        )
                    ],
                    timeScale: .months,
                    interactive: true
                )
            }
        }
        .padding(16)
    }
}

// MARK: - Sample Data

private var sampleData2023to2025: [ChartDataPoint] {
    let calendar = Calendar.current
    let start = calendar.date(from: DateComponents(year: 2023, month: 1, day: 1))!

    let values: [Double] = [10, 15, 12, 20, 35, 40, 50, 60, 80, 95, 110, 130, 145, 160, 180, 190, 200]

    return values.enumerated().map { index, value in
        let months = index * 2 // Every 2 months
        let date = calendar.date(byAdding: .month, value: months, to: start)!
        return ChartDataPoint(date: date, value: value)
    }
}

private var sampleDataDays: [ChartDataPoint] {
    let calendar = Calendar.current
    let today = Date()

    let values: [Double] = [100, 110, 95, 105, 130, 125, 150]

    return values.enumerated().map { index, value in
        let date = calendar.date(byAdding: .day, value: -6 + index, to: today)!
        return ChartDataPoint(date: date, value: value)
    }
}

private var sampleDataMonths1: [ChartDataPoint] {
    let calendar = Calendar.current
    let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!

    let values: [Double] = [50, 60, 55, 70, 80, 90, 95, 110, 120, 130, 140, 150]

    return values.enumerated().map { index, value in
        let date = calendar.date(byAdding: .month, value: index, to: start)!
        return ChartDataPoint(date: date, value: value)
    }
}

private var sampleDataMonths2: [ChartDataPoint] {
    let calendar = Calendar.current
    let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!

    let values: [Double] = [30, 35, 40, 45, 55, 65, 70, 85, 95, 100, 110, 120]

    return values.enumerated().map { index, value in
        let date = calendar.date(byAdding: .month, value: index, to: start)!
        return ChartDataPoint(date: date, value: value)
    }
}
