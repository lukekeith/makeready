//
//  CardEnrolled.swift
//  MakeReady
//
//  Enrollment card showing study title, date range, group name, and stacked cover images
//

import SwiftUI

struct CardEnrolled: View {
    let data: CardEnrolledData
    let cornerRadius: CGFloat

    init(data: CardEnrolledData, cornerRadius: CGFloat = 4) {
        self.data = data
        self.cornerRadius = cornerRadius
    }

    private let imageContainerWidth: CGFloat = 72
    private let imageContainerHeight: CGFloat = 108
    private let imageGap: CGFloat = 2

    var body: some View {
        Button {
            data.onTap?()
        } label: {
            HStack(spacing: 16) {
                // Left: Content
                VStack(alignment: .leading, spacing: 16) {
                    // Study title
                    Text(data.studyTitle)
                        .font(Typography.s17Bold)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    // Date range + lessons left
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(Typography.s14)
                            .foregroundColor(.white.opacity(0.7))

                        Text(dateRangeText)
                            .font(Typography.s13)
                            .foregroundColor(.white.opacity(0.7))

                        if let lessonsLeft = data.lessonsLeft {
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 3, height: 3)

                            let suffix = lessonsLeft == 1 ? "lesson" : "lessons"
                            Text("\(Text("\(lessonsLeft)").font(Typography.s13Bold).foregroundColor(.white)) \(suffix) left")
                                .font(Typography.s13)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .lineLimit(1)

                    // Group name
                    Text(data.groupName)
                        .font(Typography.s17Bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right: Stacked images (study on top, group on bottom)
                imageStack
            }
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(cornerRadius)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date Range

    private var dateRangeText: String {
        let formatter = DateFormatters.monthDay
        return "\(formatter.string(from: data.startDate)) - \(formatter.string(from: data.endDate))"
    }

    // MARK: - Image Stack

    private var imageStack: some View {
        let singleImageHeight = (imageContainerHeight - imageGap) / 2

        return VStack(spacing: imageGap) {
            // Study cover image (top, rounded top corners)
            imageView(url: data.studyImageURL, fallbackIcon: "book.fill")
                .frame(width: imageContainerWidth, height: singleImageHeight)
                .clipped()
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 8,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 8
                    )
                )

            // Group cover image (bottom, rounded bottom corners)
            imageView(url: data.groupImageURL, fallbackIcon: "person.2.fill")
                .frame(width: imageContainerWidth, height: singleImageHeight)
                .clipped()
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 8,
                        bottomTrailingRadius: 8,
                        topTrailingRadius: 0
                    )
                )
        }
        .frame(width: imageContainerWidth, height: imageContainerHeight)
    }

    @ViewBuilder
    private func imageView(url: String?, fallbackIcon: String) -> some View {
        if let url = url, !url.isEmpty {
            CachedCardImage(
                url: url.mediumImageUrl,
                fallbackUrl: url,
                width: imageContainerWidth,
                height: (imageContainerHeight - imageGap) / 2,
                cornerRadius: 0,
                fallback: { iconFallback(fallbackIcon) }
            )
        } else {
            iconFallback(fallbackIcon)
        }
    }

    private func iconFallback(_ systemName: String) -> some View {
        Color.iconContainerBackground
            .overlay(
                Image(systemName: systemName)
                    .font(Typography.s16)
                    .foregroundColor(.white)
            )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 12) {
            Text("Enrolled Cards")
                .font(Typography.s13Semibold)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)

            CardEnrolled(
                data: CardEnrolledData(
                    id: "enrolled-1",
                    studyTitle: "Romans in 30 Days",
                    groupName: "Young Professionals",
                    startDate: Date(),
                    endDate: Calendar.current.date(byAdding: .day, value: 30, to: Date())!,
                    lessonsLeft: 30,
                    studyImageURL: "https://images.unsplash.com/photo-1506869640319-fe1a24fd76dc?w=144&h=216&fit=crop",
                    groupImageURL: "https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=144&h=216&fit=crop",
                    onTap: { print("Tapped enrollment") }
                )
            )

            CardEnrolled(
                data: CardEnrolledData(
                    id: "enrolled-2",
                    studyTitle: "Psalms Deep Dive",
                    groupName: "Bible Study",
                    startDate: Calendar.current.date(byAdding: .day, value: -14, to: Date())!,
                    endDate: Calendar.current.date(byAdding: .day, value: 16, to: Date())!,
                    lessonsLeft: 16,
                    onTap: { print("Tapped enrollment") }
                )
            )

            CardEnrolled(
                data: CardEnrolledData(
                    id: "enrolled-3",
                    studyTitle: "Ephesians Study",
                    groupName: "Men's Group",
                    startDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
                    endDate: Calendar.current.date(byAdding: .day, value: 37, to: Date())!,
                    lessonsLeft: 30,
                    studyImageURL: "https://images.unsplash.com/photo-1504052434569-70ad5836ab65?w=144&h=216&fit=crop",
                    onTap: { print("Tapped enrollment") }
                )
            )
        }
        .padding(20)
    }
}
