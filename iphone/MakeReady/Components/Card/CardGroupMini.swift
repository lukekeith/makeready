//
//  CardGroupMini.swift
//  MakeReady
//
//  Mini group card component (120×188px)
//

import SwiftUI


struct CardGroupMini: View {
    let data: CardGroupData

    var body: some View {
        Button {
            data.onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Top: Circular image centered in 114px height container
                ZStack(alignment: .center) {
                    Color.clear
                        .frame(width: 120, height: 114)

                    imageView
                        .frame(width: 72, height: 72)
                }

                // Bottom: Content
                VStack(alignment: .leading, spacing: 8) {
                    // Title (12pt with 0.1px tracking, max 32px height)
                    Text(data.title)
                        .font(Typography.s12Bold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .frame(maxHeight: 32, alignment: .topLeading)
                        .tracking(0.1)

                    // Metadata row
                    HStack(spacing: 16) {
                        ForEach(data.metadata) { item in
                            DataComponent(item: item)
                        }
                    }
                }
                .padding(8)
            }
            .frame(width: 120, height: 188)
            .background(Color.cardBackground)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Image View

    @ViewBuilder
    private var imageView: some View {
        ZStack {
            // Base image (circular)
            switch data.imageStyle {
            case .photo(let imageURL):
                CachedCardImage(
                    url: imageURL.mediumImageUrl,
                    fallbackUrl: imageURL,
                    width: 72,
                    height: 72,
                    clipCircle: true,
                    placeholder: { loadingPlaceholder },
                    fallback: { iconFallback }
                )

            case .icon(_, _, _):
                iconFallback

            case .dateDisplay, .timeDisplay:
                // Groups don't use date/time display, but handle it gracefully
                iconFallback
            }

            // Selected state overlay (always present, animated opacity)
            ZStack {
                // Purple 80% overlay
                Circle()
                    .fill(Color.brandPrimary.opacity(0.8))
                    .frame(width: 72, height: 72)

                // Checkmark icon (24×24)
                Image("IconCheckmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white)
            }
            .opacity(data.isSelected ? 1 : 0)
            .animation(.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.2), value: data.isSelected)
        }
    }

    private var loadingPlaceholder: some View {
        Circle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 72, height: 72)
    }

    private var iconFallback: some View {
        Circle()
            .fill(Color.iconContainerBackground)
            .frame(width: 72, height: 72)
            .overlay(
                Image("IconGroup")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white)
                    .opacity(data.isSelected ? 0 : 1)
                    .animation(.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.2), value: data.isSelected)
            )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                CardGroupMini(
                    data: CardGroupData(
                        id: "group-1",
                        title: "Youth Group",
                        imageStyle: .icon(systemName: "person.2.fill", backgroundColor: .green),
                        metadata: [
                            DataItem(number: "42", label: "Members")
                        ],
                        isSelected: false,
                        onTap: nil
                    )
                )

                CardGroupMini(
                    data: CardGroupData(
                        id: "group-2",
                        title: "Seniors Fellowship Group",
                        imageStyle: .icon(systemName: "person.2.fill", backgroundColor: .orange),
                        metadata: [
                            DataItem(number: "12", label: "Members")
                        ],
                        isSelected: true,
                        onTap: nil
                    )
                )
            }
            .padding(20)
        }
    }
}
