//
//  SkeletonPostCard.swift
//  MakeReady
//
//  Skeleton loader for posts while they're being created
//

import SwiftUI

struct SkeletonPostCard: View {
    let programName: String?
    let programImageUrl: String?

    @State private var isAnimating = false

    /// Initialize for enrollment welcome post skeleton
    init(programName: String, programImageUrl: String?) {
        self.programName = programName
        self.programImageUrl = programImageUrl
    }

    /// Initialize for generic post skeleton (loading state)
    init() {
        self.programName = nil
        self.programImageUrl = nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author row skeleton
            HStack(spacing: 12) {
                // Avatar placeholder
                Circle()
                    .fill(shimmerGradient)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    // Name placeholder
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shimmerGradient)
                        .frame(width: 100, height: 14)

                    // Timestamp placeholder
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shimmerGradient)
                        .frame(width: 60, height: 10)
                }

                Spacer()
            }

            // Content preview
            VStack(alignment: .leading, spacing: 8) {
                if let programName = programName {
                    Text("\(programName) starts soon!")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    // Generic title placeholder
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shimmerGradient)
                        .frame(width: 180, height: 16)
                }

                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(height: 14)

                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(width: 200, height: 14)
            }

            // Cover image area
            if let imageUrl = programImageUrl, let url = URL(string: imageUrl) {
                // Enrollment skeleton with actual image
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(shimmerGradient)
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    // Loading indicator overlay
                    ZStack {
                        Color.black.opacity(0.3)
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                )
            } else if programName != nil {
                // Enrollment skeleton without image
                Rectangle()
                    .fill(shimmerGradient)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                    )
            } else {
                // Generic skeleton - smaller image placeholder
                Rectangle()
                    .fill(shimmerGradient)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Action bar skeleton
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "eye")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.3))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shimmerGradient)
                        .frame(width: 20, height: 12)
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrowshape.turn.up.right")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.3))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(shimmerGradient)
                        .frame(width: 20, height: 12)
                }

                Spacer()
            }
        }
        .padding(16)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }

    private var shimmerGradient: some ShapeStyle {
        Color.white.opacity(isAnimating ? 0.15 : 0.08)
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 16) {
            SkeletonPostCard(
                programName: "Romans",
                programImageUrl: nil
            )
            .padding(.horizontal, 16)
        }
    }
}
