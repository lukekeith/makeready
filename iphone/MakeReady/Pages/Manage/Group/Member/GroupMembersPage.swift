//
//  GroupMembersPage.swift
//  MakeReady
//
//  Page showing all members of a group with search functionality.
//  Also displays pending join requests that can be accepted.
//

import SwiftUI

struct GroupMembersPage: View {
    let groupId: String
    let groupName: String
    let overlayManager: OverlayManager
    let onDismiss: () -> Void

    // Use centralized state for fine-grained reactivity
    private var state: AppState { AppState.shared }

    // Data state
    @State private var members: [GroupMember] = []
    @State private var joinRequests: [JoinRequest] = []
    @State private var isLoading = true
    @State private var error: String?

    // Search state
    @State private var searchText: String = ""
    @State private var isSearchActive: Bool = false
    @FocusState private var isSearchFocused: Bool

    // Confirmation dialog state
    @State private var showAcceptConfirmation: Bool = false
    @State private var requestToAccept: JoinRequest?

    // Computed: filtered members based on search
    private var filteredMembers: [GroupMember] {
        if searchText.isEmpty {
            return members.sorted { $0.name.lowercased() < $1.name.lowercased() }
        }
        return members
            .filter { $0.name.lowercased().contains(searchText.lowercased()) }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    // Computed: is truly empty (no requests and no members)
    private var isEmpty: Bool {
        joinRequests.isEmpty && members.isEmpty
    }

    // Computed: should disable search
    private var isSearchDisabled: Bool {
        members.isEmpty
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                PageTitle.iconTitle(
                    title: "Members",
                    icon: "chevron.left",
                    onIconTap: onDismiss
                )

                if isLoading {
                    loadingContent
                } else if let error = error {
                    errorContent(error)
                } else {
                    mainContent
                }
            }
        }
        .task {
            await loadData()
        }
        .alert("Accept Request", isPresented: $showAcceptConfirmation) {
            Button("Cancel", role: .cancel) {
                requestToAccept = nil
            }
            Button("Accept") {
                if let request = requestToAccept {
                    Task {
                        await approveRequest(request)
                    }
                }
                requestToAccept = nil
            }
        } message: {
            if let request = requestToAccept {
                let name = [request.member.firstName, request.member.lastName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                Text("Accept \(name) as a member of \(groupName)?")
            }
        }
    }

    // MARK: - Loading State

