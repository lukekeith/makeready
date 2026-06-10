//
//  ConfirmEnrollmentPage.swift
//  MakeReady
//
//  Step 3 of enrollment flow: Review and confirm enrollment
//

import SwiftUI

/// All enrollment configuration to be submitted
struct EnrollmentData {
    let group: UserGroup
    let studyProgram: StudyProgram
    let startDate: Date
    let endDate: Date
    let enabledDays: Set<Int>
    var smsTime: Date?
    var requireResponse: Bool = false
}

struct ConfirmEnrollmentPage: View {
    let enrollmentData: EnrollmentData
    let onBack: () -> Void
    let onConfirm: (EnrollmentData, String, Bool) -> Void  // Pass enrollment data, smsTime, and requireResponse for parent to create

    @State private var requireResponse: Bool = true

    @State private var smsTime: Date = {
        // Default to 7:30 AM
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 7
        components.minute = 30
        return calendar.date(from: components) ?? Date()
    }()

    private let timeFormatter: DateFormatter = DateFormatters.time12Hour

    /// Convert enabled days to array of day abbreviations
    private var enabledDayStrings: [String] {
        let dayMap = [0: "Sun", 1: "Mon", 2: "Tue", 3: "Wed", 4: "Thu", 5: "Fri", 6: "Sat"]
        return enrollmentData.enabledDays.sorted().compactMap { dayMap[$0] }
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header - "Confirm" button triggers enrollment
                PageTitle.iconTitleLink(
                    title: "Confirm enrollment",
                    leftIcon: "chevron.left",
                    rightLink: "Confirm",
                    onLeftIconTap: onBack,
                    onRightLinkTap: {
                        submitEnrollment()
                    }
                )

                ScrollView {
                    VStack(spacing: 8) {
                        // Overview Section - Group + Study Program
                        overviewSection

                        // Members Stats Section
                        membersStatsSection

                        // Schedule Section
                        scheduleSection

                        // Send Invites Section
                        sendInvitesSection

                        // Require Response Section
                        FieldGroup {
                            ToggleControl(
                                title: "Require response",
                                description: "Members must submit a response for each activity before continuing.",
                                isOn: $requireResponse
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Overview Section (Group + Study Program)

    private var overviewSection: some View {
        VStack(spacing: 16) {
            // Group Info Row
            HStack(spacing: 16) {
                // Group Details
                VStack(alignment: .leading, spacing: 8) {
                    Text(enrollmentData.group.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)

                    if let description = enrollmentData.group.description {
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    }

                    // Private/Public indicator
                    HStack(spacing: 4) {
                        Image(systemName: enrollmentData.group.isPrivate ? "lock.fill" : "globe")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        Text(enrollmentData.group.isPrivate ? "Private group" : "Public group")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                // Group Image
                groupImage
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Down Arrow Icon
            Image(systemName: "arrow.down")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(.white.opacity(0.2))

            // Study Program Row
            HStack(spacing: 16) {
                // Study Details
                VStack(alignment: .leading, spacing: 8) {
                    Text(enrollmentData.studyProgram.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)

                    if let description = enrollmentData.studyProgram.description {
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(3)
                    }

                    // Duration
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(enrollmentData.studyProgram.days) days")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                // Study Image
                studyImage
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var groupImage: some View {
        if let imageURL = enrollmentData.group.coverImageUrl {
            AsyncImage(url: URL(string: imageURL)) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.3))
                        )
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .overlay(
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.3))
                )
        }
    }

    @ViewBuilder
    private var studyImage: some View {
        if let imageURL = enrollmentData.studyProgram.coverImageUrl {
            AsyncImage(url: URL(string: imageURL)) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            Image(systemName: "book.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.3))
                        )
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .overlay(
                    Image(systemName: "book.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.3))
                )
        }
    }

    // MARK: - Members Stats Section

    private var membersStatsSection: some View {
        HStack(spacing: 0) {
            // Members Included
            VStack(spacing: 4) {
                Text("\(enrollmentData.group.memberCount)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text("Members included")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)

            // Members Excluded
            VStack(spacing: 4) {
                Text("0")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text("Members excluded")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        HStack(spacing: 0) {
            // Start Date
            VStack(spacing: 0) {
                Text(dayNumber(from: enrollmentData.startDate))
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                Text(monthAbbreviation(from: enrollmentData.startDate))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.brandPrimary)
            }
            .frame(width: 60)
            .padding(.top, 16)
            .padding(.bottom, 24)

            // Center - Duration + Days
            VStack(spacing: 8) {
                Text("\(enrollmentData.studyProgram.days) day study")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.5))

                // Days of week circles
                HStack(spacing: 8) {
                    DayCircle(day: "M", isEnabled: enrollmentData.enabledDays.contains(1))
                    DayCircle(day: "T", isEnabled: enrollmentData.enabledDays.contains(2))
                    DayCircle(day: "W", isEnabled: enrollmentData.enabledDays.contains(3))
                    DayCircle(day: "T", isEnabled: enrollmentData.enabledDays.contains(4))
                    DayCircle(day: "F", isEnabled: enrollmentData.enabledDays.contains(5))
                    DayCircle(day: "S", isEnabled: enrollmentData.enabledDays.contains(6))
                    DayCircle(day: "S", isEnabled: enrollmentData.enabledDays.contains(0))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
            .padding(.bottom, 24)

            // End Date
            VStack(spacing: 0) {
                Text(dayNumber(from: enrollmentData.endDate))
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                Text(monthAbbreviation(from: enrollmentData.endDate))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.brandPrimary)
            }
            .frame(width: 60)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }

    private func dayNumber(from date: Date) -> String {
        return DateFormatters.dayOfMonth.string(from: date)
    }

    private func monthAbbreviation(from date: Date) -> String {
        return DateFormatters.monthAbbrev.string(from: date).uppercased()
    }

    // MARK: - Send Invites Section

    private var sendInvitesSection: some View {
        HStack {
            Text("Send invites")
                .font(.system(size: 17))
                .foregroundColor(.white)

            Spacer()

            DatePicker("", selection: $smsTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .colorScheme(.dark)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }

    // MARK: - Submit

    private func submitEnrollment() {
        // Format time as HH:mm
        let smsTimeString = DateFormatters.time24Hour.string(from: smsTime)

        // Pass data to parent - parent will handle API call and show skeleton
        onConfirm(enrollmentData, smsTimeString, requireResponse)
    }
}

// MARK: - Day Circle Component

private struct DayCircle: View {
    let day: String
    let isEnabled: Bool

    var body: some View {
        Text(day)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(isEnabled ? .appBackground : .white.opacity(0.5))
            .frame(width: 24, height: 24)
            .background(isEnabled ? Color.white : Color.white.opacity(0.1))
            .clipShape(Circle())
    }
}

// MARK: - Preview

#Preview {
    ConfirmEnrollmentPage(
        enrollmentData: EnrollmentData(
            group: UserGroup(
                id: "1",
                code: "ABC123",
                name: "Young professionals",
                description: "The purpose of this group is to sell advertising to large corporations.",
                coverImageUrl: nil,
                isPrivate: true,
                allowInvites: true,
                memberDirectory: true,
                welcomeMessage: nil,
                ageRange: nil,
                maxMembers: nil,
                memberCount: 27,
                creatorId: "1",
                createdAt: Date(),
                updatedAt: Date()
            ),
            studyProgram: StudyProgram(
                id: "1",
                name: "Romans",
                description: "A 30 day guided trip through the book of Romans and everything a young professional needs to know.",
                defaultActivity: .soap,
                days: 30,
                coverImageUrl: nil,
                creatorId: "1",
                isActive: true,
                createdAt: Date(),
                updatedAt: Date(),
                lessons: nil
            ),
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 42, to: Date())!,
            enabledDays: [1, 2, 3, 4, 5]
        ),
        onBack: { print("Back") },
        onConfirm: { data, smsTime, requireResponse in print("Confirm: \(data.studyProgram.name) at \(smsTime), requireResponse: \(requireResponse)") }
    )
}
