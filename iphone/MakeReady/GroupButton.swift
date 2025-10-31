//
//  GroupButton.swift
//  MakeReady
//
//  Reusable button component with multiple variants
//

import SwiftUI

enum GroupButtonVariant {
    case purple         // Purple background with label
    case purpleIcon     // Purple background, icon only
    case white          // White 10% background with label
    case whiteIcon      // White 10% background, icon only
}

struct GroupButton: View {
    let label: String?
    let icon: String?
    let variant: GroupButtonVariant
    let action: () -> Void

    // Convenience initializer for label + icon
    init(
        label: String,
        icon: String? = nil,
        variant: GroupButtonVariant = .white,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.icon = icon
        self.variant = variant
        self.action = action
    }

    // Convenience initializer for icon only
    init(
        icon: String,
        variant: GroupButtonVariant = .whiteIcon,
        action: @escaping () -> Void
    ) {
        self.label = nil
        self.icon = icon
        self.variant = variant
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Icon (before label)
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white)
                        .frame(width: 14, height: 14)
                }

                // Label
                if let label = label {
                    Text(label)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white)
                        .tracking(0.1)
                }
            }
            .frame(height: 32)
            .frame(width: isIconOnly ? 32 : nil)
            .padding(.horizontal, isIconOnly ? 0 : 16)
            .background(backgroundColor)
            .cornerRadius(isIconOnly ? 16 : 30)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var isIconOnly: Bool {
        icon != nil && label == nil
    }

    private var backgroundColor: Color {
        switch variant {
        case .purple, .purpleIcon:
            return Color(hex: "#6c47ff")
        case .white, .whiteIcon:
            return Color.white.opacity(0.1)
        }
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Purple variant")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                HStack(spacing: 12) {
                    GroupButton(label: "Poll", icon: "chart.bar.fill", variant: .purple) {
                        print("Poll tapped")
                    }

                    GroupButton(label: "Invite", variant: .purple) {
                        print("Invite tapped")
                    }

                    GroupButton(icon: "chart.bar.fill", variant: .purpleIcon) {
                        print("Chart tapped")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("White variant")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                HStack(spacing: 12) {
                    GroupButton(label: "Poll", icon: "chart.bar.fill", variant: .white) {
                        print("Poll tapped")
                    }

                    GroupButton(label: "Settings", variant: .white) {
                        print("Settings tapped")
                    }

                    GroupButton(icon: "chart.bar.fill", variant: .whiteIcon) {
                        print("Chart tapped")
                    }
                }
            }

            Spacer()
        }
        .padding(20)
    }
}
