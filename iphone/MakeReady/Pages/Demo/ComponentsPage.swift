//
//  ComponentsPage.swift
//  MakeReady
//
//  Component showcase page for testing UI components
//

import SwiftUI

struct ComponentsPage: View {
    let overlayManager: OverlayManager
    @State private var activeTab = 0

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page title
                PageTitle.iconTitle(
                    title: "Components",
                    icon: "xmark",
                    onIconTap: {
                        overlayManager.dismiss(id: OverlayID.componentsPage)
                    }
                )

                // Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ComponentTabButton(
                            title: "Fields",
                            isActive: activeTab == 0,
                            onTap: {
                                withAnimation {
                                    activeTab = 0
                                }
                            }
                        )

                        ComponentTabButton(
                            title: "Buttons",
                            isActive: activeTab == 1,
                            onTap: {
                                withAnimation {
                                    activeTab = 1
                                }
                            }
                        )

                        ComponentTabButton(
                            title: "Members",
                            isActive: activeTab == 2,
                            onTap: {
                                withAnimation {
                                    activeTab = 2
                                }
                            }
                        )

                        ComponentTabButton(
                            title: "Contacts",
                            isActive: activeTab == 3,
                            onTap: {
                                withAnimation {
                                    activeTab = 3
                                }
                            }
                        )

                        ComponentTabButton(
                            title: "Charts",
                            isActive: activeTab == 4,
                            onTap: {
                                withAnimation {
                                    activeTab = 4
                                }
                            }
                        )

                        ComponentTabButton(
                            title: "QR",
                            isActive: activeTab == 5,
                            onTap: {
                                withAnimation {
                                    activeTab = 5
                                }
                            }
                        )

                        ComponentTabButton(
                            title: "Cards",
                            isActive: activeTab == 6,
                            onTap: {
                                withAnimation {
                                    activeTab = 6
                                }
                            }
                        )

                        ComponentTabButton(
                            title: "Swipeable",
                            isActive: activeTab == 7,
                            onTap: {
                                withAnimation {
                                    activeTab = 7
                                }
                            }
                        )

                        ComponentTabButton(
                            title: "Alerts",
                            isActive: activeTab == 8,
                            onTap: {
                                withAnimation {
                                    activeTab = 8
                                }
                            }
                        )
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 8)

                // Content
                ScrollView {
                    Group {
                        if activeTab == 0 {
                            FieldsTabContent()
                        } else if activeTab == 1 {
                            ButtonsTabContent()
                        } else if activeTab == 2 {
                            MembersTabContent()
                        } else if activeTab == 3 {
                            ContactsTabContent()
                        } else if activeTab == 4 {
                            ChartsTabContent()
                        } else if activeTab == 5 {
                            QRTabContent(overlayManager: overlayManager)
                        } else if activeTab == 6 {
                            CardsTabContent()
                        } else if activeTab == 7 {
                            SwipeableTabContent()
                        } else {
                            AlertsTabContent()
                        }
                    }
                }
            }
        }
    }
}

// Tab button component
struct ComponentTabButton: View {
    let title: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(isActive ? .white : .white.opacity(0.7))

                Rectangle()
                    .fill(Color(hex: "#6c47ff"))
                    .frame(height: 2)
                    .opacity(isActive ? 1 : 0)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Fields Tab Content

struct FieldsTabContent: View {
    @State private var textValue = ""
    @State private var multilineValue = ""
    @State private var togglePrivate = false
    @State private var toggleInvites = true
    @State private var toggleWelcome = false
    @State private var dateValue = Date()
    @State private var menuValue = "Unlimited"
    @State private var nameValue = ""
    @State private var emailValue = ""
    @State private var phoneValue = ""

    // Large input states
    @State private var largeTextValue = ""
    @State private var largePhoneValue = ""
    @State private var largeEmailValue = ""
    @State private var largeIntegerValue = ""
    @State private var largeFloatValue = ""
    @State private var largeCurrencyValue = ""
    @State private var largePercentageValue = ""

