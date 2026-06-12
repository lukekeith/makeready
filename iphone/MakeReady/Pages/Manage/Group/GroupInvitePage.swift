//
//  GroupInvitePage.swift
//  MakeReady
//
//  Invite page for sharing group code and QR code
//

import SwiftUI

// MARK: - Response Model

struct GroupInviteResponse: Codable {
    let success: Bool
    let invite: GroupInviteData?
    let error: String?
}

struct GroupInviteData: Codable {
    let groupId: String
    let groupName: String
    let code: String
    let inviteUrl: String
    let qrCode: String  // Base64 data URL
}

// MARK: - View

struct GroupInvitePage: View {
    let groupId: String
    let onDismiss: () -> Void

    @State private var inviteData: GroupInviteData?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showCopiedToast = false
    @State private var qrCodeImage: UIImage?

    // Initialize from cache so the slide-in animates with content already
    // laid out — async content arriving mid-slide is inserted outside the
    // animation transaction and lands at its final position (see
    // SWIFTUI_TRANSITIONS.md § Pre-loading Content).
    init(groupId: String, onDismiss: @escaping () -> Void) {
        self.groupId = groupId
        self.onDismiss = onDismiss

        let cached = AppState.shared.groupInvitesByGroupId[groupId]
        _inviteData = State(initialValue: cached)
        _isLoading = State(initialValue: cached == nil)
        _qrCodeImage = State(initialValue: cached.flatMap { Self.decodeQRCodeImage(from: $0.qrCode) })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            PageTitle.iconTitle(
                title: "Group Invite",
                icon: "chevron.left",
                onIconTap: { onDismiss() }
            )

            if isLoading {
                loadingContent
            } else if let data = inviteData {
                mainContent(data: data)
            } else if let error = error {
                errorContent(message: error)
            }
        }
        .overlay(copiedToast)
        .task {
            await loadInviteData()
        }
    }

    // MARK: - Loading State

    private var loadingContent: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(.white)
            Spacer()
        }
    }

    // MARK: - Error State

    private func errorContent(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(Typography.s40)
                .foregroundColor(.white.opacity(0.3))

            Text("Failed to load invite")
                .font(Typography.s17Semibold)
                .foregroundColor(.white)

            Text(message)
                .font(Typography.s15)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            BoxButton(
                action: {
                    Task { await loadInviteData() }
                },
                label: "Try Again",
                variant: .secondary,
                size: .md
            )
            .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Main Content

    private func mainContent(data: GroupInviteData) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Group code section
                groupCodeSection(data: data)

                // QR Code section
                qrCodeSection(data: data)

                // Action buttons
                actionButtonsSection(data: data)

                Spacer()
                    .frame(height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
        }
    }

    // MARK: - Group Code Section

    private func groupCodeSection(data: GroupInviteData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Code box with purple border
            VStack(spacing: 16) {
                // Code display with copy button
                HStack {
                    // Code text
                    Text(data.code)
                        .font(Typography.s24Bold)
                        .foregroundColor(.white)
                        .tracking(2)

                    Spacer()

                    // Copy button
                    Button {
                        copyToClipboard(data.code)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(Typography.s18)
                            .foregroundColor(Color.brandPrimary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(Color.brandPrimary.opacity(0.1))
                .cornerRadius(8)

                // Instructions
                HStack(spacing: 4) {
                    Text("Use this code at")
                        .font(Typography.s13)
                        .foregroundColor(.white.opacity(0.5))

                    Button {
                        openJoinPage()
                    } label: {
                        Text("app.makeready.org/join/group")
                            .font(Typography.s13Medium)
                            .foregroundColor(Color.brandPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.brandPrimary.opacity(0.2), lineWidth: 2)
            )
        }
    }

    // MARK: - QR Code Section

    private func qrCodeSection(data: GroupInviteData) -> some View {
        VStack(spacing: 16) {
            // QR code with white background
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .frame(width: 264, height: 264)

                if let image = qrCodeImage {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 240, height: 240)
                } else {
                    ProgressView()
                        .tint(.gray)
                }
            }

            // Scan instruction
            Text("Scan to join \(data.groupName)")
                .font(Typography.s14)
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Action Buttons Section

    private func actionButtonsSection(data: GroupInviteData) -> some View {
        VStack(spacing: 12) {
            // Share Invite
            BoxButton(
                action: { shareInvite(data: data) },
                label: "Share Invite",
                icon: "square.and.arrow.up",
                iconPosition: .left,
                variant: .primary,
                size: .lg,
                fullWidth: true
            )

            // Copy Invite Link
            BoxButton(
                action: { copyToClipboard(data.inviteUrl) },
                label: "Copy Invite Link",
                icon: "link",
                iconPosition: .left,
                variant: .secondary,
                size: .lg,
                fullWidth: true
            )

            // Invite friends
            BoxButton(
                action: { inviteFriends(data: data) },
                label: "Invite friends",
                icon: "person.badge.plus",
                iconPosition: .left,
                variant: .secondary,
                size: .lg,
                fullWidth: true
            )
        }
    }

    // MARK: - Copied Toast

    private var copiedToast: some View {
        VStack {
            Spacer()
            if showCopiedToast {
                Text("Copied to clipboard")
                    .font(Typography.s14Medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.brandPrimary)
                    .cornerRadius(8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 32)
            }
        }
        .animation(Motion.standardBrisk, value: showCopiedToast)
    }

    // MARK: - Data Loading

    private func loadInviteData() async {
        // Only show the spinner when there's nothing cached to display —
        // flipping to the loading branch mid-slide swaps the content
        // subtree outside the animation transaction.
        if inviteData == nil {
            isLoading = true
        }
        error = nil

        do {
            let data = try await fetchInviteData()
            await MainActor.run {
                self.inviteData = data
                self.isLoading = false
                // Decode QR code image from base64
                self.qrCodeImage = Self.decodeQRCodeImage(from: data.qrCode)
            }
        } catch let err {
            await MainActor.run {
                // Keep showing cached content on a background refresh
                // failure; only surface the error screen when empty.
                if inviteData == nil {
                    self.error = err.localizedDescription
                }
                self.isLoading = false
            }
            NSLog("Failed to load invite data: \(err)")
        }
    }

    private func fetchInviteData() async throws -> GroupInviteData {
        try await GroupActions().loadGroupInvite(groupId: groupId)
    }

    private static func decodeQRCodeImage(from dataURL: String) -> UIImage? {
        // Remove data URL prefix: "data:image/png;base64,"
        let base64String = dataURL
            .replacingOccurrences(of: "data:image/png;base64,", with: "")
            .replacingOccurrences(of: "data:image/jpeg;base64,", with: "")

        guard let imageData = Data(base64Encoded: base64String) else {
            NSLog("Failed to decode base64 QR code")
            return nil
        }

        return UIImage(data: imageData)
    }

    // MARK: - Actions

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        showCopiedToast = true

        // Hide toast after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedToast = false
        }
    }

    private func openJoinPage() {
        if let url = URL(string: "\(Configuration.clientBaseURL)/join/group") {
            UIApplication.shared.open(url)
        }
    }

    private func shareInvite(data: GroupInviteData) {
        let activityVC = UIActivityViewController(
            activityItems: ["Join \(data.groupName) on MakeReady: \(data.inviteUrl)"],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func inviteFriends(data: GroupInviteData) {
        let activityVC = UIActivityViewController(
            activityItems: ["Join \(data.groupName) on MakeReady!", data.inviteUrl],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Preview

#Preview {
    GroupInvitePagePreview()
}

/// Static preview that shows the UI without API calls
private struct GroupInvitePagePreview: View {
    @State private var showCopiedToast = false

    private let mockData = GroupInviteData(
        groupId: "preview-group",
        groupName: "Young Professionals",
        code: "X7K2M9",
        inviteUrl: "https://app.makeready.org/join/X7K2M9",
        qrCode: ""
    )

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                PageTitle.iconTitle(
                    title: "Group Invite",
                    icon: "chevron.left",
                    onIconTap: { print("Dismissed") }
                )

                ScrollView {
                    VStack(spacing: 24) {
                        // Group code section
                        groupCodeSection

                        // QR Code section
                        qrCodeSection

                        // Action buttons
                        actionButtonsSection

                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                }
            }
            .overlay(copiedToast)
        }
    }

    private var groupCodeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 16) {
                HStack {
                    Text(mockData.code)
                        .font(Typography.s24Bold)
                        .foregroundColor(.white)
                        .tracking(2)

                    Spacer()

                    Button {
                        showCopiedToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCopiedToast = false
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(Typography.s18)
                            .foregroundColor(Color.brandPrimary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(Color.brandPrimary.opacity(0.1))
                .cornerRadius(8)

                HStack(spacing: 4) {
                    Text("Use this code at")
                        .font(Typography.s13)
                        .foregroundColor(.white.opacity(0.5))

                    Text("app.makeready.org/join/group")
                        .font(Typography.s13Medium)
                        .foregroundColor(Color.brandPrimary)
                }
            }
            .padding(16)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.brandPrimary.opacity(0.2), lineWidth: 2)
            )
        }
    }

    private var qrCodeSection: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .frame(width: 264, height: 264)

                // Placeholder QR code pattern for preview
                Image(systemName: "qrcode")
                    .font(Typography.s180)
                    .foregroundColor(Color.brandPrimary)
            }

            Text("Scan to join \(mockData.groupName)")
                .font(Typography.s14)
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            BoxButton(
                action: { print("Share Invite") },
                label: "Share Invite",
                icon: "square.and.arrow.up",
                iconPosition: .left,
                variant: .primary,
                size: .lg,
                fullWidth: true
            )

            BoxButton(
                action: {
                    showCopiedToast = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showCopiedToast = false
                    }
                },
                label: "Copy Invite Link",
                icon: "link",
                iconPosition: .left,
                variant: .secondary,
                size: .lg,
                fullWidth: true
            )

            BoxButton(
                action: { print("Invite friends") },
                label: "Invite friends",
                icon: "person.badge.plus",
                iconPosition: .left,
                variant: .secondary,
                size: .lg,
                fullWidth: true
            )
        }
    }

    private var copiedToast: some View {
        VStack {
            Spacer()
            if showCopiedToast {
                Text("Copied to clipboard")
                    .font(Typography.s14Medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.brandPrimary)
                    .cornerRadius(8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 32)
            }
        }
        .animation(Motion.standardBrisk, value: showCopiedToast)
    }
}
