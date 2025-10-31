//
//  ToggleControl.swift
//  MakeReady
//
//  Toggle control with title and description
//

import SwiftUI

struct ToggleControl: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Title and description
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // Custom toggle matching Figma design
            CustomToggle(isOn: $isOn)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// Custom toggle component matching Figma design
struct CustomToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isOn.toggle()
            }
        }) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                // Background
                RoundedRectangle(cornerRadius: 40)
                    .fill(isOn ? Color.white : Color.white.opacity(0.5))
                    .frame(width: 63, height: 28)

                // Knob
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "#0d101a"))
                    .frame(width: 33, height: 21)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 3.5)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Wrapper for multiple toggle controls
struct ToggleGroup<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 20) {
            // Single toggle
            ToggleGroup {
                ToggleControl(
                    title: "Private",
                    description: "Only members can see members and their activity in the group.",
                    isOn: .constant(false)
                )
            }
            .padding(.horizontal, 16)

            // Multiple toggles grouped
            ToggleGroup {
                ToggleControl(
                    title: "Private",
                    description: "Only members can see members and their activity in the group.",
                    isOn: .constant(true)
                )

                Divider()
                    .background(Color.white.opacity(0.1))

                ToggleControl(
                    title: "Allow members to send invites",
                    description: "Enable this option to send invites from their mobile web portal",
                    isOn: .constant(true)
                )

                Divider()
                    .background(Color.white.opacity(0.1))

                ToggleControl(
                    title: "Send welcome message",
                    description: "Send a welcome message to every member when they join the group",
                    isOn: .constant(false)
                )
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.top, 40)
    }
}
