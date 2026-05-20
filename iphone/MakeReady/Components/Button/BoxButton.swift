//
//  BoxButton.swift
//  MakeReady
//
//  Flexible button component with comprehensive variant support
//

import SwiftUI

enum BoxButtonVariant {
    case primary      // Purple #6C47FF background with white 100% text/icon
    case secondary    // White 5% background with white 100% text/icon
    case destructive  // White 20% background with #FF4759 text/icon
    case disabled     // White 5% background with white 20% text/icon
}

enum BoxButtonStyle {
    case solid   // Fill with color
    case border  // 2px border with color
}

enum BoxButtonSize {
    case lg  // Large: 16px vertical, 24px horizontal padding
    case md  // Medium: 12px vertical, 20px horizontal padding
    case sm  // Small: 8px vertical, 16px horizontal padding
}

enum BoxButtonIconPosition {
    case left
    case right
    case none
}

struct BoxButton: View {
    let label: String?
    let icon: String?
    let iconPosition: BoxButtonIconPosition
    let variant: BoxButtonVariant
    let style: BoxButtonStyle
    let size: BoxButtonSize
    let fullWidth: Bool
    let iconOpacity: Double
    let labelOpacity: Double
    let action: () -> Void

    // Convenience initializer with all options
    init(
        action: @escaping () -> Void,
        label: String? = nil,
        icon: String? = nil,
        iconPosition: BoxButtonIconPosition = .none,
        variant: BoxButtonVariant = .primary,
        style: BoxButtonStyle = .solid,
        size: BoxButtonSize = .md,
        fullWidth: Bool = false,
        iconOpacity: Double = 1.0,
        labelOpacity: Double = 1.0
    ) {
        self.action = action
        self.label = label
        self.icon = icon
        self.iconPosition = iconPosition
        self.variant = variant
        self.style = style
        self.size = size
        self.fullWidth = fullWidth
        self.iconOpacity = iconOpacity
        self.labelOpacity = labelOpacity
    }

    private var isIconOnly: Bool {
        label == nil && icon != nil
    }

