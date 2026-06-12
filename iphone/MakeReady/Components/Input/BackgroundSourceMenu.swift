//
//  BackgroundSourceMenu.swift
//  MakeReady
//
//  Bottom-sheet menu offering the three image sources for a read-block
//  background: existing media library, phone photos, or fresh camera capture.
//  Presented via OverlayManager.presentMenu from EditBlockBackgroundPage.
//

import SwiftUI

struct BackgroundSourceMenu: View {
    let onPickFromLibrary: () -> Void
    let onPickFromPhotos:  () -> Void
    let onTakePhoto:       () -> Void

    @Environment(\.dismissOverlay) private var dismissOverlay

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                LessonActionMenuItem(
                    icon: "photo.on.rectangle.angled",
                    title: "Choose from Media Library",
                    style: .normal
                ) {
                    dismissOverlay?()
                    onPickFromLibrary()
                }

                LessonActionMenuItem(
                    icon: "photo.fill",
                    title: "Choose from Photos",
                    style: .normal
                ) {
                    dismissOverlay?()
                    onPickFromPhotos()
                }

                LessonActionMenuItem(
                    icon: "camera.fill",
                    title: "Take Photo",
                    style: .normal
                ) {
                    dismissOverlay?()
                    onTakePhoto()
                }
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Button(action: { dismissOverlay?() }) {
                Image(systemName: "xmark")
                    .font(Typography.s20Medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            }
            .buttonStyle(.plain)
        }
    }
}
