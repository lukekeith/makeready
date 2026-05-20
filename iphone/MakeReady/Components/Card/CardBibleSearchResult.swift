//
//  CardBibleSearchResult.swift
//  MakeReady
//
//  Bible search result card with book icon, reference title, and verse preview.
//

import SwiftUI

struct CardBibleSearchResult: View {
    let reference: String
    let text: String
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(alignment: .top, spacing: 8) {
                // Book icon
                Image(systemName: "book.closed")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)

                // Reference + verse text
                VStack(alignment: .leading, spacing: 0) {
                    Text(reference)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(text)
                        .font(.system(size: 12))
                        .foregroundColor(.white70)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
        .padding(16)
    }
}
