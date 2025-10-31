//
//  HamburgerMenu.swift
//  MakeReady
//
//  Hamburger menu that slides up from bottom
//

import SwiftUI

struct HamburgerMenu: View {
    @Binding var isPresented: Bool
    @Binding var showComponentsPage: Bool

    var body: some View {
        ZStack {
            // Backdrop
            if isPresented {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    }
            }

            // Menu content
            VStack {
                Spacer()

                VStack(spacing: 0) {
                    // Menu items
                    VStack(spacing: 0) {
                        HamburgerMenuItem(
                            icon: "square.grid.2x2",
                            title: "Components"
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isPresented = false
                            }
                            // Delay to allow menu to close before showing page
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showComponentsPage = true
                            }
                        }
                    }
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // Close button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    }
                    .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#21242d"))
                .clipShape(RoundedCornersShape(corners: [.topLeft, .topRight], radius: 16))
                .offset(y: isPresented ? 0 : 500)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

// Hamburger menu item
struct HamburgerMenuItem: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Title
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                // Icon on the right
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(Color(hex: "#7c7cff"))
                    .frame(width: 32, height: 32)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        HamburgerMenu(
            isPresented: .constant(true),
            showComponentsPage: .constant(false)
        )
    }
}
