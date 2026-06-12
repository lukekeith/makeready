//
//  CardStudyMini.swift
//  MakeReady
//
//  Mini study card component (120×188px)
//

import SwiftUI

struct CardStudyMini: View {
    let data: CardStudyData

    var body: some View {
        Button {
            data.onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Top: Image (120×114)
                imageView
                    .frame(width: 120, height: 114)

                // Bottom: Content
                VStack(alignment: .leading, spacing: 8) {
                    // Title (12pt with 0.1px tracking, max 32px height)
                    Text(data.title)
                        .font(Typography.s12Bold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .frame(maxHeight: 32, alignment: .topLeading)
                        .tracking(0.1)

                    // Metadata row (only first item)
                    if let firstItem = data.metadata.first {
                        DataComponent(item: firstItem)
                    }
                }
                .padding(8)
            }
            .frame(width: 120, height: 188)
            .background(cardBackgroundColor)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private var cardBackgroundColor: Color {
        if data.status == .pending {
            return Color.backgroundPurple  // Solid dark purple for pending
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
                    width: 120,
                    height: 114,
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
            .frame(width: 120, height: 114)
            .overlay(
                Image(systemName: "book.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.white)
            )
            .cornerRadius(8)
    }

    private func iconView(systemName: String, backgroundColor: Color?, foregroundColor: Color?) -> some View {
        (backgroundColor ?? Color.iconContainerBackground)
            .frame(width: 120, height: 114)
            .overlay(
                Image(systemName: systemName.isEmpty ? "book.fill" : systemName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
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
            .background(Color.brandPrimary)
            .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                CardStudyMini(
                    data: CardStudyData(
                        id: "study-1",
                        title: "Study title",
                        description: nil,
                        type: nil,
                        imageStyle: .photo(imageURL: "https://images.unsplash.com/photo-1506869640319-fe1a24fd76dc?w=240&h=228&fit=crop"),
                        metadata: [
                            DataItem(icon: "clock", value: "28")
                        ],
                        status: .confirmed,
                        onTap: nil
                    )
                )

                CardStudyMini(
                    data: CardStudyData(
                        id: "study-2",
                        title: "Study title",
                        description: nil,
                        type: nil,
                        imageStyle: .icon(systemName: "book.fill", backgroundColor: .orange),
                        metadata: [
                            DataItem(icon: "clock", value: "28")
                        ],
                        status: .pending,
                        onTap: nil
                    )
                )
            }
            .padding(20)
        }
    }
}
