//
//  SkeletonCardStudy.swift
//  MakeReady
//
//  Skeleton loading placeholder for CardStudy
//  Matches CardStudy dimensions: 140px height with 16px padding
//

import SwiftUI

struct SkeletonCardStudy: View {
    var body: some View {
        HStack(spacing: 16) {
            // Left: Text placeholders
            VStack(alignment: .leading, spacing: 0) {
                // Title placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 140, height: 17)

                // Description placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 180, height: 13)
                    .padding(.top, 8)

                // Metadata placeholder
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 60, height: 12)
                }
                .padding(.top, 16)
            }
            .frame(maxHeight: .infinity, alignment: .center)

            Spacer(minLength: 0)

            // Right: Image placeholder (72×108)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.1))
                .frame(width: 72, height: 108)
        }
        .padding(16)
        .frame(height: 140)
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
            Text("Skeleton Study Cards")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)

            SkeletonCardStudy()
            SkeletonCardStudy()
        }
        .padding(20)
    }
}
