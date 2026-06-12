//
//  VideoSourceBar.swift
//  MakeReady
//
//  Sticky bar showing current video source with dropdown and MR logo
//

import SwiftUI

// MARK: - Video Source Enum

enum VideoSource: String, CaseIterable {
    case videos = "Videos"
    case favorites = "Favorites"
    case makeReady = "MakeReady"
    case allAlbums = "All albums"

    var icon: String {
        switch self {
        case .videos:
            return "play.rectangle"
        case .favorites:
            return "heart"
        case .makeReady:
            return "mr.logo" // Custom asset
        case .allAlbums:
            return "square.grid.2x2"
        }
    }

    var systemIcon: String? {
        switch self {
        case .videos:
            return "play.rectangle"
        case .favorites:
            return "heart"
        case .makeReady:
            return nil // Uses custom image
        case .allAlbums:
            return "square.grid.2x2"
        }
    }
}

// MARK: - Video Source Bar

struct VideoSourceBar: View {
    @Binding var currentSource: VideoSource
    var onSourceTap: () -> Void
    var onMakeReadyTap: () -> Void

    var body: some View {
        HStack {
            // Source dropdown button
            Button(action: onSourceTap) {
                HStack(spacing: 4) {
                    Text(currentSource.rawValue)
                        .font(Typography.s17Bold)
                        .foregroundColor(.white)

                    Image(systemName: "chevron.down")
                        .font(Typography.s14Semibold)
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            // MakeReady logo button
            Button(action: onMakeReadyTap) {
                Image("MRLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack {
            VideoSourceBar(
                currentSource: .constant(.videos),
                onSourceTap: { print("Source tapped") },
                onMakeReadyTap: { print("MR tapped") }
            )

            Spacer()
        }
    }
}
