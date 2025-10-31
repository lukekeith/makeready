//
//  HomePage.swift
//  MakeReady
//
//  Created by MakeReady Team
//

import SwiftUI

struct HomePage: View {
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
                    tabs: ["Home"],
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

                Spacer()

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

// MARK: - Color Extensions
extension Color {
    static let appBackground = Color(hex: "#0d101a")
}

#Preview {
    HomePage()
}
