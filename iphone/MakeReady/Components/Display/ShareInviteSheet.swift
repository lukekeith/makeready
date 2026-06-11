//
//  ShareInviteSheet.swift
//  MakeReady
//
//  A modal sheet for sharing team invites via QR code.
//  Includes QR code display, copy link button, and native share sheet.
//

import SwiftUI

struct ShareInviteSheet: View {
    let inviteCode: String
    let overlayManager: OverlayManager
    @Environment(AuthManager.self) var authManager

    @State private var qrCodeImage: UIImage?
    @State private var showCopiedFeedback = false

    private var inviteURL: String {
        "https://www.makeready.org/join/\(inviteCode)"
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page Title
                PageTitle.iconLink(
                    leftIcon: "xmark",
                    rightLink: "Done",
                    onLeftIconTap: { overlayManager.dismiss(id: OverlayID.shareInvite) },
                    onRightLinkTap: { overlayManager.dismiss(id: OverlayID.shareInvite) }
                )

                // Content
                VStack(spacing: 0) {
                    Spacer()

                    // QR Code - Centered
                    InviteQRCodeView(
                        inviteCode: inviteCode,
                        size: 320,
                        includeLogo: true
                    )
                    .onChange(of: inviteCode) {
                        generateQRImage()
                    }
                    .task {
                        generateQRImage()
                    }

                    Spacer()

                    // Action Buttons - Bottom
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
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(hex: "#6c47ff"))
                                .cornerRadius(12)
                            }
                        }

                        // Copy Link Button
                        Button(action: copyInviteLink) {
                            HStack {
                                Image(systemName: showCopiedFeedback ? "checkmark" : "link")
                                Text(showCopiedFeedback ? "Copied!" : "Copy Invite Link")
                            }
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color(hex: "#6c47ff"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
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

    private func generateQRImage() {
        Task {
            do {
                // Build full invite URL to encode in QR code
                let inviteURL = "https://www.makeready.org/join/\(inviteCode)"
                let image = try await InviteActions().generateQRCode(
                    data: inviteURL,
                    color: "#6c47ff",
                    backgroundColor: "#ffffff",
                    size: 800, // High-res for sharing
                    errorCorrectionLevel: "M",
                    includeLogo: false
                )
                await MainActor.run {
                    self.qrCodeImage = image
                }
            } catch {
                print("Error generating QR code: \(error)")
            }
        }
    }
}

#Preview {
    ShareInviteSheet(
        inviteCode: "PREVIEW123",
        overlayManager: OverlayManager()
    )
        .environment(AuthManager())
}