    // Validation errors
    @State private var phoneError: String? = nil
    @State private var emailError: String? = nil
    @State private var integerError: String? = nil
    @State private var currencyError: String? = nil

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Text Input (Placeholder)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                FieldGroup {
                    TextInput(placeholder: "Enter group name", text: $textValue)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Text Input (Labeled with Icons)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                FieldGroup {
                    TextInput(label: "Name", icon: "person.fill", text: $nameValue)
                    Divider().background(Color.white.opacity(0.1)).padding(.leading, 52)
                    TextInput(label: "Email", icon: "envelope.fill", text: $emailValue)
                    Divider().background(Color.white.opacity(0.1)).padding(.leading, 52)
                    TextInput(label: "Phone", icon: "phone.fill", text: $phoneValue, keyboardType: .phonePad)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Multiline Text Input")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                FieldGroup {
                    MultilineTextInput(
                        placeholder: "Describe the purpose of the group",
                        text: $multilineValue
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Toggle Controls")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                ToggleGroup {
                    ToggleControl(
                        title: "Private",
                        description: "Only members can see members and their activity in the group.",
                        isOn: $togglePrivate
                    )

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.leading, 16)

                    ToggleControl(
                        title: "Allow members to send invites",
                        description: "Enable this option to send invites from their mobile web portal",
                        isOn: $toggleInvites
                    )

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.leading, 16)

                    ToggleControl(
                        title: "Send welcome message",
                        description: "Send a welcome message to every member when they join the group",
                        isOn: $toggleWelcome
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Date Picker")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                FieldGroup {
                    DatePickerField(label: "Date", date: $dateValue)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Menu Input")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                FieldGroup {
                    MenuInput(
                        label: "Max members",
                        options: ["Unlimited", "10", "25", "50", "100"],
                        selectedOption: $menuValue
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Large Text Input - Data Types")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .padding(.top, 20)

                Text("These inputs automatically format and validate based on their type")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.bottom, 8)
            }

            VStack(alignment: .leading, spacing: 20) {
                // Phone
                VStack(alignment: .leading, spacing: 4) {
                    Text("Phone - Auto-formats as (###) ###-####")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                    LargeTextInput(
                        label: "Phone",
                        inputType: .phone,
                        text: $largePhoneValue,
                        validationError: $phoneError
                    )
                }

                // Integer
                VStack(alignment: .leading, spacing: 4) {
                    Text("Integer - Numbers only")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                    LargeTextInput(
                        label: "Age",
                        inputType: .integer,
                        text: $largeIntegerValue,
                        validationError: $integerError
                    )
                }

                // Float
                VStack(alignment: .leading, spacing: 4) {
                    Text("Float - Decimal numbers")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                    LargeTextInput(
                        label: "Weight (lbs)",
                        inputType: .float,
                        text: $largeFloatValue
                    )
                }

                // Currency
                VStack(alignment: .leading, spacing: 4) {
                    Text("Currency - $ icon, thousand separators, 2 decimals")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                    LargeTextInput(
                        label: "Amount",
                        inputType: .currency,
                        text: $largeCurrencyValue,
                        validationError: $currencyError
                    )
                }

                // Email
                VStack(alignment: .leading, spacing: 4) {
                    Text("Email - Validates email format")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                    LargeTextInput(
                        label: "Email",
                        inputType: .email,
                        text: $largeEmailValue,
                        validationError: $emailError
                    )
                }

                // Percentage
                VStack(alignment: .leading, spacing: 4) {
                    Text("Percentage - 0-100 with % icon")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                    LargeTextInput(
                        label: "Completion",
                        inputType: .percentage,
                        text: $largePercentageValue
                    )
                }

                // Alphanumeric (default)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Alphanumeric - Any characters (default)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                    LargeTextInput(
                        label: "Full name",
                        inputType: .alphanumeric,
                        text: $largeTextValue
                    )
                }
            }

            Spacer(minLength: 80)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
}

// MARK: - Buttons Tab Content

struct ButtonsTabContent: View {
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Purple variant")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                HStack(spacing: 12) {
                    ActionButton(label: "Poll", icon: "chart.bar.fill", variant: .purple) {
                        print("Poll tapped")
                    }

                    ActionButton(label: "Invite", variant: .purple) {
                        print("Invite tapped")
                    }

