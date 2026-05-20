//
//  SkeletonCardMediaFull.swift
//  MakeReady
//
//  Skeleton loading placeholder for CardMediaFull grid card.
//

import SwiftUI

struct SkeletonCardMediaFull: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .aspectRatio(1, contentMode: .fit)
            .shimmer()
    }
}

#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        let columns = [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]

        LazyVGrid(columns: columns, spacing: 8) {
            SkeletonCardMediaFull()
            SkeletonCardMediaFull()
            SkeletonCardMediaFull()
            SkeletonCardMediaFull()
            SkeletonCardMediaFull()
            SkeletonCardMediaFull()
        }
        .padding(16)
    }
}
