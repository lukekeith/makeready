//
//  HomePage.swift
//  MakeReady
//
//  Created by MakeReady Team
//

import SwiftUI

struct HomePage: View {
    @State private var showUserMenu = false

    var body: some View {
        ZStack {
            // Background
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Navigation Bar at bottom
                NavBar(showUserMenu: $showUserMenu)
            }

            // User menu overlay
            if showUserMenu {
                UserMenu(isPresented: $showUserMenu)
                    .transition(.opacity)
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
