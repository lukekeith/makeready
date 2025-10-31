//
//  MembersPage.swift
//  MakeReady
//
//  Members and groups page with tab navigation
//

import SwiftUI

struct MembersPage: View {
    @State private var showUserMenu = false
    @State private var showAddMenu = false
    @State private var showHamburgerMenu = false
    @State private var showProfilePage = false
    @State private var activeTab = 0

    var body: some View {
        ZStack {
            // Background
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page Header with tabs
                PageHeader(
                    tabs: ["Members", "Groups"],
                    activeTab: $activeTab,
                    avatarURL: nil,
                    onNotificationTap: {
                        print("Notification tapped")
                    },
                    onAvatarTap: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showUserMenu = true
                        }
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

                // Navigation Bar at bottom
                NavBar(
                    showUserMenu: $showUserMenu,
                    showAddMenu: $showAddMenu,
                    showHamburgerMenu: $showHamburgerMenu
                )
            }

            // User menu overlay
            if showUserMenu {
                UserMenu(
                    isPresented: $showUserMenu,
                    showProfilePage: $showProfilePage
                )
            }

            // Add menu overlay
            if showAddMenu {
                AddMenu(isPresented: $showAddMenu)
            }
        }
    }
}

#Preview {
    MembersPage()
}
