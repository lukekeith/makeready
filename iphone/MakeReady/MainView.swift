//
//  MainView.swift
//  MakeReady
//
//  Main view that manages navigation between pages
//

import SwiftUI

enum MainTab {
    case home
    case schedule
    case members
}

struct MainView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var currentTab: MainTab = .home
    @State private var showUserMenu = false
    @State private var showAddMenu = false

    var body: some View {
        ZStack {
            // Current page content
            Group {
                switch currentTab {
                case .home:
                    HomePageContent(
                        showUserMenu: $showUserMenu,
                        showAddMenu: $showAddMenu,
                        avatarURL: authManager.currentUser?.avatarURL
                    )
                case .schedule:
                    SchedulePageContent(
                        showUserMenu: $showUserMenu,
                        showAddMenu: $showAddMenu,
                        avatarURL: authManager.currentUser?.avatarURL
                    )
                case .members:
                    MembersPageContent(
                        showUserMenu: $showUserMenu,
                        showAddMenu: $showAddMenu,
                        avatarURL: authManager.currentUser?.avatarURL
                    )
                }
            }

            // Bottom navbar
            VStack {
                Spacer()
                NavBar(
                    showUserMenu: $showUserMenu,
                    showAddMenu: $showAddMenu,
                    onHomeTap: { currentTab = .home },
                    onScheduleTap: { currentTab = .schedule },
                    onMembersTap: { currentTab = .members }
                )
            }

            // User menu overlay
            if showUserMenu {
                UserMenu(isPresented: $showUserMenu)
            }

            // Add menu overlay
            if showAddMenu {
                AddMenu(isPresented: $showAddMenu)
            }
        }
    }
}

// MARK: - Page Content Components

struct HomePageContent: View {
    @Binding var showUserMenu: Bool
    @Binding var showAddMenu: Bool
    let avatarURL: String?
    @State private var activeTab = 0

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PageHeader(
                    tabs: ["Home"],
                    activeTab: $activeTab,
                    avatarURL: avatarURL,
                    onNotificationTap: {
                        print("Notification tapped")
                    },
                    onAvatarTap: {
                        print("Avatar tapped")
                    }
                )

                Spacer()
            }
        }
    }
}

struct SchedulePageContent: View {
    @Binding var showUserMenu: Bool
    @Binding var showAddMenu: Bool
    let avatarURL: String?
    @State private var activeTab = 0

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PageHeader(
                    tabs: ["Schedule"],
                    activeTab: $activeTab,
                    avatarURL: avatarURL,
                    onNotificationTap: {
                        print("Notification tapped")
                    },
                    onAvatarTap: {
                        print("Avatar tapped")
                    }
                )

                Spacer()
            }
        }
    }
}

struct MembersPageContent: View {
    @Binding var showUserMenu: Bool
    @Binding var showAddMenu: Bool
    let avatarURL: String?
    @State private var activeTab = 0

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                PageHeader(
                    tabs: ["Members", "Groups"],
                    activeTab: $activeTab,
                    avatarURL: avatarURL,
                    onNotificationTap: {
                        print("Notification tapped")
                    },
                    onAvatarTap: {
                        print("Avatar tapped")
                    }
                )

                // Content area
                TabView(selection: $activeTab) {
                    // Members tab content
                    VStack {
                        Spacer()
                        Text("Members Content")
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                    }
                    .tag(0)

                    // Groups tab content
                    VStack {
                        Spacer()
                        Text("Groups Content")
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                    }
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
    }
}

#Preview {
    MainView()
}
