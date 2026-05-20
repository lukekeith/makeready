//
//  CardActivityType.swift
//  MakeReady
//
//  Activity type card with two display modes:
//  - .list: compact row with icon/image, title, optional description (matches CardLessonActivity .small)
//  - .grid: square card with full-bleed image and centered bottom label (for 3-column grids)
//

import SwiftUI

// MARK: - Mode

enum CardActivityTypeMode {
    case list
    case grid
}

// MARK: - Image Style

enum CardActivityTypeImage {
    case icon(systemName: String, backgroundColor: Color)
    case asset(name: String, backgroundColor: Color)
    case photo(url: String)
}

// MARK: - View

struct CardActivityType: View {
    let title: String
    let description: String?
    let image: CardActivityTypeImage
    let mode: CardActivityTypeMode
    let available: Bool
    let labelColor: Color
    let iconColor: Color
    let onTap: () -> Void

    init(
        title: String,
        description: String? = nil,
        image: CardActivityTypeImage,
        mode: CardActivityTypeMode = .list,
        available: Bool = true,
        labelColor: Color = .white,
        iconColor: Color = .white,
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.description = description
        self.image = image
        self.mode = mode
        self.available = available
        self.labelColor = labelColor
        self.iconColor = iconColor
        self.onTap = onTap
    }

    var body: some View {
        Button {
            if available { onTap() }
        } label: {
            switch mode {
            case .list:
                listLayout
            case .grid:
                gridLayout
            }
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .opacity(available ? 1 : 0.35)
    }

    // MARK: - List Layout

    private var listLayout: some View {
        HStack(spacing: 12) {
            imageView(width: 40, height: 40, cornerRadius: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let description = description {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.cardBackground)
        .cornerRadius(4)
    }

    // MARK: - Grid Layout

    private var gridLayout: some View {
        GeometryReader { geo in
            let isCompact = geo.size.width < 120
            ZStack(alignment: .bottom) {
                // Full-bleed image
                gridImageView(size: geo.size.width)

                // Bottom label
                Text(title)
                    .font(.system(size: isCompact ? 11 : 14, weight: .bold))
                    .foregroundColor(labelColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, isCompact ? 8 : 16)
            }
            .frame(width: geo.size.width, height: geo.size.width)
            .cornerRadius(isCompact ? 6 : 8)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Image Views

    @ViewBuilder
    private func imageView(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        switch image {
        case .icon(let systemName, let backgroundColor):
            backgroundColor
                .overlay(
                    Image(systemName: systemName)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                )
                .frame(width: width, height: height)
                .cornerRadius(cornerRadius)

        case .asset(let name, let backgroundColor):
            backgroundColor
                .overlay(
                    Image(name)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                )
                .frame(width: width, height: height)
                .cornerRadius(cornerRadius)

        case .photo(let url):
            CachedCardImage(
                url: url,
                width: width,
                height: height,
                cornerRadius: cornerRadius,
                fallback: {
                    Color.iconContainerBackground
                        .frame(width: width, height: height)
                        .cornerRadius(cornerRadius)
                }
            )
        }
    }

    @ViewBuilder
    private func gridImageView(size: CGFloat) -> some View {
        switch image {
        case .icon(let systemName, let backgroundColor):
            backgroundColor
                .overlay(
                    Image(systemName: systemName)
                        .font(.system(size: 32))
                        .foregroundColor(iconColor)
                )
                .frame(width: size, height: size)

        case .asset(let name, let backgroundColor):
            backgroundColor
                .overlay(
                    Image(name)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(iconColor)
                        .frame(width: 32, height: 32)
                )
                .frame(width: size, height: size)

        case .photo(let url):
            CachedCardImage(
                url: url,
                width: size,
                height: size,
                cornerRadius: 0,
                fallback: {
                    Color.iconContainerBackground
                        .frame(width: size, height: size)
                }
            )
        }
    }
}

// MARK: - Previews

#Preview("List Mode") {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        VStack(spacing: 8) {
            CardActivityType(
                title: "Read",
                description: "Add a reading section with rich text content.",
                image: .icon(systemName: "book.fill", backgroundColor: Color(hex: "#6c47ff")),
                mode: .list,
                onTap: {}
            )

            CardActivityType(
                title: "Write",
                description: "Add a prompt for members to write a response.",
                image: .icon(systemName: "pencil.line", backgroundColor: Color(hex: "#6c47ff")),
                mode: .list,
                onTap: {}
            )

            CardActivityType(
                title: "Video",
                description: "Add a video message from your library.",
                image: .icon(systemName: "play.fill", backgroundColor: Color(hex: "#6c47ff")),
                mode: .list,
                onTap: {}
            )

            CardActivityType(
                title: "YouTube",
                description: "Add a YouTube video for members to watch.",
                image: .icon(systemName: "play.rectangle.fill", backgroundColor: Color(hex: "#6c47ff")),
                mode: .list,
                onTap: {}
            )

            // Unavailable
            CardActivityType(
                title: "SOAP",
                description: "Scripture, Observation, Application, Prayer.",
                image: .icon(systemName: "book.fill", backgroundColor: Color(hex: "#6c47ff")),
                mode: .list,
                available: false,
                onTap: {}
            )
        }
        .padding(16)
    }
}

#Preview("Grid Mode") {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            CardActivityType(
                title: "Read",
                image: .icon(systemName: "book.fill", backgroundColor: Color(hex: "#6c47ff")),
                mode: .grid,
                onTap: {}
            )

