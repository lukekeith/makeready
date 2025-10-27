//
//  SchedulePage.swift
//  MakeReady
//
//  Schedule page with calendar and events
//

import SwiftUI

struct SchedulePage: View {
    @State private var showUserMenu = false
    @State private var showAddMenu = false
    @State private var activeTab = 0

    var body: some View {
        ZStack {
            // Background
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page Header with tabs
                PageHeader(
                    tabs: ["Schedule"],
                    activeTab: $activeTab,
                    avatarURL: nil,
                    onNotificationTap: {
                        print("Notification tapped")
                    },
                    onAvatarTap: {
                        print("Avatar tapped")
                    }
                )

                Spacer()

                // Navigation Bar at bottom
                NavBar(showUserMenu: $showUserMenu, showAddMenu: $showAddMenu)
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

#Preview {
    SchedulePage()
}
