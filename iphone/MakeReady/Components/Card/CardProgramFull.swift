//
//  CardProgramFull.swift
//  MakeReady
//
//  Full-width program card for library browse section.
//  Shows cover image, title, description, tags, metadata, and author.
//

import SwiftUI

struct CardProgramFullData: Identifiable {
    let id: String
    let title: String
    let description: String?
    let coverImageUrl: String?
    let tags: [String]
    let days: Int
    let enrollmentCount: Int?
    let authorName: String?
    let createdAt: Date
    let isPublished: Bool 
    let onTap: (() -> Void)?

    // Hashable without closures
    static func == (lhs: CardProgramFullData, rhs: CardProgramFullData) -> Bool {
        lhs.id == rhs.id
    }
}

struct CardProgramFull: View {
    let data: CardProgramFullData

    private var weeksCount: Int {
        Int(ceil(Double(data.days) / 7.0))
    }

    /// Shared per-render formatter (Phase 5.1 formatter pass; main-thread).
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    private var relativeDate: String {
        return Self.relativeFormatter.localizedString(for: data.createdAt, relativeTo: Date())
    }

    private var imageFallback: some View {
        ZStack {
            Color.white.opacity(0.08)
            Image(systemName: "book.fill")
                .font(Typography.s32)
                .foregroundColor(.white.opacity(0.2))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-bleed cover image — slightly zoomed and shifted up
            // to position focal points above center
            GeometryReader { geo in
                if let url = data.coverImageUrl, !url.isEmpty {
                    CachedCardImage(
                        url: url.mediumImageUrl,
                        fallbackUrl: url,
                        width: geo.size.width,
                        height: geo.size.height,
                        cornerRadius: 0,
                        fallback: { imageFallback }
                    )
                    .scaleEffect(1.15)
                    .offset(y: -geo.size.height * 0.05)
                } else {
                    imageFallback
                }
            }

            // Content overlay with semi-transparent background
            VStack(alignment: .leading, spacing: 16) {
                // Group 1: Title + Description
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.title)
                        .font(Typography.s17Bold)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if let description = data.description, !description.isEmpty {
                        Text(description)
                            .font(Typography.s14)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                }

                // Group 2: Tags
                if !data.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(data.tags, id: \.self) { tag in
                            Text(tag)
                                .font(Typography.s10Semibold)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.white.opacity(0.15)))
                        }
                        Spacer()
                    }
                }

                HStack(spacing: 16) {
                    DataComponent(item: DataItem(icon: "calendar", value: "\(data.days)"))
                    DataComponent(item: DataItem(icon: "clock", value: "\(weeksCount) weeks"))
                    if let count = data.enrollmentCount, count > 0 {
                        DataComponent(item: DataItem(icon: "person.2", value: "\(count)"))
                    }
                }

                // Group 3: Author + Date
                HStack {
                    if let author = data.authorName {
                        Text(author)
                            .font(Typography.s12Medium)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    Text(relativeDate)
                        .font(Typography.s12)
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground.opacity(0.8))

            // Published badge (top-right, above overlay)
            if data.isPublished {
                VStack {
                    HStack {
                        Spacer()
                        Text("Published")
                            .font(Typography.s10Semibold)
                            .foregroundColor(Color(hex: "#234D2E"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.success))
                            .padding(.top, 16)
                            .padding(.trailing, 16)
                    }
                    Spacer()
                }
            }
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        VStack(spacing: 16) {
            CardProgramFull(data: CardProgramFullData(
                id: "1",
                title: "Romans in 30 Days",
                description: "A 12 week journey through the core beliefs and practices of something that this lesson is about.",
                coverImageUrl: nil,
                tags: ["Faith & Scripture", "Bible", "Another tag"],
                days: 27,
                enrollmentCount: 28,
                authorName: "Tony Stark",
                createdAt: Date().addingTimeInterval(-5 * 86400),
                isPublished: true,
                onTap: nil
            ))
        }
        .padding(16)
    }
}
