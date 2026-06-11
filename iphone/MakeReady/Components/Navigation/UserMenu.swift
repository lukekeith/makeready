//
//  UserMenu.swift
//  MakeReady
//
//  User menu content - presented via overlayManager.presentMenu()
//  ManagedMenuView provides: dark overlay, slide-up animation, swipe-to-dismiss
//

import SwiftUI

struct UserMenu: View {
    @Environment(AuthManager.self) var authManager
    @Environment(OverlayManager.self) private var overlayManager
    @Environment(\.dismissOverlay) private var dismissOverlay
    @Environment(\.dismissOverlayThen) private var dismissOverlayThen

    /// Centralized state — read user's organization list from here.
    private var state: AppState { AppState.shared }

    var body: some View {
        // Menu content only - ManagedMenuView provides chrome
        VStack(spacing: 0) {
            // User info section
            VStack(spacing: 16) {
                // Avatar - use CachedAsyncImage to prevent reload during animation
                if let user = authManager.currentUser {
                    CachedAsyncImage(
                        urlString: user.avatarURL,
                        size: 80,
                        fallbackInitials: String(user.name.prefix(1))
                    )
                    .id("userMenuAvatar-\(user.id)")

                    // User name
                    Text(user.name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.top, 24)
            .padding(.bottom, 32)

            // Menu buttons
            VStack(spacing: 12) {
                // My Profile button
                Button(action: handleMyProfile) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)

                        Text("My profile")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white)

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())

                // One row per organization the user belongs to. Today the
                // server only returns the org the user owns, so this typically
                // renders a single button; the loop scales when multi-org
                // listing is added server-side.
                ForEach(state.userOrganizations) { org in
                    organizationButton(org: org)
                }

                // Logout button
                Button(action: handleLogout) {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)

                        Text("Logout")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white)

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    /// Dismiss menu using ManagedMenuView's animated dismissal.
    /// With a completion, it runs once the exit animation actually finishes
    /// (Phase 3.2 — replaces wall-clock asyncAfter waits).
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

    private func handleMyProfile() {
        dismissMenu {
            overlayManager.present(.profilePage) {
                ProfilePage(overlayManager: overlayManager)
                    .environment(authManager)
            }
        }
    }

    /// Row styled like My Profile / Logout, named after the organization.
    /// Tap dismisses the menu then presents OrgHomePage for that org.
    private func organizationButton(org: OrganizationData) -> some View {
        Button {
            handleOpenOrg(org: org)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.white)
                    .frame(width: 20, height: 20)

                Text(org.name)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func handleOpenOrg(org: OrganizationData) {
        dismissMenu {
            overlayManager.present(.orgHome) {
                OrgHomePage(overlayManager: overlayManager, organization: org)
                    .environment(authManager)
            }
        }
    }

    private func handleLogout() {
        dismissMenu()

        // Delay logout to allow menu animation to complete
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            try? await authManager.signOut()
        }
    }
}

#Preview {
    // Preview shows UserMenu content (in production, wrapped by ManagedMenuView)
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack {
            Spacer()
            UserMenu()
                .environment(OverlayManager())
                .environment(AuthManager())
        }
    }
}
