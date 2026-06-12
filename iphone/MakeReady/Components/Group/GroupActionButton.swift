//
//  GroupActionButton.swift
//  MakeReady
//
//  Pill-shaped action button for group home page (Video, Message, Meeting, Gallery)
//  Horizontal layout: label on left, purple icon on right
//

import SwiftUI

struct GroupActionButton: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .font(Typography.s15Medium)
                    .foregroundColor(.white)

                Image(systemName: icon)
                    .font(Typography.s14)
                    .foregroundColor(Color.brandPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Horizontally scrolling row of group action buttons
struct GroupActionButtonRow: View {
    let onVideoTap: () -> Void
    let onMessageTap: () -> Void
    let onMeetingTap: () -> Void
    let onGalleryTap: (() -> Void)?

    init(
        onVideoTap: @escaping () -> Void,
        onMessageTap: @escaping () -> Void,
        onMeetingTap: @escaping () -> Void,
        onGalleryTap: (() -> Void)? = nil
    ) {
        self.onVideoTap = onVideoTap
        self.onMessageTap = onMessageTap
        self.onMeetingTap = onMeetingTap
        self.onGalleryTap = onGalleryTap
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                GroupActionButton(
                    label: "Video",
                    icon: "video.fill",
                    action: onVideoTap
                )

                GroupActionButton(
                    label: "Message",
                    icon: "message.fill",
                    action: onMessageTap
                )

                GroupActionButton(
                    label: "Meeting",
                    icon: "person.2.fill",
                    action: onMeetingTap
                )

                if let onGalleryTap = onGalleryTap {
                    GroupActionButton(
                        label: "Gallery",
                        icon: "photo.fill",
                        action: onGalleryTap
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 20) {
            // Single button
            GroupActionButton(
                label: "Video",
                icon: "video.fill"
            ) {
                print("Video tapped")
            }

            // Full scrolling row
            GroupActionButtonRow(
                onVideoTap: { print("Video") },
                onMessageTap: { print("Message") },
                onMeetingTap: { print("Meeting") },
                onGalleryTap: { print("Gallery") }
            )

            Spacer()
        }
        .padding(.top, 40)
    }
}
