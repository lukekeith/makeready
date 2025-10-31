//
//  LargeTextInput.swift
//  MakeReady
//
//  Large text input with label above and bottom border line
//  Supports various input types with formatting and validation
//

import SwiftUI

struct LargeTextInput: View {
    let label: String
    let inputType: InputType
    @Binding var text: String
    @Binding var validationError: String?
    @FocusState private var isFocused: Bool

    // Internal state for formatted display
    @State private var displayText: String = ""

    // Initialize with input type
    init(
        label: String,
        inputType: InputType = .alphanumeric,
        text: Binding<String>,
        validationError: Binding<String?> = .constant(nil)
    ) {
        self.label = label
        self.inputType = inputType
        self._text = text
        self._validationError = validationError
        self._displayText = State(initialValue: text.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.5))
                .tracking(0.1)

            // Input area
            HStack(spacing: 0) {
                // Left icon (for currency)
                if inputType == .currency, let icon = inputType.icon {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 32, alignment: .leading)
                }

                // Text field
                TextField("", text: $displayText)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(.white)
                    .tracking(-0.15)
                    .accentColor(Color(hex: "#6c47ff"))
                    .keyboardType(inputType.keyboardType)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused($isFocused)
                    .frame(height: 34)
                    .onChange(of: displayText) { oldValue, newValue in
                        handleTextChange(newValue)
                    }
                    .onChange(of: isFocused) { oldValue, newValue in
                        if !newValue {
                            // Validate when focus is lost
                            validate()
                        }
                    }

                // Right icon (for percentage, email, phone - if not currency)
                if inputType != .currency, let icon = inputType.icon {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 32, alignment: .trailing)
                }
            }

            // Bottom line
            Rectangle()
                .fill(borderColor)
                .frame(height: 1)

            // Error message
            if let error = validationError {
                Text(error)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(hex: "#FF4759"))
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
        .onAppear {
            // Initialize display text from bound value
            displayText = InputFormatter.format(text, for: inputType)
        }
    }

    // Border color based on focus and error state
    private var borderColor: Color {
        if validationError != nil {
            return Color(hex: "#FF4759") // Error red
        } else if isFocused {
            return Color(hex: "#6c47ff") // Focused purple
        } else {
            return Color.white.opacity(0.2) // Default
        }
    }

    // Handle text changes with formatting
    private func handleTextChange(_ newValue: String) {
        // Format the input
        let formatted = InputFormatter.format(newValue, for: inputType)

        // Update display text if different
        if formatted != displayText {
            displayText = formatted
        }

        // Get raw value for binding
        let rawValue = InputFormatter.unformat(formatted, for: inputType)

        // Update bound value
        text = rawValue

        // Clear validation error when user starts typing
        if validationError != nil {
            validationError = nil
        }
    }

    // Validate input
    private func validate() {
        validationError = InputValidator.validate(text, for: inputType)
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: 32) {
                Text("Large Text Input with Data Types")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)

                // Alphanumeric
                VStack(alignment: .leading, spacing: 12) {
                    Text("Alphanumeric")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    LargeTextInput(label: "Full name", inputType: .alphanumeric, text: .constant(""))
                }
                .padding(.horizontal, 16)

                // Phone
                VStack(alignment: .leading, spacing: 12) {
                    Text("Phone")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    LargeTextInput(label: "Phone", inputType: .phone, text: .constant(""))
                }
                .padding(.horizontal, 16)

                // Integer
                VStack(alignment: .leading, spacing: 12) {
                    Text("Integer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    LargeTextInput(label: "Age", inputType: .integer, text: .constant(""))
                }
                .padding(.horizontal, 16)

                // Float
                VStack(alignment: .leading, spacing: 12) {
                    Text("Float")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    LargeTextInput(label: "Weight (lbs)", inputType: .float, text: .constant(""))
                }
                .padding(.horizontal, 16)

                // Currency
                VStack(alignment: .leading, spacing: 12) {
                    Text("Currency")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    LargeTextInput(label: "Amount", inputType: .currency, text: .constant(""))
                }
                .padding(.horizontal, 16)

                // Email
                VStack(alignment: .leading, spacing: 12) {
                    Text("Email")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    LargeTextInput(label: "Email", inputType: .email, text: .constant(""))
                }
                .padding(.horizontal, 16)

                // Percentage
                VStack(alignment: .leading, spacing: 12) {
                    Text("Percentage")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    LargeTextInput(label: "Completion", inputType: .percentage, text: .constant(""))
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 80)
            }
            .padding(.top, 40)
        }
    }
}
