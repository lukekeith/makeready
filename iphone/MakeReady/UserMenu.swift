//
//  UserMenu.swift
//  MakeReady
//
//  User menu that slides up from bottom
//

import SwiftUI

struct UserMenu: View {
    @EnvironmentObject var authManager: AuthManager
    @Binding var isPresented: Bool
    @Binding var showProfilePage: Bool

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
                    // User info section
                    VStack(spacing: 16) {
                        // Avatar
                        if let user = authManager.currentUser {
                            AsyncImage(url: URL(string: user.avatarURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Text(user.name.prefix(1))
                                            .font(.system(size: 40, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())

                            // User name
                            Text(user.name)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.top, 40)
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
                .frame(maxWidth: .infinity)
                .background(Color.appBackground)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: -5)
                .offset(y: isPresented ? 0 : 500)
            }
            .ignoresSafeArea()
        }
    }

    private func handleMyProfile() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }

        // Delay to allow menu animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showProfilePage = true
        }
    }

    private func handleLogout() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPresented = false
        }

        // Delay logout to allow menu animation to complete
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            try? await authManager.signOut()
        }
    }
}

#Preview {
    UserMenu(
        isPresented: .constant(true),
        showProfilePage: .constant(false)
    )
    .environmentObject(AuthManager())
}
