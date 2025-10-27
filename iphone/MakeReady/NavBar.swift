//
//  NavBar.swift
//  MakeReady
//
//  Created by MakeReady Team
//

import SwiftUI

struct NavBar: View {
    @Binding var showUserMenu: Bool
    @Binding var showAddMenu: Bool

    var body: some View {
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
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showAddMenu = true
                }
            }

            // People
            NavBarButton(icon: "IconPeople") {
                print("People tapped")
            }

            // Menu (Hamburger)
            NavBarButton(icon: "IconMenu") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showUserMenu = true
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .background(
            // 10% white with 20px blur
            Color.white.opacity(0)
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
        NavBar(showUserMenu: .constant(false), showAddMenu: .constant(false))
    }
    .background(Color(hex: "#0d101a"))
}
