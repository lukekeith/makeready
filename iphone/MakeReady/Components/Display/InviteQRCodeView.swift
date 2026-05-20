//
//  InviteQRCodeView.swift
//  MakeReady
//
//  A reusable SwiftUI component for displaying QR codes.
//  Generates QR code asynchronously from server API with loading state.
//

import SwiftUI

struct InviteQRCodeView: View {
    let inviteCode: String
    let size: CGFloat
    let includeLogo: Bool

    @State private var qrCodeImage: UIImage?
    @State private var isGenerating = true
    @State private var error: Error?
    @EnvironmentObject var authManager: AuthManager

    init(
        inviteCode: String,
        size: CGFloat = 300,
        includeLogo: Bool = true
    ) {
        self.inviteCode = inviteCode
        self.size = size
        self.includeLogo = includeLogo
    }

    var body: some View {
        ZStack {
            if let image = qrCodeImage {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else if isGenerating {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(width: size, height: size)
            } else if error != nil {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.red.opacity(0.7))

                    Text("Failed to generate QR code")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(width: size, height: size)
            }
        }
        .task {
            await generateQRCode()
        }
    }

    private func generateQRCode() async {
        isGenerating = true
        error = nil

        do {
            // Generate QR code from server API
            // Build full invite URL to encode in QR code
            let inviteURL = "https://www.makeready.org/join/\(inviteCode)"

            // If no session cookie, use the test endpoint (useful for demos/debugging)
            let image: UIImage
            if !authManager.hasSessionCookie {
                print("⚠️ No session cookie - using test QR endpoint")
                image = try await generateQRCodeTest(
                    data: inviteURL,
                    size: Int(size * 2),
                    includeLogo: includeLogo
                )
            } else {
                image = try await authManager.generateQRCode(
                    data: inviteURL,
                    color: "#6c47ff",
                    backgroundColor: "#ffffff",
                    size: Int(size * 2), // 2x for retina
                    errorCorrectionLevel: "M",
                    includeLogo: includeLogo
                )
            }

            await MainActor.run {
                self.qrCodeImage = image
                self.isGenerating = false
            }
        } catch let err {
            await MainActor.run {
                self.error = err
                self.isGenerating = false
                print("❌ QR generation failed: \(err.localizedDescription)")
            }
        }
    }

    /// Generate QR code using test endpoint (no auth required)
    private func generateQRCodeTest(data: String, size: Int, includeLogo: Bool) async throws -> UIImage {
        guard let url = URL(string: "\(Configuration.baseURL)/api/qrcode/test") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "data": data,
            "size": size,
            "includeLogo": includeLogo
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        guard let image = UIImage(data: responseData) else {
            throw NSError(domain: "QRCode", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to decode QR code image"
            ])
        }

        print("✅ QR code generated via test endpoint")
        return image
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 32) {
            Text("Invite QR Code")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            InviteQRCodeView(
                inviteCode: "ABC123XYZ",
                size: 250
            )
            .environmentObject(AuthManager())

            Text("Scan to join team")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(32)
    }
}
