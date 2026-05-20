//
//  AlphabetScrubber.swift
//  MakeReady
//
//  Reusable alphabet navigation scrubber for alphabetically sorted lists
//  Vertically centered with configurable letter tap action
//  Supports both tap and drag gestures like the native Contacts app
//

import SwiftUI

struct AlphabetScrubber: View {
    let letters: [String]
    let onLetterTap: (String) -> Void
    
    @State private var currentLetter: String?
    @State private var isDragging = false

    init(
        letters: [String] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map { String($0) },
        onLetterTap: @escaping (String) -> Void = { _ in }
    ) {
        self.letters = letters
        self.onLetterTap = onLetterTap
    }

    var body: some View {
        VStack {
            Spacer() // Push alphabet to vertical center

            VStack(spacing: 2) {
                ForEach(letters, id: \.self) { letter in
                    Text(letter)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#5680ff"))
                        .frame(width: 28, height: letterHeight)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let letterIndex = letterIndexFromLocation(value.location.y, totalHeight: CGFloat(letters.count) * letterHeight)
                        if letterIndex >= 0 && letterIndex < letters.count {
                            let letter = letters[letterIndex]
                            if letter != currentLetter {
                                currentLetter = letter
                                onLetterTap(letter)
                            }
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        currentLetter = nil
                    }
            )

            Spacer() // Push alphabet to vertical center
        }
        .frame(width: 28)
    }
    
    private var letterHeight: CGFloat { 16 }
    
    private func letterIndexFromLocation(_ y: CGFloat, totalHeight: CGFloat) -> Int {
        // Account for the Spacer at top - letters are centered vertically
        // Estimate the top offset based on available space
        let index = Int(y / letterHeight)
        return max(0, min(letters.count - 1, index))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        HStack {
            // Simulated content list
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(["A", "B", "C", "D", "E", "F", "G", "H"], id: \.self) { letter in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(letter)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)

                            ForEach(1...3, id: \.self) { index in
                                Text("\(letter)dam Smith \(index)")
                                    .font(.system(size: 17))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.trailing, 28) // Space for scrubber
            }

            // Alphabet scrubber overlay
            AlphabetScrubber { letter in
                print("Tapped letter: \(letter)")
            }
        }
    }
}
