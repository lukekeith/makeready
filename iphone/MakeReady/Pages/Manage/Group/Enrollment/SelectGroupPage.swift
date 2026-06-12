//
//  SelectGroupPage.swift
//  MakeReady
//
//  Step 1 of enrollment flow (from program): Select a group
//

import SwiftUI

struct SelectGroupPage: View {
    let enrolledGroupIds: Set<String>
    let onClose: () -> Void
    let onNext: (UserGroup) -> Void

    // Initialize from cache synchronously so content is ready BEFORE modal animation starts
    @State private var groups: [UserGroup]
    @State private var selectedGroupId: String?
    @State private var searchText = ""
    @State private var isLoading: Bool
    @State private var error: String?
    @FocusState private var isSearchFocused: Bool

    // Use centralized state for fine-grained reactivity
    private var state: AppState { AppState.shared }

    init(
        enrolledGroupIds: Set<String> = [],
        onClose: @escaping () -> Void,
        onNext: @escaping (UserGroup) -> Void
    ) {
        self.enrolledGroupIds = enrolledGroupIds
        self.onClose = onClose
        self.onNext = onNext

        // Pre-load from cache for smooth modal animation
        let cachedGroups = AppState.shared.orderedGroups
        _groups = State(initialValue: cachedGroups)
        _isLoading = State(initialValue: cachedGroups.isEmpty)
    }

    private var filteredGroups: [UserGroup] {
        if searchText.isEmpty {
            return groups
        }
        return groups.filter { group in
            group.name.localizedCaseInsensitiveContains(searchText) ||
            (group.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var selectedGroup: UserGroup? {
        guard let id = selectedGroupId else { return nil }
        return groups.first { $0.id == id }
    }

    private var shouldShowSearch: Bool {
        !searchText.isEmpty || groups.count > 10
    }

    var body: some View {
        VStack(spacing: 0) {
            if groups.isEmpty || isLoading {
                loadingContent
            } else if let error = error {
                errorContent(error)
            } else if filteredGroups.isEmpty {
                emptyContent
            } else {
                listContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                PageTitle.iconTitleLink(
                    title: "Select Group",
                    leftIcon: "xmark",
                    rightLink: "Next",
                    rightLinkDisabled: selectedGroupId == nil,
                    onLeftIconTap: onClose,
                    onRightLinkTap: {
                        if let group = selectedGroup {
                            onNext(group)
                        }
                    }
                )

                if shouldShowSearch {
                    SearchField(
                        isActive: .constant(true),
                        searchText: $searchText,
                        isFocused: $isSearchFocused,
                        placeholder: "Search groups"
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .background(Color.appBackground)
        }
        .task {
            if groups.isEmpty {
                await loadGroups()
            }
        }
    }

    // MARK: - List Content

    private var listContent: some View {
        ScrollView {
            VStack(spacing: 4) {
                Color.clear
                    .frame(height: shouldShowSearch ? 140 : 70)

                ForEach(filteredGroups, id: \.id) { group in
                    let isEnrolled = enrolledGroupIds.contains(group.id)

                    // Count active enrollments for this group from cache
                    let activeEnrollmentCount = state.enrollmentsFor(groupId: group.id)
                        .filter { $0.isActive }
                        .count

                    let metadata: [DataItem] = {
                        var items = [DataItem(number: "\(group.memberCount)", label: "Members")]
                        if activeEnrollmentCount > 0 {
                            items.append(DataItem(number: "\(activeEnrollmentCount)", label: activeEnrollmentCount == 1 ? "Enrollment" : "Enrollments"))
                        }
                        return items
                    }()

                    CardGroup(
                        data: CardGroupData(
                            id: group.id,
                            title: group.name,
                            imageStyle: group.coverImageUrl != nil
                                ? .photo(imageURL: group.coverImageUrl!)
                                : .icon(systemName: "person.2.fill", backgroundColor: .purple),
                            metadata: metadata,
                            isSelected: selectedGroupId == group.id,
                            onTap: isEnrolled ? nil : {
                                withAnimation(Motion.micro) {
                                    if selectedGroupId == group.id {
                                        selectedGroupId = nil
                                    } else {
                                        selectedGroupId = group.id
                                    }
                                }
                            }
                        )
                    )
                    .opacity(isEnrolled ? 0.5 : 1.0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Loading Content (Skeleton Cards)

    private var loadingContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                Color.clear
                    .frame(height: shouldShowSearch ? 140 : 70)

                ForEach(0..<4, id: \.self) { _ in
                    SkeletonCardGroup()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Error Content

    private func errorContent(_ errorMessage: String) -> some View {
        VStack {
            Spacer()
                .frame(height: 100)
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(Typography.s40)
                    .foregroundColor(.orange)
                Text(errorMessage)
                    .font(Typography.s15)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await loadGroups() }
                }
                .foregroundColor(.brandPrimary)
            }
            .padding()
            Spacer()
        }
    }

    // MARK: - Empty Content

    private var emptyContent: some View {
        VStack {
            Spacer()
                .frame(height: 100)
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(Typography.s40)
                    .foregroundColor(.white.opacity(0.3))
                Text(searchText.isEmpty ? "No groups found" : "No groups match your search")
                    .font(Typography.s15)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        }
    }

    // MARK: - Data Loading

    private func loadGroups() async {
        isLoading = true
        error = nil

        do {
            try await GroupActions().loadGroups()
            await MainActor.run {
                groups = state.orderedGroups
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        SelectGroupPage(
            onClose: { print("Close") },
            onNext: { group in print("Selected: \(group.name)") }
        )
    }
}
