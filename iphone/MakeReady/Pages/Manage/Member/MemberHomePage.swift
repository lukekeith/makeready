//
//  MemberHomePage.swift
//  MakeReady
//
//  Member management page with Groups, Members, and Enrolled tabs
//

import SwiftUI

struct MemberHomePage: View {
    let overlayManager: OverlayManager
    let avatarURL: String?
    @Binding var pendingSubTab: Int?
    @State private var activeTab = 0
    @Environment(AuthManager.self) var authManager

    // Use centralized state for fine-grained reactivity
    private var state: AppState { AppState.shared }
    @State private var selectedGroupId: String?
    @State private var groupToDelete: UserGroup?
    @State private var showDeleteConfirmation = false

    // Swipe state to prevent scrolling during card swipes
    @StateObject private var swipeState = SwipeState()

    // Refresh state - prevents stacking multiple refresh requests
    @State private var isRefreshing = false

    // Members tab state
    @State private var allMembers: [GroupMember] = []
    @State private var isMembersLoading = true
    @State private var membersError: String?
    @State private var membersLoaded = false

    // Members tab search state
    @State private var memberSearchText: String = ""
    @State private var isMemberSearchActive: Bool = false
    @FocusState private var isMemberSearchFocused: Bool

    // Requests state (loaded for card on Members tab)
    @State private var allJoinRequests: [GroupJoinRequest] = []
    @State private var isRequestsLoading = true
    @State private var requestsError: String?
    @State private var requestsLoaded = false

    // Enrolled tab state
    @State private var enrollmentToUnenroll: ProgramEnrollment?
    @State private var isProcessingUnenrollment = false
    @State private var unenrolledProgramName = ""

    // Computed properties for state access
    private var groups: [UserGroup] {
        state.orderedGroups
    }

    private var isInitialLoading: Bool {
        state.loadingStates.isInitialLoading(.groups)
    }

    // MARK: - Members Tab Computed Properties

    /// Deduplicated members sorted alphabetically, filtered by search
    private var filteredAllMembers: [GroupMember] {
        // Deduplicate by userId — keep the first occurrence (arbitrary, they share the same user data)
        var seen = Set<String>()
        let unique = allMembers.filter { member in
            if seen.contains(member.userId) { return false }
            seen.insert(member.userId)
            return true
        }

        let sorted = unique.sorted { $0.name.lowercased() < $1.name.lowercased() }

        if memberSearchText.isEmpty {
            return sorted
        }
        return sorted.filter { $0.name.lowercased().contains(memberSearchText.lowercased()) }
    }

    /// Get all group names a user belongs to (across all loaded members)
    private func groupNamesForUser(userId: String) -> [String] {
        let groupIds = Set(allMembers.filter { $0.userId == userId }.map { $0.groupId })
        return groupIds.compactMap { groupId in
            state.groups[groupId]?.name
        }.sorted()
    }

    private var isMemberSearchDisabled: Bool {
        allMembers.isEmpty
    }

    private var isMembersEmpty: Bool {
        allMembers.isEmpty
    }

    // MARK: - Enrolled Tab Computed Properties

    private var allEnrollments: [ProgramEnrollment] {
        var result: [ProgramEnrollment] = []
        for program in state.orderedPrograms {
            result.append(contentsOf: state.programEnrollmentsFor(programId: program.id))
        }
        return result.sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PageHeader(
                    tabs: ["Groups", "Members", "Enrolled"],
                    activeTab: $activeTab
                ) {
                    HStack(spacing: 8) {
                        Button {
                            overlayManager.present(.groupsInviteMenu) {
                                InviteMenu(
                                    overlayManager: overlayManager,
                                    menuId: Route.groupsInviteMenu.id
                                )
                                .environment(authManager)
                            }
                        } label: {
                            Image(systemName: "paperplane")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            overlayManager.present(.groupsAddMenu) {
                                ActionCardMenu(
                                    title: "Create New",
                                    items: [
                                        ActionCardMenuItem(icon: "person.2.fill", title: "Group", description: "Create a new group") {
                                            overlayManager.dismiss(.groupsAddMenu) {
                                                overlayManager.presentModal(id: OverlayID.createGroup) {
                                                    CreateGroupPage(overlayManager: overlayManager)
                                                }
                                            }
                                        },
                                    ]
                                )
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Content area (no swipe - tabs only, to avoid conflict with swipeable cards)
                switch activeTab {
                case 0:
                    groupsTabContent
                case 1:
                    membersTabContent
                case 2:
                    enrolledTabContent
                default:
                    groupsTabContent
                }
            }
        }
        .task {
            switch activeTab {
            case 0: await loadGroups()
            case 1:
                await loadAllMembers()
                await loadRequestsOnly()
            case 2: await loadAllEnrollments()
            default: await loadGroups()
            }
        }
        .onChange(of: activeTab) { oldValue, newValue in
            Task {
                switch newValue {
                case 0: await loadGroups()
                case 1:
                    await loadAllMembers()
                    await loadRequestsOnly()
                case 2: await loadAllEnrollments()
                default: break
                }
            }
        }
        .onAppear {
            if let tab = pendingSubTab {
                activeTab = tab
                pendingSubTab = nil
            }
        }
        .onChange(of: pendingSubTab) { _, newValue in
            if let tab = newValue {
                withAnimation(Motion.standard) {
                    activeTab = tab
                }
                pendingSubTab = nil
            }
        }
        .alert("Delete Group?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                groupToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let group = groupToDelete {
                    deleteGroup(group)
                }
                groupToDelete = nil
            }
        } message: {
            if let group = groupToDelete {
                Text("This will permanently delete \"\(group.name)\" and all its posts.")
            }
        }
    }

