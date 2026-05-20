//
//  UnenrollOptionsModal.swift
//  MakeReady
//
//  Full-screen modal that fetches enrollment status and presents context-aware
//  unenroll options based on whether members have submitted responses.
//

import SwiftUI

// MARK: - Types

enum UnenrollOption {
    case fullRemoval
    case cancelFuture
}

enum UnenrollModalPhase: Equatable {
    case loading
    case options
    case confirm
    case error(String)
}

// MARK: - UnenrollOptionsModal

struct UnenrollOptionsModal: View {
    let enrollmentId: String
    let programName: String
    let programImageUrl: String?
    let onConfirm: (UnenrollOption) -> Void
    let onDismiss: () -> Void

    @State private var phase: UnenrollModalPhase = .loading
    @State private var unenrollInfo: UnenrollInfo?
    @State private var selectedOption: UnenrollOption?

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            switch phase {
            case .loading:
                loadingContent
            case .options:
                optionsContent
            case .confirm:
                confirmContent
            case .error(let message):
                errorContent(message: message)
            }
        }
        .task {
            await fetchUnenrollInfo()
        }
    }

    // MARK: - Loading

    private var loadingContent: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .tint(.white)
            Text("Checking enrollment status...")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
        }
    }

    // MARK: - Options

    private var optionsContent: some View {
        VStack(spacing: 0) {
            PageTitle.iconTitle(
                title: "Unenroll",
                icon: "xmark",
                onIconTap: { onDismiss() }
            )

            ScrollView {
                VStack(spacing: 24) {
                    // Program header
                    programHeader

                    // Summary
                    if let info = unenrollInfo {
                        Text("\(info.totalLessons) scheduled lessons")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)

                        if info.canFullyUnenroll {
                            // No member data — can fully remove
                            infoBanner(
                                icon: "checkmark.circle.fill",
                                text: "No members have submitted responses yet",
                                color: Color(hex: "#57db5d")
                            )

                            optionCard(
                                icon: "trash",
                                title: "Remove Enrollment",
                                description: "All \(info.totalLessons) scheduled lessons will be removed. No member data will be lost.",
                                isDestructive: true
                            ) {
                                selectedOption = .fullRemoval
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    phase = .confirm
                                }
                            }
                        } else {
                            // Has member data — limited options
                            infoBanner(
                                icon: "exclamationmark.triangle.fill",
                                text: "\(info.lessonsWithData) of \(info.totalLessons) lessons have member responses",
                                color: Color(hex: "#ffaa00")
                            )

                            optionCard(
                                icon: "calendar.badge.minus",
                                title: "Cancel Future Lessons",
                                description: "Remove \(info.cleanLessons) upcoming lessons with no member data. \(info.lessonsWithData) lessons with responses will be preserved.",
                                isDestructive: false
                            ) {
                                selectedOption = .cancelFuture
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    phase = .confirm
                                }
                            }

                            // Disabled explanation for full removal
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 10) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white.opacity(0.2))
                                    Text("Remove Enrollment")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.2))
                                }
                                Text("Full removal is not available — \(info.lessonsWithData) lessons contain member data.")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.2))
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                        }
                    }

                    // Never mind button
                    Button(action: { onDismiss() }) {
                        Text("Never mind")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)

                    Spacer().frame(height: 40)
                }
                .padding(.top, 16)
            }
        }
    }

    // MARK: - Confirm

    private var confirmContent: some View {
        VStack(spacing: 0) {
            PageTitle.iconTitle(
                title: "Confirm",
                icon: "chevron.left",
                onIconTap: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        phase = .options
                    }
                }
            )

            Spacer()

            VStack(spacing: 24) {
                // Icon
                Image(systemName: selectedOption == .fullRemoval ? "trash.circle.fill" : "calendar.badge.minus")
                    .font(.system(size: 48))
                    .foregroundColor(selectedOption == .fullRemoval ? Color(hex: "#ff4444") : Color(hex: "#ffaa00"))

                // Title
                Text(selectedOption == .fullRemoval ? "Remove Enrollment" : "Cancel Future Lessons")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                // Description
                if let info = unenrollInfo {
                    Text(confirmDescription(info: info))
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                // Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        if let option = selectedOption {
                            onConfirm(option)
                        }
                    }) {
                        Text("Yes, proceed")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(selectedOption == .fullRemoval ? Color(hex: "#ff4444") : Color(hex: "#ffaa00"))
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            phase = .options
                        }
                    }) {
                        Text("Go back")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Error

    private func errorContent(message: String) -> some View {
        VStack(spacing: 0) {
            PageTitle.iconTitle(
                title: "Unenroll",
                icon: "xmark",
                onIconTap: { onDismiss() }
            )

            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.3))

                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)

                Button("Try Again") {
                    phase = .loading
                    Task { await fetchUnenrollInfo() }
                }
                .foregroundColor(Color(hex: "#6c47ff"))
            }
            .padding(32)

            Spacer()
        }
    }

    // MARK: - Subviews

    private var programHeader: some View {
        HStack(spacing: 14) {
                CachedAsyncImage(
                urlString: programImageUrl,
                size: 56,
                fallbackIcon: "book.fill"
            )
            .cornerRadius(10)

            Text(programName)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private func infoBanner(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(color.opacity(0.9))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal, 16)
    }

    private func optionCard(icon: String, title: String, description: String, isDestructive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isDestructive ? Color(hex: "#ff4444") : .white)
                    .frame(width: 36, height: 36)
                    .background(isDestructive ? Color(hex: "#ff4444").opacity(0.15) : Color.white.opacity(0.08))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isDestructive ? Color(hex: "#ff4444") : .white)
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .lineSpacing(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(16)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func confirmDescription(info: UnenrollInfo) -> String {
        if selectedOption == .fullRemoval {
            return "This will remove all \(info.totalLessons) scheduled lessons from \(programName). This action cannot be undone."
        } else {
            return "This will remove \(info.cleanLessons) upcoming lessons with no member data from \(programName). \(info.lessonsWithData) lessons with member responses will be preserved."
        }
    }

    private func fetchUnenrollInfo() async {
        do {
            let info = try await EnrollmentActions().getUnenrollInfo(id: enrollmentId)
            await MainActor.run {
                unenrollInfo = info
                withAnimation(.easeInOut(duration: 0.2)) {
                    phase = .options
                }
            }
        } catch {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    phase = .error(error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    UnenrollOptionsModal(
        enrollmentId: "preview-id",
        programName: "Ephesians Study",
        programImageUrl: nil,
        onConfirm: { option in print("Confirmed: \(option)") },
        onDismiss: { print("Dismissed") }
    )
}
