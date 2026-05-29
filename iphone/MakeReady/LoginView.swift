//
//  LoginView.swift
//  MakeReady
//
//  Created by MakeReady Team
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#303131"),
                    Color(hex: "#141413")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo
                Image("LoginLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 100)

                // Google Sign In Button
                Button(action: handleGoogleSignIn) {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#0d101a")))
                                .frame(width: 14, height: 14)
                        } else {
                            // Google Logo
                            Image("GoogleIcon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14)
                        }

                        Text(isLoading ? "Signing in..." : "Continue with Google")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Color(hex: "#0d101a"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isLoading)

                Spacer()
            }
            .padding(.horizontal, 64)
            .padding(.vertical, 32)

            // Error message fixed at bottom
            if let error = errorMessage {
                VStack {
                    Spacer()

                    Text(error)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white)
                        .lineSpacing(18 - 13)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(Color(hex: "#FF4759"))
                        .cornerRadius(8)
                        .padding(.horizontal, 64)
                        .padding(.bottom, 32)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // DEBUG bypass button (top-right corner)
            #if DEBUG
            VStack {
                HStack {
                    Spacer()

                    ActionButton(icon: "arrow.right", variant: .whitePurple, action: handleDebugBypass)
                        .padding(.top, 32)
                        .padding(.trailing, 32)
                }
                Spacer()
            }
            #endif
        }
    }

    private func handleGoogleSignIn() {
        print("👆 Google Sign In button tapped")
        isLoading = true
        errorMessage = nil

        Task {
            do {
                if Configuration.isLocalDevelopment {
                    // Local dev: use dev-login endpoint (no Google OAuth needed)
                    try await authManager.devLogin(email: "luke@lukekeith.com")
                } else {
                    try await authManager.signInWithGoogle()
                }
                print("✅ Sign in completed successfully")
            } catch {
                print("❌ Sign in error: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "Sign in failed. Please try again."
                    isLoading = false
                }
            }
        }
    }

    #if DEBUG
    private func handleDebugBypass() {
        print("🔓 DEBUG: Bypass button tapped")
        Task {
            try? await authManager.devLogin(email: "luke@lukekeith.com")
        }
    }
    #endif
}

// MARK: - Color Extensions
#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
