//
//  TextInput.swift
//  MakeReady
//
//  Single-line text input field with support for data types and validation
//

import SwiftUI

struct TextInput: View {
    let placeholder: String?
    let label: String?
    let icon: String?
    let iconColor: Color
    let inputType: InputType
    @Binding var text: String
    @Binding var validationError: String?
    @FocusState private var isFocused: Bool

    // Internal state for formatted display
    @State private var displayText: String = ""

    // Placeholder variant (existing, backward compatible)
    init(
        placeholder: String,
        inputType: InputType = .alphanumeric,
        text: Binding<String>,
        validationError: Binding<String?> = .constant(nil),
        keyboardType: UIKeyboardType = .default
    ) {
        self.placeholder = placeholder
        self.label = nil
        self.icon = nil
        self.iconColor = Color(hex: "#6c47ff")
        self.inputType = inputType
        self._text = text
        self._validationError = validationError
        self._displayText = State(initialValue: text.wrappedValue)
    }

    // Labeled variant (with optional icon, backward compatible)
    init(
        label: String,
        icon: String? = nil,
        iconColor: Color = Color(hex: "#6c47ff"),
        inputType: InputType = .alphanumeric,
        text: Binding<String>,
        validationError: Binding<String?> = .constant(nil),
        keyboardType: UIKeyboardType = .default
    ) {
        self.placeholder = nil
        self.label = label
        self.icon = icon
        self.iconColor = iconColor
        self.inputType = inputType
        self._text = text
        self._validationError = validationError
        self._displayText = State(initialValue: text.wrappedValue)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon (if provided and labeled variant)
            if let icon = icon, label != nil {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(validationError != nil ? Color(hex: "#FF4759") : iconColor)
                    .frame(width: 24)
            }

            // Label (if provided)
            if let label = label {
                Text(label)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white)

                Spacer()
            }

            // Text field
            TextField("", text: $displayText, prompt: placeholder != nil ? Text(placeholder!).foregroundColor(.white.opacity(0.5)) : nil)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(label != nil ? .white.opacity(0.7) : .white)
                .accentColor(Color(hex: "#6c47ff"))
                .keyboardType(inputType.keyboardType)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .multilineTextAlignment(label != nil ? .trailing : .leading)
                .focused($isFocused)
                .onChange(of: displayText) { oldValue, newValue in
                    handleTextChange(newValue)
                }
                .onChange(of: isFocused) { oldValue, newValue in
                    if !newValue {
                        validate()
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, label != nil ? 12 : 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if label != nil {
                isFocused = true
            }
        }
        .onAppear {
            // Initialize display text from bound value
            displayText = InputFormatter.format(text, for: inputType)
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

// Wrapper for field groups (multiple inputs grouped together)
struct FieldGroup<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 20) {
            Text("Placeholder variant")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)

            // Placeholder variant - empty
            FieldGroup {
                TextInput(placeholder: "Enter group name", text: .constant(""))
            }
            .padding(.horizontal, 16)

            // Placeholder variant - with value
            FieldGroup {
                TextInput(placeholder: "Enter group name", text: .constant("My Group"))
            }
            .padding(.horizontal, 16)

            Text("Labeled variant")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 20)

            // Labeled variant with icon - empty
            FieldGroup {
                TextInput(label: "Name", icon: "person.fill", text: .constant(""))
                Divider().background(Color.white.opacity(0.1)).padding(.leading, 52)
                TextInput(label: "Email", icon: "envelope.fill", inputType: .email, text: .constant(""))
            }
            .padding(.horizontal, 16)

            // Labeled variant with phone formatting
            FieldGroup {
                TextInput(label: "Phone", icon: "phone.fill", inputType: .phone, text: .constant(""))
                Divider().background(Color.white.opacity(0.1)).padding(.leading, 52)
                TextInput(label: "City", icon: "location.fill", text: .constant("New York"))
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.top, 40)
    }
}
