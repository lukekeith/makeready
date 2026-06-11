//
//  EditYouTubeActivityPage.swift
//  MakeReady
//
//  Form page for editing YOUTUBE activity fields:
//  title, youtubeUrl, and segment range (start/end via range slider).
//

import SwiftUI

struct EditYouTubeActivityPage: View {
    let activity: StudyActivity
    let programId: String?
    let onCancel: () -> Void
    let onSave: (String, String?, Int?, Int?) -> Void

    @Environment(AuthManager.self) var authManager

    private var canEdit: Bool {
        guard let programId else { return false }
        return AppState.shared.programs[programId]?.isEditable(by: authManager.currentUser?.id) ?? false
    }

    @State private var title: String = ""
    @State private var youtubeUrl: String = ""
    @State private var isFetchingMetadata = false
    @State private var isSaving = false
    @State private var metadataTitle: String? = nil

    @State private var originalTitle: String = ""
    @State private var originalYoutubeUrl: String = ""

    // Preview state
    @State private var showPreviewModal = false

    private var hasChanges: Bool {
        title != originalTitle ||
        youtubeUrl != originalYoutubeUrl
    }

    private var youtubeVideoId: String? {
        let patterns = [
            "(?:v=)([a-zA-Z0-9_-]{11})",
            "(?:youtu\\.be/)([a-zA-Z0-9_-]{11})",
            "(?:embed/)([a-zA-Z0-9_-]{11})",
            "(?:shorts/)([a-zA-Z0-9_-]{11})"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: youtubeUrl, range: NSRange(youtubeUrl.startIndex..., in: youtubeUrl)),
               let range = Range(match.range(at: 1), in: youtubeUrl) {
                return String(youtubeUrl[range])
            }
        }
        return nil
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if canEdit {
                    PageTitle.linkTitleLink(
                        title: "YouTube Video",
                        leftLink: "Cancel",
                        rightLink: isSaving ? "Saving..." : (hasChanges ? "Save" : "Done"),
                        rightLinkColor: isSaving ? .white.opacity(0.3) : nil,
                        onLeftLinkTap: { onCancel() },
                        onRightLinkTap: {
                            guard !isSaving else { return }
                            if hasChanges {
                                save()
                            } else {
                                onCancel()
                            }
                        }
                    )
                } else {
                    PageTitle.iconTitle(
                        title: "YouTube Video",
                        icon: "chevron.left",
                        onIconTap: { onCancel() }
                    )
                }

                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Title
                        FieldGroup {
                            TextInput(
                                floatingLabel: "Activity title",
                                autocorrect: true,
                                text: $title
                            )
                        }
                        .padding(.horizontal, 16)
                        .disabled(!canEdit)

                        // 2. YouTube URL
                        FieldGroup {
                            TextInput(
                                floatingLabel: "YouTube URL",
                                autocorrect: false,
                                text: $youtubeUrl
                            )
                        }
                        .padding(.horizontal, 16)
                        .disabled(!canEdit)
                        .onChange(of: youtubeUrl) { _, newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty && youtubeVideoId != nil {
                                fetchMetadata(url: trimmed)
                            }
                        }

                        // 3. Video preview (shows after URL entered)
                        if let videoId = youtubeVideoId {
                            YouTubePreview(videoId: videoId)
                                .padding(.horizontal, 16)

                            if isFetchingMetadata {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading video info...")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        previewButton
                    }
                    
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .fullScreenCover(isPresented: $showPreviewModal) {
            LessonPreviewModal(url: LessonPreviewModal.lessonURL(forActivityId: activity.id), isPresented: $showPreviewModal)
        }
        .onAppear {
            title = activity.title ?? ""
            youtubeUrl = activity.youtubeUrl ?? ""

            originalTitle = title
            originalYoutubeUrl = youtubeUrl

            // Fetch metadata to auto-fill title if empty
            if youtubeVideoId != nil {
                fetchMetadata(url: youtubeUrl)
            }
        }
    }

    @ViewBuilder
    private var previewButton: some View {
        if programId != nil {
            BoxButton(
                action: { openPreview() },
                label: "Preview",
                icon: "eye",
                iconPosition: .right,
                variant: .secondary,
                style: .solid,
                size: .lg,
                fullWidth: true,
                iconOpacity: 0.5
            )
            .padding(.horizontal, 16)
        }
    }

    private func fetchMetadata(url: String) {
        isFetchingMetadata = true
        Task {
            do {
                let fetchedTitle = try await ProgramActions().fetchYouTubeMetadataTitle(url: url)
                await MainActor.run {
                    isFetchingMetadata = false
                    metadataTitle = fetchedTitle
                    // Auto-fill title if empty
                    if title.isEmpty, let fetchedTitle, !fetchedTitle.isEmpty {
                        title = fetchedTitle
                    }
                }
            } catch {
                await MainActor.run { isFetchingMetadata = false }
                NSLog("⚠️ Failed to fetch YouTube metadata: \(error)")
            }
        }
    }

    private func save() {
        guard !youtubeUrl.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSaving = true

        let finalTitle = title.trimmingCharacters(in: .whitespaces)
        let finalUrl = youtubeUrl.trimmingCharacters(in: .whitespaces)

        Task {
            do {
                _ = try await ProgramActions().updateActivityYouTube(
                    activityId: activity.id,
                    title: finalTitle.isEmpty ? (metadataTitle ?? "YouTube") : finalTitle,
                    youtubeUrl: finalUrl
                )
                await MainActor.run {
                    isSaving = false
                    originalTitle = title
                    originalYoutubeUrl = youtubeUrl
                }
            } catch {
                NSLog("❌ Failed to save YouTube activity: \(error)")
                await MainActor.run { isSaving = false }
            }
        }
    }

    // MARK: - Preview

    private func openPreview() {
        showPreviewModal = true
    }
}

// MARK: - YouTube Metadata Response

// MARK: - YouTube Preview

private struct YouTubePreview: View {
    let videoId: String

    var body: some View {
        Button {
            openYouTube()
        } label: {
            ZStack {
                AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    case .empty, .failure:
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .aspectRatio(16/9, contentMode: .fill)
                    @unknown default:
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .aspectRatio(16/9, contentMode: .fill)
                    }
                }

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(radius: 4)
            }
        }
        .buttonStyle(.plain)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func openYouTube() {
        // Try YouTube app first, fall back to Safari
        let appURL = URL(string: "youtube://www.youtube.com/watch?v=\(videoId)")
        let webURL = URL(string: "https://www.youtube.com/watch?v=\(videoId)")

        if let appURL, UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let webURL {
            UIApplication.shared.open(webURL)
        }
    }
}
