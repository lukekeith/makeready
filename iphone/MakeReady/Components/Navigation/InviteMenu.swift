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
    @State private var createOperation: UUID?

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
                            overlayManager.present(.inviteContacts) {
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
                    .font(Typography.s20)
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
        let generation = AppState.shared.initialLoad.generation
        let operation = UUID()
        createOperation = operation
        isCreatingInvite = true
        Task { @MainActor in
            guard AppState.shared.initialLoad.isCurrent(generation), createOperation == operation, !Task.isCancelled else { return }
            do {
                let invite = try await InviteActions().createInvite()
                guard AppState.shared.initialLoad.isCurrent(generation), createOperation == operation, !Task.isCancelled else { return }
                isCreatingInvite = false
                // Use the existing completed-dismissal callback; no delayed work crosses sessions.
                dismissMenu {
                    guard AppState.shared.initialLoad.isCurrent(generation), createOperation == operation else { return }
                    createOperation = nil
                    overlayManager.present(.shareInvite) {
                        ShareInviteSheet(inviteCode: invite.code, overlayManager: overlayManager)
                            .environment(authManager)
                    }
                }
            } catch {
                guard AppState.shared.initialLoad.isCurrent(generation), createOperation == operation else { return }
                createOperation = nil
                isCreatingInvite = false
                // Silent on cancellation; a current failure retains this menu's existing dismiss recovery.
                guard !Task.isCancelled, !GroupActions.isCancellation(error) else { return }
                dismissMenu()
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