                    ActionButton(icon: "chart.bar.fill", variant: .purpleIcon) {
                        print("Chart tapped")
                    }

                    Spacer()
                }

                HStack(spacing: 12) {
                    ActionButton(label: "Add", icon: "plus.circle", variant: .purple) {
                        print("Add tapped")
                    }

                    ActionButton(label: "Send", icon: "paperplane.fill", variant: .purple) {
                        print("Send tapped")
                    }

                    ActionButton(icon: "star.fill", variant: .purpleIcon) {
                        print("Star tapped")
                    }

                    Spacer()
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("White variant")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                HStack(spacing: 12) {
                    ActionButton(label: "Settings", icon: "gearshape", variant: .white) {
                        print("Settings tapped")
                    }

                    ActionButton(label: "Edit", variant: .white) {
                        print("Edit tapped")
                    }

                    ActionButton(icon: "ellipsis", variant: .whiteIcon) {
                        print("More tapped")
                    }

                    Spacer()
                }

                HStack(spacing: 12) {
                    ActionButton(label: "Delete", icon: "trash", variant: .white) {
                        print("Delete tapped")
                    }

                    ActionButton(label: "Share", icon: "square.and.arrow.up", variant: .white) {
                        print("Share tapped")
                    }

                    ActionButton(icon: "heart.fill", variant: .whiteIcon) {
                        print("Heart tapped")
                    }

                    Spacer()
                }
            }

            Spacer(minLength: 80)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
}

// MARK: - Members Tab Content

struct MembersTabContent: View {
    // Load from fixtures
    let members: [FixturesManager.MemberFixture] = FixturesManager.shared.loadMembers()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Member Cards")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)

            ForEach(members, id: \.id) { memberFixture in
                CardMember(
                    data: CardMemberData(
                        id: memberFixture.id,
                        firstName: memberFixture.firstName ?? "",
                        lastName: memberFixture.lastName ?? "",
                        avatarURL: memberFixture.avatarURL,
                        metadata: buildMemberMetadata(memberFixture),
                        groups: memberFixture.groups,
                        onTap: {
                            print("Tapped member card")
                        }
                    )
                ) {
                    ActionButton(label: "Invite", variant: .purple) {
                        print("Invite from card")
                    }
                }
            }

            Spacer(minLength: 80)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }

    private func buildMemberMetadata(_ member: FixturesManager.MemberFixture) -> [DataItem] {
        var items: [DataItem] = []

        // Add age if available
        if let birthDate = member.birthDateAsDate {
            let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
            items.append(DataItem(icon: "calendar", value: "Age \(age)"))
        }

        // Add join date if available
        if let joinDate = member.joinDateAsDate {
            items.append(DataItem(icon: "clock", value: DateFormatters.monthYear.string(from: joinDate)))
        }

        return items
    }
}

// MARK: - Contacts Tab Content

struct ContactsTabContent: View {
    // Load from fixtures
    let contacts: [FixturesManager.ContactFixture] = FixturesManager.shared.loadContacts()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Contact Cards")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)

            ForEach(contacts, id: \.id) { contactFixture in
                CardContact(
                    data: CardContactData(
                        id: contactFixture.id,
                        firstName: contactFixture.firstName ?? "",
                        lastName: contactFixture.lastName ?? "",
                        avatarURL: contactFixture.avatarURL,
                        onTap: {
                            print("Tapped contact card")
                        }
                    )
                ) {
                    ActionButton(label: "Invite", variant: .purple) {
                        print("Invite from card")
                    }
                }
            }

            Spacer(minLength: 80)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
}

// MARK: - Charts Tab Content

