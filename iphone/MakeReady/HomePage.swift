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

    var body: some View {
        ZStack {
            // Background
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
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

// MARK: - Color Extensions
extension Color {
    static let appBackground = Color(hex: "#0d101a")
}

#Preview {
    HomePage()
}
