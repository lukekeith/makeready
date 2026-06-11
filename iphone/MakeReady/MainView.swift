//
//  MainView.swift
//  MakeReady
//
//  Main view that manages navigation between pages
//

import SwiftUI

enum MainTab {
    case home
    case groups
    case library
    case calendar
    case search
    case studyPrograms
}

// MARK: - NavBar Visibility Environment Key

struct NavBarVisibleKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var navBarVisible: Bool {
        get { self[NavBarVisibleKey.self] }
        set { self[NavBarVisibleKey.self] = newValue }
    }
}

struct MainView: View {
    @Environment(AuthManager.self) var authManager
    @State private var currentTab: MainTab = .home
    @State private var groupsSubTab: Int?  // Set to switch MemberHomePage to a specific tab
    @State private var studyProgramsSubTab: Int?  // Set to switch MainPrograms to a specific tab

    // Overlay manager for centralized z-index control
    @State private var overlayManager = OverlayManager()

    // Convert MainTab to NavBarTab for active state highlighting
    private var navBarActiveTab: NavBarTab {
        switch currentTab {
        case .home:
            return .home
        case .groups:
            return .groups
        case .library:
            return .library
        case .calendar:
            return .calendar
        case .search:
            return .search
        case .studyPrograms:
            return .none
        }
    }

    var body: some View {
        ZStack {
            // Current page content
            Group {
                switch currentTab {
                case .home:
                    MainHome(
                        overlayManager: overlayManager,
                        avatarURL: authManager.currentUser?.avatarURL,
                        onAddTap: {
                            overlayManager.presentMenu(id: OverlayID.addMenu) {
                                AddMenu()
                                    .environment(authManager)
                            }
                        },
                        onKPITap: { destination in
                            switch destination {
                            case .members:
                                groupsSubTab = 1
                                currentTab = .groups
                            case .groups:
                                groupsSubTab = 0
                                currentTab = .groups
                            case .enrolledLessons:
                                groupsSubTab = 2
                                currentTab = .groups
                            case .studies:
                                studyProgramsSubTab = 0
                                currentTab = .studyPrograms
                            }
                        }
                    )
                case .groups:
                    MainGroups(
                        overlayManager: overlayManager,
                        avatarURL: authManager.currentUser?.avatarURL,
                        pendingSubTab: $groupsSubTab
                    )
                case .library:
                    MainLibrary(overlayManager: overlayManager)
                case .calendar:
                    MainCalendar(
                        overlayManager: overlayManager,
                        avatarURL: authManager.currentUser?.avatarURL
                    )
                case .search:
                    GlobalSearchPage(overlayManager: overlayManager)
                case .studyPrograms:
                    MainPrograms(
                        overlayManager: overlayManager,
                        avatarURL: authManager.currentUser?.avatarURL,
                        initialTab: $studyProgramsSubTab
                    )
                }
            }
            .environment(\.navBarVisible, true)

            // Bottom navbar
            VStack {
                Spacer()
                NavBar(
                    activeTab: navBarActiveTab,
                    avatarURL: authManager.currentUser?.avatarURL,
                    onHomeTap: { currentTab = .home },
                    onGroupsTap: { currentTab = .groups },
                    onLibraryTap: { currentTab = .library },
                    onCalendarTap: { currentTab = .calendar },
                    onSearchTap: {
                        currentTab = .search
                    },
                    onProfileTap: {
                        overlayManager.presentMenu(id: OverlayID.userMenu) {
                            UserMenu()
                                .environment(authManager)
                        }
                    }
                )
            }
            .ignoresSafeArea(edges: .bottom)
        }
        // Render all managed overlays at the very top
        .overlay {
            ForEach(overlayManager.sortedOverlays) { item in
                item.content
            }
        }
        .environment(overlayManager)
        // Handle pending deep links from push notifications
        .onChange(of: PushNotificationManager.shared.pendingDeepLink) { _, newDeepLink in
            handleDeepLink(newDeepLink)
        }
        .task {
            // Centralized data loading - runs once when user is authenticated
            await AppState.shared.loadInitialData()
        }
        .onAppear {
            // Check for pending deep link when view appears
            let pendingLink = PushNotificationManager.shared.pendingDeepLink
            if pendingLink != .none {
                handleDeepLink(pendingLink)
            }
        }
    }

    /// Handle deep link navigation
    private func handleDeepLink(_ deepLink: DeepLink) {
        switch deepLink {
        case .joinRequests:
            NSLog("🔗 MainView: Handling join requests deep link")
            currentTab = .groups
            groupsSubTab = 1  // Switch to Members tab (requests card shown at top)
            PushNotificationManager.shared.clearPendingDeepLink()

        case .group(let groupId):
            NSLog("🔗 MainView: Handling group deep link for group %@", groupId)
            currentTab = .groups
            presentGroupHome(groupId: groupId)
            PushNotificationManager.shared.clearPendingDeepLink()

        case .importFile:
            NSLog("🔗 MainView: Handling .makeready file import deep link")
            // Switch to Library tab — MainLibrary observes pendingDeepLink and
            // triggers the existing import preview flow. Do NOT clear the
            // deep link here; MainLibrary clears it after consuming the URL.
            currentTab = .library

        case .none:
            break
        }
    }

    /// Present the group home page as a modal overlay
    private func presentGroupHome(groupId: String) {
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
}

#Preview {
    MainView()
        .environment(AuthManager())
}