struct ChartsTabContent: View {
    var body: some View {
        VStack(spacing: 32) {
            // Example 1: Single line with gradient (matching Figma)
            VStack(alignment: .leading, spacing: 12) {
                Text("Growth Chart (Gradient)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Purple to cyan gradient with area fill. Smooth catmullRom curves for aesthetics.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                LineChart(
                    dataPoints: sampleData2023to2025,
                    color: .gradient(
                        colors: [Color(hex: "#6c47ff"), Color(hex: "#47d4ff")],
                        angle: 90
                    ),
                    lineWidth: 3,
                    timeScale: .years,
                    showArea: true,
                    interpolationMethod: .catmullRom
                )
            }

            // Example 2: Solid color line
            VStack(alignment: .leading, spacing: 12) {
                Text("Daily Activity (Solid)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Solid brand color. Linear interpolation for precise point-to-point connections.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                LineChart(
                    dataPoints: sampleDataDays,
                    color: .solid(Color.brandPrimary),
                    lineWidth: 2,
                    timeScale: .days,
                    animated: true,
                    interpolationMethod: .linear
                )
            }

            // Example 3: Multiple trend lines
            VStack(alignment: .leading, spacing: 12) {
                Text("Multiple Trends")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Two trend lines. Monotone interpolation for smooth, accurate comparisons.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

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
                    interactive: true,
                    interpolationMethod: .monotone
                )
            }

            // Example 4: Different gradient angle
            VStack(alignment: .leading, spacing: 12) {
                Text("Weekly Progress (Diagonal)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Gradient at 45° angle. Uses default monotone interpolation (smooth + accurate).")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                LineChart(
                    dataPoints: sampleDataWeeks,
                    color: .gradient(
                        colors: [Color(hex: "#ff6b6b"), Color(hex: "#ffd93d")],
                        angle: 45
                    ),
                    lineWidth: 2.5,
                    timeScale: .weeks
                )
            }

            // Example 5: Budget Breakdown (Donut Chart)
            VStack(alignment: .leading, spacing: 12) {
                Text("Budget Breakdown (Donut)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Donut chart with center label. Perfect for part-to-whole relationships.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                VStack(spacing: 16) {
                    DonutChart(
                        dataPoints: budgetDonutData,
                        centerLabelText: "$12.5k",
                        centerLabelSubtext: "Budget"
                    )
                    .frame(width: 200, height: 200)

                    DonutChartLegend(dataPoints: budgetDonutData)
                }
                .frame(maxWidth: .infinity)
            }

            // Example 6: Member Rankings (Horizontal Bar)
            VStack(alignment: .leading, spacing: 12) {
                Text("Top Members (Horizontal Bar)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Horizontal bars perfect for rankings on mobile. Long labels don't crowd.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                HorizontalBarChart(
                    dataPoints: memberRankingsData,
                    showValues: true
                )
            }

            // Example 7: Monthly Metrics (Vertical Bar)
            VStack(alignment: .leading, spacing: 12) {
                Text("Monthly Revenue (Vertical Bar)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Classic vertical bars for time-series data. Works well with 5-7 categories.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                VerticalBarChart(
                    dataPoints: monthlyMetricsData,
                    showValues: true,
                    chartHeight: 180
                )
            }

            // Example 8: Activity Heatmap
            VStack(alignment: .leading, spacing: 12) {
                Text("Team Activity (Heat Map)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("GitHub-style heat map. Shows patterns over time with color intensity.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                HeatMapChart(
                    dataPoints: generateHeatMapData(weeks: 8),
                    showDayLabels: true
                )

                // Legend
                HStack(spacing: 8) {
                    Text("Less")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))

                    ForEach(0..<5) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatMapIntensityColor(for: index))
                            .frame(width: 12, height: 12)
                    }

