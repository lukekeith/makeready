//
//  SkeletonCardProgramFull.swift
//  MakeReady
//
//  Skeleton loading placeholder matching CardProgramFull layout.
//

import SwiftUI

struct SkeletonCardProgramFull: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            // Image placeholder (full bleed)
            Color.white.opacity(0.08)

            // Content overlay
            VStack(alignment: .leading, spacing: 0) {
                // Title
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 180, height: 17)

                // Description
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 260, height: 14)
                    .padding(.top, 6)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 200, height: 14)
                    .padding(.top, 4)

                // Tags
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 80, height: 20)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 50, height: 20)
                }
                .padding(.top, 10)

                // Metadata
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 40, height: 12)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 60, height: 12)
                }
                .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.cardBackground.opacity(0.8))
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shimmer()
    }
}

#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        VStack(spacing: 16) {
            SkeletonCardProgramFull()
            SkeletonCardProgramFull()
        }
        .padding(16)
    }
}
