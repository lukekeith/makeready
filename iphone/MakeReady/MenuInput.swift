//
//  MenuInput.swift
//  MakeReady
//
//  Menu input with dropdown-style selection
//

import SwiftUI

struct MenuInput: View {
    let label: String
    let options: [String]
    @Binding var selectedOption: String
    @State private var showPicker = false

    var body: some View {
        Button(action: {
            showPicker = true
        }) {
            HStack(spacing: 8) {
                // Label
                Text(label)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white)

                Spacer()

                // Selected value
                Text(selectedOption)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white)

                // Chevron
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showPicker) {
            MenuPickerSheet(
                options: options,
                selectedOption: $selectedOption,
                isPresented: $showPicker
            )
        }
    }
}

// Sheet for menu picker
struct MenuPickerSheet: View {
    let options: [String]
    @Binding var selectedOption: String
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            selectedOption = option
                            isPresented = false
                        }) {
                            HStack {
                                Text(option)
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(.white)

                                Spacer()

                                if option == selectedOption {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(Color(hex: "#6c47ff"))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        if option != options.last {
                            Divider()
                                .background(Color.white.opacity(0.1))
                        }
                    }
                }
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 20)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(Color(hex: "#6c47ff"))
                }
            }
        }
        .presentationDetents([.height(400)])
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 20) {
            FieldGroup {
                MenuInput(
                    label: "Max members",
                    options: ["Unlimited", "10", "25", "50", "100"],
                    selectedOption: .constant("Unlimited")
                )
            }
            .padding(.horizontal, 16)

            FieldGroup {
                MenuInput(
                    label: "Visibility",
                    options: ["Public", "Private", "Hidden"],
                    selectedOption: .constant("Public")
                )
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.top, 40)
    }
}
