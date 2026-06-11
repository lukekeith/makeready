//
//  StudyInvitePage.swift
//  MakeReady
//
//  Invite page for sharing study/lesson invite code and QR code
//

import SwiftUI

// MARK: - Response Model

struct LessonInviteResponse: Codable {
    let success: Bool
    let invite: LessonInviteData?
    let error: String?
}

struct LessonInviteData: Codable {
    let lessonScheduleId: String
    let code: String
    let inviteUrl: String
    let qrCode: String  // Base64 data URL
    let dayNumber: Int?  // At root level in server response
    let scheduledDate: String?
    let passageReference: String?
    let studyProgram: LessonInviteProgram?  // Server sends "studyProgram"
    let group: LessonInviteGroup?
}

struct LessonInviteProgram: Codable {
    let id: String
    let name: String
    let days: Int
    let coverImageUrl: String?
}

struct LessonInviteGroup: Codable {
    let id: String
    let name: String
    let code: String
    let coverImageUrl: String?
}

// MARK: - View

struct StudyInvitePage: View {
    let scheduleId: String
    let dayNumber: Int  // Fallback if API fails
    let studyName: String  // Fallback if API fails
    let onDismiss: () -> Void
    var previewData: LessonInviteData? = nil  // For previews only

    @State private var inviteData: LessonInviteData?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showCopiedToast = false
    @State private var qrCodeImage: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            PageTitle.iconTitle(
                title: "Study Invite",
                icon: "xmark",
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
        .background(Color.appBackground)
        .overlay(copiedToast)
        .task {
            // Skip API call if preview data provided
            if let preview = previewData {
                inviteData = preview
                isLoading = false
                return
            }
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
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))

            Text("Failed to load invite")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Text(message)
                .font(.system(size: 15))
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

    private func mainContent(data: LessonInviteData) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Code section
                codeSection(data: data)

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

    // MARK: - Code Section

