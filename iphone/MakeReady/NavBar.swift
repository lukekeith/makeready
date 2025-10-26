//
//  NavBar.swift
//  MakeReady
//
//  Created by MakeReady Team
//

import SwiftUI

struct NavBar: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Home
                NavBarButton(icon: "IconHome") {
                    print("Home tapped")
                }

                // Calendar
                NavBarButton(icon: "IconCalendar") {
                    print("Calendar tapped")
                }

                // Plus (Add)
                NavBarButton(icon: "IconPlus", tintColor: .green) {
                    print("Add tapped")
                }

                // People
                NavBarButton(icon: "IconPeople") {
                    print("People tapped")
                }

                // Menu
                NavBarButton(icon: "IconMenu") {
                    print("Menu tapped")
                }
            }
            .frame(height: 96)
            .padding(.horizontal, 16)
        }
        .background(
            // 10% white with 20px blur
            Color.white.opacity(0.1)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct NavBarButton: View {
    let icon: String
    var tintColor: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
                .foregroundColor(tintColor)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack {
        Spacer()
        NavBar()
    }
    .background(Color(hex: "#0d101a"))
}
