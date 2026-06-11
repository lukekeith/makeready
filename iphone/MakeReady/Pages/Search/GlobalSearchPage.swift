//
//  GlobalSearchPage.swift
//  MakeReady
//
//  Global search page that searches all entities in AppState.
//  Presented as a modal from the hamburger menu.
//  Tapping a result slides in the detail page from the right (HStack offset pattern).
//

import SwiftUI

struct GlobalSearchPage: View {
    let overlayManager: OverlayManager
    @State private var selectedProgramId: String?
    @State private var searchText = ""
    @State private var isSearchActive = false
    @FocusState private var isSearchFocused: Bool

    // Category filter
    @State private var filterCategory: SearchResultCategory?

    // Search results (loaded async from server)
    @State private var searchResults: [SearchResultCategory: CategoryResults] = [:]
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    // Recent items (loaded async from API)
    @State private var recentResults: [SearchResultCategory: CategoryResults] = [:]

    private var state: AppState { AppState.shared }
    private var keyboard: KeyboardState { KeyboardState.shared }

    private var sortedCategories: [SearchResultCategory] {
        searchResults.keys.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var visibleCategories: [SearchResultCategory] {
        if let filter = filterCategory {
            return sortedCategories.filter { $0 == filter }
        }
        return sortedCategories
    }

    private var recentCategories: [SearchResultCategory] {
        recentResults.keys.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        searchScreen
        .background(Color.appBackground)
        .onChange(of: searchText) {
            filterCategory = nil
            triggerSearch()
        }
        .onAppear {
            Task {
                recentResults = await GlobalSearchEngine.fetchRecentItems(in: state)
            }
        }
    }

    // MARK: - Search Screen

    private var searchScreen: some View {
        VStack(spacing: 0) {
            SearchField(
                isActive: $isSearchActive,
                searchText: $searchText,
                isFocused: $isSearchFocused,
                placeholder: "Search everything",
                onClose: { searchText = ""; filterCategory = nil },
                onClear: { searchText = ""; filterCategory = nil }
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)

            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                recentsView
            } else if isSearching && sortedCategories.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(.white30)
                    Spacer()
                }
            } else if sortedCategories.isEmpty {
                emptyStateView
            } else {
                resultsView
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Navigation

    private func handleResultTap(_ result: SearchResult) {
        guard result.category != .template else { return }
        isSearchFocused = false
        presentAsModal(result)
    }

    private func presentAsModal(_ result: SearchResult) {
        switch result.category {
        case .program:
            selectedProgramId = result.entityId
            overlayManager.presentModal(id: OverlayID.programHome) {
                ProgramHomeModalContent(
                    overlayManager: overlayManager,
                    selectedProgramId: $selectedProgramId,
                    onDismiss: {
                        overlayManager.dismiss(id: OverlayID.programHome)
                    }
                )
            }

        case .group:
            overlayManager.presentModal(id: OverlayID.groupHome) {
                GroupHomePage(
                    overlayManager: overlayManager,
                    groupId: result.entityId,
                    onDismiss: { overlayManager.dismiss(id: OverlayID.groupHome) }
                )
            }

        case .lesson:
            let lessonModalId = "searchLesson"
            overlayManager.presentModal(id: lessonModalId) {
                SearchLessonDetail(
                    lessonId: result.entityId,
                    programId: result.parentId,
                    onDismiss: { overlayManager.dismiss(id: lessonModalId) }
                )
            }

        case .video:
            let videoModalId = "searchVideo"
            if let video = state.videos[result.entityId],
               let url = URL(string: video.playbackUrl) {
                overlayManager.presentModal(id: videoModalId) {
                    VideoPlayerPage(
                        videoURL: url,
                        title: video.displayTitle,
                        onDismiss: { overlayManager.dismiss(id: videoModalId) }
                    )
                }
            } else if let playbackUrl = result.playbackUrl,
                      let url = URL(string: playbackUrl) {
                overlayManager.presentModal(id: videoModalId) {
                    VideoPlayerPage(
                        videoURL: url,
                        title: result.title,
                        onDismiss: { overlayManager.dismiss(id: videoModalId) }
                    )
                }
            }

        case .member:
            overlayManager.presentModal(id: OverlayID.memberProfile) {
                MemberProfilePage(
                    memberId: result.entityId,
                    onDismiss: { overlayManager.dismiss(id: OverlayID.memberProfile) }
                )
            }

        case .enrollment:
            if let enrollment = state.enrollments[result.entityId] {
                overlayManager.presentModal(id: OverlayID.enrollmentSchedule, dismissOnTapOutside: false) {
                    EnrollmentSchedulePage(
                        enrollment: enrollment,
                        onDismiss: { overlayManager.dismiss(id: OverlayID.enrollmentSchedule) },
                        overlayManager: overlayManager
                    )
                }
            }

        case .post:
            let postModalId = "searchPost"
            overlayManager.presentModal(id: postModalId) {
                PostDetailPage(
                    postId: result.entityId,
                    title: result.title,
                    subtitle: result.subtitle,
                    imageURL: result.imageURL,
                    onDismiss: { overlayManager.dismiss(id: postModalId) }
                )
            }

        case .event:
            let eventModalId = "searchEvent"
            overlayManager.presentModal(id: eventModalId) {
                EventDetailPage(
                    eventId: result.entityId,
                    title: result.title,
                    subtitle: result.subtitle,
                    imageURL: result.imageURL,
                    onDismiss: { overlayManager.dismiss(id: eventModalId) }
                )
            }

        case .notification:
            overlayManager.presentModal(id: OverlayID.notificationFeed) {
                NotificationFeedPage()
            }

        default:
            break
        }
    }

    // MARK: - Search

    private func triggerSearch() {
        searchTask?.cancel()
        let query = searchText
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.count < 2 {
            searchResults = [:]
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }

            let results = await GlobalSearchEngine.search(query: query)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        }
    }