    // MARK: - Groups Tab

    private var groupsTabContent: some View {
        ScrollView {
            VStack(spacing: 4) {
                if isInitialLoading && !state.hasCachedGroups {
                    // Show skeleton on first load
                    VStack(spacing: 4) {
                        SkeletonCardGroup()
                        SkeletonCardGroup()
                        SkeletonCardGroup()
                    }
                    .padding(.horizontal, 16)
                } else if groups.isEmpty {
                    emptyGroupsView
                } else {
                    groupsList
                        .environment(\.swipeState, swipeState)
                }
            }
            .padding(.bottom, 100)  // Space for NavBar
        }
        .scrollDisabled(swipeState.isSwiping)
        .refreshable {
            guard !isRefreshing else { return }
            isRefreshing = true

            Task.detached { @MainActor in
                defer { isRefreshing = false }
                await loadGroups(forceRefresh: true)
            }

            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    private var emptyGroupsView: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "person.3")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))

            Text("No Groups")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text("Create your first group to start connecting")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            Spacer()
        }
    }

    private var groupsList: some View {
        ForEach(groups, id: \.id) { group in
            SwipeableCard(
                slideButtons: [
                    SlideButton(icon: "trash", style: .delete) {
                        groupToDelete = group
                        showDeleteConfirmation = true
                    }
                ],
                onTap: {
                    selectedGroupId = group.id
                    presentGroupHome()
                }
            ) {
                CardGroup(data: cardGroupData(from: group))
            }
            .padding(.horizontal, 16)
        }
    }

    private func cardGroupData(from group: UserGroup) -> CardGroupData {
        let imageStyle: CardImageStyle
        if let coverUrl = group.coverImageUrl, !coverUrl.isEmpty {
            imageStyle = .photo(imageURL: coverUrl)
        } else {
            imageStyle = .icon(systemName: "person.2.fill", backgroundColor: .purple)
        }

        let activeEnrollments = state.enrollmentsFor(groupId: group.id).filter { $0.isActive }

        var metadata = [
            DataItem(number: "\(group.memberCount)", label: "Members")
        ]
        if !activeEnrollments.isEmpty {
            metadata.append(DataItem(number: "\(activeEnrollments.count)", label: activeEnrollments.count == 1 ? "Active Study" : "Active Studies"))
        }

        return CardGroupData(
            id: group.id,
            title: group.name,
            imageStyle: imageStyle,
            metadata: metadata,
            isSelected: false,
            pendingRequestCount: state.pendingJoinRequestsByGroupId[group.id]?.count ?? 0,
            onTap: nil
        )
    }

    private func presentGroupHome() {
        guard let groupId = selectedGroupId else { return }

        overlayManager.presentModal(id: OverlayID.groupHome) {
            GroupHomePage(
                overlayManager: overlayManager,
                groupId: groupId,
                onDismiss: {
                    overlayManager.dismiss(id: OverlayID.groupHome)
                }
            )
        }
    }

    // MARK: - Members Tab

    // Search overlay: 8pt top + ~44pt field + 8pt gap to first card = 60pt
    private let membersListTopPadding: CGFloat = 60

    private var membersTabContent: some View {
        Group {
            if isMembersLoading && !membersLoaded {
                membersLoadingContent
            } else if let error = membersError {
                membersErrorContent(error)
            } else {
                membersMainContent
            }
        }
    }

    private var membersLoadingContent: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(.white)
            Spacer()
        }
    }

    private func membersErrorContent(_ errorMessage: String) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.3))

                Text(errorMessage)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)

                Button("Try Again") {
                    Task { await loadAllMembers() }
                }
                .foregroundColor(Color(hex: "#6c47ff"))
            }
            .padding(32)
            Spacer()
        }
    }

    private var membersMainContent: some View {
        ZStack(alignment: .top) {
            if isMembersEmpty && allJoinRequests.isEmpty {
                VStack {
                    Color.clear.frame(height: membersListTopPadding)
                    membersEmptyContent
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: membersListTopPadding)

                        // Member requests card (if any pending requests)
                        if !allJoinRequests.isEmpty && memberSearchText.isEmpty {
                            memberRequestsCard
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                        }

                        // Members section
                        if !filteredAllMembers.isEmpty {
                            membersMembersSection
                        } else if !memberSearchText.isEmpty {
                            membersNoSearchResults
                        }

                        Spacer()
                            .frame(height: 100)
                    }
                }
                .mask(
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [.clear, .black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 52)

                        Color.black
                    }
                )
            }

            // Search field (always visible, disabled when no members and no requests)
            SearchField(
                isActive: $isMemberSearchActive,
                searchText: $memberSearchText,
                isFocused: $isMemberSearchFocused,
                placeholder: "Search members",
                onClose: {
                    memberSearchText = ""
                },
                onClear: {
                    memberSearchText = ""
                }
            )
            .opacity(isMemberSearchDisabled ? 0.5 : 1.0)
            .allowsHitTesting(!isMemberSearchDisabled)
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    // MARK: - Member Requests Card

    private var memberRequestsCard: some View {
        Button {
            presentRequestsPage()
        } label: {
            HStack {
                Text("Member requests")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Text("\(allJoinRequests.count)")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    private func presentRequestsPage() {
        overlayManager.presentPage(id: OverlayID.memberRequests) {
            MemberRequestsPage(
                overlayManager: overlayManager,
                allJoinRequests: allJoinRequests,
                onRequestApproved: {
                    Task { await loadRequestsOnly() }
                }
            )
        }
    }

    private var membersEmptyContent: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "person.2")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.3))

                Text("No members")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white.opacity(0.2))
            }
            Spacer()
        }
    }

    private var membersNoSearchResults: some View {
        VStack(spacing: 12) {
            Text("No results for \"\(memberSearchText)\"")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Enrolled Tab

    private var enrolledTabContent: some View {
        ScrollView {
            VStack(spacing: 4) {
                if allEnrollments.isEmpty {
                    enrolledEmptyState
                } else {
                    ForEach(allEnrollments) { enrollment in
                        let program = state.programs[enrollment.studyProgramId]
                        let totalLessons = program?.lessons?.count ?? program?.days ?? 0
                        let daysSinceStart = max(0, Calendar.current.dateComponents([.day], from: enrollment.startDate, to: Date()).day ?? 0)
                        let lessonsLeft = max(0, totalLessons - daysSinceStart)
                        SwipeableCard(
                            slideButtons: [
                                SlideButton(icon: "trash", style: .delete) {
                                    presentUnenrollModal(enrollment: enrollment)
                                }
                            ],
                            onTap: {
                                openEnrollmentLessons(enrollment, program: program)
                            }
                        ) {
                            CardEnrolled(
                                data: CardEnrolledData(
                                    id: enrollment.id,
                                    studyTitle: program?.name ?? "Study",
                                    groupName: enrollment.group?.name ?? "Group",
                                    startDate: enrollment.startDate,
                                    endDate: enrollment.endDate,
                                    lessonsLeft: lessonsLeft,
                                    studyImageURL: program?.coverImageUrl,
                                    groupImageURL: enrollment.group?.coverImageUrl,
                                    onTap: nil
                                )
                            )
                        }
                    }
                    .environment(\.swipeState, swipeState)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .scrollDisabled(swipeState.isSwiping)
        .refreshable {
            await loadAllEnrollments(forceRefresh: true)
        }
    }

    private var enrolledEmptyState: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 80)

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))

            Text("No Enrollments")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text("Enroll a group in a study program to get started")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            Spacer()
        }
    }

    private func loadRequestsOnly(forceRefresh: Bool = false) async {
        if !requestsLoaded {
            isRequestsLoading = true
        }
        requestsError = nil

        do {
            // Ensure groups are loaded first
            try await GroupActions().loadGroups(forceRefresh: forceRefresh)

            let currentGroups = state.orderedGroups

            let requests = await withTaskGroup(
                of: (String, [JoinRequest]?).self,
                returning: [GroupJoinRequest].self
            ) { group in
                for userGroup in currentGroups {
                    group.addTask {
                        let requests = try? await self.loadJoinRequestsForGroup(groupId: userGroup.id)
                        return (userGroup.id, requests)
                    }
                }

                var collected: [GroupJoinRequest] = []
                for await (groupId, requests) in group {
                    if let requests = requests {
                        let wrapped = requests.map { GroupJoinRequest(groupId: groupId, request: $0) }
                        collected.append(contentsOf: wrapped)
                    }
                }
                return collected
            }

            allJoinRequests = requests
            isRequestsLoading = false
            requestsLoaded = true
        } catch {
            requestsError = error.localizedDescription
            isRequestsLoading = false
        }
    }


    // MARK: - Members Tab: Member List

    private var membersMembersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 4) {
                ForEach(filteredAllMembers) { member in
                    allMembersMemberRow(member)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func allMembersMemberRow(_ member: GroupMember) -> some View {
        CardMember(
            data: CardMemberData(
                id: member.id,
                firstName: firstName(from: member.name),
                lastName: lastName(from: member.name),
                avatarURL: member.avatarUrl,
                metadata: [DataItem(label: "Joined", value: formatDate(member.joinedAt))],
                groups: groupNamesForUser(userId: member.userId),
                onTap: {
                    handleMemberTap(member)
                }
            )
        )
    }

    // MARK: - Members Tab: Data Loading

    private func loadAllMembers() async {
        // Only show loading spinner on first load
        if !membersLoaded {
            isMembersLoading = true
        }
        membersError = nil

        do {
            // First ensure groups are loaded
            try await GroupActions().loadGroups(forceRefresh: false)

            let currentGroups = state.orderedGroups

            // Load members for all groups concurrently
            let members = await withTaskGroup(
                of: [GroupMember].self,
                returning: [GroupMember].self
            ) { group in
                for userGroup in currentGroups {
                    group.addTask {
                        (try? await GroupActions().loadMembers(groupId: userGroup.id)) ?? []
                    }
                }

                var collected: [GroupMember] = []
                for await groupMembers in group {
                    collected.append(contentsOf: groupMembers)
                }
                return collected
            }

            allMembers = members
            isMembersLoading = false
            membersLoaded = true
        } catch {
            membersError = error.localizedDescription
            isMembersLoading = false
        }
    }

    private func loadJoinRequestsForGroup(groupId: String) async throws -> [JoinRequest] {
        // Routes through GroupActions so the result lands in
        // AppState.pendingJoinRequestsByGroupId — this drives the red-dot
        // indicators on group cards and the group-home `person.2` icon.
        try await GroupActions().loadJoinRequests(groupId: groupId)
    }


    // MARK: - Members Tab: Helpers

    private func firstName(from name: String) -> String {
        name.components(separatedBy: " ").first ?? name
    }

    private func lastName(from name: String) -> String {
        let components = name.components(separatedBy: " ")
        return components.count > 1 ? components.dropFirst().joined(separator: " ") : ""
    }

    private func formatDate(_ date: Date) -> String {
        return DateFormatters.monthDayYear.string(from: date)
    }

    private func handleMemberTap(_ member: GroupMember) {
        overlayManager.presentModal(id: OverlayID.memberProfile) {
            MemberProfilePage(memberId: member.userId)
        }
    }

    // MARK: - Enrollment Actions

    private func openEnrollmentLessons(_ enrollment: ProgramEnrollment, program: StudyProgram?) {
        let programSummary: StudyProgramSummary? = program.map {
            StudyProgramSummary(
                id: $0.id,
                name: $0.name,
                description: $0.description,
                days: $0.days,
                coverImageUrl: $0.coverImageUrl
            )
        }

        let enrollmentWithProgram = EnrollmentWithProgram(
            id: enrollment.id,
            groupId: enrollment.groupId,
            studyProgramId: enrollment.studyProgramId,
            startDate: enrollment.startDate,
            endDate: enrollment.endDate,
            enabledDays: enrollment.enabledDays,
            smsTime: enrollment.smsTime,
            timezone: enrollment.timezone,
            requireResponse: enrollment.requireResponse,
            currentLessonId: enrollment.currentLessonId,
            createdAt: enrollment.createdAt,
            updatedAt: enrollment.updatedAt,
            studyProgram: programSummary,
            isActive: enrollment.isActive
        )

        overlayManager.presentModal(id: OverlayID.enrollmentSchedule, dismissOnTapOutside: false) {
            EnrollmentSchedulePage(
                enrollment: enrollmentWithProgram,
                onDismiss: {
                    overlayManager.dismiss(id: OverlayID.enrollmentSchedule)
                },
                leftIcon: "xmark",
                overlayManager: overlayManager,
                titleOverride: "Lessons"
            )
        }
    }

    private func loadAllEnrollments(forceRefresh: Bool = false) async {
        let actions = ProgramActions()
        // Ensure programs are loaded first
        do {
            try await actions.loadPrograms(forceRefresh: forceRefresh)
        } catch {
            NSLog("⚠️ Failed to load programs: \(error)")
        }
        for program in state.orderedPrograms {
            let hasEnrollments = (program._count?.enrollments ?? 0) > 0
            let hasCached = state.hasCachedProgramEnrollments(programId: program.id)
            if hasEnrollments && (!hasCached || forceRefresh) {
                do {
                    _ = try await actions.getProgramEnrollments(programId: program.id, forceRefresh: forceRefresh)
                } catch {
                    NSLog("⚠️ Failed to load enrollments for program \(program.id): \(error)")
                }
            }
        }
    }

    private func presentUnenrollModal(enrollment: ProgramEnrollment) {
        overlayManager.presentModal(id: OverlayID.unenrollOptions) {
            UnenrollOptionsModal(
                enrollmentId: enrollment.id,
                programName: state.programs[enrollment.studyProgramId]?.name ?? "Study Program",
                programImageUrl: state.programs[enrollment.studyProgramId]?.coverImageUrl,
                onConfirm: { option in
                    handleEnrollmentUnenrollConfirmed(enrollment: enrollment, option: option)
                },
                onDismiss: {
                    overlayManager.dismiss(id: OverlayID.unenrollOptions)
                }
            )
        }
    }

    private func handleEnrollmentUnenrollConfirmed(enrollment: ProgramEnrollment, option: UnenrollOption) {
        overlayManager.dismiss(id: OverlayID.unenrollOptions)
        unenrolledProgramName = state.programs[enrollment.studyProgramId]?.name ?? "the program"
        isProcessingUnenrollment = true

        UnenrollConfirmation.present(
            overlayManager: overlayManager,
            option: option,
            programName: unenrolledProgramName,
            isProcessing: $isProcessingUnenrollment,
            onDismiss: {
                overlayManager.dismiss(id: OverlayID.confirmationOverlay)
            }
        )

        Task {
            do {
                switch option {
                case .fullRemoval:
                    try await EnrollmentActions().deleteEnrollment(id: enrollment.id)
                case .cancelFuture:
                    try await EnrollmentActions().cancelFutureLessons(id: enrollment.id)
                }
                _ = try? await ProgramActions().getProgramEnrollments(programId: enrollment.studyProgramId, forceRefresh: true)
                await MainActor.run {
                    isProcessingUnenrollment = false
                }
            } catch {
                await MainActor.run {
                    isProcessingUnenrollment = false
                    overlayManager.dismiss(id: OverlayID.confirmationOverlay)
                    NSLog("❌ Failed to unenroll: \(error)")
                }
            }
        }
    }

    // MARK: - Group Actions

    private func loadGroups(forceRefresh: Bool = false) async {
        do {
            try await GroupActions().loadGroups(forceRefresh: forceRefresh)

            // Load enrollments for all groups (for active study count on cards)
            await withTaskGroup(of: Void.self) { taskGroup in
                for group in state.orderedGroups {
                    taskGroup.addTask {
                        _ = try? await EnrollmentActions().loadEnrollments(groupId: group.id)
                    }
                }
            }
        } catch {
            NSLog("Failed to load groups: \(error)")
        }
    }

    private func deleteGroup(_ group: UserGroup) {
        Task {
            do {
                try await GroupActions().deleteGroup(id: group.id)
                NSLog("Deleted group: \(group.name)")
            } catch {
                NSLog("Failed to delete group: \(error)")
            }
        }
    }
}

// MARK: - Group Join Request (wraps JoinRequest with its groupId)

struct GroupJoinRequest: Identifiable, Sendable {
    let groupId: String
    let request: JoinRequest

    var id: String { "\(groupId)-\(request.id)" }
}

// MARK: - Chart API Response Models

struct HeatmapBucket: Codable {
    let day: Int      // 0 (Sun) - 6 (Sat)
    let hour: Int     // 0-23
    let count: Int
}

struct HeatmapResponse: Codable {
    let success: Bool
    let data: [HeatmapBucket]?
    let error: String?
}

struct DayActivityCount: Codable {
    let date: String  // "yyyy-MM-dd"
    let count: Int
}

struct WeeklyStatsResponse: Codable {
    let success: Bool
    let data: [DayActivityCount]?
    let error: String?
}