    private var loadingContent: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(.white)
            Spacer()
        }
    }

    // MARK: - Error State

    private func errorContent(_ errorMessage: String) -> some View {
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
                    Task { await loadData() }
                }
                .foregroundColor(Color(hex: "#6c47ff"))
            }
            .padding(32)
            Spacer()
        }
    }

    // MARK: - Main Content

    private let listTopPadding: CGFloat = 60

    private var mainContent: some View {
        ZStack(alignment: .top) {
            // Background: Scrollable content with top padding and gradient mask
            if isEmpty {
                // Empty state with top padding
                VStack {
                    Color.clear.frame(height: listTopPadding)
                    emptyContent
                }
            } else {
                // Scrollable content with requests and members
                ScrollView {
                    VStack(spacing: 0) {
                        // Top padding to push content below search field
                        Color.clear.frame(height: listTopPadding)

                        // Requests section
                        if !joinRequests.isEmpty {
                            requestsSection
                        }

                        // Members section
                        if !filteredMembers.isEmpty {
                            membersSection
                        } else if !searchText.isEmpty {
                            // No search results
                            noSearchResultsContent
                        }

                        Spacer()
                            .frame(height: 40)
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

            // Foreground: Search field (always visible, disabled when no members)
            searchField
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        SearchField(
            isActive: $isSearchActive,
            searchText: $searchText,
            isFocused: $isSearchFocused,
            placeholder: "Search members",
            onClose: {
                searchText = ""
            },
            onClear: {
                searchText = ""
            }
        )
        .opacity(isSearchDisabled ? 0.5 : 1.0)
        .allowsHitTesting(!isSearchDisabled)
    }

    // MARK: - Empty State

    private var emptyContent: some View {
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

    // MARK: - No Search Results

    private var noSearchResultsContent: some View {
        VStack(spacing: 12) {
            Text("No results for \"\(searchText)\"")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Requests Section

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Text("Requests")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 16)

            // Request cards
            VStack(spacing: 4) {
                ForEach(joinRequests) { request in
                    requestRow(request)
                }
            }
            .padding(.horizontal, 16)
        }
        // Mirror the 12pt gap between header and cards above the header too,
        // so the section breathes from whatever sits above it.
        .padding(.top, 12)
    }

    private func requestRow(_ request: JoinRequest) -> some View {
        CardMember(
            data: CardMemberData(
                id: request.id,
                firstName: request.member.firstName ?? "",
                lastName: request.member.lastName ?? "",
                avatarURL: request.member.avatarUrl,
                metadata: requestMetadata(request),
                groups: [],
                onTap: {
                    handleRequestTap(request)
                }
            )
        ) {
            ActionButton(label: "Accept", variant: .purple) {
                requestToAccept = request
                showAcceptConfirmation = true
            }
        }
    }

    private func requestMetadata(_ request: JoinRequest) -> [DataItem] {
        var items: [DataItem] = []

        // Requested date
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        items.append(DataItem(label: "Requested", value: formatter.string(from: request.createdAt)))

        return items
    }

    // MARK: - Members Section

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header (only show if there are also requests)
            if !joinRequests.isEmpty {
                Text("Members")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.horizontal, 16)
            }

            // Member cards
            VStack(spacing: 4) {
                ForEach(filteredMembers) { member in
                    memberRow(member)
                }
            }
            .padding(.horizontal, 16)
        }
        // Mirror the 12pt gap between header and cards above the header too.
        // Only applies when the header renders (joinRequests not empty); when
        // the header is hidden the section is the only block on screen and
        // doesn't need extra spacing.
        .padding(.top, joinRequests.isEmpty ? 0 : 12)
    }

    private func memberRow(_ member: GroupMember) -> some View {
        CardMember(
            data: CardMemberData(
                id: member.id,
                firstName: firstName(from: member.name),
                lastName: lastName(from: member.name),
                avatarURL: member.avatarUrl,
                metadata: memberMetadata(member),
                groups: [], // TODO: Add other groups when API supports it
                onTap: {
                    handleMemberTap(member)
                }
            )
        )
    }

    private func memberMetadata(_ member: GroupMember) -> [DataItem] {
        var items: [DataItem] = []

        // TODO: Add age when API supports it
        // items.append(DataItem(label: "Age", value: "\(age)"))

        // Joined date
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        items.append(DataItem(label: "Joined", value: formatter.string(from: member.joinedAt)))

        return items
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        error = nil

        do {
            // Load members and requests in parallel
            async let membersTask = GroupActions().loadMembers(groupId: groupId)
            async let requestsTask = loadJoinRequests()

            let (loadedMembers, loadedRequests) = try await (membersTask, requestsTask)

            await MainActor.run {
                members = loadedMembers
                joinRequests = loadedRequests
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func loadJoinRequests() async throws -> [JoinRequest] {
        // Routes through GroupActions so the result updates AppState — keeps
        // the red-dot indicators on group cards and the group-home `person.2`
        // icon in sync after approve/decline actions trigger this reload.
        try await GroupActions().loadJoinRequests(groupId: groupId)
    }

    // MARK: - Actions

    private func handleRequestTap(_ request: JoinRequest) {
        overlayManager.presentModal(id: OverlayID.memberRequestProfile) {
            MemberRequestProfilePage(
                memberId: request.member.id,
                groupId: groupId,
                groupName: groupName,
                requestId: request.id,
                requestDate: request.createdAt,
                requestMessage: request.message,
                onApprove: {
                    Task { await loadData() }
                }
            )
        }
    }

    private func handleMemberTap(_ member: GroupMember) {
        overlayManager.presentModal(id: OverlayID.memberProfile) {
            MemberProfilePage(memberId: member.userId)
        }
    }

    private func approveRequest(_ request: JoinRequest) async {
        do {
            // Removes the request from AppState synchronously on success so
            // the red-dot indicators update instantly; loadData() then
            // reconciles the local list with the server.
            try await GroupActions().approveJoinRequest(groupId: groupId, requestId: request.id)
            await loadData()
        } catch {
            NSLog("Failed to approve request: \(error.localizedDescription)")
            // TODO: Show error to user
        }
    }

    // MARK: - Helpers

    private func firstName(from name: String) -> String {
        name.components(separatedBy: " ").first ?? name
    }

    private func lastName(from name: String) -> String {
        let components = name.components(separatedBy: " ")
        return components.count > 1 ? components.dropFirst().joined(separator: " ") : ""
    }
}

// MARK: - Preview

#Preview("With Members & Requests") {
    GroupMembersPreviewWithData()
}

#Preview("Empty State") {
    GroupMembersPreviewEmpty()
}

/// Preview with members and requests
private struct GroupMembersPreviewWithData: View {
    @State private var mockRequests: [JoinRequest] = [
        JoinRequest(
            id: "req-1",
            status: "pending",
            message: "Hi! I'd love to join.",
            createdAt: Date().addingTimeInterval(-86400 * 2),
            member: JoinRequestMember(id: "m1", firstName: "New", lastName: "Person", avatarUrl: nil)
        ),
        JoinRequest(
            id: "req-2",
            status: "pending",
            message: nil,
            createdAt: Date().addingTimeInterval(-86400),
            member: JoinRequestMember(id: "m2", firstName: "Another", lastName: "Request", avatarUrl: "https://i.pravatar.cc/150?u=another")
        ),
    ]

    @State private var mockMembers: [PreviewMember] = [
        PreviewMember(id: "1", name: "Tony Stark", avatarUrl: "https://i.pravatar.cc/150?u=tony", joinedAt: date("Jul 7, 2025")),
        PreviewMember(id: "2", name: "Alexandria Ocasio-Cortez Rodriguez", avatarUrl: nil, joinedAt: date("Jan 15, 2025")),
        PreviewMember(id: "3", name: "Jo Wu", avatarUrl: "https://i.pravatar.cc/150?u=jo", joinedAt: date("Mar 1, 2025")),
        PreviewMember(id: "4", name: "Bob Smith", avatarUrl: nil, joinedAt: date("Dec 10, 2024")),
        PreviewMember(id: "5", name: "Sarah Johnson", avatarUrl: "https://i.pravatar.cc/150?u=sarah", joinedAt: date("Feb 20, 2025")),
        PreviewMember(id: "6", name: "Madonna", avatarUrl: nil, joinedAt: date("Jun 5, 2025")),
        PreviewMember(id: "7", name: "Emma Davis", avatarUrl: "https://i.pravatar.cc/150?u=emma", joinedAt: date("Apr 12, 2025")),
        PreviewMember(id: "8", name: "Robert Williams", avatarUrl: nil, joinedAt: date("Nov 3, 2024")),
        PreviewMember(id: "9", name: "Michael Chen", avatarUrl: "https://i.pravatar.cc/150?u=michael", joinedAt: date("May 18, 2025")),
        PreviewMember(id: "10", name: "Jennifer Martinez", avatarUrl: nil, joinedAt: date("Aug 22, 2025")),
    ]

    @State private var searchText: String = ""
    @State private var isSearchActive: Bool = false
    @FocusState private var isSearchFocused: Bool

    private let listTopPadding: CGFloat = 60

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                PageTitle.iconTitle(
                    title: "Members",
                    icon: "chevron.left",
                    onIconTap: { }
                )

                // Content area with ZStack for layered fade effect
                ZStack(alignment: .top) {
                    // Background: Scrollable content with top padding and gradient mask
                    ScrollView {
                        VStack(spacing: 0) {
                            // Top padding to push content below search field
                            Color.clear.frame(height: listTopPadding)

                            // Requests section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Requests")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                    .padding(.horizontal, 16)

                                VStack(spacing: 0) {
                                    ForEach(mockRequests) { request in
                                        CardMember(
                                            data: CardMemberData(
                                                id: request.id,
                                                firstName: request.member.firstName ?? "",
                                                lastName: request.member.lastName ?? "",
                                                avatarURL: request.member.avatarUrl,
                                                metadata: [DataItem(label: "Requested", value: "Jan 3, 2025")],
                                                groups: []
                                            )
                                        ) {
                                            ActionButton(label: "Accept", variant: .purple) {
                                                print("Accept \(request.member.firstName ?? "")")
                                            }
                                        }
                                    }
                                }
                            }

                            // Members section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Members")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                    .padding(.horizontal, 16)

                                VStack(spacing: 0) {
                                    ForEach(mockMembers.filter { searchText.isEmpty || $0.name.lowercased().contains(searchText.lowercased()) }) { member in
                                        let parts = member.name.components(separatedBy: " ")
                                        CardMember(
                                            data: CardMemberData(
                                                id: member.id,
                                                firstName: parts.first ?? "",
                                                lastName: parts.dropFirst().joined(separator: " "),
                                                avatarURL: member.avatarUrl,
                                                metadata: [DataItem(label: "Joined", value: formatDate(member.joinedAt))],
                                                groups: []
                                            )
                                        )
                                    }
                                }
                            }

                            Spacer().frame(height: 40)
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

                    // Foreground: Search field
                    SearchField(
                        isActive: $isSearchActive,
                        searchText: $searchText,
                        isFocused: $isSearchFocused,
                        placeholder: "Search members",
                        onClose: {
                            searchText = ""
                        },
                        onClear: {
                            searchText = ""
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private static func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.date(from: string) ?? Date()
    }
}

private func date(_ string: String) -> Date {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy"
    return formatter.date(from: string) ?? Date()
}

/// Preview model for members
private struct PreviewMember: Identifiable {
    let id: String
    let name: String
    let avatarUrl: String?
    let joinedAt: Date
}

/// Preview with empty state
private struct GroupMembersPreviewEmpty: View {
    @State private var searchText: String = ""
    @State private var isSearchActive: Bool = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                PageTitle.iconTitle(
                    title: "Members",
                    icon: "chevron.left",
                    onIconTap: { }
                )

                // Search field (disabled appearance for empty state)
                SearchField(
                    isActive: $isSearchActive,
                    searchText: $searchText,
                    isFocused: $isSearchFocused,
                    placeholder: "Search members"
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .opacity(0.5)
                .allowsHitTesting(false)

                // Empty state
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
        }
    }
}
