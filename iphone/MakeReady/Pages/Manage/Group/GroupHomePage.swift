//
//  GroupHomePage.swift
//  MakeReady
//
//  Group detail page with posts wall, action buttons, and member management
//

import SwiftUI

struct GroupHomePage: View {
    let overlayManager: OverlayManager
    let groupId: String
    let onDismiss: () -> Void
    var leftIcon: String

    // Use centralized state for fine-grained reactivity
    private var state: AppState { AppState.shared }

    // Local state
    @State private var group: UserGroup?
    @State private var posts: [GroupPost] = []
    @State private var nextCursor: String?
    @State private var isLoadingPosts = false
    @State private var hasMorePosts = true

    // Edit screen state
    @State private var showEditGroup = false
    @State private var coverImage: UIImage?
    @State private var pendingCoverImage: UIImage?  // Image being uploaded in background
    @State private var isUploadingCover = false

    // Enrollments screen state
    @State private var showEnrollments = false

    // Pending enrollment state (for skeleton loader)
    @State private var pendingEnrollmentData: EnrollmentData?
    @State private var isCreatingEnrollment = false

    // Confirmation overlay state
    @State private var isProcessingEnrollment = false
    @State private var confirmedEnrollmentData: EnrollmentData?

    // Pre-fetched enrollment data for instant modal display
    // nil = not loaded yet, empty = loaded with no enrollments
    @State private var cachedEnrollments: [EnrollmentWithProgram]? = nil
    @State private var cachedLessonDates: Set<Date>? = nil

    // Next upcoming lesson (computed from cached enrollment details)
    @State private var nextLesson: (schedule: LessonSchedule, enrollment: EnrollmentWithProgram)? = nil

    // Lesson invite modal state (for sharing lessons)
    @State private var selectedLessonForInvite: (schedule: LessonSchedule, enrollment: EnrollmentWithProgram)? = nil

    // Add lesson dialog state
    @State private var showAddLessonDialog = false
    @State private var isAddingLesson = false
    @State private var addLessonEnrollmentId: String? = nil

    // Edit activities state

    // Age range state (synced with group model)
    @State private var ageMin: String = "18"
    @State private var ageMax: String = "34"

    // Navigation state (Phase 3.4): nested SlideStacks replace the 3-position
    // currentScreen carousel. Settings is the LEADING detail of the outer
    // stack (preserving the screen-0-on-the-left layout); the dynamic right
    // screen is the trailing detail of the inner stack, keyed by type.
    @State private var showSettings = false
    @State private var rightScreen: RightScreenType? = nil

    /// Types of pages that can appear in the right screen position
    enum RightScreenType: Equatable, Hashable {
        case members
        case enrollments
        case invite
    }

    // Refresh state - prevents stacking multiple refresh requests
    @State private var isRefreshing = false

    // Initialize with cached group for smooth animation
    init(
        overlayManager: OverlayManager,
        groupId: String,
        leftIcon: String = "xmark",
        onDismiss: @escaping () -> Void
    ) {
        self.overlayManager = overlayManager
        self.groupId = groupId
        self.leftIcon = leftIcon
        self.onDismiss = onDismiss

        // Initialize from cache for immediate display
        let cachedGroup = AppState.shared.groups[groupId]
        _group = State(initialValue: cachedGroup)
    }

    var body: some View {
        ZStack {
            // Background at root level - stays fixed
            Color.appBackground
                .ignoresSafeArea()

            if let group = group {
                // Outer stack: settings enters from the LEFT (detailEdge:
                // .leading preserves the inverted screen-0 layout). Inner
                // stack: the dynamic right screen, keyed by type.
                SlideStack(isPresented: $showSettings, detailEdge: .leading) {
                    SlideStack(item: $rightScreen) {
                        mainContent(group: group)
                    } detail: { screen in
                        rightScreenContent(screen)
                    }
                } detail: {
                    editGroupContent(group: group)
                }
                .clipped()  // Clip AFTER offset so icons animate with page
            } else {
                // Loading state
                loadingContent
            }
        }
        .task {
            await loadInitialData()
        }
        .onDisappear {
            // Update cache when closing
            if let updatedGroup = group {
                Task { @MainActor in
                    state.groups.upsert(updatedGroup)
                    state.persist()
                }
            }
        }
        .fullScreenCover(item: Binding(
            get: { selectedLessonForInvite.map { LessonInviteItem(schedule: $0.schedule, enrollment: $0.enrollment) } },
            set: { _ in selectedLessonForInvite = nil }
        )) { item in
            StudyInvitePage(
                scheduleId: item.schedule.id,
                dayNumber: item.schedule.lesson.dayNumber,
                studyName: item.enrollment.studyProgram?.name ?? "Study",
                onDismiss: {
                    selectedLessonForInvite = nil
                }
            )
        }
        .overlay {
            DialogOverlay(
                isPresented: $showAddLessonDialog,
                title: "Add a new lesson?",
                message: "This will add a new scheduled lesson to the end of the enrollment.",
                buttons: [
                    DialogButtonConfig(
                        isAddingLesson ? "Adding..." : "Add lesson",
                        style: .primary
                    ) {
                        addScheduledLesson()
                    },
                    DialogButtonConfig("Cancel", style: .secondary) {}
                ]
            )
        }
    }