                    Text("More")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer(minLength: 80)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }

    // Sample data for charts
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

    private var sampleDataWeeks: [ChartDataPoint] {
        let calendar = Calendar.current
        let today = Date()

        let values: [Double] = [40, 55, 45, 60]

        return values.enumerated().map { index, value in
            let date = calendar.date(byAdding: .weekOfYear, value: -3 + index, to: today)!
            return ChartDataPoint(date: date, value: value)
        }
    }

    // Sample data for donut chart
    private var budgetDonutData: [DonutChartDataPoint] {
        [
            DonutChartDataPoint(label: "Marketing", value: 4500, color: Color(hex: "#6c47ff")),
            DonutChartDataPoint(label: "Development", value: 3500, color: Color(hex: "#47d4ff")),
            DonutChartDataPoint(label: "Design", value: 2000, color: Color(hex: "#ff6b9d")),
            DonutChartDataPoint(label: "Operations", value: 1500, color: Color(hex: "#ffd93d")),
            DonutChartDataPoint(label: "Other", value: 1000, color: Color.white.opacity(0.3))
        ]
    }

    // Sample data for horizontal bar chart
    private var memberRankingsData: [BarChartDataPoint] {
        [
            BarChartDataPoint(label: "Sarah J.", value: 145, color: Color(hex: "#6c47ff")),
            BarChartDataPoint(label: "Mike T.", value: 132, color: Color(hex: "#6c47ff").opacity(0.8)),
            BarChartDataPoint(label: "Emma W.", value: 118, color: Color(hex: "#6c47ff").opacity(0.6)),
            BarChartDataPoint(label: "John D.", value: 95, color: Color(hex: "#6c47ff").opacity(0.4)),
            BarChartDataPoint(label: "Lisa K.", value: 87, color: Color(hex: "#6c47ff").opacity(0.3))
        ]
    }

    // Sample data for vertical bar chart
    private var monthlyMetricsData: [BarChartDataPoint] {
        [
            BarChartDataPoint(label: "Jan", value: 12500, color: Color(hex: "#6c47ff")),
            BarChartDataPoint(label: "Feb", value: 14200, color: Color(hex: "#6c47ff")),
            BarChartDataPoint(label: "Mar", value: 13800, color: Color(hex: "#6c47ff")),
            BarChartDataPoint(label: "Apr", value: 16100, color: Color(hex: "#6c47ff")),
            BarChartDataPoint(label: "May", value: 18300, color: Color(hex: "#6c47ff")),
            BarChartDataPoint(label: "Jun", value: 19500, color: Color(hex: "#6c47ff"))
        ]
    }

    // Generate heat map data
    private func generateHeatMapData(weeks: Int) -> [HeatMapDataPoint] {
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

    // Heat map intensity color
    private func heatMapIntensityColor(for level: Int) -> Color {
        switch level {
        case 0:
            return Color.white.opacity(0.05)
        case 1:
            return Color(hex: "#6c47ff").opacity(0.2)
        case 2:
            return Color(hex: "#6c47ff").opacity(0.4)
        case 3:
            return Color(hex: "#6c47ff").opacity(0.7)
        case 4:
            return Color(hex: "#6c47ff")
        default:
            return Color.white.opacity(0.05)
        }
    }
}

// MARK: - QR Tab Content

struct QRTabContent: View {
    let overlayManager: OverlayManager
    @Environment(AuthManager.self) var authManager

    var body: some View {
        VStack(spacing: 32) {
            // Example 1: QR Code with Branding
            VStack(alignment: .leading, spacing: 12) {
                Text("QR Code (Branded)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Custom-styled QR code with MakeReady branding. Generated from server API.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                InviteQRCodeView(
                    inviteCode: "ABC123XYZ",
                    size: 200
                )
                .frame(maxWidth: .infinity)
            }

            // Example 2: Share Invite Sheet Demo
            VStack(alignment: .leading, spacing: 12) {
                Text("Share Invite Sheet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Complete share flow with QR code, copy link, and native sharing.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                Button(action: {
                    overlayManager.presentModal(id: "shareInviteDemo") {
                        ShareInviteSheet(
                            inviteCode: "DEMO123",
                            overlayManager: overlayManager
                        )
                        .environment(authManager)
                    }
                }) {
                    HStack {
                        Image(systemName: "qrcode")
                        Text("Open Share Sheet")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "#6c47ff"))
                    .cornerRadius(10)
                }
            }

            Spacer(minLength: 80)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
}

// MARK: - Cards Tab Content

struct CardsTabContent: View {
    // Load card data from fixtures
    let fixtures = CardFixtures.shared

    // State for group card selection (only Group cards are selectable)
    @State private var groupSelectionStates: [String: Bool] = [:]

    var body: some View {
        VStack(spacing: 32) {
            // Study Cards
            VStack(alignment: .leading, spacing: 12) {
                Text("Study Cards")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Studies show interval (daily/weekly) and participants. Pending state shows PENDING badge inside image.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                // Row cards from fixtures
                ForEach(fixtures.studyRowCards, id: \.id) { cardData in
                    CardStudy(data: cardData)
                }

                // Mini cards from fixtures
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(fixtures.studyMiniCards, id: \.id) { cardData in
                            CardStudyMini(data: cardData)
                        }
                    }
                }
            }

