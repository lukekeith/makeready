//
//  SkeletonCardLessonActivity.swift
//  MakeReady
//
//  Skeleton loading placeholder matching CardLessonActivity small layout
//

import SwiftUI

struct SkeletonCardLessonActivity: View {
    var body: some View {
        HStack(spacing: 12) {
            // Left: Image placeholder (40×40)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
                .frame(width: 40, height: 40)

            // Right: Two lines of text
            VStack(alignment: .leading, spacing: 4) {
                // Title placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 120, height: 15)

                // Description placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 80, height: 13)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.cardBackground)
        .cornerRadius(4)
        .shimmer()
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 8) {
            SkeletonCardLessonActivity()
            SkeletonCardLessonActivity()
            SkeletonCardLessonActivity()
        }
        .padding(20)
    }
}
