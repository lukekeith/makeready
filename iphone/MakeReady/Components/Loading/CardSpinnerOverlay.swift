//
//  CardSpinnerOverlay.swift
//  MakeReady
//
//  Small spinner overlay for cards during save/update operations
//

import SwiftUI

struct CardSpinnerOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.9)
        }
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 20) {
            Text("Card Spinner Overlay")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)

            // On a card-like element
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.cardBackground)
                    .frame(height: 140)
                    .overlay(
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Sample Card")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                Text("With spinner overlay")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding()
                            Spacer()
                        }
                    )

                CardSpinnerOverlay()
            }
        }
        .padding(20)
    }
}
