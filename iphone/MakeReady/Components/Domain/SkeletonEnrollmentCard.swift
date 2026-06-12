//
//  SkeletonEnrollmentCard.swift
//  MakeReady
//
//  Skeleton loader for enrollment cards while they're being created
//

import SwiftUI

struct SkeletonEnrollmentCard: View {
    let programName: String
    let programImageUrl: String?
    let programDays: Int

    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 12) {
            // Program cover image
            programImage

            // Program info + status
            VStack(alignment: .leading, spacing: 4) {
                // Program name
                Text(programName)
                    .font(Typography.s15Semibold)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)

                // Days count
                Text("\(programDays) days")
                    .font(Typography.s13)
                    .foregroundColor(.white.opacity(0.4))

                // Status indicator skeleton
                HStack(spacing: 4) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.brandPrimary))
                        .scaleEffect(0.7)

                    Text("Creating...")
                        .font(Typography.s12Medium)
                        .foregroundColor(Color.brandPrimary.opacity(0.7))
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.brandPrimary.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(4)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }

    // MARK: - Program Image

    private var programImage: some View {
        Group {
            if let imageUrl = programImageUrl,
               let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        imagePlaceholder
                    @unknown default:
                        imagePlaceholder
                    }
                }
            } else {
                imagePlaceholder
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            ZStack {
                Color.black.opacity(0.2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        )
    }

    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.brandPrimary.opacity(isAnimating ? 0.4 : 0.2))
            .overlay(
                Image(systemName: "book.fill")
                    .font(Typography.s20)
                    .foregroundColor(.white.opacity(0.5))
            )
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 12) {
            SkeletonEnrollmentCard(
                programName: "Romans",
                programImageUrl: nil,
                programDays: 30
            )
        }
        .padding(16)
    }
}
