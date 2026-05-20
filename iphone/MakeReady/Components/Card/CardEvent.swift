//
//  CardEvent.swift
//  MakeReady
//
//  Event card component (Row layout)
//

import SwiftUI


struct CardEvent: View {
    let data: CardEventData
    let cornerRadius: CGFloat

    init(data: CardEventData, cornerRadius: CGFloat = 4) {
        self.data = data
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Button {
            data.onTap?()
        } label: {
            HStack(spacing: 16) {
                // Left: Content
                VStack(alignment: .leading, spacing: 0) {
                    // Title
                    Text(data.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    // Subtitle (if present)
                    if let subtitle = data.subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }

                    // Metadata row
                    HStack(spacing: 16) {
                        ForEach(data.metadata) { item in
                            DataComponent(item: item)
                        }
                    }
                    .padding(.top, 16)
                }
                .frame(maxHeight: .infinity, alignment: .center)

                Spacer(minLength: 0)

                // Right: Date Display/Image (72×108)
                imageView
                    .frame(width: 72, height: 108)
            }
            .padding(16)
            .frame(height: 140)
            .background(Color.cardBackground)
            .cornerRadius(cornerRadius)
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
                    width: 72,
                    height: 108,
                    fallback: { iconFallback }
                )

            case .icon(let systemName, let backgroundColor, let foregroundColor):
                iconView(systemName: systemName, backgroundColor: backgroundColor, foregroundColor: foregroundColor)

            case .dateDisplay(let day, let month):
                dateDisplayView(day: day, month: month)

            case .timeDisplay(let time, let period):
                timeDisplayView(time: time, period: period)
            }
        }
    }

    private var iconFallback: some View {
        Color.iconContainerBackground
            .overlay(
                Image(systemName: "calendar")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(.white)
            )
            .cornerRadius(8)
    }

    private func iconView(systemName: String, backgroundColor: Color?, foregroundColor: Color?) -> some View {
        (backgroundColor ?? Color.iconContainerBackground)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(foregroundColor ?? .white)
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
                .lineSpacing(24 - 20) // Target 24px line height
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

        ScrollView {
            VStack(spacing: 32) {
                // Row Event Cards
                VStack(alignment: .leading, spacing: 12) {
                    Text("Event Cards - Row")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    CardEvent(
                        data: CardEventData(
                            id: "event-1",
                            title: "Event title",
                            subtitle: "Weekly bible study",
                            imageStyle: .dateDisplay(day: 30, month: "OCT"),
                            metadata: [
                                DataItem(icon: "mappin", value: "Starbucks, Little Elm TX")
                            ],
                            status: nil,
                            onTap: nil
                        )
                    )

                    CardEvent(
                        data: CardEventData(
                            id: "event-2",
                            title: "Event title",
                            subtitle: "Weekly bible study",
                            imageStyle: .dateDisplay(day: 18, month: "SEP"),
                            metadata: [
                                DataItem(icon: "mappin", value: "Starbucks, Little Elm TX")
                            ],
                            status: nil,
                            onTap: nil
                        )
                    )

                    Text("Event Cards - Time Display")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .padding(.top, 16)

                    CardEvent(
                        data: CardEventData(
                            id: "event-3",
                            title: "Morning Prayer",
                            subtitle: "Weekly bible study",
                            imageStyle: .timeDisplay(time: "6:30", period: "AM"),
                            metadata: [
                                DataItem(icon: "mappin", value: "Starbucks, Little Elm TX")
                            ],
                            status: nil,
                            onTap: nil
                        )
                    )

                    CardEvent(
                        data: CardEventData(
                            id: "event-4",
                            title: "Evening Worship",
                            subtitle: "Community gathering",
                            imageStyle: .timeDisplay(time: "7:00", period: "PM"),
                            metadata: [
                                DataItem(icon: "mappin", value: "Main Church Building")
                            ],
                            status: nil,
                            onTap: nil
                        )
                    )

                    CardEvent(
                        data: CardEventData(
                            id: "event-5",
                            title: "Lunch Meeting",
                            subtitle: "Leadership team",
                            imageStyle: .timeDisplay(time: "12:30", period: "PM"),
                            metadata: [
                                DataItem(icon: "mappin", value: "Conference Room A")
                            ],
                            status: nil,
                            onTap: nil
                        )
                    )
                }
            }
            .padding(20)
        }
    }
}
