//
//  AgeRangeInput.swift
//  MakeReady
//
//  Age range input with single label and two side-by-side number pickers
//

import SwiftUI

struct AgeRangeInput: View {
    let label: String
    @Binding var minAge: String
    @Binding var maxAge: String

    // Computed options with validation
    var minOptions: [String] {
        let maxValue = Int(maxAge) ?? 99
        return (0...maxValue).map { "\($0)" }
    }

    var maxOptions: [String] {
        let minValue = Int(minAge) ?? 0
        return (minValue...99).map { "\($0)" }
    }

    @State private var showMinPicker = false
    @State private var showMaxPicker = false

    var body: some View {
        HStack(spacing: 4) {
            // Label
            Text(label)
                .font(Typography.s17)
                .foregroundColor(.white)

            Spacer()

            // Min age button
            Button(action: {
                showMinPicker = true
            }) {
                Text(minAge)
                    .font(Typography.s17)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .sheet(isPresented: $showMinPicker) {
                WheelPickerSheet(
                    label: "Age from",
                    options: minOptions,
                    selectedOption: $minAge,
                    isPresented: $showMinPicker
                )
            }

            // Max age button
            Button(action: {
                showMaxPicker = true
            }) {
                Text(maxAge)
                    .font(Typography.s17)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .sheet(isPresented: $showMaxPicker) {
                WheelPickerSheet(
                    label: "Age to",
                    options: maxOptions,
                    selectedOption: $maxAge,
                    isPresented: $showMaxPicker
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 20) {
            FieldGroup {
                AgeRangeInput(
                    label: "Age range",
                    minAge: .constant("18"),
                    maxAge: .constant("34")
                )
            }
            .padding(.horizontal, 16)
        }
    }
}