            CardActivityType(
                title: "Write",
                image: .icon(systemName: "pencil.line", backgroundColor: Color(hex: "#3b82f6")),
                mode: .grid,
                onTap: {}
            )

            CardActivityType(
                title: "Video",
                image: .icon(systemName: "play.fill", backgroundColor: Color(hex: "#ef4444")),
                mode: .grid,
                onTap: {}
            )

            CardActivityType(
                title: "YouTube",
                image: .icon(systemName: "play.rectangle.fill", backgroundColor: Color(hex: "#dc2626")),
                mode: .grid,
                onTap: {}
            )

            CardActivityType(
                title: "SOAP",
                image: .photo(url: "https://picsum.photos/200/200"),
                mode: .grid,
                onTap: {}
            )

            CardActivityType(
                title: "Unavailable",
                image: .icon(systemName: "lock.fill", backgroundColor: Color.gray),
                mode: .grid,
                available: false,
                onTap: {}
            )
        }
        .padding(16)
    }
}

#Preview("Grid Mode 2") {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
            CardActivityType(
                title: "Read",
                image: .icon(systemName: "book.fill", backgroundColor: Color(hex: "#6c47ff")),
                mode: .grid,
                onTap: {}
            )

            CardActivityType(
                title: "Write",
                image: .icon(systemName: "pencil.line", backgroundColor: Color(hex: "#3b82f6")),
                mode: .grid,
                onTap: {}
            )

            CardActivityType(
                title: "Video",
                image: .icon(systemName: "play.fill", backgroundColor: Color(hex: "#ef4444")),
                mode: .grid,
                onTap: {}
            )

            CardActivityType(
                title: "YouTube",
                image: .icon(systemName: "play.rectangle.fill", backgroundColor: Color(hex: "#dc2626")),
                mode: .grid,
                onTap: {}
            )
        }
        .padding(16)
    }
}

#Preview("Grid Mode 4") {
    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
            CardActivityType(
                title: "Read",
                image: .icon(systemName: "book.fill", backgroundColor: Color(hex: "#6c47ff")),
                mode: .grid,
                onTap: {}
            )
            CardActivityType(
                title: "Write",
                image: .icon(systemName: "pencil.line", backgroundColor: Color(hex: "#3b82f6")),
                mode: .grid,
                onTap: {}
            )
            CardActivityType(
                title: "Video",
                image: .icon(systemName: "play.fill", backgroundColor: Color(hex: "#ef4444")),
                mode: .grid,
                onTap: {}
            )
            CardActivityType(
                title: "YouTube",
                image: .icon(systemName: "play.rectangle.fill", backgroundColor: Color(hex: "#dc2626")),
                mode: .grid,
                onTap: {}
            )
            CardActivityType(
                title: "Prayer",
                image: .icon(systemName: "hands.sparkles.fill", backgroundColor: Color(hex: "#8b5cf6")),
                mode: .grid,
                onTap: {}
            )
            CardActivityType(
                title: "Discuss",
                image: .icon(systemName: "bubble.left.and.bubble.right.fill", backgroundColor: Color(hex: "#06b6d4")),
                mode: .grid,
                onTap: {}
            )
            CardActivityType(
                title: "Quiz",
                image: .icon(systemName: "questionmark.circle.fill", backgroundColor: Color(hex: "#f59e0b")),
                mode: .grid,
                onTap: {}
            )
            CardActivityType(
                title: "Listen",
                image: .icon(systemName: "headphones", backgroundColor: Color(hex: "#10b981")),
                mode: .grid,
                onTap: {}
            )
            CardActivityType(
                title: "Journal",
                image: .icon(systemName: "note.text", backgroundColor: Color(hex: "#ec4899")),
                mode: .grid,
                onTap: {}
            )
            CardActivityType(
                title: "Memorize",
                image: .icon(systemName: "brain.head.profile.fill", backgroundColor: Color(hex: "#14b8a6")),
                mode: .grid,
                onTap: {}
            )
            CardActivityType(
                title: "Worship",
                image: .icon(systemName: "music.note", backgroundColor: Color(hex: "#a855f7")),
                mode: .grid,
                onTap: {}
            )
            CardActivityType(
                title: "Serve",
                image: .icon(systemName: "heart.fill", backgroundColor: Color(hex: "#f43f5e")),
                mode: .grid,
                onTap: {}
            )
            CardActivityType(
                title: "Meditate",
                image: .icon(systemName: "leaf.fill", backgroundColor: Color(hex: "#22c55e")),
                mode: .grid,
                onTap: {}
            )
            CardActivityType(
                title: "Share",
                image: .icon(systemName: "megaphone.fill", backgroundColor: Color(hex: "#f97316")),
                mode: .grid,
                onTap: {}
            )
            CardActivityType(
                title: "Checklist",
                image: .icon(systemName: "checklist", backgroundColor: Color(hex: "#0ea5e9")),
                mode: .grid,
                onTap: {}
            )
            CardActivityType(
                title: "Photo",
                image: .icon(systemName: "camera.fill", backgroundColor: Color(hex: "#64748b")),
                mode: .grid,
                onTap: {}
            )
        }
        .padding(12)
    }
    .background(Color.appBackground)
}