    // MARK: - Loading State

    private var loadingContent: some View {
        VStack(spacing: 0) {
            PageTitle.iconTitleIcons(
                title: "",
                leftIcon: leftIcon,
                rightIcons: [
                    IconAction(icon: "paperplane") { },
                    IconAction(icon: "person.2") { },
                    IconAction(icon: "calendar") { },
                    IconAction(icon: "book") { },
                    IconAction(icon: "gearshape") { }
                ],
                onLeftIconTap: { onDismiss() }
            )

            Spacer()
            ProgressView()
                .tint(.white)
            Spacer()
        }
    }

    // MARK: - Right Screen Content (Dynamic)

    /// Right-screen pane, built from the SlideStack-mounted type — NOT from
    /// rightScreen, which clears at dismissal while the pane is still
    /// sliding out. Dismissals just nil the item; SlideStack animates.
    @ViewBuilder
    private func rightScreenContent(_ screen: RightScreenType) -> some View {
        switch screen {
        case .members:
            GroupMembersPage(
                groupId: groupId,
                groupName: group?.name ?? "this group",
                overlayManager: overlayManager,
                onDismiss: {
                    rightScreen = nil
                }
            )

        case .enrollments:
            EnrollmentsListPage(
                groupId: groupId,
                onDismiss: {
                    rightScreen = nil
                },
                overlayManager: overlayManager,
                onUnenroll: {
                    // Refresh posts when unenrollment completes (welcome post should be deleted)
                    Task {
                        await loadPosts()
                        await prefetchEnrollments()
                    }
                },
                pendingEnrollment: pendingEnrollmentData,
                isCreatingEnrollment: isCreatingEnrollment
            )

        case .invite:
            GroupInvitePage(
                groupId: groupId,
                onDismiss: {
                    rightScreen = nil
                }
            )
        }
    }

    // MARK: - Main Content

