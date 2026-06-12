//
//  CardVideo.swift
//  MakeReady
//
//  Video card component with Row and Mini layouts
//

import SwiftUI


struct CardVideo: View {
    let data: CardVideoData
    let showAnimatedBorder: Bool
    let randomizeBorderStart: Bool
    let compact: Bool
    let cornerRadius: CGFloat

    @State private var borderRotation: Double = 0
    @State private var hasStartedAnimation = false

    init(data: CardVideoData, showAnimatedBorder: Bool = false, randomizeBorderStart: Bool = true, compact: Bool = false, cornerRadius: CGFloat = 4) {
        self.data = data
        self.showAnimatedBorder = showAnimatedBorder
        self.randomizeBorderStart = randomizeBorderStart
        self.compact = compact
        self.cornerRadius = cornerRadius
    }

    private var imageHeight: CGFloat { compact ? 72 : 108 }
    private var cardHeight: CGFloat { compact ? 104 : 140 }

    var body: some View {
        Button {
            data.onTap?()
        } label: {
            HStack(spacing: 16) {
                // Left: Content
                VStack(alignment: .leading, spacing: 0) {
                    // Layout changes based on status
                    if data.status == .new {
                        // New variant: "VIDEO" (uppercase), then description
                        Text(data.title)
                            .font(Typography.s14Bold)
                            .foregroundColor(.white)

                        if let description = data.description {
                            Text(description)
                                .font(Typography.s16Bold)
                                .foregroundColor(Color.brandPrimary)
                                .lineLimit(2)
                                .padding(.top, 4)
                        }
                    } else {
                        // Standard variant: Description above title
                        if let description = data.description {
                            Text(description)
                                .font(Typography.s13)
                                .foregroundColor(Color.white.opacity(0.7))
                                .lineLimit(1)
                        }

                        // Title
                        Text(data.title)
                            .font(Typography.s17Bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .padding(.top, data.description != nil ? 4 : 0)

                        // Metadata row (not shown in .new variant)
                        HStack(spacing: 16) {
                            ForEach(data.metadata) { item in
                                DataComponent(item: item)
                            }
                        }
                        .padding(.top, 16)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)

                Spacer(minLength: 0)

                // Right: Image (72×108) with play icon
                imageViewWithPlayIcon
            }
            .padding(16)
            .frame(height: cardHeight)
            .background(cardBackgroundColor)
            .cornerRadius(cornerRadius)
            .overlay(
                Group {
                    if showAnimatedBorder && (data.status == .new || data.status == .pending) {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        Color.brandPrimary,
                                        Color.brandPrimary.opacity(0.2),
                                        Color.brandPrimary
                                    ]),
                                    center: .center,
                                    angle: .degrees(borderRotation)
                                ),
                                lineWidth: 2
                            )
                    }
                }
            )
            .onAppear {
                if showAnimatedBorder && (data.status == .new || data.status == .pending) && !hasStartedAnimation {
                    let startOffset = randomizeBorderStart ? Double.random(in: 0..<360) : 0
                    borderRotation = startOffset
                    hasStartedAnimation = true
                    withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                        borderRotation = startOffset + 360
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var cardBackgroundColor: Color {
        if showAnimatedBorder {
            return Color.cardBackground
        }
        if data.status == .pending || data.status == .new {
            return Color.backgroundPurple
        } else {
            return Color.cardBackground
        }
    }

    // MARK: - Image View with Play Icon

    @ViewBuilder
    private var imageViewWithPlayIcon: some View {
        ZStack {
            // Background image
            switch data.imageStyle {
            case .photo(let imageURL):
                if imageURL.hasPrefix("asset://") {
                    // Local asset image
                    let assetName = imageURL.replacingOccurrences(of: "asset://", with: "")
                    Image(assetName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 72, height: imageHeight)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    // Remote URL
                    CachedCardImage(
                        url: imageURL.mediumImageUrl,
                        fallbackUrl: imageURL,
                        width: 72,
                        height: imageHeight,
                        fallback: { iconFallback.frame(width: 72, height: imageHeight) }
                    )
                }

            case .icon(let systemName, let backgroundColor, let foregroundColor):
                iconView(systemName: systemName, backgroundColor: backgroundColor, foregroundColor: foregroundColor)
                    .frame(width: 72, height: imageHeight)

            case .dateDisplay, .timeDisplay:
                // Videos don't use date/time display, but handle it gracefully
                iconFallback
                    .frame(width: 72, height: imageHeight)
            }
        }
        .overlay(alignment: .bottom) {
            // Play icon overlay - 16px from bottom, centered horizontally
            playIcon
                .padding(.bottom, 16)
        }
    }

    private var iconFallback: some View {
        Color.iconContainerBackground
            .overlay(
                Image(systemName: "play.circle.fill")
                    .font(Typography.s24)
                    .foregroundColor(.white)
            )
            .cornerRadius(8)
    }

    private func iconView(systemName: String, backgroundColor: Color?, foregroundColor: Color?) -> some View {
        (backgroundColor ?? Color.iconContainerBackground)
            .overlay(
                Group {
                    if data.status == .new {
                        // Centered play button for .new status
                        Image(systemName: "play.fill")
                            .font(Typography.s32)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: systemName)
                            .font(Typography.s24)
                            .foregroundColor(foregroundColor ?? .white)
                    }
                }
            )
            .cornerRadius(8)
    }

    // MARK: - Play Icon

    @ViewBuilder
    private var playIcon: some View {
        // Hide play icon in .new status
        if data.status != .new {
            // 24×24 play icon (decorative, non-interactive)
            Image("IconVideoPlay")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: 32) {
                // Row Video Cards
                VStack(alignment: .leading, spacing: 12) {
                    Text("Video Cards - Row")
                        .font(Typography.s13Semibold)
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    CardVideo(
                        data: CardVideoData(
                            id: "video-1",
                            title: "Sunday Sermon: Faith in Action",
                            description: "Sermons",
                            imageStyle: .photo(imageURL: "https://picsum.photos/116/116"),
                            metadata: [
                                DataItem(icon: "eye", value: "1.2K"),
                                DataItem(icon: "clock", value: "5 mins ago"),
                                DataItem(icon: "square.and.arrow.up", value: "45")
                            ],
                            status: .confirmed,
                            onTap: nil
                        )
                    )

                    // Pending/New video card (purple background)
                    CardVideo(
                        data: CardVideoData(
                            id: "video-2",
                            title: "VIDEO",
                            description: "Select video",
                            imageStyle: .icon(
                                systemName: "play.fill",
                                backgroundColor: nil,
                                foregroundColor: Color.purple
                            ),
                            metadata: [],
                            status: .new,
                            onTap: nil
                        )
                    )

                }

            }
            .padding(20)
        }
    }
}