            // Event Cards
            VStack(alignment: .leading, spacing: 12) {
                Text("Event Cards")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Events display day/month instead of images. Primary data: location (Row), time (Mini).")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                // Row cards from fixtures
                ForEach(fixtures.eventRowCards, id: \.id) { cardData in
                    CardEvent(data: cardData)
                }

                // Mini cards from fixtures
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(fixtures.eventMiniCards, id: \.id) { cardData in
                            CardEventMini(data: cardData)
                        }
                    }
                }
            }

            // Group Cards
            VStack(alignment: .leading, spacing: 12) {
                Text("Group Cards")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Groups show image/icon and member count. Tap cards to toggle selected state (500ms animation).")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                // Row cards from fixtures
                ForEach(fixtures.groupRowCards, id: \.id) { cardData in
                    CardGroup(
                        data: CardGroupData(
                            id: cardData.id,
                            title: cardData.title,
                            imageStyle: cardData.imageStyle,
                            metadata: cardData.metadata,
                            isSelected: groupSelectionStates[cardData.id] ?? false,
                            onTap: {
                                groupSelectionStates[cardData.id] = !(groupSelectionStates[cardData.id] ?? false)
                            }
                        )
                    )
                }

                // Mini cards from fixtures
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(fixtures.groupMiniCards, id: \.id) { cardData in
                            CardGroupMini(
                                data: CardGroupData(
                                    id: cardData.id,
                                    title: cardData.title,
                                    imageStyle: cardData.imageStyle,
                                    metadata: cardData.metadata,
                                    isSelected: groupSelectionStates[cardData.id] ?? false,
                                    onTap: {
                                        groupSelectionStates[cardData.id] = !(groupSelectionStates[cardData.id] ?? false)
                                    }
                                )
                            )
                        }
                    }
                }
            }

            // Video Cards
            VStack(alignment: .leading, spacing: 12) {
                Text("Video Cards")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Videos always have images with play button overlay. Shows views, time posted, shares.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                // Row card (first from fixtures)
                if let firstRowCard = fixtures.videoRowCards.first {
                    CardVideo(data: firstRowCard)
                }

                // Mini card (first from fixtures)
                if let firstMiniCard = fixtures.videoMiniCards.first {
                    CardVideoMini(data: firstMiniCard)
                }
            }

            // Lesson Cards
            VStack(alignment: .leading, spacing: 12) {
                Text("Lesson Cards")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Lessons show day indicator and activities. Empty lessons show 'Select activities' prompt.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                // Show all lesson examples
                ForEach(fixtures.lessonCards, id: \.id) { cardData in
                    CardLesson(data: cardData)
                }
            }

            Spacer(minLength: 80)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
}

// MARK: - Swipeable Tab Content

struct SwipeableTabContent: View {
    // Load card data from fixtures
    let fixtures = CardFixtures.shared

