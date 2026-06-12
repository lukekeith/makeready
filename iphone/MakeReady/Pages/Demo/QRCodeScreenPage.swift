//
//  QRCodeScreenPage.swift
//  MakeReady
//
//  QR Code screen that fetches QR codes from the server API
//  with customizable styling and logo embedding.
//

import SwiftUI

struct QRCodeScreenPage: View {
    let inviteCode: String
    @Environment(AuthManager.self) var authManager
    @Environment(\.dismiss) var dismiss

    @State private var qrCodeImage: UIImage?
    @State private var isLoading = false
    @State private var error: String?
    @State private var showCopiedFeedback = false

    private var inviteURL: String {
        "\(Configuration.clientBaseURL)/join/group/\(inviteCode)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Share Team Invite")
                                .font(Typography.s24Bold)
                                .foregroundColor(.white)

                            Text("Scan QR code or share invite link")
                                .font(Typography.s14)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.top, 20)

                        // QR Code Display
                        VStack(spacing: 16) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                                    .frame(width: 280, height: 280)
                            } else if let error = error {
                                VStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(Typography.s48)
                                        .foregroundColor(.red.opacity(0.8))

                                    Text("Failed to generate QR code")
                                        .font(Typography.s16Semibold)
                                        .foregroundColor(.white)

                                    Text(error)
                                        .font(Typography.s14)
                                        .foregroundColor(.white.opacity(0.6))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 16)

                                    Button("Try Again") {
                                        Task {
                                            await loadQRCodeFromServer()
                                        }
                                    }
                                    .font(Typography.s15Semibold)
                                    .foregroundColor(Color.brandPrimary)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .frame(width: 280, height: 280)
                            } else if let image = qrCodeImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .interpolation(.none)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 280, height: 280)
                                    .cornerRadius(8)
                            } else {
                                Rectangle()
                                    .fill(Color.white.opacity(0.05))
                                    .frame(width: 280, height: 280)
                                    .cornerRadius(8)
                            }

                            // Invite Code Display
                            HStack(spacing: 12) {
                                Text("Code:")
                                    .font(Typography.s14)
                                    .foregroundColor(.white.opacity(0.5))

                                Text(inviteCode)
                                    .font(Typography.s16Bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)

                        // Action Buttons
                        VStack(spacing: 12) {
                            // Share Button
                            if let image = qrCodeImage {
                                ShareLink(
                                    item: Image(uiImage: image),
                                    preview: SharePreview(
                                        "MakeReady Team Invite",
                                        image: Image(uiImage: image)
                                    )
                                ) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Share QR Code")
                                    }
                                    .font(Typography.s17Bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.brandPrimary)
                                    .cornerRadius(12)
                                }
                            }

                            // Copy Link Button
                            Button(action: copyInviteLink) {
                                HStack {
                                    Image(systemName: showCopiedFeedback ? "checkmark" : "link")
                                    Text(showCopiedFeedback ? "Copied!" : "Copy Invite Link")
                                }
                                .font(Typography.s17Bold)
                                .foregroundColor(Color.brandPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(Typography.s16Semibold)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .task {
                await loadQRCodeFromServer()
            }
        }
    }

    // MARK: - Actions

    private func copyInviteLink() {
        UIPasteboard.general.string = inviteURL

        // Show feedback
        withAnimation {
            showCopiedFeedback = true
        }

        // Hide feedback after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedFeedback = false
            }
        }
    }

    private func loadQRCodeFromServer() async {
        isLoading = true
        error = nil

        do {
            print("🎨 Generating QR code from server for invite: \(inviteCode)")

            // Build full invite URL to encode in QR code
            let inviteURL = "https://www.makeready.org/join/\(inviteCode)"
            let image = try await InviteActions().generateQRCode(
                data: inviteURL,
                color: "#6c47ff",      // Brand purple
                backgroundColor: "#ffffff",
                size: 600,             // High resolution
                errorCorrectionLevel: "M",
                includeLogo: true      // Include MakeReady logo
            )

            await MainActor.run {
                self.qrCodeImage = image
                self.isLoading = false
                print("✅ QR code loaded successfully")
            }
        } catch {
            await MainActor.run {
                self.isLoading = false

                if let urlError = error as? URLError, urlError.code == .userAuthenticationRequired {
                    self.error = "Please sign in to generate QR codes"
                } else {
                    self.error = error.localizedDescription
                }

                print("❌ Failed to load QR code: \(error)")
            }
        }
    }
}

#Preview {
    QRCodeScreenPage(inviteCode: "PREVIEW123")
        .environment(AuthManager())
}
