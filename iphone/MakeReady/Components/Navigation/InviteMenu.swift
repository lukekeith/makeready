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

    @Environment(AuthManager.self) var authManager
    @Environment(\.dismissOverlay) private var dismissOverlay
    @Environment(\.dismissOverlayThen) private var dismissOverlayThen

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
                        dismissMenu {
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

        Task {
            do {
                let invite = try await InviteActions().createInvite()

                await MainActor.run {
                    isCreatingInvite = false

                    overlayManager.presentModal(id: OverlayID.shareInvite) {
                        ShareInviteSheet(
                            inviteCode: invite.code,
                            overlayManager: overlayManager
                        )
                        .environment(authManager)
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
            .environment(AuthManager())
        }
    }
}
