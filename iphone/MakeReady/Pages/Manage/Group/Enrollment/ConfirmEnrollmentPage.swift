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
    /// "Sync to study" — set on the Confirm step, travels with the data.
    var syncMode: EnrollmentSyncMode = .off
}

struct ConfirmEnrollmentPage: View {
    /// The same visual screen serves two flows: creating an enrollment
    /// ("Confirm enrollment") and editing one ("Edit enrollment",
    /// monday#12270302158). Edit mode swaps the header (Cancel/Save), shows a
    /// warning banner, and makes the group/study/schedule rows tappable.
    enum Mode { case create, edit }

    let enrollmentData: EnrollmentData
    let onBack: () -> Void
    let onConfirm: (EnrollmentData, String, Bool) -> Void  // Pass enrollment data, smsTime, and requireResponse for parent to create

    // Edit-mode configuration (all no-ops / hidden in create mode)
    let mode: Mode
    let warningSummary: [String]
    let saveEnabled: Bool
    let onCancel: (() -> Void)?
    let onSave: ((EnrollmentData, String, Bool) -> Void)?
    let onEditGroup: (() -> Void)?
    let onEditStudy: (() -> Void)?
    let onEditSchedule: (() -> Void)?

    @State private var requireResponse: Bool

    // "Sync to study" (study sync): off = frozen copy; on defaults to
    // Automatic, with an Approval-required alternative.
    @State private var syncToStudy: Bool
    @State private var syncModeOption: String
    @State private var smsTime: Date

    private let timeFormatter: DateFormatter = DateFormatters.time12Hour

    init(
        enrollmentData: EnrollmentData,
        onBack: @escaping () -> Void = {},
        onConfirm: @escaping (EnrollmentData, String, Bool) -> Void = { _, _, _ in },
        mode: Mode = .create,
        warningSummary: [String] = [],
        saveEnabled: Bool = true,
        onCancel: (() -> Void)? = nil,
        onSave: ((EnrollmentData, String, Bool) -> Void)? = nil,
        onEditGroup: (() -> Void)? = nil,
        onEditStudy: (() -> Void)? = nil,
        onEditSchedule: (() -> Void)? = nil,
        seedRequireResponse: Bool? = nil,
        seedSmsTime: Date? = nil,
        seedSyncMode: EnrollmentSyncMode? = nil
    ) {
        self.enrollmentData = enrollmentData
        self.onBack = onBack
        self.onConfirm = onConfirm
        self.mode = mode
        self.warningSummary = warningSummary
        self.saveEnabled = saveEnabled
        self.onCancel = onCancel
        self.onSave = onSave
        self.onEditGroup = onEditGroup
        self.onEditStudy = onEditStudy
        self.onEditSchedule = onEditSchedule

        // Seed the toggles/time. Defaults preserve the create-flow behavior
        // (requireResponse on, sync off, 7:30 AM).
        _requireResponse = State(initialValue: seedRequireResponse ?? true)
        let seededSync = seedSyncMode ?? .off
        _syncToStudy = State(initialValue: seededSync != .off)
        _syncModeOption = State(initialValue: seededSync == .approval ? "Approval" : "Automatic")
        if let seedSmsTime {
            _smsTime = State(initialValue: seedSmsTime)
        } else {
            var components = DateComponents()
            components.hour = 7
            components.minute = 30
            _smsTime = State(initialValue: Calendar.current.date(from: components) ?? Date())
        }
    }

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
                // Header — create shows a back chevron + "Confirm"; edit shows a
                // "Cancel" link + "Save" (nothing persists until Save).
                if mode == .edit {
                    PageTitle(
                        title: "Edit enrollment",
                        leftLink: "Cancel",
                        rightLink: "Save",
                        rightLinkDisabled: !saveEnabled,
                        onLeftLinkTap: { onCancel?() },
                        onRightLinkTap: { submitEdit() }
                    )
                } else {
                    PageTitle.iconTitleLink(
                        title: "Confirm enrollment",
                        leftIcon: "chevron.left",
                        rightLink: "Confirm",
                        onLeftIconTap: onBack,
                        onRightLinkTap: {
                            submitEnrollment()
                        }
                    )
                }