    var body: some View {
        Button(action: action) {
            Group {
                if isIconOnly {
                    Image(systemName: icon!)
                        .font(.system(size: iconSize, weight: .regular))
                        .foregroundColor(foregroundColor)
                        .opacity(iconOpacity)
                        .frame(
                            maxWidth: fullWidth ? .infinity : buttonHeight,
                            minHeight: buttonHeight,
                            maxHeight: buttonHeight
                        )
                } else {
                    HStack(spacing: iconSpacing) {
                        // Icon on left
                        if iconPosition == .left, let icon = icon {
                            Image(systemName: icon)
                                .font(.system(size: iconSize, weight: .regular))
                                .foregroundColor(foregroundColor)
                                .opacity(iconOpacity)
                        }

                        // Label
                        if let label = label {
                            Text(label)
                                .font(.system(size: fontSize, weight: .semibold))
                                .foregroundColor(foregroundColor)
                                .opacity(labelOpacity)
                        }

                        // Push icon to far right when fullWidth with label + right icon
                        if fullWidth && label != nil && iconPosition == .right && icon != nil {
                            Spacer()
                        }

                        // Icon on right
                        if iconPosition == .right, let icon = icon {
                            Image(systemName: icon)
                                .font(.system(size: iconSize, weight: .regular))
                                .foregroundColor(foregroundColor)
                                .opacity(iconOpacity)
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .frame(height: buttonHeight)
                    .frame(maxWidth: fullWidth ? .infinity : nil)
                }
            }
            .background(backgroundColor)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: style == .border ? 2 : 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(variant == .disabled)
    }

    // MARK: - Size Configuration

    private var buttonHeight: CGFloat {
        switch size {
        case .lg: return 56
        case .md: return 46
        case .sm: return 34
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .lg: return 24
        case .md: return 20
        case .sm: return 16
        }
    }

    private var fontSize: CGFloat {
        switch size {
        case .lg: return 17
        case .md: return 15
        case .sm: return 13
        }
    }

    private var iconSize: CGFloat {
        switch size {
        case .lg: return 20
        case .md: return 16
        case .sm: return 14
        }
    }

    private var iconSpacing: CGFloat {
        switch size {
        case .lg: return 12
        case .md: return 10
        case .sm: return 8
        }
    }

    // MARK: - Color Configuration

    private var backgroundColor: Color {
        if style == .border {
            return Color.clear
        }

        switch variant {
        case .primary:
            return Color(hex: "#6C47FF")
        case .secondary:
            return Color.white.opacity(0.05)
        case .destructive:
            return Color.white.opacity(0.20)
        case .disabled:
            return Color.white.opacity(0.05)
        }
    }

    private var borderColor: Color {
        guard style == .border else { return Color.clear }

        switch variant {
        case .primary:
            return Color(hex: "#6C47FF")
        case .secondary:
            return Color.white.opacity(1.0)
        case .destructive:
            return Color(hex: "#FF4759")
        case .disabled:
            return Color.white.opacity(0.20)
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return Color.white
        case .secondary:
            return Color.white
        case .destructive:
            return Color(hex: "#FF4759")
        case .disabled:
            return Color.white.opacity(0.20)
        }
    }
}

#Preview("Full button") {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: 32) {
                // Primary variants
                VStack(alignment: .leading, spacing: 12) {
                    Text("Primary")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    VStack(spacing: 12) {
                        BoxButton(
                            action: { print("Primary tapped") },
                            label: "Primary Button",
                            variant: .primary,
                            style: .solid,
                            size: .lg
                        )

                        BoxButton(
                            action: { print("Primary with icon tapped") },
                            label: "Primary with Icon",
                            icon: "plus",
                            iconPosition: .left,
                            variant: .primary,
                            style: .solid,
                            size: .md
                        )

                        BoxButton(
                            action: { print("Primary border tapped") },
                            label: "Primary Border",
                            variant: .primary,
                            style: .border,
                            size: .sm
                        )
                    }
                }

                // Secondary variants
                VStack(alignment: .leading, spacing: 12) {
                    Text("Secondary")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    VStack(spacing: 12) {
                        BoxButton(
                            action: { print("Secondary tapped") },
                            label: "Secondary Button",
                            variant: .secondary,
                            style: .solid,
                            size: .lg
                        )

                        BoxButton(
                            action: { print("Secondary with icon tapped") },
                            label: "Secondary with Icon",
                            icon: "arrow.right",
                            iconPosition: .right,
                            variant: .secondary,
                            style: .solid,
                            size: .md
                        )

                        BoxButton(
                            action: { print("Secondary border tapped") },
                            label: "Secondary Border",
                            variant: .secondary,
                            style: .border,
                            size: .sm
                        )
                    }
                }

                // Destructive variants
                VStack(alignment: .leading, spacing: 12) {
                    Text("Destructive")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    VStack(spacing: 12) {
                        BoxButton(
                            action: { print("Delete tapped") },
                            label: "Delete",
                            icon: "trash",
                            iconPosition: .left,
                            variant: .destructive,
                            style: .solid,
                            size: .lg
                        )

                        BoxButton(
                            action: { print("Remove tapped") },
                            label: "Remove",
                            variant: .destructive,
                            style: .border,
                            size: .md
                        )
                    }
                }

                // Disabled variants
                VStack(alignment: .leading, spacing: 12) {
                    Text("Disabled")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    VStack(spacing: 12) {
                        BoxButton(
                            action: { print("Disabled tapped") },
                            label: "Disabled Button",
                            variant: .disabled,
                            style: .solid,
                            size: .lg
                        )

                        BoxButton(
                            action: { print("Disabled border tapped") },
                            label: "Disabled Border",
                            variant: .disabled,
                            style: .border,
                            size: .md
                        )
                    }
                }

                // Full width examples
                VStack(alignment: .leading, spacing: 12) {
                    Text("Full Width")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    VStack(spacing: 12) {
                        BoxButton(
                            action: { print("Full width tapped") },
                            label: "Full Width Primary",
                            variant: .primary,
                            style: .solid,
                            size: .lg,
                            fullWidth: true
                        )

                        BoxButton(
                            action: { print("Full width secondary tapped") },
                            label: "Full Width Secondary",
                            icon: "checkmark",
                            iconPosition: .right,
                            variant: .secondary,
                            style: .border,
                            size: .md,
                            fullWidth: true
                        )
                    }
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
    }
}

#Preview("Icon only") {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: 32) {
                // Primary icon only
                VStack(alignment: .leading, spacing: 12) {
                    Text("Primary")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    HStack(spacing: 12) {
                        BoxButton(
                            action: { print("lg") },
                            icon: "plus",
                            iconPosition: .left,
                            variant: .primary,
                            style: .solid,
                            size: .lg
                        )
                        BoxButton(
                            action: { print("md") },
                            icon: "plus",
                            iconPosition: .left,
                            variant: .primary,
                            style: .solid,
                            size: .md
                        )
                        BoxButton(
                            action: { print("sm") },
                            icon: "plus",
                            iconPosition: .left,
                            variant: .primary,
                            style: .solid,
                            size: .sm
                        )
                    }

                    HStack(spacing: 12) {
                        BoxButton(
                            action: { print("lg border") },
                            icon: "plus",
                            iconPosition: .left,
                            variant: .primary,
                            style: .border,
                            size: .lg
                        )
                        BoxButton(
                            action: { print("md border") },
                            icon: "plus",
                            iconPosition: .left,
                            variant: .primary,
                            style: .border,
                            size: .md
                        )
                        BoxButton(
                            action: { print("sm border") },
                            icon: "plus",
                            iconPosition: .left,
                            variant: .primary,
                            style: .border,
                            size: .sm
                        )
                    }
                }

                // Secondary icon only
                VStack(alignment: .leading, spacing: 12) {
                    Text("Secondary")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    HStack(spacing: 12) {
                        BoxButton(
                            action: { print("lg") },
                            icon: "trash",
                            iconPosition: .left,
                            variant: .secondary,
                            style: .solid,
                            size: .lg
                        )
                        BoxButton(
                            action: { print("md") },
                            icon: "trash",
                            iconPosition: .left,
                            variant: .secondary,
                            style: .solid,
                            size: .md
                        )
                        BoxButton(
                            action: { print("sm") },
                            icon: "trash",
                            iconPosition: .left,
                            variant: .secondary,
                            style: .solid,
                            size: .sm
                        )
                    }

                    HStack(spacing: 12) {
                        BoxButton(
                            action: { print("lg border") },
                            icon: "xmark",
                            iconPosition: .left,
                            variant: .secondary,
                            style: .border,
                            size: .lg
                        )
                        BoxButton(
                            action: { print("md border") },
                            icon: "xmark",
                            iconPosition: .left,
                            variant: .secondary,
                            style: .border,
                            size: .md
                        )
                        BoxButton(
                            action: { print("sm border") },
                            icon: "xmark",
                            iconPosition: .left,
                            variant: .secondary,
                            style: .border,
                            size: .sm
                        )
                    }
                }

                // Destructive icon only
                VStack(alignment: .leading, spacing: 12) {
                    Text("Destructive")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    HStack(spacing: 12) {
                        BoxButton(
                            action: { print("lg") },
                            icon: "trash",
                            iconPosition: .left,
                            variant: .destructive,
                            style: .solid,
                            size: .lg
                        )
                        BoxButton(
                            action: { print("md") },
                            icon: "trash",
                            iconPosition: .left,
                            variant: .destructive,
                            style: .solid,
                            size: .md
                        )
                        BoxButton(
                            action: { print("sm") },
                            icon: "trash",
                            iconPosition: .left,
                            variant: .destructive,
                            style: .solid,
                            size: .sm
                        )
                    }
                }

                // Disabled icon only
                VStack(alignment: .leading, spacing: 12) {
                    Text("Disabled")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    HStack(spacing: 12) {
                        BoxButton(
                            action: { print("lg") },
                            icon: "gear",
                            iconPosition: .left,
                            variant: .disabled,
                            style: .solid,
                            size: .lg
                        )
                        BoxButton(
                            action: { print("md") },
                            icon: "gear",
                            iconPosition: .left,
                            variant: .disabled,
                            style: .solid,
                            size: .md
                        )
                        BoxButton(
                            action: { print("sm") },
                            icon: "gear",
                            iconPosition: .left,
                            variant: .disabled,
                            style: .solid,
                            size: .sm
                        )
                    }
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
    }
}
