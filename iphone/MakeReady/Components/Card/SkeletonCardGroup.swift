//
//  SkeletonCardGroup.swift
//  MakeReady
//
//  Skeleton loading placeholder for CardGroup
//  Matches CardGroup dimensions: 104px height with circular 72px image
//

import SwiftUI

struct SkeletonCardGroup: View {
    var body: some View {
        HStack(spacing: 16) {
            // Left: Circular image placeholder (72×72)
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 72, height: 72)

            // Right: Content placeholders
            VStack(alignment: .leading, spacing: 0) {
                // Title placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 140, height: 17)

                // Metadata placeholder (members count)
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 24, height: 13)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 56, height: 13)
                }
                .padding(.top, 16)
            }
            .frame(maxHeight: .infinity, alignment: .center)

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(height: 104)
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

        VStack(spacing: 12) {
            Text("Skeleton Group Cards")
                .font(Typography.s13Semibold)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)

            SkeletonCardGroup()
            SkeletonCardGroup()
            SkeletonCardGroup()
        }
        .padding(20)
    }
}