    // MARK: - Recents

    private var recentsView: some View {
        ScrollView {
            if recentCategories.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 36))
                        .foregroundColor(.white20)
                    Text("No recent items")
                        .font(.system(size: 15))
                        .foregroundColor(.white50)
                }
                .padding(.top, 80)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(recentCategories) { category in
                        if let categoryResults = recentResults[category] {
                            categorySection(category: category, results: categoryResults, showDivider: false)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, keyboard.isVisible ? keyboard.height : 40)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.white20)
            Text("No results for '\(searchText)'")
                .font(.system(size: 15))
                .foregroundColor(.white50)
            Spacer()
        }
    }

    // MARK: - Results

    private var resultsView: some View {
        VStack(spacing: 0) {
            // Filter badges
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sortedCategories) { category in
                        if let categoryResults = searchResults[category] {
                            filterBadge(category: category, count: categoryResults.totalCount)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            // Filtered results
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(visibleCategories) { category in
                        if let categoryResults = searchResults[category] {
                            categorySection(category: category, results: categoryResults)
                        }
                    }
                }
                .padding(.bottom, keyboard.isVisible ? keyboard.height : 40)
            }
        }
    }

    private func filterBadge(category: SearchResultCategory, count: Int) -> some View {
        let isSelected = filterCategory == category

        return Button {
            withAnimation(Motion.micro) {
                filterCategory = isSelected ? nil : category
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 12))
                Text("\(category.displayName) \(count)")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .white50)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isSelected ? Color.brandPrimary : Color.white.opacity(0.08))
            )
            .overlay(
                Capsule().stroke(isSelected ? Color.clear : Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func categorySection(category: SearchResultCategory, results: CategoryResults, showDivider: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 14))
                    .foregroundColor(.white50)
                    .frame(width: 20, height: 20)

                Text(category.displayName.uppercased())
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white50)
                    .kerning(1.2)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            ForEach(results.results) { result in
                resultRow(result)
            }

            if results.totalCount > results.results.count {
                Button {
                } label: {
                    Text("Show all \(results.totalCount) results")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.brandPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(PlainButtonStyle())
            }

            if showDivider {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
            }
        }
    }

    private func resultRow(_ result: SearchResult) -> some View {
        CardSearchResult(result: result, highlightQuery: searchText) {
            handleResultTap(result)
        }
    }
}

// MARK: - Preview

#Preview {
    GlobalSearchPage(overlayManager: OverlayManager())
        .environment(OverlayManager())
}
