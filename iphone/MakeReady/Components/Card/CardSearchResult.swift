//
//  CardSearchResult.swift
//  MakeReady
//
//  Search result card with circular image, highlighted title,
//  timestamp, description, and navigation chevron.
//

import SwiftUI

struct CardSearchResult: View {
    let title: String
    let subtitle: String?
    let timestamp: String?
    let imageURL: String?
    let firstName: String?
    let lastName: String?
    let sfSymbol: String
    let isMember: Bool
    let isVideo: Bool
    let showChevron: Bool
    let highlightQuery: String
    let onTap: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        timestamp: String? = nil,
        imageURL: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        sfSymbol: String = "doc.fill",
        isMember: Bool = false,
        isVideo: Bool = false,
        showChevron: Bool = true,
        highlightQuery: String = "",
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.timestamp = timestamp
        self.imageURL = imageURL
        self.firstName = firstName
        self.lastName = lastName
        self.sfSymbol = sfSymbol
        self.isMember = isMember
        self.isVideo = isVideo
        self.showChevron = showChevron
        self.highlightQuery = highlightQuery
        self.onTap = onTap
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                imageView

                VStack(alignment: .leading, spacing: 2) {
                    highlightedText(title, query: highlightQuery)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if timestamp != nil || subtitle != nil {
                        HStack(spacing: 0) {
                            if let timestamp = timestamp {
                                Text(timestamp)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white30)
                                    .lineLimit(1)

                                if subtitle != nil {
                                    Text("  ·  ")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white20)
                                }
                            }

                            if let subtitle = subtitle {
                                Text(subtitle)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white50)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white20)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Image

    @ViewBuilder
    private var imageView: some View {
        if isMember {
            Avatar(
                imageURL: imageURL,
                firstName: firstName ?? "",
                lastName: lastName ?? "",
                size: .md
            )
        } else if isVideo {
            ZStack {
                if let imageURL = imageURL, !imageURL.isEmpty,
                   let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            Color.white.opacity(0.08)
                        }
                    }
                } else {
                    Color.white.opacity(0.08)
                }

                Image(systemName: "play.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        } else if let imageURL = imageURL, !imageURL.isEmpty {
            CachedAsyncImage(
                url: URL(string: imageURL),
                size: 40,
                fallbackIcon: sfSymbol
            )
            .clipShape(Circle())
        } else {
            Image(systemName: sfSymbol)
                .font(.system(size: 16))
                .foregroundColor(Color.brandPrimary)
                .frame(width: 40, height: 40)
                .background(Color.brandPrimary.opacity(0.15))
                .clipShape(Circle())
        }
    }

    // MARK: - Text Highlighting

    private func highlightedText(_ text: String, query: String) -> Text {
        let lowercaseText = text.lowercased()
        let lowercaseQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard !lowercaseQuery.isEmpty,
              let range = lowercaseText.range(of: lowercaseQuery) else {
            return Text(text)
        }

        let before = String(text[text.startIndex..<range.lowerBound])
        let match = String(text[range.lowerBound..<range.upperBound])
        let after = String(text[range.upperBound..<text.endIndex])

        var result = AttributedString(before)
        var highlighted = AttributedString(match)
        highlighted.foregroundColor = Color.brandPrimary
        result.append(highlighted)
        result.append(AttributedString(after))
        return Text(result)
    }
}

// MARK: - Convenience initializer from SearchResult

extension CardSearchResult {
    init(result: SearchResult, highlightQuery: String = "", onTap: @escaping () -> Void) {
        let nameParts = result.category == .member ? result.title.components(separatedBy: " ") : []

        self.init(
            title: result.title,
            subtitle: result.subtitle,
            timestamp: result.timestamp,
            imageURL: result.imageURL,
            firstName: nameParts.first,
            lastName: nameParts.count > 1 ? nameParts[1] : nil,
            sfSymbol: result.sfSymbol ?? result.category.icon,
            isMember: result.category == .member,
            isVideo: result.category == .video,
            showChevron: false,
            highlightQuery: highlightQuery,
            onTap: onTap
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 0) {
            CardSearchResult(
                title: "Romans in 30 Days",
                subtitle: "30 days, 28 lessons",
                timestamp: "2h ago",
                sfSymbol: "text.book.closed.fill",
                highlightQuery: "roman"
            ) {}

            CardSearchResult(
                title: "Young Professionals",
                subtitle: "27 members",
                timestamp: "Yesterday",
                imageURL: "https://example.com/photo.jpg",
                sfSymbol: "person.3.fill",
                highlightQuery: "young"
            ) {}

            CardSearchResult(
                title: "John Smith",
                subtitle: "Young Professionals",
                timestamp: "3d ago",
                firstName: "John",
                lastName: "Smith",
                isMember: true,
                highlightQuery: "john"
            ) {}

            CardSearchResult(
                title: "Day 5 - Grace",
                subtitle: "Day 5 - Romans in 30 Days",
                sfSymbol: "list.bullet.rectangle.fill",
                showChevron: false,
                highlightQuery: "grace"
            ) {}
        }
    }
}
