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

    // Typed navigation state — tab, sub-tab signals, deep-link routing
    // (Phase 3.8; replaces the loose currentTab/sub-tab @State vars).
    @State private var coordinator = NavigationCoordinator()

    // Overlay manager for centralized z-index control
    @State private var overlayManager = OverlayManager()

    // Convert MainTab to NavBarTab for active state highlighting
    private var navBarActiveTab: NavBarTab {
        switch coordinator.tab {
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
        @Bindable var coordinator = coordinator

        ZStack {
            // Current page content
            Group {
                switch coordinator.tab {
                case .home:
                    MainHome(
                        overlayManager: overlayManager,
                        avatarURL: authManager.currentUser?.avatarURL,
                        onAddTap: {
                            overlayManager.present(.addMenu) {
                                AddMenu()
                                    .environment(authManager)
                            }
                        },
                        onKPITap: { destination in
                            switch destination {
                            case .members:
                                coordinator.navigate(to: .groupsTab(subTab: 1))
                            case .groups:
                                coordinator.navigate(to: .groupsTab(subTab: 0))
                            case .enrolledLessons:
                                coordinator.navigate(to: .groupsTab(subTab: 2))
                            case .studies:
                                coordinator.navigate(to: .studyProgramsTab(subTab: 0))
                            }
                        }
                    )
                case .groups:
                    MainGroups(
                        overlayManager: overlayManager,
                        avatarURL: authManager.currentUser?.avatarURL,
                        pendingSubTab: $coordinator.groupsSubTab
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
                        initialTab: $coordinator.studyProgramsSubTab
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
                    onHomeTap: { coordinator.navigate(to: .tab(.home)) },
                    onGroupsTap: { coordinator.navigate(to: .tab(.groups)) },
                    onLibraryTap: { coordinator.navigate(to: .tab(.library)) },
                    onCalendarTap: { coordinator.navigate(to: .tab(.calendar)) },
                    onSearchTap: {
                        coordinator.navigate(to: .tab(.search))
                    },
                    onProfileTap: {
                        overlayManager.present(.userMenu) {
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
        .environment(coordinator)
        // Handle pending deep links from push notifications
        .onChange(of: PushNotificationManager.shared.pendingDeepLink) { _, newDeepLink in
            coordinator.handle(deepLink: newDeepLink)
        }
        .task {
            // Centralized data loading - runs once when user is authenticated
            await AppState.shared.loadInitialData()
        }
        .onAppear {
            // Wire the coordinator's overlay presentation BEFORE handling any
            // pending deep link (a cold-start .group link presents group home).
            coordinator.overlayManager = overlayManager

            // Check for pending deep link when view appears
            let pendingLink = PushNotificationManager.shared.pendingDeepLink
            if pendingLink != .none {
                coordinator.handle(deepLink: pendingLink)
            }
        }
    }
}

#Preview {
    MainView()
        .environment(AuthManager())
}
