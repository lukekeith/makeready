//
//  AddMenu.swift
//  MakeReady
//
//  Add activity menu content - presented via overlayManager.presentMenu()
//  ManagedMenuView provides: dark overlay, slide-up animation, swipe-to-dismiss
//

import SwiftUI

struct AddMenu: View {
    @Environment(AuthManager.self) var authManager
    @Environment(OverlayManager.self) private var overlayManager
    @Environment(\.dismissOverlay) private var dismissOverlay
    @Environment(\.dismissOverlayThen) private var dismissOverlayThen

    // Submenu sliding state (internal to this menu)
    @State private var showSubmenu: Bool = false
    @State private var mainMenuOffset: CGFloat = 0
    @State private var submenuOffset: CGFloat = 500
    @State private var isCreatingInvite: Bool = false

    var body: some View {
        // Menu content only - ManagedMenuView provides chrome
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
                            dismissMenu {
                                overlayManager.presentModal(id: OverlayID.createGroup) {
                                    CreateGroupPage(overlayManager: overlayManager)
                                }
                            }
                        }

                        AddMenuItem(
                            icon: "IconStudy",
                            title: "Create study program",
                            showSubmenu: false
                        ) {
                            print("Create study tapped")
                            dismissMenu {
                                overlayManager.presentModal(id: OverlayID.createProgram) {
                                    CreateProgramPage(overlayManager: overlayManager)
                                }
                            }
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
                InviteMemberSubmenu(
                    onBack: {
                        dismissSubmenu()
                    },
                    onDismiss: {
                        dismissMenu()
                    },
                    onInviteContacts: {
                        dismissMenu {
                            overlayManager.presentModal(id: OverlayID.inviteContacts) {
                                InviteContactsPage(overlayManager: overlayManager)
                            }
                        }
                    },
                    onShowQRCode: {
                        createInviteAndShowQR()
                    }
                )
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
    }

    private func openSubmenu() {
        withAnimation(Motion.springSoft) {
            mainMenuOffset = -Screen.bounds.width
            submenuOffset = 0
            showSubmenu = true
        }
    }

    private func dismissSubmenu() {
        withAnimation(Motion.springSoft) {
            mainMenuOffset = 0
            submenuOffset = Screen.bounds.width
            showSubmenu = false
        }
    }

    /// Dismiss menu using ManagedMenuView's animated dismissal
    /// Dismiss with optional completion that runs once the exit animation
    /// actually finishes (Phase 3.2 — replaces wall-clock asyncAfter waits).
    private func dismissMenu(then completion: (() -> Void)? = nil) {
        if let completion {
            if let dismissOverlayThen {
                dismissOverlayThen(completion)
            } else {
                dismissOverlay?()
                completion()
            }
        } else {
            dismissOverlay?()
        }
    }

    private func createInviteAndShowQR() {
        guard !isCreatingInvite else { return }

        isCreatingInvite = true
        NSLog("🔵 QR Code button tapped - Creating invite...")

        Task {
            do {
                NSLog("📤 API Request: POST /api/invites")
                NSLog("📤 Request body: { groupId: nil, expiresAt: nil }")

                // Create invite via API
                let invite = try await InviteActions().createInvite()

                NSLog("📥 API Response received:")
                NSLog("📥   success: true")
                NSLog("📥   invite.id: %@", invite.id)
                NSLog("📥   invite.code: %@", invite.code)
                NSLog("📥   invite.userId: %@", invite.userId)
                NSLog("📥   invite.groupId: %@", invite.groupId ?? "nil")
                NSLog("📥   invite.createdAt: %@", invite.createdAt)
                NSLog("📥   invite.expiresAt: %@", invite.expiresAt ?? "nil")
                NSLog("✅ Invite created successfully - Opening share sheet...")

                await MainActor.run {
                    self.isCreatingInvite = false

                    // Present share invite modal
                    overlayManager.presentModal(id: OverlayID.shareInvite) {
                        ShareInviteSheet(
                            inviteCode: invite.code,
                            overlayManager: overlayManager
                        )
                        .environment(authManager)
                    }

                    // Dismiss menu after a short delay to allow sheet to present
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        dismissMenu()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isCreatingInvite = false
                    NSLog("❌ API Error: Failed to create invite")
                    NSLog("❌ Error: %@", error.localizedDescription)
                    // Still dismiss menu even on error
                    dismissMenu()
                }
            }
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
    let onInviteContacts: () -> Void
    let onShowQRCode: () -> Void

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
                    onShowQRCode()
                }

                SubmenuItem(icon: "IconInvite", title: "Invite members") {
                    print("Invite members tapped")
                    onDismiss()
                }

                SubmenuItem(icon: "IconUser", title: "Invite contacts") {
                    onInviteContacts()
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

#Preview {
    // Preview shows AddMenu content (in production, wrapped by ManagedMenuView)
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack {
            Spacer()
            AddMenu()
                .environment(OverlayManager())
                .environment(AuthManager())
        }
    }
}
