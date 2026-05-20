//
//  InviteMenu.swift
//  MakeReady
//
//  Standalone invite menu - presented via overlayManager.presentMenu()
//  ManagedMenuView provides: dark overlay, slide-up animation, swipe-to-dismiss
//

import SwiftUI

struct InviteMenu: View {
    let overlayManager: OverlayManager
    let menuId: String

    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismissOverlay) private var dismissOverlay

    @State private var isCreatingInvite = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                // Menu items
                VStack(spacing: 0) {
                    SubmenuItem(icon: "IconChat", title: "Send message") {
                        dismissMenu()
                    }

                    SubmenuItem(icon: "IconLink", title: "Copy link") {
                        dismissMenu()
                    }

                    SubmenuItem(icon: "IconQR", title: "QR Code") {
                        createInviteAndShowQR()
                    }

                    SubmenuItem(icon: "IconInvite", title: "Invite members") {
                        dismissMenu()
                    }

                    SubmenuItem(icon: "IconUser", title: "Invite contacts") {
                        dismissMenu()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            overlayManager.presentModal(id: OverlayID.inviteContacts) {
                                InviteContactsPage(overlayManager: overlayManager)
                            }
                        }
                    }
                }
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Close button
            Button {
                dismissMenu()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            }
            .padding(.horizontal, 16)
        }
    }

    private func dismissMenu() {
        dismissOverlay?()
    }

    private func createInviteAndShowQR() {
        guard !isCreatingInvite else { return }
        isCreatingInvite = true

        Task {
            do {
                let invite = try await authManager.createInvite()

                await MainActor.run {
                    isCreatingInvite = false

                    overlayManager.presentModal(id: OverlayID.shareInvite) {
                        ShareInviteSheet(
                            inviteCode: invite.code,
                            overlayManager: overlayManager
                        )
                        .environmentObject(authManager)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        dismissMenu()
                    }
                }
            } catch {
                await MainActor.run {
                    isCreatingInvite = false
                    dismissMenu()
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack {
            Spacer()
            InviteMenu(
                overlayManager: OverlayManager(),
                menuId: "preview"
            )
            .environmentObject(AuthManager())
        }
    }
}
