//
//  ActionButton.swift
//  MakeReady
//
//  Reusable button component with multiple variants
//

import SwiftUI

enum ActionButtonVariant {
    case purple         // Purple background with label
    case purpleIcon     // Purple background, icon only
    case white          // White 10% background with label
    case whiteIcon      // White 10% background, icon only
    case whitePurple    // Solid white background, purple icon (icon only)
    case swipeLarge     // Large variant for swipeable cards (48×48px, icon only, accepts custom size/opacity)
    case circleBlur     // 64×64 circle, white 5% bg with backdrop blur, white 24px icon
}

struct ActionButton: View {
    let label: String?
    let icon: String?
    let variant: ActionButtonVariant
    let action: () -> Void

    // Optional parameters for swipeLarge variant (progressive reveal)
    let customSize: CGFloat?      // For animated size changes
    let customIconSize: CGFloat?  // For animated icon size
    let customOpacity: Double?    // For fade-in animation

    // Convenience initializer for label + icon
    init(
        label: String,
        icon: String? = nil,
        variant: ActionButtonVariant = .white,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.icon = icon
        self.variant = variant
        self.action = action
        self.customSize = nil
        self.customIconSize = nil
        self.customOpacity = nil
    }

    // Convenience initializer for icon only
    init(
        icon: String,
        variant: ActionButtonVariant = .whiteIcon,
        action: @escaping () -> Void
    ) {
        self.label = nil
        self.icon = icon
        self.variant = variant
        self.action = action
        self.customSize = nil
        self.customIconSize = nil
        self.customOpacity = nil
    }

    // Convenience initializer for swipeLarge with animated properties
    init(
        icon: String,
        variant: ActionButtonVariant = .swipeLarge,
        size: CGFloat,
        iconSize: CGFloat,
        opacity: Double,
        action: @escaping () -> Void
    ) {
        self.label = nil
        self.icon = icon
        self.variant = variant
        self.action = action
        self.customSize = size
        self.customIconSize = iconSize
        self.customOpacity = opacity
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Icon (before label)
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: effectiveIconSize, weight: .regular))
                        .foregroundColor(iconColor)
                        .frame(width: effectiveIconSize, height: effectiveIconSize)
                }

                // Label
                if let label = label {
                    Text(label)
                        .font(Typography.s12)
                        .foregroundColor(labelColor)
                        .tracking(0.1)
                }
            }
            .frame(height: effectiveHeight)
            .frame(width: effectiveWidth)
            .padding(.horizontal, isIconOnly ? 0 : 16)
            .background {
                if variant == .circleBlur {
                    RoundedRectangle(cornerRadius: effectiveCornerRadius)
                        .fill(.ultraThinMaterial)
                } else {
                    RoundedRectangle(cornerRadius: effectiveCornerRadius)
                        .fill(backgroundColor)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: effectiveCornerRadius))
            .opacity(effectiveOpacity)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var isIconOnly: Bool {
        icon != nil && label == nil
    }

    private var effectiveHeight: CGFloat {
        if variant == .swipeLarge, let size = customSize {
            return size
        }
        if variant == .circleBlur { return 64 }
        return 32
    }

    private var effectiveWidth: CGFloat? {
        if variant == .swipeLarge, let size = customSize {
            return size
        }
        if variant == .circleBlur { return 64 }
        return isIconOnly ? 32 : nil
    }

    private var effectiveIconSize: CGFloat {
        if variant == .swipeLarge, let iconSize = customIconSize {
            return iconSize
        }
        if variant == .circleBlur { return 24 }
        return 14
    }

    private var effectiveCornerRadius: CGFloat {
        if variant == .swipeLarge, let size = customSize {
            return size / 2  // Fully rounded
        }
        if variant == .circleBlur { return 32 }
        return isIconOnly ? 16 : 30
    }

    private var effectiveOpacity: Double {
        if variant == .swipeLarge, let opacity = customOpacity {
            return opacity
        }
        return 1.0
    }

    private var backgroundColor: Color {
        switch variant {
        case .purple, .purpleIcon:
            return Color.brandPrimary
        case .white, .whiteIcon, .swipeLarge:
            return Color.white.opacity(0.1)
        case .whitePurple:
            return Color.white
        case .circleBlur:
            return Color.white.opacity(0.05)  // Handled by background builder
        }
    }

    private var iconColor: Color {
        switch variant {
        case .whitePurple:
            return Color.brandPrimary
        case .purple, .purpleIcon, .white, .whiteIcon, .swipeLarge, .circleBlur:
            return Color.white
        }
    }

    private var labelColor: Color {
        switch variant {
        case .whitePurple:
            return Color.brandPrimary
        case .purple, .purpleIcon, .white, .whiteIcon, .swipeLarge, .circleBlur:
            return Color.white
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
                    .font(Typography.s13Semibold)
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                HStack(spacing: 12) {
                    ActionButton(label: "Poll", icon: "chart.bar.fill", variant: .purple) {
                        print("Poll tapped")
                    }

                    ActionButton(label: "Invite", variant: .purple) {
                        print("Invite tapped")
                    }

                    ActionButton(icon: "chart.bar.fill", variant: .purpleIcon) {
                        print("Chart tapped")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("White variant")
                    .font(Typography.s13Semibold)
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                HStack(spacing: 12) {
                    ActionButton(label: "Poll", icon: "chart.bar.fill", variant: .white) {
                        print("Poll tapped")
                    }

                    ActionButton(label: "Settings", variant: .white) {
                        print("Settings tapped")
                    }

                    ActionButton(icon: "chart.bar.fill", variant: .whiteIcon) {
                        print("Chart tapped")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Circle blur variant")
                    .font(Typography.s13Semibold)
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                HStack(spacing: 12) {
                    ActionButton(icon: "bubble.left.and.bubble.right", variant: .circleBlur) {
                        print("Chat tapped")
                    }

                    ActionButton(icon: "phone", variant: .circleBlur) {
                        print("Phone tapped")
                    }

                    ActionButton(icon: "envelope", variant: .circleBlur) {
                        print("Email tapped")
                    }
                }
            }

            Spacer()
        }
        .padding(20)
    }
}
