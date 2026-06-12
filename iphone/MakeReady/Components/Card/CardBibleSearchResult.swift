//
//  CardBibleSearchResult.swift
//  MakeReady
//
//  Bible search result card with book icon, reference title, and verse preview.
//  Named-passage (pericope) results additionally carry a title and summary —
//  rendered as "The Parable of the Prodigal Son — Luke 15:11-24" with the
//  summary below, so concept-search hits read as first-class answers.
//

import SwiftUI

struct CardBibleSearchResult: View {
    let reference: String
    let text: String
    var title: String? = nil
    var summary: String? = nil
    var onTap: (() -> Void)?

    private var isPassage: Bool { title?.isEmpty == false }

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(alignment: .top, spacing: 8) {
                // Book icon — open book for named passages, closed for verses
                Image(systemName: isPassage ? "book.pages" : "book.closed")
                    .font(Typography.s14)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)

                if let title, isPassage {
                    // Named passage: title + reference header, summary preview
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Text(title).font(Typography.s12Bold).foregroundColor(.white))  \(Text(reference).font(Typography.s11).foregroundColor(.white50))")
                            .lineLimit(2)

                        Text(summary ?? text)
                            .font(Typography.s12)
                            .foregroundColor(.white70)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // Single verse / range: reference + verse text
                    VStack(alignment: .leading, spacing: 0) {
                        Text(reference)
                            .font(Typography.s12Bold)
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(text)
                            .font(Typography.s12)
                            .foregroundColor(.white70)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 2) {
            Group {
                CardBibleSearchResult(
                    reference: "John 3:16",
                    text: "For God so loved the world that he gave his one and only Son..."
                )

                CardBibleSearchResult(
                    reference: "Romans 8:28",
                    text: "And we know that in all things God works for the good of those who love him..."
                )

                CardBibleSearchResult(
                    reference: "Psalm 23:1",
                    text: "The Lord is my shepherd; I shall not want."
                )
            }

            Group {
                CardBibleSearchResult(
                    reference: "Luke 15:11-24",
                    text: "He said, \"A certain man had two sons. The younger of them said to his father...\" …",
                    title: "The Parable of the Prodigal Son",
                    summary: "A son squanders his inheritance, returns home in shame, and is welcomed back with celebration by his forgiving father."
                )

                CardBibleSearchResult(
                    reference: "1 Samuel 17:24-31",
                    text: "All the men of Israel, when they saw the man, fled from him...",
                    title: "David Volunteers to Fight Goliath",
                    summary: "Young David hears Goliath's defiance and volunteers to face the giant when seasoned soldiers will not."
                )
            }
        }
        .padding(16)
    }
}
