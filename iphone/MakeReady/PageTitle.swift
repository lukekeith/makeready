//
//  PageTitle.swift
//  MakeReady
//
//  Navigation title component for secondary pages
//  Supports various configurations: icons, links, dropdown menu
//

import SwiftUI

struct PageTitle: View {
    // Content
    let title: String?
    let leftIcon: String?        // SF Symbol name (e.g., "chevron.left", "xmark")
    let leftLink: String?        // Text for left link (e.g., "Done")
    let rightIcon: String?       // SF Symbol name (e.g., "gearshape", "chevron.right")
    let rightLink: String?       // Text for right link (e.g., "Done")
    let showDropdown: Bool       // Show dropdown chevron next to title

    // Actions
    let onLeftIconTap: (() -> Void)?
    let onLeftLinkTap: (() -> Void)?
    let onRightIconTap: (() -> Void)?
    let onRightLinkTap: (() -> Void)?
    let onDropdownTap: (() -> Void)?

    // Default initializer with all options
    init(
        title: String? = nil,
        leftIcon: String? = nil,
        leftLink: String? = nil,
        rightIcon: String? = nil,
        rightLink: String? = nil,
        showDropdown: Bool = false,
        onLeftIconTap: (() -> Void)? = nil,
        onLeftLinkTap: (() -> Void)? = nil,
        onRightIconTap: (() -> Void)? = nil,
        onRightLinkTap: (() -> Void)? = nil,
        onDropdownTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.leftIcon = leftIcon
        self.leftLink = leftLink
        self.rightIcon = rightIcon
        self.rightLink = rightLink
        self.showDropdown = showDropdown
        self.onLeftIconTap = onLeftIconTap
        self.onLeftLinkTap = onLeftLinkTap
        self.onRightIconTap = onRightIconTap
        self.onRightLinkTap = onRightLinkTap
        self.onDropdownTap = onDropdownTap
    }

    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                // Left content
                if let leftIcon = leftIcon {
                    Button(action: {
                        onLeftIconTap?()
                    }) {
                        Image(systemName: leftIcon)
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                    }
                } else if let leftLink = leftLink {
                    Button(action: {
                        onLeftLinkTap?()
                    }) {
                        Text(leftLink)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(Color(hex: "#6c47ff"))
                            .frame(height: 40)
                            .padding(.horizontal, 8)
                    }
                }

                Spacer()

                // Right content
                if let rightLink = rightLink {
                    Button(action: {
                        onRightLinkTap?()
                    }) {
                        Text(rightLink)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(Color(hex: "#6c47ff"))
                            .frame(height: 40)
                            .padding(.horizontal, 8)
                    }
                } else if let rightIcon = rightIcon {
                    Button(action: {
                        onRightIconTap?()
                    }) {
                        Image(systemName: rightIcon)
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                    }
                }
            }

            // Centered title (always centered regardless of other content)
            if let title = title {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)

                    // Dropdown chevron (if enabled)
                    if showDropdown {
                        Button(action: {
                            onDropdownTap?()
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 8)
    }
}

// MARK: - Convenience Initializers

extension PageTitle {
    /// Icon + Title variant (most common: back navigation)
    static func iconTitle(
        title: String,
        icon: String = "chevron.left",
        onIconTap: @escaping () -> Void
    ) -> PageTitle {
        PageTitle(
            title: title,
            leftIcon: icon,
            onLeftIconTap: onIconTap
        )
    }

    /// Icon + Title + Link variant
    static func iconTitleLink(
        title: String,
        leftIcon: String = "chevron.left",
        rightLink: String = "Done",
        onLeftIconTap: @escaping () -> Void,
        onRightLinkTap: @escaping () -> Void
    ) -> PageTitle {
        PageTitle(
            title: title,
            leftIcon: leftIcon,
            rightLink: rightLink,
            onLeftIconTap: onLeftIconTap,
            onRightLinkTap: onRightLinkTap
        )
    }

