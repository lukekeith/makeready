//
//  LoginView.swift
//  MakeReady
//
//  Created by MakeReady Team
//

import SwiftUI

struct LoginView: View {
    @State private var navigateToHome = false

    var body: some View {
        NavigationStack {
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
                    NavigationLink(destination: HomePage()) {
                        HStack(spacing: 8) {
                            // Google Logo
                            Image("GoogleIcon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14)

                            Text("Continue with Google")
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

                    Spacer()
                }
                .padding(.horizontal, 64)
                .padding(.vertical, 32)
            }
            .navigationBarHidden(true)
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
