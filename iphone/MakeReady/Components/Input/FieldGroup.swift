//
//  FieldGroup.swift
//  MakeReady
//
//  Field group container for styling multiple inputs
//

import SwiftUI

// MARK: - Field Group

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
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - Field Group Helpers

// 1px divider for field groups
struct FieldGroupDivider: View {
    var inset: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(height: 1)
            .padding(.leading, inset)
    }
}

// Text description for field groups
struct FieldGroupDescription: View {
    let text: String
    var isDisabled: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(.white.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .opacity(isDisabled ? 0.5 : 1.0)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 20) {
            // Example with dividers
            FieldGroup {
                Text("Item 1")
                    .padding()
                FieldGroupDivider()
                Text("Item 2")
                    .padding()
                FieldGroupDivider()
                Text("Item 3")
                    .padding()
            }

            // Example with description
            FieldGroup {
                Text("Setting")
                    .padding()
                FieldGroupDivider()
                FieldGroupDescription(text: "This is a description explaining the setting above.")
            }
        }
        .padding()
    }
}
