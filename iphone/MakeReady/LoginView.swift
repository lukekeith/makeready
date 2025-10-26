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
            // Background
            Color.brandPrimary
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo and Welcome Text
                VStack(spacing: 0) {
                    // Logo
                    Image("MRLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)

                    // Welcome Text
                    Text("Welcome to MakeReady")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }

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

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .padding(.horizontal, 64)
                }

                Spacer()
            }
            .padding(.horizontal, 64)
            .padding(.vertical, 32)
        }
    }

    private func handleGoogleSignIn() {
        print("👆 Google Sign In button tapped")
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authManager.signInWithGoogle()
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
}

// MARK: - Color Extensions
extension Color {
    static let brandPrimary = Color(hex: "#6c47ff")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    LoginView()
}