    /// Icon + Title + Icon variant
    static func iconTitleIcon(
        title: String,
        leftIcon: String = "xmark",
        rightIcon: String = "checkmark",
        onLeftIconTap: @escaping () -> Void,
        onRightIconTap: @escaping () -> Void
    ) -> PageTitle {
        PageTitle(
            title: title,
            leftIcon: leftIcon,
            rightIcon: rightIcon,
            onLeftIconTap: onLeftIconTap,
            onRightIconTap: onRightIconTap
        )
    }

    /// Icon + Menu (dropdown) variant
    static func iconMenu(
        title: String,
        leftIcon: String = "xmark",
        onLeftIconTap: @escaping () -> Void,
        onDropdownTap: @escaping () -> Void
    ) -> PageTitle {
        PageTitle(
            title: title,
            leftIcon: leftIcon,
            showDropdown: true,
            onLeftIconTap: onLeftIconTap,
            onDropdownTap: onDropdownTap
        )
    }

    /// Link + Title variant
    static func linkTitle(
        title: String,
        link: String = "Done",
        onLinkTap: @escaping () -> Void
    ) -> PageTitle {
        PageTitle(
            title: title,
            leftLink: link,
            onLeftLinkTap: onLinkTap
        )
    }

    /// Icon + Link variant (no title)
    static func iconLink(
        leftIcon: String = "xmark",
        rightLink: String = "Done",
        onLeftIconTap: @escaping () -> Void,
        onRightLinkTap: @escaping () -> Void
    ) -> PageTitle {
        PageTitle(
            leftIcon: leftIcon,
            rightLink: rightLink,
            onLeftIconTap: onLeftIconTap,
            onRightLinkTap: onRightLinkTap
        )
    }

    /// Icon + Icon variant (no title)
    static func iconIcon(
        leftIcon: String = "xmark",
        rightIcon: String = "xmark",
        onLeftIconTap: @escaping () -> Void,
        onRightIconTap: @escaping () -> Void
    ) -> PageTitle {
        PageTitle(
            leftIcon: leftIcon,
            rightIcon: rightIcon,
            onLeftIconTap: onLeftIconTap,
            onRightIconTap: onRightIconTap
        )
    }

    /// Icon only variant
    static func icon(
        icon: String = "xmark",
        onIconTap: @escaping () -> Void
    ) -> PageTitle {
        PageTitle(
            leftIcon: icon,
            onLeftIconTap: onIconTap
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 24) {
            // Icon + Title + Link
            PageTitle.iconTitleLink(
                title: "Invite people",
                onLeftIconTap: { print("Back") },
                onRightLinkTap: { print("Done") }
            )

            Divider().background(Color.white.opacity(0.1))

            // Link + Title
            PageTitle.linkTitle(
                title: "Invite people",
                onLinkTap: { print("Done") }
            )

            Divider().background(Color.white.opacity(0.1))

            // Icon + Title + Icon
            PageTitle.iconTitleIcon(
                title: "Invite people",
                onLeftIconTap: { print("Close") },
                onRightIconTap: { print("Confirm") }
            )

            Divider().background(Color.white.opacity(0.1))

            // Icon + Title
            PageTitle.iconTitle(
                title: "Invite people",
                onIconTap: { print("Back") }
            )

            Divider().background(Color.white.opacity(0.1))

            // Icon + Menu
            PageTitle.iconMenu(
                title: "Invite people",
                onLeftIconTap: { print("Close") },
                onDropdownTap: { print("Menu") }
            )

            Divider().background(Color.white.opacity(0.1))

            // Icon + Link
            PageTitle.iconLink(
                onLeftIconTap: { print("Close") },
                onRightLinkTap: { print("Done") }
            )

            Divider().background(Color.white.opacity(0.1))

            // Icon + Icon
            PageTitle.iconIcon(
                onLeftIconTap: { print("Close left") },
                onRightIconTap: { print("Close right") }
            )

            Divider().background(Color.white.opacity(0.1))

            // Icon only
            PageTitle.icon(
                onIconTap: { print("Close") }
            )

            Spacer()
        }
    }
}
