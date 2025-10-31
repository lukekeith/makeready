//
//  MultilineTextInput.swift
//  MakeReady
//
//  Multi-line text input field (text area)
//

import SwiftUI

struct MultilineTextInput: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 130

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }

            // Text editor
            TextEditor(text: $text)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(minHeight: minHeight)
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

            // Multiline input with text
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
