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
    let autocorrect: Bool
    let floatingLabel: Bool
    /// Optional hard cap on the number of characters. When set, input beyond this
    /// length is truncated at entry (nil = no limit; existing call sites unchanged).
    let maxLength: Int?
    @Binding var text: String
    @Binding var validationError: String?
    @FocusState private var isFocused: Bool

    // Internal state for formatted display
    @State private var displayText: String = ""

    // Placeholder variant (existing, backward compatible)
    init(
        placeholder: String,
        inputType: InputType = .alphanumeric,
        autocorrect: Bool = false,
        maxLength: Int? = nil,
        text: Binding<String>,
        validationError: Binding<String?> = .constant(nil),
        keyboardType: UIKeyboardType = .default
    ) {
        self.placeholder = placeholder
        self.label = nil
        self.icon = nil
        self.iconColor = Color.brandPrimary
        self.inputType = inputType
        self.autocorrect = autocorrect
        self.floatingLabel = false
        self.maxLength = maxLength
        self._text = text
        self._validationError = validationError
        self._displayText = State(initialValue: text.wrappedValue)
    }

    // Labeled variant (with optional icon, backward compatible)
    init(
        label: String,
        icon: String? = nil,
        iconColor: Color = Color.brandPrimary,
        inputType: InputType = .alphanumeric,
        autocorrect: Bool = false,
        maxLength: Int? = nil,
        text: Binding<String>,
        validationError: Binding<String?> = .constant(nil),
        keyboardType: UIKeyboardType = .default
    ) {
        self.placeholder = nil
        self.label = label
        self.icon = icon
        self.iconColor = iconColor
        self.inputType = inputType
        self.autocorrect = autocorrect
        self.floatingLabel = false
        self.maxLength = maxLength
        self._text = text
        self._validationError = validationError
        self._displayText = State(initialValue: text.wrappedValue)
    }

    // Floating label variant
    init(
        floatingLabel: String,
        icon: String? = nil,
        iconColor: Color = Color.brandPrimary,
        inputType: InputType = .alphanumeric,
        autocorrect: Bool = false,
        maxLength: Int? = nil,
        text: Binding<String>,
        validationError: Binding<String?> = .constant(nil),
        keyboardType: UIKeyboardType = .default
    ) {
        self.placeholder = floatingLabel
        self.label = nil
        self.icon = icon
        self.iconColor = iconColor
        self.inputType = inputType
        self.autocorrect = autocorrect
        self.floatingLabel = true
        self.maxLength = maxLength
        self._text = text
        self._validationError = validationError
        self._displayText = State(initialValue: text.wrappedValue)
    }

    private var isFloatingUp: Bool {
        isFocused || !displayText.isEmpty
    }

    var body: some View {
        if floatingLabel {
            floatingLabelBody
        } else {
            standardBody
        }
    }

    // MARK: - Floating Label Variant

    private var floatingLabelBody: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(Typography.s16)
                    .foregroundColor(validationError != nil ? Color.error : iconColor)
                    .frame(width: 24)
            }

            // Text field — fixed position, label overlaid absolutely
            TextField("", text: $displayText)
                .font(Typography.s17)
                .foregroundColor(.white)
                .accentColor(Color.brandPrimary)
                .keyboardType(inputType.keyboardType)
                .autocapitalization(.none)
                .autocorrectionDisabled(!autocorrect)
                .focused($isFocused)
                .onChange(of: displayText) { oldValue, newValue in
                    handleTextChange(newValue)
                }
                .onChange(of: isFocused) { oldValue, newValue in
                    if !newValue {
                        validate()
                    }
                }
                .overlay(alignment: .leading) {
                    // Floating label — absolute positioned, doesn't affect layout
                    if let placeholder = placeholder {
                        Text(placeholder)
                            .font(.system(size: isFloatingUp ? 12 : 17, weight: .regular))
                            .foregroundColor(
                                isFocused ? Color.brandPrimary : .white.opacity(isFloatingUp ? 0.5 : 0.35)
                            )
                            .offset(y: isFloatingUp ? -18 : 0)
                            .animation(Motion.settle, value: isFloatingUp)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
        .onAppear {
            displayText = InputFormatter.format(text, for: inputType)
        }
        .onChange(of: text) { _, newValue in
            let formatted = InputFormatter.format(newValue, for: inputType)
            if formatted != displayText {
                displayText = formatted
            }
        }
    }

    // MARK: - Standard Variants (placeholder + labeled)

    private var standardBody: some View {
        HStack(spacing: 12) {
            // Icon (if provided and labeled variant)
            if let icon = icon, label != nil {
                Image(systemName: icon)
                    .font(Typography.s16)
                    .foregroundColor(validationError != nil ? Color.error : iconColor)
                    .frame(width: 24)
            }

            // Label (if provided)
            if let label = label {
                Text(label)
                    .font(Typography.s17)
                    .foregroundColor(isFocused ? .white : .white.opacity(0.7))

                Spacer()
            }

            // Text field
            TextField("", text: $displayText, prompt: placeholder != nil ? Text(placeholder!).foregroundColor(.white.opacity(isFocused ? 0.25 : 0.5)) : nil)
                .font(Typography.s17)
                .foregroundColor(label != nil ? .white.opacity(0.7) : .white)
                .accentColor(Color.brandPrimary)
                .keyboardType(inputType.keyboardType)
                .autocapitalization(.none)
                .autocorrectionDisabled(!autocorrect)
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
        .onChange(of: text) { _, newValue in
            // Sync display text when the binding changes externally (e.g. from .onAppear of parent)
            let formatted = InputFormatter.format(newValue, for: inputType)
            if formatted != displayText {
                displayText = formatted
            }
        }
    }

    // Handle text changes with formatting
    private func handleTextChange(_ newValue: String) {
        // Enforce an optional hard character cap at entry so an over-long value can't
        // reach the field (or a save that would reject it). nil = no limit.
        var capped = newValue
        if let maxLength, capped.count > maxLength {
            capped = String(capped.prefix(maxLength))
        }

        // Format the input
        let formatted = InputFormatter.format(capped, for: inputType)

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

        VStack(spacing: 20) {
            Text("Placeholder variant")
                .font(Typography.s13Semibold)
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
                .font(Typography.s13Semibold)
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

            Text("Floating label variant")
                .font(Typography.s13Semibold)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 20)

            // Floating label - empty (label shows as placeholder)
            FieldGroup {
                TextInput(floatingLabel: "Group Name", text: .constant(""))
                Divider().background(Color.white.opacity(0.1))
                TextInput(floatingLabel: "Email Address", inputType: .email, text: .constant(""))
            }
            .padding(.horizontal, 16)

            // Floating label - with value (label floats above)
            FieldGroup {
                TextInput(floatingLabel: "Group Name", text: .constant("Young Professionals"))
                Divider().background(Color.white.opacity(0.1))
                TextInput(floatingLabel: "Email Address", inputType: .email, text: .constant("john@example.com"))
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.top, 40)
    }
}