    var body: some View {
        VStack(spacing: 32) {
            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("Swipeable Cards")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Swipe cards left to reveal action buttons. Buttons grow from 24→48px and fade in progressively. Tap card when revealed to close.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))
            }

            // Event Cards
            VStack(alignment: .leading, spacing: 12) {
                Text("Event Cards")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Events can be rescheduled, skipped, or deleted.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                ForEach(fixtures.eventRowCards.prefix(2), id: \.id) { cardData in
                    SwipeableCard(
                        slideButtons: [
                            SlideButton(icon: "trash", style: .delete) {
                                print("Delete event: \(cardData.title)")
                            },
                            SlideButton(icon: "calendar", style: .reschedule) {
                                print("Reschedule event: \(cardData.title)")
                            },
                            SlideButton(icon: "forward", style: .skip) {
                                print("Skip event: \(cardData.title)")
                            }
                        ]
                    ) {
                        CardEvent(data: cardData)
                    }
                }
            }

            // Study Cards
            VStack(alignment: .leading, spacing: 12) {
                Text("Study Cards")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Studies can be rescheduled, skipped, edited, or deleted.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                ForEach(fixtures.studyRowCards.prefix(2), id: \.id) { cardData in
                    SwipeableCard(
                        slideButtons: [
                            SlideButton(icon: "trash", style: .delete) {
                                print("Delete study: \(cardData.title)")
                            },
                            SlideButton(icon: "calendar", style: .reschedule) {
                                print("Reschedule study: \(cardData.title)")
                            },
                            SlideButton(icon: "forward", style: .skip) {
                                print("Skip study: \(cardData.title)")
                            },
                            SlideButton(icon: "pencil", style: .edit) {
                                print("Edit study: \(cardData.title)")
                            }
                        ]
                    ) {
                        CardStudy(data: cardData)
                    }
                }
            }

            // Video Cards
            VStack(alignment: .leading, spacing: 12) {
                Text("Video Cards")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Videos can be edited or deleted.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                if let videoCard = fixtures.videoRowCards.first {
                    SwipeableCard(
                        slideButtons: [
                            SlideButton(icon: "trash", style: .delete) {
                                print("Delete video: \(videoCard.title)")
                            },
                            SlideButton(icon: "pencil", style: .edit) {
                                print("Edit video: \(videoCard.title)")
                            }
                        ]
                    ) {
                        CardVideo(data: videoCard)
                    }
                }
            }

            // Group Cards
            VStack(alignment: .leading, spacing: 12) {
                Text("Group Cards")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Groups can be edited or deleted.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                ForEach(fixtures.groupRowCards.prefix(2), id: \.id) { cardData in
                    SwipeableCard(
                        slideButtons: [
                            SlideButton(icon: "trash", style: .delete) {
                                print("Delete group: \(cardData.title)")
                            },
                            SlideButton(icon: "pencil", style: .edit) {
                                print("Edit group: \(cardData.title)")
                            }
                        ]
                    ) {
                        CardGroup(data: cardData)
                    }
                }
            }

            // Lesson Cards
            VStack(alignment: .leading, spacing: 12) {
                Text("Lesson Cards")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Lessons can be edited or deleted.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                // Only show lessons with activities (skip empty one)
                ForEach(fixtures.lessonCards.filter { !$0.activities.isEmpty }.prefix(2), id: \.id) { cardData in
                    SwipeableCard(
                        slideButtons: [
                            SlideButton(icon: "trash", style: .delete) {
                                print("Delete lesson: Day \(cardData.day)")
                            },
                            SlideButton(icon: "pencil", style: .edit) {
                                print("Edit lesson: Day \(cardData.day)")
                            }
                        ]
                    ) {
                        CardLesson(data: cardData)
                    }
                }
            }

            Spacer(minLength: 80)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
}

// MARK: - Alerts Tab Content

struct AlertsTabContent: View {
    var body: some View {
        VStack(spacing: 32) {
            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("Alert Components")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Alerts display important messages to users with distinct styles for warnings and critical issues.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))
            }

            // Warning Alerts
            VStack(alignment: .leading, spacing: 12) {
                Text("Warning Alerts")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Use for non-critical notifications that require user attention.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                Alert(message: "Your session will expire in 5 minutes.", variant: .warning)
                Alert(message: "Please review your changes before saving.", variant: .warning)
            }

            // Critical Alerts
            VStack(alignment: .leading, spacing: 12) {
                Text("Critical Alerts")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Use for urgent issues that require immediate attention.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                Alert(message: "Failed to connect to server. Please check your internet connection.", variant: .critical)
                Alert(message: "Payment processing error. Please contact support.", variant: .critical)
            }

            // Long Message Example
            VStack(alignment: .leading, spacing: 12) {
                Text("Long Messages")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                Text("Alerts automatically expand to accommodate longer messages.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))

                Alert(
                    message: "We've detected unusual activity on your account. For your security, we recommend changing your password and reviewing recent transactions. If you did not authorize these changes, please contact our support team immediately.",
                    variant: .warning
                )
            }

            Spacer(minLength: 80)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
}

#Preview {
    ComponentsPage(overlayManager: OverlayManager())
        .environment(AuthManager())
}
