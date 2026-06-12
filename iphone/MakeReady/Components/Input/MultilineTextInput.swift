//
//  MultilineTextInput.swift
//  MakeReady
//
//  Multi-line text input field with floating label (matches TextInput style)
//

import SwiftUI

struct MultilineTextInput: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 130
    var autocorrect: Bool = false
    @FocusState private var isFocused: Bool

    private var isFloatingUp: Bool {
        isFocused || !text.isEmpty
    }

    var body: some View {
        // Text editor — fixed position, label overlaid absolutely
        TextEditor(text: $text)
            .font(Typography.s17)
            .foregroundColor(.white)
            .tint(Color.brandPrimary)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .autocorrectionDisabled(!autocorrect)
            .background(Color.clear)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .focused($isFocused)
            .overlay(alignment: .topLeading) {
                // Floating label — absolute positioned, doesn't affect layout
                Text(placeholder)
                    .font(.system(size: isFloatingUp ? 12 : 17, weight: .regular))
                    .foregroundColor(
                        isFocused ? Color.brandPrimary : .white.opacity(isFloatingUp ? 0.5 : 0.35)
                    )
                    .padding(.leading, 16)
                    .offset(y: isFloatingUp ? 2 : 12)
                    .animation(Motion.settle, value: isFloatingUp)
                    .allowsHitTesting(false)
            }
        .frame(minHeight: minHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 20) {
            // Empty multiline input
            FieldGroup {
                MultilineTextInput(
                    placeholder: "Describe the purpose of the group",
                    text: .constant("")
                )
            }
            .padding(.horizontal, 16)

            // Multiline input with text (label floats up)
            FieldGroup {
                MultilineTextInput(
                    placeholder: "Describe the purpose of the group",
                    text: .constant("This is a group for people who love coding and want to build amazing apps together.")
                )
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.top, 40)
    }
}
