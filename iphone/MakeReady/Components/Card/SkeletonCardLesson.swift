//
//  SkeletonCardLesson.swift
//  MakeReady
//
//  Skeleton loading placeholder for CardLesson
//  Matches CardLesson dimensions: 76px height
//

import SwiftUI

struct SkeletonCardLesson: View {
    var body: some View {
        HStack(spacing: 8) {
            // Left: Day indicator placeholder
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 20, height: 10)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 20, height: 18)
            }
            .padding(16)
            .frame(maxHeight: .infinity)

            // Center: Activity placeholders
            VStack(alignment: .leading, spacing: 6) {
                // Activity line 1
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 120, height: 12)

                // Activity line 2
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 90, height: 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: Chevron placeholder
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.06))
                .frame(width: 40, height: 50)
                .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .background(Color.cardBackground)
        .cornerRadius(4)
        .shimmer()
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 4) {
            Text("Skeleton Lesson Cards")
                .font(Typography.s13Semibold)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .padding(.bottom, 12)

            SkeletonCardLesson()
            SkeletonCardLesson()
        }
        .padding(20)
    }
}
