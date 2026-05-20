//
//  CardEventMini.swift
//  MakeReady
//
//  Mini event card component (120×188px)
//

import SwiftUI

struct CardEventMini: View {
    let data: CardEventData

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
                        .font(.system(size: 12, weight: .bold))
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
            .background(Color.cardBackground)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Image View

    @ViewBuilder
    private var imageView: some View {
        ZStack {
            switch data.imageStyle {
            case .photo(let imageURL):
                CachedCardImage(
                    url: imageURL.mediumImageUrl,
                    fallbackUrl: imageURL,
                    width: 120,
                    height: 114,
                    fallback: { iconFallback }
                )

            case .icon(let systemName, _, _):
                iconView(systemName: systemName)

            case .dateDisplay(let day, let month):
                dateDisplayView(day: day, month: month)

            case .timeDisplay(let time, let period):
                timeDisplayView(time: time, period: period)
            }
        }
    }

    private var iconFallback: some View {
        Color.iconContainerBackground
            .frame(width: 120, height: 114)
            .overlay(
                Image(systemName: "calendar")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(.white)
            )
            .cornerRadius(8)
    }

    private func iconView(systemName: String) -> some View {
        Color.iconContainerBackground
            .frame(width: 120, height: 114)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(.white)
            )
            .cornerRadius(8)
    }

    private func dateDisplayView(day: Int, month: String) -> some View {
        VStack(spacing: 4) {
            Text("\(day)")
                .font(.system(size: 28, weight: .regular))
                .foregroundColor(.white)
                .tracking(-0.15)

            Text(month.uppercased())
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(hex: "#6c47ff"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#485470").opacity(0.5))
        .cornerRadius(8)
    }

    private func timeDisplayView(time: String, period: String) -> some View {
        VStack(spacing: 4) {
            Text(time)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .tracking(-0.15)

            Text(period.uppercased())
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(hex: "#6c47ff"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#485470").opacity(0.5))
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
                CardEventMini(
                    data: CardEventData(
                        id: "event-1",
                        title: "Event title",
                        subtitle: nil,
                        imageStyle: .dateDisplay(day: 20, month: "FEB"),
                        metadata: [
                            DataItem(icon: "clock", value: "7:00 PM")
                        ],
                        status: nil,
                        onTap: nil
                    )
                )

                CardEventMini(
                    data: CardEventData(
                        id: "event-2",
                        title: "Event title",
                        subtitle: nil,
                        imageStyle: .dateDisplay(day: 5, month: "MAR"),
                        metadata: [
                            DataItem(icon: "clock", value: "6:00 PM")
                        ],
                        status: nil,
                        onTap: nil
                    )
                )
            }
            .padding(20)
        }
    }
}
