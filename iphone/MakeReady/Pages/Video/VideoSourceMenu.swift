//
//  VideoSourceMenu.swift
//  MakeReady
//
//  Popup menu for selecting video source
//

import SwiftUI

struct VideoSourceMenu: View {
    @Binding var isPresented: Bool
    @Binding var selectedSource: VideoSource
    var onAlbumsSelected: () -> Void
    var anchorY: CGFloat = 0  // Y position offset (used when not in overlay mode)

    var body: some View {
        // Menu popup
        VStack(spacing: 0) {
            ForEach(VideoSource.allCases, id: \.self) { source in
                menuItem(for: source)
            }
        }
        .frame(width: 220)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 13/255, green: 16/255, blue: 26/255).opacity(0.5))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Menu Item

    @ViewBuilder
    private func menuItem(for source: VideoSource) -> some View {
        Button {
            handleSelection(source)
        } label: {
            HStack(spacing: 12) {
                // Icon
                Group {
                    if source == .makeReady {
                        Image("MRLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                    } else if let systemIcon = source.systemIcon {
                        Image(systemName: systemIcon)
                            .font(Typography.s18)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                    }
                }

                // Label
                Text(source.rawValue)
                    .font(Typography.s17)
                    .foregroundColor(.white)

                Spacer()

                // Checkmark if selected
                if source == selectedSource {
                    Image(systemName: "checkmark")
                        .font(Typography.s16Semibold)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Selection Handling

    private func handleSelection(_ source: VideoSource) {
        switch source {
        case .videos:
            selectedSource = source
            isPresented = false

        case .favorites:
            // Placeholder - show coming soon
            showComingSoon()

        case .makeReady:
            // Placeholder - show coming soon
            showComingSoon()

        case .allAlbums:
            selectedSource = source
            isPresented = false
            onAlbumsSelected()
        }
    }

    private func showComingSoon() {
        // For now, just dismiss - later add toast/alert
        isPresented = false
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VideoSourceMenu(
            isPresented: .constant(true),
            selectedSource: .constant(.videos),
            onAlbumsSelected: { print("Albums selected") },
            anchorY: 500
        )
    }
}
