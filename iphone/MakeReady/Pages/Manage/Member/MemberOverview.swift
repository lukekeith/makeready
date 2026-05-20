//
//  MemberOverview.swift
//  MakeReady
//
//  Members and groups page with tab navigation
//  Note: This is an older standalone page, kept for reference
//

import SwiftUI

struct MemberOverview: View {
    @State private var overlayManager = OverlayManager()
    @State private var activeTab = 0
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        ZStack {
            // Background
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page Header with tabs
                PageHeader(
                    tabs: ["Members", "Groups"],
                    activeTab: $activeTab
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
                    onProfileTap: {
                        overlayManager.presentMenu(id: OverlayID.hamburgerMenu) {
                            HamburgerMenu()
                        }
                    }
                )
            }
        }
        .overlay {
            ForEach(overlayManager.sortedOverlays) { item in
                item.content
            }
        }
        .environment(overlayManager)
    }
}

#Preview {
    MemberOverview()
        .environmentObject(AuthManager())
}