    private func mainContent(group: UserGroup) -> some View {
        VStack(spacing: 0) {
            // Header with multiple right icons (no title)
            PageTitle.iconTitleIcons(
                title: "",
                leftIcon: leftIcon,
                rightIcons: [
                    IconAction(icon: "paperplane") { handleInvite() },
                    IconAction(
                        icon: "person.2",
                        showBadge: state.hasPendingJoinRequests(forGroupId: groupId)
                    ) { handleMembers() },
                    IconAction(icon: "calendar") { handleCalendar() },
                    IconAction(icon: "book") { handleEnrollments() },
                    IconAction(icon: "gearshape") { handleSettings() }
                ],
                onLeftIconTap: { onDismiss() }
            )

            // Scrollable content
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Cover image with title overlay (or just title if no cover)
                    groupHeaderView

                    // Action buttons row (50% width each)
                    HStack(spacing: 8) {
                        BoxButton(
                            action: { handleInvite() },
                            label: "Invite",
                            icon: "paperplane",
                            iconPosition: .left,
                            variant: .secondary,
                            size: .md,
                            fullWidth: true
                        )

                        BoxButton(
                            action: { handleEnroll() },
                            label: "Enroll",
                            icon: "checkmark.circle",
                            iconPosition: .left,
                            variant: .primary,
                            size: .md,
                            fullWidth: true
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // Horizontally scrolling action buttons
                    GroupActionButtonRow(
                        onVideoTap: { handleCreatePost(.video) },
                        onMessageTap: { handleCreatePost(.announcement) },
                        onMeetingTap: { handleCreatePost(.event) }
                    )
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    // Divider above posts
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)

                    // Next Lesson section (if available)
                    if let nextLessonData = nextLesson {
                        nextLessonSection(schedule: nextLessonData.schedule, enrollment: nextLessonData.enrollment)
                    }

                    // Posts list (no section header per Figma design)
                    if posts.isEmpty && !isLoadingPosts && !isCreatingEnrollment {
                        emptyPostsView
                    } else if posts.isEmpty && isLoadingPosts {
                        // Initial loading state - show skeleton posts
                        ForEach(0..<3, id: \.self) { index in
                            SkeletonPostCard()

                            // Divider between skeletons
                            if index < 2 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 1)
                            }
                        }
                    } else {
                        // Skeleton post for pending enrollment
                        if isCreatingEnrollment, let enrollmentData = pendingEnrollmentData {
                            SkeletonPostCard(
                                programName: enrollmentData.studyProgram.name,
                                programImageUrl: enrollmentData.studyProgram.coverImageUrl
                            )

                            // Divider after skeleton
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 1)
                        }

                        ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                            GroupPostCard(post: post)

                            // Add divider between posts (not after last post)
                            if index < posts.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 1)
                            }
                        }

                        // Load more indicator
                        if hasMorePosts && !posts.isEmpty {
                            ProgressView()
                                .tint(.white)
                                .padding(.vertical, 20)
                                .onAppear {
                                    loadMorePosts()
                                }
                        }
                    }

                    // Bottom padding
                    Spacer()
                        .frame(height: 40)
                }
            }
            .refreshable {
                guard !isRefreshing else { return }
                isRefreshing = true

                Task.detached { @MainActor in
                    defer { isRefreshing = false }
                    await refreshData()
                }

                try? await Task.sleep(for: .milliseconds(500))
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Edit Group Content

    private func editGroupContent(group: UserGroup) -> some View {
        ZStack {
            VStack(spacing: 0) {
                // Header with back arrow and Done link
                PageTitle.iconTitleLink(
                    title: "Edit Group",
                    leftIcon: "chevron.left",
                    rightLink: "Done",
                    onLeftIconTap: {
                        showSettings = false  // Back to main
                    },
                    onRightLinkTap: {
                        saveGroup()
                    }
                )

                // Scrollable content
                ScrollView {
                    VStack(spacing: 20) {
                        // Cover image picker
                        CoverImagePicker(
                            selectedImage: $coverImage,
                            programName: self.group?.name ?? "",
                            programDescription: self.group?.description ?? "",
                            mode: .display,
                            existingImageUrl: self.group?.coverImageUrl
                        )

                        // Group name
                        FieldGroup {
                            TextInput(
                                floatingLabel: "Group name",
                                autocorrect: true,
                                text: Binding(
                                    get: { self.group?.name ?? "" },
                                    set: { if var g = self.group { g.name = $0; self.group = g } }
                                )
                            )
                        }
                        .padding(.horizontal, 16)

                        // Description
                        FieldGroup {
                            MultilineTextInput(
                                placeholder: "Describe the purpose of this group",
                                text: Binding(
                                    get: { self.group?.description ?? "" },
                                    set: { if var g = self.group { g.description = $0.isEmpty ? nil : $0; self.group = g } }
                                ),
                                minHeight: 130
                            )
                        }
                        .padding(.horizontal, 16)

                        // Privacy toggles
                        ToggleGroup {
                            ToggleControl(
                                title: "Private",
                                description: "Only members can see members and their activity in the group.",
                                isOn: Binding(
                                    get: { self.group?.isPrivate ?? false },
                                    set: { if var g = self.group { g.isPrivate = $0; self.group = g } }
                                )
                            )

                            ToggleControl(
                                title: "Allow members to send invites",
                                description: "Enable this option to send invites from their mobile web portal",
                                isOn: Binding(
                                    get: { self.group?.allowInvites ?? true },
                                    set: { if var g = self.group { g.allowInvites = $0; self.group = g } }
                                )
                            )

                            ToggleControl(
                                title: "Member directory",
                                description: "Allow members to see other members in the group",
                                isOn: Binding(
                                    get: { self.group?.memberDirectory ?? true },
                                    set: { if var g = self.group { g.memberDirectory = $0; self.group = g } }
                                )
                            )
                        }
                        .padding(.horizontal, 16)

                        // Age range
                        FieldGroup {
                            AgeRangeInput(
                                label: "Age range",
                                minAge: $ageMin,
                                maxAge: $ageMax
                            )
                        }
                        .padding(.horizontal, 16)
                        .onChange(of: ageMin) { _, newValue in
                            if var g = self.group {
                                let min = Int(newValue)
                                if g.ageRange == nil {
                                    g.ageRange = AgeRange(min: min, max: 99)
                                } else {
                                    g.ageRange?.min = min
                                }
                                self.group = g
                            }
                        }
                        .onChange(of: ageMax) { _, newValue in
                            if var g = self.group {
                                let max = Int(newValue)
                                if g.ageRange == nil {
                                    g.ageRange = AgeRange(min: 0, max: max)
                                } else {
                                    g.ageRange?.max = max
                                }
                                self.group = g
                            }
                        }

                        // Max members
                        FieldGroup {
                            MenuInput(
                                label: "Max members",
                                options: ["Unlimited"] + (1...100).map { "\($0)" },
                                selectedOption: Binding(
                                    get: {
                                        if let max = self.group?.maxMembers {
                                            return "\(max)"
                                        }
                                        return "Unlimited"
                                    },
                                    set: { newValue in
                                        if var g = self.group {
                                            g.maxMembers = newValue == "Unlimited" ? nil : Int(newValue)
                                            self.group = g
                                        }
                                    }
                                ),
                                style: .wheel
                            )
                        }
                        .padding(.horizontal, 16)

                        Spacer()
                            .frame(height: 40)
                    }
                }
            }

        }
    }

    // MARK: - Group Header

    private var groupHeaderView: some View {
        VStack(spacing: 0) {
            // Show pending cover image (being uploaded) or existing cover
            if let pendingImage = pendingCoverImage {
                // Pending upload - show local image with spinner
                ZStack(alignment: .bottomLeading) {
                    Image(uiImage: pendingImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 240)
                        .clipped()
                        .overlay(Color.black.opacity(0.3))

                    // Upload spinner in top-right corner
                    VStack {
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(12)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                                .padding(16)
                        }
                        Spacer()
                    }
                    .frame(height: 240)

                    // Gradient overlay
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.appBackground
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 240)

                    // Title overlay
                    groupTitleSection
                        .padding(16)
                }
            } else if let coverUrl = group?.coverImageUrl, let url = URL(string: coverUrl) {
                // Existing cover image
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                    }
                    .frame(height: 240)
                    .clipped()

                    // Gradient overlay
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            Color.appBackground
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 240)

                    // Title overlay
                    groupTitleSection
                        .padding(16)
                }
            } else {
                // Just the title section (no cover image)
                groupTitleSection
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
        }
    }

    private var groupTitleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Group name
            Text(group?.name ?? "Group")
                .font(Typography.s22)
                .foregroundColor(.white)
                .tracking(-0.1)

            // Group info row
            HStack(spacing: 16) {
                // Privacy indicator
                HStack(spacing: 4) {
                    Image(systemName: group?.isPrivate == true ? "lock.fill" : "lock.open.fill")
                        .font(Typography.s14)
                        .foregroundColor(.white)

                    Text(group?.isPrivate == true ? "Private group" : "Public group")
                        .font(Typography.s13)
                        .foregroundColor(.white.opacity(0.7))
                }

                // Member count
                HStack(spacing: 4) {
                    Text("\(group?.memberCount ?? 0)")
                        .font(Typography.s13)
                        .foregroundColor(.white)

                    Text("members")
                        .font(Typography.s13)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Next Lesson Section

    private func nextLessonSection(schedule: LessonSchedule, enrollment: EnrollmentWithProgram) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section label
            Text("NEXT LESSON")
                .font(Typography.s15Bold)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.5)

            // Upcoming lesson card
            CardLesson(
                data: cardLessonData(for: schedule, enrollment: enrollment),
                onTap: {
                    handleNextLessonTap(schedule: schedule, enrollment: enrollment)
                }
            )

            // Divider after next lesson section
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Card Data Mapping

    private func cardLessonData(for schedule: LessonSchedule, enrollment: EnrollmentWithProgram) -> CardLessonData {
        let activities = schedule.lesson.activities.sorted(by: { $0.orderNumber < $1.orderNumber }).map { activity in
            LessonActivityData(
                icon: ActivityStyle.icon(forRawType: activity.type),
                type: activity.type,
                title: activity.title ?? activityTypeLabel(for: activity.type),
                status: .incomplete
            )
        }

        return CardLessonData(
            id: schedule.id,
            day: schedule.lesson.dayNumber,
            mode: .lesson,
            activities: activities,
            title: schedule.lesson.title,
            date: schedule.scheduledDate,
            coverImageUrl: enrollment.studyProgram?.coverImageUrl,
            estimatedMinutes: schedule.lesson.totalEstimatedMinutes
        )
    }

    private func activityTypeLabel(for type: String) -> String {
        switch type {
        case "READ": return "Read"
        case "VIDEO": return "Video"
        case "USER_INPUT": return "Response"
        default: return type.capitalized
        }
    }

    private func handleNextLessonTap(schedule: LessonSchedule, enrollment: EnrollmentWithProgram) {
        NSLog("Tapped next lesson: Day \(schedule.lesson.dayNumber)")

        overlayManager.present(.lessonActionMenu) {
            LessonActionMenu(
                schedule: schedule,
                studyName: enrollment.studyProgram?.name ?? "Study",
                enrollmentId: enrollment.id,
                onEditActivities: {
                    overlayManager.present(.editEnrollmentDay) {
                        EditEnrollmentDayWrapper(
                            schedule: schedule,
                            enrollmentId: enrollment.id,
                            overlayManager: overlayManager
                        )
                    }
                },
                onOpenLesson: {
                    handleOpenLesson(schedule: schedule, enrollment: enrollment)
                },
                onShareLesson: {
                    handleShareLesson(schedule: schedule, enrollment: enrollment)
                },
                onAddLesson: {
                    addLessonEnrollmentId = enrollment.id
                    showAddLessonDialog = true
                },
                onDelete: {
                    handleDeleteLesson(schedule: schedule, enrollment: enrollment)
                }
            )
        }
    }

    private func handleOpenLesson(schedule: LessonSchedule, enrollment: EnrollmentWithProgram) {
        // Fetch the invite URL from the API and open it
        Task {
            do {
                let invite = try await EnrollmentActions().loadLessonInvite(scheduleId: schedule.id)
                if let url = URL(string: invite.inviteUrl) {
                    await MainActor.run {
                        UIApplication.shared.open(url)
                    }
                }
            } catch {
                await MainActor.run {
                    // User tapped "Open Lesson" — surface; retry refetches
                    // the invite from the captured schedule/enrollment.
                    state.recordError(
                        error,
                        context: "GroupHomePage.handleOpenLesson",
                        surface: true,
                        friendlyMessage: "Couldn't open the lesson",
                        retry: { handleOpenLesson(schedule: schedule, enrollment: enrollment) }
                    )
                }
            }
        }
    }

    private func handleShareLesson(schedule: LessonSchedule, enrollment: EnrollmentWithProgram) {
        // Open the StudyInvitePage modal
        selectedLessonForInvite = (schedule: schedule, enrollment: enrollment)
    }

    private func handleRescheduleLesson(schedule: LessonSchedule) {
        NSLog("Reschedule tapped for lesson: Day \(schedule.lesson.dayNumber)")
        // TODO: Implement reschedule functionality
    }

    private func handleDeleteLesson(schedule: LessonSchedule, enrollment: EnrollmentWithProgram) {
        NSLog("Delete tapped for lesson: Day \(schedule.lesson.dayNumber)")
        // TODO: Implement delete functionality with confirmation
    }

    private func addScheduledLesson() {
        guard !isAddingLesson,
              let enrollmentId = addLessonEnrollmentId else { return }
        isAddingLesson = true

        Task {
            do {
                try await EnrollmentActions().addScheduledLesson(enrollmentId: enrollmentId)
                // Refresh enrollment data to show the new lesson
                if let groupId = group?.id {
                    _ = try? await EnrollmentActions().loadEnrollments(groupId: groupId)
                }
            } catch {
                await MainActor.run {
                    // Clear the pending state before recording so the banner
                    // never sits over a stuck spinner. User tapped "Add
                    // Lesson" — surface; retry restores the captured
                    // enrollment id and re-runs the same add.
                    isAddingLesson = false
                    addLessonEnrollmentId = nil
                    state.recordError(
                        error,
                        context: "GroupHomePage.addScheduledLesson",
                        surface: true,
                        friendlyMessage: "Couldn't add the lesson",
                        retry: {
                            addLessonEnrollmentId = enrollmentId
                            addScheduledLesson()
                        }
                    )
                }
                return
            }
            isAddingLesson = false
            addLessonEnrollmentId = nil
        }
    }

    // MARK: - Empty State

    private var emptyPostsView: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 40)

            Image(systemName: "bubble.left.and.bubble.right")
                .font(Typography.s40)
                .foregroundColor(.white.opacity(0.3))

            Text("No posts yet")
                .font(Typography.s17Semibold)
                .foregroundColor(.white)

            Text("Be the first to share something with the group")
                .font(Typography.s15)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Data Loading

    private func loadInitialData() async {
        // Load group details if not cached
        if group == nil {
            do {
                let loadedGroup = try await GroupActions().getGroup(id: groupId)
                await MainActor.run {
                    group = loadedGroup
                    syncAgeStateFromGroup(loadedGroup)
                }
            } catch {
                // Console-only: cold load in .task — no user action to answer.
                await MainActor.run {
                    state.recordError(error, context: "GroupHomePage.loadInitialData")
                }
            }
        } else if let cachedGroup = group {
            // Sync age state from cached group
            await MainActor.run {
                syncAgeStateFromGroup(cachedGroup)
            }
        }

        // Load initial posts
        await loadPosts()

        // Pre-fetch enrollments for instant modal display
        await prefetchEnrollments()

        // Pre-fetch pending join requests so the `person.2` icon's red dot
        // is correct on first frame for direct navigation into the group.
        _ = try? await GroupActions().loadJoinRequests(groupId: groupId)

        // Pre-fetch the group invite so GroupInvitePage renders from cache
        // and rides the slide-in even on the first tap (its cache is
        // in-memory only, so it starts cold every launch).
        _ = try? await GroupActions().loadGroupInvite(groupId: groupId)
    }

    private func syncAgeStateFromGroup(_ group: UserGroup) {
        ageMin = "\(group.ageRange?.min ?? 18)"
        ageMax = "\(group.ageRange?.max ?? 34)"
    }

    private func refreshData() async {
        // Reset pagination
        await MainActor.run {
            nextCursor = nil
            hasMorePosts = true
        }

        // Reload group
        do {
            let loadedGroup = try await GroupActions().getGroup(id: groupId)
            await MainActor.run {
                group = loadedGroup
            }
        } catch {
            // Console-only: refresh failure, page keeps showing cached group.
            await MainActor.run {
                state.recordError(error, context: "GroupHomePage.refreshData")
            }
        }

        // Reload posts
        await loadPosts()
    }

    private func loadPosts() async {
        guard !isLoadingPosts else { return }

        await MainActor.run {
            isLoadingPosts = true
        }

        do {
            let result = try await GroupActions().loadPosts(groupId: groupId, cursor: nil)
            await MainActor.run {
                posts = result.posts
                nextCursor = result.nextCursor
                hasMorePosts = result.nextCursor != nil
                isLoadingPosts = false
            }
        } catch {
            await MainActor.run {
                isLoadingPosts = false
                // Console-only: background load, list keeps cached posts.
                state.recordError(error, context: "GroupHomePage.loadPosts")
            }
        }
    }

    private func loadMorePosts() {
        guard !isLoadingPosts, hasMorePosts, let cursor = nextCursor else { return }

        Task {
            await MainActor.run {
                isLoadingPosts = true
            }

            do {
                let result = try await GroupActions().loadPosts(groupId: groupId, cursor: cursor)
                await MainActor.run {
                    posts.append(contentsOf: result.posts)
                    nextCursor = result.nextCursor
                    hasMorePosts = result.nextCursor != nil
                    isLoadingPosts = false
                }
            } catch {
                await MainActor.run {
                    isLoadingPosts = false
                    // Console-only: scroll pagination, list keeps loaded posts.
                    state.recordError(error, context: "GroupHomePage.loadMorePosts")
                }
            }
        }
    }

    // MARK: - Pre-fetch Enrollments

    /// Pre-fetch enrollments so the enrollment modal opens instantly with complete data
    private func prefetchEnrollments() async {
        do {
            // Fetch all enrollments for this group
            let enrollments = try await EnrollmentActions().loadEnrollments(groupId: groupId)
            await MainActor.run {
                cachedEnrollments = enrollments
            }

            // Fetch lesson dates for active enrollments only
            var lessonDates: Set<Date> = []
            let calendar = Calendar.current
            let now = Date()

            // Track the next upcoming lesson across all enrollments
            var earliestUpcomingLesson: (schedule: LessonSchedule, enrollment: EnrollmentWithProgram)? = nil

            for enrollment in enrollments where enrollment.isActive {
                do {
                    let details = try await EnrollmentActions().getEnrollmentDetails(id: enrollment.id)
                    for schedule in details.lessonSchedules {
                        let dayStart = calendar.startOfDay(for: schedule.scheduledDate)
                        lessonDates.insert(dayStart)

                        // Check if this is an upcoming lesson (not completed and scheduled in the future or today)
                        let isUpcoming = schedule.isCompleted != true && schedule.scheduledDate >= calendar.startOfDay(for: now)

                        if isUpcoming {
                            if let current = earliestUpcomingLesson {
                                // If this lesson is earlier than the current earliest, update it
                                if schedule.scheduledDate < current.schedule.scheduledDate {
                                    earliestUpcomingLesson = (schedule: schedule, enrollment: enrollment)
                                }
                            } else {
                                // First upcoming lesson found
                                earliestUpcomingLesson = (schedule: schedule, enrollment: enrollment)
                            }
                        }
                    }
                } catch {
                    // Console-only: prefetch — calendar dots just stay stale.
                    await MainActor.run {
                        state.recordError(error, context: "GroupHomePage.prefetchEnrollments (details)")
                    }
                }
            }

            await MainActor.run {
                cachedLessonDates = lessonDates
                nextLesson = earliestUpcomingLesson
            }

            NSLog("📚 Pre-fetched \(enrollments.count) enrollments, \(lessonDates.count) lesson dates, next lesson: \(earliestUpcomingLesson != nil ? "Day \(earliestUpcomingLesson!.schedule.lesson.dayNumber)" : "none")")
        } catch {
            // Console-only: prefetch for instant modal display, modal handles
            // its own loading state when the cache is empty.
            await MainActor.run {
                state.recordError(error, context: "GroupHomePage.prefetchEnrollments")
            }
        }
    }

    // MARK: - Save Group

    private func saveGroup() {
        guard let currentGroup = group else { return }

        // Capture the cover image before navigating back
        let imageToUpload = coverImage

        // Immediately navigate back (optimistic UI)
        showSettings = false  // Back to main
        coverImage = nil

        // If there's a cover image to upload, show the pending state
        if let image = imageToUpload {
            pendingCoverImage = image
            isUploadingCover = true
        }

        NSLog("Saving group in background:")
        NSLog("  Name: \(currentGroup.name)")
        NSLog("  Has cover image: \(imageToUpload != nil)")

        performGroupSave(currentGroup, imageToUpload: imageToUpload)
    }

    /// The actual save work, separated from saveGroup()'s one-shot UI
    /// resets so the error banner's Retry can re-run it (idempotent
    /// update-by-id + re-upload of the captured image).
    private func performGroupSave(_ currentGroup: UserGroup, imageToUpload: UIImage?) {
        Task {
            do {
                // Save group data
                let updatedGroup = try await GroupActions().updateGroup(
                    id: currentGroup.id,
                    name: currentGroup.name,
                    description: currentGroup.description,
                    isPrivate: currentGroup.isPrivate,
                    allowInvites: currentGroup.allowInvites,
                    memberDirectory: currentGroup.memberDirectory,
                    welcomeMessage: currentGroup.welcomeMessage,
                    ageRange: currentGroup.ageRange,
                    maxMembers: currentGroup.maxMembers
                )

                await MainActor.run {
                    group = updatedGroup
                }

                // Upload cover image if we have one
                if let image = imageToUpload {
                    do {
                        _ = try await GroupActions().uploadCoverImage(
                            groupId: currentGroup.id,
                            image: image
                        )
                        // Refresh group to get updated cover image URL
                        let finalGroup = try await GroupActions().getGroup(id: currentGroup.id)
                        await MainActor.run {
                            group = finalGroup
                            pendingCoverImage = nil
                            isUploadingCover = false
                        }
                        NSLog("Cover image uploaded successfully")
                    } catch {
                        await MainActor.run {
                            pendingCoverImage = nil
                            isUploadingCover = false
                            // User-initiated (they picked a cover and hit
                            // Done) — surface it, with retry re-running the
                            // full save including the captured image.
                            state.recordError(
                                error,
                                context: "GroupHomePage.saveGroup (cover upload)",
                                surface: true,
                                friendlyMessage: "Couldn't upload the cover image",
                                retry: { performGroupSave(currentGroup, imageToUpload: imageToUpload) }
                            )
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    // The user hit Done and we navigated back optimistically —
                    // a silent failure here loses their edits (Decision
                    // Point A exemplar). Retry re-runs the same save.
                    state.recordError(
                        error,
                        context: "GroupHomePage.saveGroup",
                        surface: true,
                        friendlyMessage: "Couldn't save group changes",
                        retry: { performGroupSave(currentGroup, imageToUpload: imageToUpload) }
                    )
                }
            }
        }
    }

    // MARK: - Actions

    private func handleInvite() {
        rightScreen = .invite
    }

    private func handleMembers() {
        rightScreen = .members
    }

    private func handleCalendar() {
        NSLog("Calendar tapped")
        // TODO: Present group calendar
    }

    private func handleSettings() {
        showSettings = true  // Settings is LEFT of main (leading detail)
    }

    private func handleEnrollments() {
        rightScreen = .enrollments
    }

    private func handleEnroll() {
        guard let group = group else { return }

        // Open modal immediately - pass cached data (may be nil, modal handles loading state)
        overlayManager.present(.enrollmentFlow) {
            EnrollmentFlowModal(
                preselectedGroup: group,
                preselectedProgram: nil,
                existingEnrollments: cachedEnrollments,
                existingLessonDates: cachedLessonDates,
                onDismiss: {
                    overlayManager.dismiss(.enrollmentFlow)
                },
                onComplete: { enrollmentData, smsTime, requireResponse in
                    // Dismiss modal immediately
                    overlayManager.dismiss(.enrollmentFlow)

                    // Store data for confirmation overlay
                    confirmedEnrollmentData = enrollmentData
                    isProcessingEnrollment = true

                    // Show confirmation overlay IMMEDIATELY in processing state
                    showProcessingConfirmation(enrollmentData: enrollmentData)

                    // Create enrollment in background
                    createEnrollmentInBackground(enrollmentData: enrollmentData, smsTime: smsTime, requireResponse: requireResponse)
                }
            )
        }
    }

    private func createEnrollmentInBackground(enrollmentData: EnrollmentData, smsTime: String, requireResponse: Bool) {
        // Store pending data and show skeleton
        pendingEnrollmentData = enrollmentData
        isCreatingEnrollment = true

        // Convert enabled days to array of day abbreviations
        let dayMap = [0: "Sun", 1: "Mon", 2: "Tue", 3: "Wed", 4: "Thu", 5: "Fri", 6: "Sat"]
        let enabledDayStrings = enrollmentData.enabledDays.sorted().compactMap { dayMap[$0] }

        Task {
            do {
                // Call API
                let enrollment = try await EnrollmentActions().createEnrollment(
                    groupId: enrollmentData.group.id,
                    studyProgramId: enrollmentData.studyProgram.id,
                    startDate: enrollmentData.startDate,
                    enabledDays: enabledDayStrings,
                    smsTime: smsTime,
                    timezone: TimeZone.current.identifier,
                    requireResponse: requireResponse,
                    syncMode: enrollmentData.syncMode
                )
                NSLog("✅ Created enrollment: \(enrollment.id)")

                // Refresh posts to get the welcome post
                await loadPosts()

                // Refresh cached enrollments
                await prefetchEnrollments()

                await MainActor.run {
                    pendingEnrollmentData = nil
                    isCreatingEnrollment = false

                    // Transition overlay from processing to success
                    isProcessingEnrollment = false
                }
            } catch {
                await MainActor.run {
                    pendingEnrollmentData = nil
                    isCreatingEnrollment = false
                    isProcessingEnrollment = false

                    // Dismiss the processing overlay, then surface the
                    // failure (Decision Point A — was a TODO). Retry re-runs
                    // the whole flow incl. the processing overlay.
                    overlayManager.dismiss(.confirmationOverlay)
                    state.recordError(
                        error,
                        context: "GroupHomePage.createEnrollment",
                        surface: true,
                        friendlyMessage: "Couldn't create the enrollment",
                        retry: {
                            isProcessingEnrollment = true
                            showProcessingConfirmation(enrollmentData: enrollmentData)
                            createEnrollmentInBackground(
                                enrollmentData: enrollmentData,
                                smsTime: smsTime,
                                requireResponse: requireResponse
                            )
                        }
                    )
                }
            }
        }
    }

    private func showProcessingConfirmation(enrollmentData: EnrollmentData) {
        // Format the start date
        let formattedDate = DateFormatters.fullMonthDayYear.string(from: enrollmentData.startDate)

        // Build the confirmation message with bold parts
        let message = AttributedString.safeMarkdown("**\(enrollmentData.group.name)** has been successfully enrolled in **\(enrollmentData.studyProgram.name)** starting on **\(formattedDate)**.")

        overlayManager.present(.confirmationOverlay) {
            ConfirmationOverlay(
                style: .success,
                message: message,
                buttonLabel: "Done",
                isProcessing: $isProcessingEnrollment,
                processingMessage: "Processing enrollment",
                onDismiss: {
                    overlayManager.dismiss(.confirmationOverlay)
                    // Return to the main group screen
                    showSettings = false
                    rightScreen = nil
                }
            )
        }
    }

    private func handleCreatePost(_ type: PostType) {
        NSLog("Create \(type.displayName) tapped")
        // TODO: Present create post flow
    }
}

// MARK: - Helper Types

/// Identifiable wrapper for lesson invite modal presentation
private struct LessonInviteItem: Identifiable {
    let schedule: LessonSchedule
    let enrollment: EnrollmentWithProgram

    var id: String { schedule.id }
}

#Preview {
    GroupHomePage(
        overlayManager: OverlayManager(),
        groupId: "preview-group",
        onDismiss: { print("Dismissed") }
    )
}