                ScrollView {
                    VStack(spacing: 8) {
                        // Warning banner (edit mode) — destructive/impacting changes
                        if mode == .edit, !warningSummary.isEmpty {
                            warningBanner
                        }

                        // Overview Section - Group + Study Program
                        overviewSection

                        // Members Stats Section
                        membersStatsSection

                        // Schedule Section
                        scheduleSection
                            .enrollmentEditTap(onEditSchedule)

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

                        // Sync to Study Section (study sync)
                        FieldGroup {
                            ToggleControl(
                                title: "Sync to study",
                                description: "Keep this group's lessons up to date when the study publishes changes. Completed lessons are never changed.",
                                isOn: $syncToStudy
                            )
                        }

                        if syncToStudy {
                            VStack(spacing: 8) {
                                MenuInput(
                                    label: "Updates",
                                    options: ["Automatic", "Approval"],
                                    selectedOption: $syncModeOption,
                                    style: .segmented
                                )

                                Text(
                                    syncModeOption == "Approval"
                                        ? "You review updates and choose when to apply them."
                                        : "Published updates apply to future lessons right away."
                                )
                                .font(Typography.s13)
                                .foregroundColor(.white.opacity(0.5))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
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
                        .font(Typography.s17Bold)
                        .foregroundColor(.white)

                    if let description = enrollmentData.group.description {
                        Text(description)
                            .font(Typography.s13)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    }

                    // Private/Public indicator
                    HStack(spacing: 4) {
                        Image(systemName: enrollmentData.group.isPrivate ? "lock.fill" : "globe")
                            .font(Typography.s14)
                            .foregroundColor(.white.opacity(0.7))
                        Text(enrollmentData.group.isPrivate ? "Private group" : "Public group")
                            .font(Typography.s13)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                // Group Image
                groupImage
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .enrollmentEditTap(onEditGroup)

            // Down Arrow Icon
            Image(systemName: "arrow.down")
                .font(Typography.s32Medium)
                .foregroundColor(.white.opacity(0.2))

            // Study Program Row
            HStack(spacing: 16) {
                // Study Details
                VStack(alignment: .leading, spacing: 8) {
                    Text(enrollmentData.studyProgram.name)
                        .font(Typography.s17Bold)
                        .foregroundColor(.white)

                    if let description = enrollmentData.studyProgram.description {
                        Text(description)
                            .font(Typography.s13)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(3)
                    }

                    // Duration
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(Typography.s14)
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(enrollmentData.studyProgram.days) days")
                            .font(Typography.s13)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                // Study Image
                studyImage
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .enrollmentEditTap(onEditStudy)
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
                                .font(Typography.s32)
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
                        .font(Typography.s32)
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
                                .font(Typography.s32)
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
                        .font(Typography.s32)
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
                    .font(Typography.s22Bold)
                    .foregroundColor(.white)
                Text("Members included")
                    .font(Typography.s13)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)

            // Members Excluded
            VStack(spacing: 4) {
                Text("0")
                    .font(Typography.s22Bold)
                    .foregroundColor(.white)
                Text("Members excluded")
                    .font(Typography.s13)
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
                    .font(Typography.s28)
                    .foregroundColor(.white)
                Text(monthAbbreviation(from: enrollmentData.startDate))
                    .font(Typography.s15Bold)
                    .foregroundColor(.brandPrimary)
            }
            .frame(width: 60)
            .padding(.top, 16)
            .padding(.bottom, 24)

            // Center - Duration + Days
            VStack(spacing: 8) {
                Text("\(enrollmentData.studyProgram.days) day study")
                    .font(Typography.s15)
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
                    .font(Typography.s28)
                    .foregroundColor(.white)
                Text(monthAbbreviation(from: enrollmentData.endDate))
                    .font(Typography.s15Bold)
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
                .font(Typography.s17)
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

        // Pass data to parent - parent will handle API call and show skeleton.
        // syncMode travels inside the data (the closure signature predates it).
        var data = enrollmentData
        data.syncMode = syncToStudy
            ? (syncModeOption == "Approval" ? .approval : .auto)
            : .off
        onConfirm(data, smsTimeString, requireResponse)
    }

    /// Edit-mode Save — hands the pending values up to the flow, which shows the
    /// confirmation dialog and calls the update endpoint (monday#12270302158).
    private func submitEdit() {
        let smsTimeString = DateFormatters.time24Hour.string(from: smsTime)
        var data = enrollmentData
        data.syncMode = syncToStudy
            ? (syncModeOption == "Approval" ? .approval : .auto)
            : .off
        onSave?(data, smsTimeString, requireResponse)
    }

    // MARK: - Warning Banner (edit mode)

    private var warningBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(Typography.s14)
                    .foregroundColor(.warning)
                Text("Review these changes")
                    .font(Typography.s15Bold)
                    .foregroundColor(.white)
            }
            ForEach(warningSummary, id: \.self) { line in
                Text(line)
                    .font(Typography.s13)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.warning.opacity(0.12))
        .cornerRadius(8)
    }
}

private extension View {
    /// Makes a row tappable only when an edit action is supplied — so the
    /// create flow (which passes nil) is untouched, and edit mode gets the
    /// drilldown gesture.
    @ViewBuilder
    func enrollmentEditTap(_ action: (() -> Void)?) -> some View {
        if let action {
            contentShape(Rectangle()).onTapGesture(perform: action)
        } else {
            self
        }
    }
}

// MARK: - Day Circle Component

private struct DayCircle: View {
    let day: String
    let isEnabled: Bool

    var body: some View {
        Text(day)
            .font(Typography.s13Bold)
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