    private func codeSection(data: LessonInviteData) -> some View {
        // Extract the code entry URL from inviteUrl (e.g., "https://app.makeready.org/join/study/abc" -> "app.makeready.org/join/study")
        let codeEntryInfo = extractCodeEntryUrl(from: data.inviteUrl)

        return VStack(alignment: .leading, spacing: 12) {
            // Code box with purple border
            VStack(spacing: 16) {
                // Code display with copy button
                HStack {
                    // Code text
                    Text(data.code)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .tracking(2)

                    Spacer()

                    // Copy button
                    Button {
                        copyToClipboard(data.code)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "#6c47ff"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(Color(hex: "#6c47ff").opacity(0.1))
                .cornerRadius(8)

                // Instructions
                HStack(spacing: 4) {
                    Text("Use this code at")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))

                    Button {
                        openJoinPage(url: codeEntryInfo.fullUrl)
                    } label: {
                        Text(codeEntryInfo.displayUrl)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "#6c47ff"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#6c47ff").opacity(0.2), lineWidth: 2)
            )
        }
    }

    /// Extracts the code entry URL from the full invite URL
    /// e.g., "https://app.makeready.org/join/study/abc123" -> (displayUrl: "app.makeready.org/join/study", fullUrl: "https://app.makeready.org/join/study")
    private func extractCodeEntryUrl(from inviteUrl: String) -> (displayUrl: String, fullUrl: String) {
        guard let url = URL(string: inviteUrl),
              let host = url.host else {
            // Fallback if URL parsing fails
            return (displayUrl: "makeready.org", fullUrl: "https://makeready.org")
        }

        // Get path components and remove the last one (the schedule ID)
        var pathComponents = url.pathComponents.filter { $0 != "/" }
        if !pathComponents.isEmpty {
            pathComponents.removeLast()  // Remove the schedule ID
        }

        let basePath = pathComponents.joined(separator: "/")
        let displayUrl = basePath.isEmpty ? host : "\(host)/\(basePath)"
        let fullUrl = basePath.isEmpty ? "https://\(host)" : "https://\(host)/\(basePath)"

        return (displayUrl: displayUrl, fullUrl: fullUrl)
    }

    // MARK: - QR Code Section

    private func qrCodeSection(data: LessonInviteData) -> some View {
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
            Text("Scan to join Day \(data.dayNumber ?? 1) of \(data.studyProgram?.name ?? "Study")")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Action Buttons Section

    private func actionButtonsSection(data: LessonInviteData) -> some View {
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
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#6c47ff"))
                    .cornerRadius(8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 32)
            }
        }
        .animation(Motion.standardBrisk, value: showCopiedToast)
    }

    // MARK: - Data Loading

    private func loadInviteData() async {
        isLoading = true
        error = nil

        do {
            let data = try await fetchInviteData()
            await MainActor.run {
                self.inviteData = data
                self.isLoading = false
                // Decode QR code image from base64
                self.qrCodeImage = decodeQRCodeImage(from: data.qrCode)
            }
        } catch let err {
            await MainActor.run {
                self.error = err.localizedDescription
                self.isLoading = false
            }
            NSLog("Failed to load study invite data: \(err)")
        }
    }

    private func fetchInviteData() async throws -> LessonInviteData {
        try await EnrollmentActions().loadLessonInvite(scheduleId: scheduleId)
    }

    private func decodeQRCodeImage(from dataURL: String) -> UIImage? {
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

    private func openJoinPage(url urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func shareInvite(data: LessonInviteData) {
        let activityVC = UIActivityViewController(
            activityItems: ["Join Day \(data.dayNumber ?? 1) of \(data.studyProgram?.name ?? "Study") on MakeReady: \(data.inviteUrl)"],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func inviteFriends(data: LessonInviteData) {
        let activityVC = UIActivityViewController(
            activityItems: ["Join \(data.studyProgram?.name ?? "Study") Day \(data.dayNumber ?? 1) on MakeReady!", data.inviteUrl],
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
    StudyInvitePagePreview()
}

/// Static preview that shows the UI without API calls
private struct StudyInvitePagePreview: View {
    @State private var showCopiedToast = false

    private let mockData = LessonInviteData(
        lessonScheduleId: "preview-schedule",
        code: "S7K2M9",
        inviteUrl: "https://app.makeready.org/join/study/preview-schedule",
        qrCode: "",
        dayNumber: 5,
        scheduledDate: "2025-01-05T00:00:00.000Z",
        passageReference: "Romans 8:28-30",
        studyProgram: LessonInviteProgram(id: "p1", name: "Foundation Study", days: 30, coverImageUrl: nil),
        group: LessonInviteGroup(id: "g1", name: "Preview Group", code: "ABC123", coverImageUrl: nil)
    )

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                PageTitle.iconTitle(
                    title: "Study Invite",
                    icon: "xmark",
                    onIconTap: { print("Dismissed") }
                )

                ScrollView {
                    VStack(spacing: 24) {
                        // Code section
                        codeSection

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

    private var codeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 16) {
                HStack {
                    Text(mockData.code)
                        .font(.system(size: 24, weight: .bold))
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
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "#6c47ff"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(Color(hex: "#6c47ff").opacity(0.1))
                .cornerRadius(8)

                HStack(spacing: 4) {
                    Text("Use this code at")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))

                    // Extract display URL from mockData.inviteUrl
                    Text(displayUrlFromInviteUrl(mockData.inviteUrl))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "#6c47ff"))
                }
            }
            .padding(16)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#6c47ff").opacity(0.2), lineWidth: 2)
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
                    .font(.system(size: 180))
                    .foregroundColor(Color(hex: "#6c47ff"))
            }

            Text("Scan to join Day \(mockData.dayNumber ?? 1) of \(mockData.studyProgram?.name ?? "Study")")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
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
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#6c47ff"))
                    .cornerRadius(8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 32)
            }
        }
        .animation(Motion.standardBrisk, value: showCopiedToast)
    }

    /// Helper to extract display URL from invite URL for preview
    private func displayUrlFromInviteUrl(_ inviteUrl: String) -> String {
        guard let url = URL(string: inviteUrl),
              let host = url.host else {
            return "makeready.org"
        }

        var pathComponents = url.pathComponents.filter { $0 != "/" }
        if !pathComponents.isEmpty {
            pathComponents.removeLast()
        }

        let basePath = pathComponents.joined(separator: "/")
        return basePath.isEmpty ? host : "\(host)/\(basePath)"
    }
}
