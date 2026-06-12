//
//  Kpi.swift
//  MakeReady
//
//  Reusable KPI component for displaying key performance indicators
//  with automatic value formatting, labels, icons, and inline sparkline
//  trend lines. Four variants: standard, compact, sparkline, iconValue.
//

import SwiftUI
import Charts

// MARK: - Data Structures

/// How to format the KPI value
enum KpiValueType {
    case number
    case decimal(places: Int = 2)
    case currency(symbol: String = "$")
    case percent
    case custom(prefix: String = "", suffix: String = "")
}

/// Sparkline trend data
struct KpiTrend {
    let points: [Double]
    var color: Color = .brandPrimary
}

/// Layout variant
enum KpiVariant {
    case standard
    case compact
    case sparkline
    case iconValue
}

// MARK: - Sparkline Data Point

private struct SparklinePoint: Identifiable {
    let id: Int
    let value: Double
}

// MARK: - Sparkline View

private struct SparklineView: View {
    let trend: KpiTrend

    private var dataPoints: [SparklinePoint] {
        trend.points.enumerated().map { SparklinePoint(id: $0.offset, value: $0.element) }
    }

    var body: some View {
        Chart(dataPoints) { point in
            LineMark(
                x: .value("X", point.id),
                y: .value("Y", point.value)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(trend.color)

            AreaMark(
                x: .value("X", point.id),
                y: .value("Y", point.value)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(
                LinearGradient(
                    colors: [trend.color.opacity(0.3), trend.color.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}

// MARK: - Kpi Component

struct Kpi: View {
    let value: Double
    let valueType: KpiValueType
    let label: String
    var description: String? = nil
    var icon: String? = nil
    var iconColor: Color? = nil
    var trend: KpiTrend? = nil
    var variant: KpiVariant = .standard

    private var formattedValue: String {
        Self.format(value, type: valueType)
    }

    private static func format(_ value: Double, type: KpiValueType) -> String {
        switch type {
        case .number:
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"

        case .decimal(let places):
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = places
            formatter.maximumFractionDigits = places
            return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(places)f", value)

        case .currency(let symbol):
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return "\(symbol)\(formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))")"

        case .percent:
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = value.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
            formatter.maximumFractionDigits = 1
            return "\(formatter.string(from: NSNumber(value: value)) ?? "\(value)")%"

        case .custom(let prefix, let suffix):
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            let formatted = formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
            return "\(prefix)\(formatted)\(suffix)"
        }
    }

    var body: some View {
        Group {
            switch variant {
            case .standard:
                standardLayout
            case .compact:
                compactLayout
            case .sparkline:
                sparklineLayout
            case .iconValue:
                iconValueLayout
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var resolvedIconColor: Color {
        iconColor ?? .white.opacity(0.5)
    }

    // MARK: - Standard

    private var standardLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(Typography.s13)
                        .foregroundColor(resolvedIconColor)
                }
                Text(label)
                    .font(Typography.s13Semibold)
                    .foregroundColor(.white.opacity(0.5))
            }

            Text(formattedValue)
                .font(Typography.s28Bold)
                .foregroundColor(.white)

            if let description = description {
                Text(description)
                    .font(Typography.s13)
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Compact

    private var compactLayout: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(Typography.s15)
                    .foregroundColor(resolvedIconColor)
            }

            Text(formattedValue)
                .font(Typography.s17Bold)
                .foregroundColor(.white)

            Spacer()

            Text(label)
                .font(Typography.s13Semibold)
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Sparkline

    private var sparklineLayout: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(label)
                    .font(Typography.s13Semibold)
                    .foregroundColor(.white.opacity(0.5))

                Text(formattedValue)
                    .font(Typography.s28Bold)
                    .foregroundColor(.white)

                if let description = description {
                    Text(description)
                        .font(Typography.s13)
                        .foregroundColor(.white.opacity(0.3))
                }
            }

            Spacer()

            if let trend = trend {
                SparklineView(trend: trend)
                    .frame(width: 80, height: 48)
            }
        }
    }

    // MARK: - Icon Value

    private var iconValueLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Value top-left, icon top-right, aligned on same row
            HStack(alignment: .top) {
                Text(formattedValue)
                    .font(Typography.s24Bold)
                    .foregroundColor(.white)

                Spacer()

                if let icon = icon {
                    Image(systemName: icon)
                        .font(Typography.s22)
                        .foregroundColor(resolvedIconColor)
                }
            }

            Spacer().frame(height: 16)

            // Label
            Text(label)
                .font(Typography.s13Semibold)
                .foregroundColor(.white.opacity(0.5))

            if let description = description {
                Spacer().frame(height: 8)

                Text(description)
                    .font(Typography.s13)
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

#Preview("Standard") {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 16) {
            Kpi(
                value: 12450,
                valueType: .currency(),
                label: "Revenue",
                description: "Monthly revenue",
                icon: "chart.line.uptrend.xyaxis"
            )

            Kpi(
                value: 85.5,
                valueType: .percent,
                label: "Completion Rate",
                description: "Across all programs",
                icon: "checkmark.circle"
            )
        }
        .padding(16)
    }
}

#Preview("Compact") {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 12) {
            Kpi(
                value: 1234,
                valueType: .number,
                label: "Members",
                icon: "person.2",
                variant: .compact
            )

            Kpi(
                value: 42,
                valueType: .custom(suffix: " days"),
                label: "Streak",
                icon: "flame",
                variant: .compact
            )
        }
        .padding(16)
    }
}

#Preview("Sparkline") {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 16) {
            Kpi(
                value: 12450,
                valueType: .currency(),
                label: "Revenue",
                description: "Monthly revenue",
                trend: KpiTrend(points: [8, 10, 9, 12, 11, 14, 13, 16]),
                variant: .sparkline
            )

            Kpi(
                value: 342,
                valueType: .number,
                label: "Active Users",
                description: "Last 30 days",
                trend: KpiTrend(points: [200, 220, 250, 240, 280, 310, 342], color: .green),
                variant: .sparkline
            )
        }
        .padding(16)
    }
}

#Preview("Icon Value") {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            Kpi(
                value: 27,
                valueType: .number,
                label: "Members",
                icon: "person.2.fill",
                iconColor: .blue,
                variant: .iconValue
            )

            Kpi(
                value: 5,
                valueType: .custom(prefix: "Level "),
                label: "Progress",
                icon: "star.fill",
                iconColor: .yellow,
                variant: .iconValue
            )

            Kpi(
                value: 98.2,
                valueType: .percent,
                label: "Uptime",
                description: "Across all services last 30 days",
                icon: "bolt.fill",
                iconColor: .green,
                variant: .iconValue
            )

            Kpi(
                value: 3450,
                valueType: .currency(),
                label: "Donations",
                description: "Monthly total from all groups",
                icon: "heart.fill",
                iconColor: .pink,
                variant: .iconValue
            )
        }
        .padding(16)
    }
}
