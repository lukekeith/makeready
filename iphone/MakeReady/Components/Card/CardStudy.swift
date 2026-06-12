//
//  CardStudy.swift
//  MakeReady
//
//  Study card component with Row and Mini layouts
//

import SwiftUI

struct CardStudy: View {
    let data: CardStudyData
    let showAnimatedBorder: Bool
    let randomizeBorderStart: Bool
    let compact: Bool
    let cornerRadius: CGFloat

    @State private var borderRotation: Double = 0
    @State private var hasStartedAnimation = false

    init(data: CardStudyData, showAnimatedBorder: Bool = false, randomizeBorderStart: Bool = true, compact: Bool = false, cornerRadius: CGFloat = 4) {
        self.data = data
        self.showAnimatedBorder = showAnimatedBorder
        self.randomizeBorderStart = randomizeBorderStart
        self.compact = compact
        self.cornerRadius = cornerRadius
    }

    private var imageSize: CGFloat { compact ? 72 : 108 }
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
                        // New variant: TYPE (uppercase), then description
                        if let type = data.type {
                            Text(type)
                                .font(Typography.s14Bold)
                                .foregroundColor(.white)
                        }

                        if let description = data.description {
                            Text(description)
                                .font(Typography.s16Bold)
                                .foregroundColor(.purple)
                                .lineLimit(2)
                                .padding(.top, 4)
                        }
                    } else {
                        // Standard variant: Title, then description
                        Text(data.title)
                            .font(Typography.s17Bold)
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if let description = data.description {
                            Text(description)
                                .font(Typography.s13)
                                .foregroundColor(Color.white.opacity(0.7))
                                .lineLimit(2)
                                .padding(.top, 0)
                        }
                    }

                    // Metadata row (not shown in .new variant)
                    if data.status != .new {
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

                // Right: Image (72×72 square in compact, 72×108 portrait otherwise)
                imageView
                    .frame(width: 72, height: imageSize)
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
            return Color.backgroundPurple  // Solid dark purple for pending and new
        } else {
            return Color.cardBackground
        }
    }

    // MARK: - Image View

    @ViewBuilder
    private var imageView: some View {
        ZStack(alignment: .top) {
            // Background image/icon
            switch data.imageStyle {
            case .photo(let imageURL):
                CachedCardImage(
                    url: imageURL.mediumImageUrl,
                    fallbackUrl: imageURL,
                    width: 72,
                    height: imageSize,
                    fallback: { iconFallback }
                )

            case .icon(let systemName, let backgroundColor, let foregroundColor):
                iconView(systemName: systemName, backgroundColor: backgroundColor, foregroundColor: foregroundColor)

            case .dateDisplay, .timeDisplay:
                // Studies don't use date/time display, but handle it gracefully
                iconFallback
            }

            // Status badge (pending state only) - positioned at top of image
            if data.status == .pending {
                statusBadge
            }
        }
    }

    private var iconFallback: some View {
        Color.iconContainerBackground
            .overlay(
                Image(systemName: "book.fill")
                    .font(Typography.s24)
                    .foregroundColor(.white)
            )
            .cornerRadius(8)
    }

    private func iconView(systemName: String, backgroundColor: Color?, foregroundColor: Color?) -> some View {
        (backgroundColor ?? Color.iconContainerBackground)
            .overlay(
                Image(systemName: systemName.isEmpty ? "book.fill" : systemName)
                    .font(Typography.s24)
                    .foregroundColor(foregroundColor ?? .white)
            )
            .cornerRadius(8)
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        Text("PENDING")
            .font(Typography.s11Bold)
            .foregroundColor(.white)
            .tracking(0.1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(Color.purple)
            .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 12) {
            Text("Study Cards - Row")
                .font(Typography.s13Semibold)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)

            CardStudy(
                data: CardStudyData(
                    id: "study-1",
                    title: "Study title",
                    description: "Description of the study, maximum of two lines, then ellipsis.",
                    type: nil,
                    imageStyle: .photo(imageURL: "https://images.unsplash.com/photo-1506869640319-fe1a24fd76dc?w=144&h=216&fit=crop"),
                    metadata: [
                        DataItem(icon: "clock", value: "28"),
                        DataItem(number: "28", label: "Participants")
                    ],
                    status: .confirmed,
                    onTap: nil
                )
            )

            CardStudy(
                data: CardStudyData(
                    id: "study-2",
                    title: "Study title",
                    description: "Description of the study, maximum of two lines, then ellipsis.",
                    type: nil,
                    imageStyle: .icon(systemName: "book.fill"),
                    metadata: [
                        DataItem(icon: "clock", value: "28"),
                        DataItem(number: "28", label: "Participants")
                    ],
                    status: .pending,
                    onTap: nil
                )
            )

            CardStudy(
                data: CardStudyData(
                    id: "study-3",
                    title: "Study title",
                    description: "Select a passage",
                    type: "SOAP",
                    imageStyle: .icon(
                        systemName: "arrow.right.circle",
                        backgroundColor: nil,
                        foregroundColor: Color.purple
                    ),
                    metadata: [],
                    status: .new,
                    onTap: nil
                )
            )

            Text("With Published / Draft Badge")
                .font(Typography.s13Semibold)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .padding(.top, 12)

            CardStudy(
                data: CardStudyData(
                    id: "study-published",
                    title: "Romans in 30 days",
                    description: "A journey through the book of Romans.",
                    imageStyle: .icon(systemName: "book.fill"),
                    metadata: [
                        DataItem(icon: "calendar", value: "30 days"),
                        DataItem(badge: "Published", color: Color.success, textColor: Color(hex: "#234D2E"))
                    ],
                    status: .confirmed,
                    onTap: nil
                )
            )

            CardStudy(
                data: CardStudyData(
                    id: "study-draft",
                    title: "Psalms Deep Dive",
                    description: "Exploring the poetry of the Psalms.",
                    imageStyle: .icon(systemName: "book.fill"),
                    metadata: [
                        DataItem(icon: "calendar", value: "14 days"),
                        DataItem(badge: "Draft", color: Color(hex: "#6E7079"), textColor: Color(hex: "#D3D4D7"))
                    ],
                    status: .confirmed,
                    onTap: nil
                )
            )
        }
        .padding(20)
    }
}
