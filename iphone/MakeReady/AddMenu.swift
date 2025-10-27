//
//  AddMenu.swift
//  MakeReady
//
//  Add activity menu that slides up from the bottom
//

import SwiftUI

struct AddMenu: View {
    @Binding var isPresented: Bool
    @State private var offset: CGFloat = UIScreen.main.bounds.height
    @State private var overlayOpacity: Double = 0
    @State private var showSubmenu: Bool = false
    @State private var mainMenuOffset: CGFloat = 0
    @State private var submenuOffset: CGFloat = UIScreen.main.bounds.width

    var body: some View {
        ZStack {
            // Dark overlay background
            Color.black.opacity(overlayOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissMenu()
                }

            VStack(spacing: 0) {
                Spacer()

                // Single menu container with sliding content
                VStack(spacing: 0) {
                    // Sliding content container
                    ZStack {
                        // Main menu content
                        VStack(spacing: 8) {
                        // First section - Main actions
                        VStack(spacing: 0) {
                            AddMenuItem(
                                icon: "IconChat",
                                title: "Send message",
                                showSubmenu: false
                            ) {
                                print("Send message tapped")
                                dismissMenu()
                            }

                            AddMenuItem(
                                icon: "IconLink",
                                title: "Invite member",
                                showSubmenu: true
                            ) {
                                openSubmenu()
                            }

                            AddMenuItem(
                                icon: "IconMeeting",
                                title: "Create meeting",
                                showSubmenu: false
                            ) {
                                print("Create meeting tapped")
                                dismissMenu()
                            }

                            AddMenuItem(
                                icon: "IconGroup",
                                title: "Create group",
                                showSubmenu: false
                            ) {
                                print("Create group tapped")
                                dismissMenu()
                            }

                            AddMenuItem(
                                icon: "IconStudy",
                                title: "Create study",
                                showSubmenu: false
                            ) {
                                print("Create study tapped")
                                dismissMenu()
                            }
                        }
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)

                        // Second section - Record video
                        VStack(spacing: 0) {
                            AddMenuItem(
                                icon: "IconRecordVideo",
                                title: "Record video",
                                showSubmenu: false,
                                iconColor: Color(hex: "#ff4444")
                            ) {
                                print("Record video tapped")
                                dismissMenu()
                            }
                        }
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .offset(x: mainMenuOffset)

                    // Invite Member Submenu content
                    InviteMemberSubmenu(onBack: {
                        dismissSubmenu()
                    }, onDismiss: {
                        dismissMenu()
                    })
                    .offset(x: submenuOffset)
                    }
                    .padding(.top, 8)

                    // Fixed close button
                    Button(action: {
                        dismissMenu()
                    }) {
                        Image("IconClose")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    }
                    .padding(.horizontal, 16)
                }
                .background(Color(hex: "#21242d"))
                .clipShape(RoundedCornersShape(corners: [.topLeft, .topRight], radius: 16))
                .offset(y: offset)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                overlayOpacity = 0.5
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                offset = 0
            }
        }
    }

    private func openSubmenu() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            mainMenuOffset = -UIScreen.main.bounds.width
            submenuOffset = 0
            showSubmenu = true
        }
    }

    private func dismissSubmenu() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            mainMenuOffset = 0
            submenuOffset = UIScreen.main.bounds.width
            showSubmenu = false
        }
    }

    private func dismissMenu() {
        withAnimation(.easeIn(duration: 0.25)) {
            overlayOpacity = 0
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offset = UIScreen.main.bounds.height
        }

        // Delay the actual dismissal to allow animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}

struct AddMenuItem: View {
    let icon: String
    let title: String
    let showSubmenu: Bool
    var iconColor: Color = Color(hex: "#7c7cff")
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon container
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(iconColor)
                    .frame(width: 32, height: 32)

                // Title
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                // Submenu arrow (if applicable)
                if showSubmenu {
                    Image("IconSubmenu")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Invite Member Submenu
struct InviteMemberSubmenu: View {
    let onBack: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Header with back button
            HStack {
                Button(action: onBack) {
                    Image("IconChevronLeft")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .foregroundColor(.white)
                        .opacity(0.5)
                }

                Spacer()

                Text("Invite member")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                // Invisible spacer to center title
                Color.clear.frame(width: 24, height: 24)
            }
            .padding(16)
            .frame(height: 53)

            // Menu items
            VStack(spacing: 0) {
                SubmenuItem(icon: "IconChat", title: "Send message") {
                    print("Send message tapped")
                    onDismiss()
                }

                SubmenuItem(icon: "IconLink", title: "Copy link") {
                    print("Copy link tapped")
                    onDismiss()
                }

                SubmenuItem(icon: "IconQR", title: "QR Code") {
                    print("QR Code tapped")
                    onDismiss()
                }

                SubmenuItem(icon: "IconInvite", title: "Invite members") {
                    print("Invite members tapped")
                    onDismiss()
                }

                SubmenuItem(icon: "IconUser", title: "Invite contacts") {
                    print("Invite contacts tapped")
                    onDismiss()
                }
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}

// Submenu item (icon on right)
struct SubmenuItem: View {
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
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(Color(hex: "#7c7cff"))
                    .frame(width: 32, height: 32)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Custom shape for rounding specific corners
struct RoundedCornersShape: Shape {
    var corners: UIRectCorner
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        AddMenu(isPresented: .constant(true))
    }
}
