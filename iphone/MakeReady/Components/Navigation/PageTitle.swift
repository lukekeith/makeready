//
//  PageTitle.swift
//  MakeReady
//
//  Navigation title component for secondary pages
//  Supports various configurations: icons, links, dropdown menu
//

import SwiftUI
import UIKit

/// Data for a single icon action button
struct IconAction: Identifiable {
    var id: String { icon }  // Use icon name as stable id for proper animation
    let icon: String
    /// When true, a small red presence dot is overlaid at the icon's
    /// top-trailing corner (e.g. for "this group has pending requests").
    var showBadge: Bool = false
    let action: () -> Void
}

struct PageTitle: View {
    // Modal context — adds top padding when drag indicator is overlaid
    @Environment(\.modalProvidesDragIndicator) private var modalProvidesDragIndicator
    @Environment(\.isModalRoot) private var isModalRoot

    /// Dismiss keyboard before running any navigation action
    private func dismissKeyboardAndRun(_ action: (() -> Void)?) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        action?()
    }

    // Content
    let title: String?
    let leftIcon: String?        // SF Symbol name (e.g., "chevron.left", "xmark")
    let leftLink: String?        // Text for left link (e.g., "Done")
    let rightIcon: String?       // SF Symbol name (e.g., "gearshape", "chevron.right")
    let rightLink: String?       // Text for right link (e.g., "Done")
    let rightIcons: [IconAction]?  // Multiple right icons (for iconTitleIcons variant)
    let showDropdown: Bool       // Show dropdown chevron next to title

    // When true and leftIcon is nil, auto-resolve icon from isModalRoot environment
    private let autoResolveLeftIcon: Bool

    // Disabled states
    let rightLinkDisabled: Bool

    // Actions
    let onLeftIconTap: (() -> Void)?
    let onLeftLinkTap: (() -> Void)?
    let onRightIconTap: (() -> Void)?
    let onRightLinkTap: (() -> Void)?
    let onDropdownTap: (() -> Void)?

    /// Resolves the left icon, using environment when autoResolveLeftIcon is enabled
    private var resolvedLeftIcon: String? {
        if let leftIcon { return leftIcon }
        if autoResolveLeftIcon {
            return isModalRoot ? "xmark" : "chevron.left"
        }
        return nil
    }

    // Default initializer with all options
    init(
        title: String? = nil,
        leftIcon: String? = nil,
        leftLink: String? = nil,
        rightIcon: String? = nil,
        rightLink: String? = nil,
        rightIcons: [IconAction]? = nil,
        showDropdown: Bool = false,
        autoResolveLeftIcon: Bool = false,
        rightLinkDisabled: Bool = false,
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
        self.rightIcons = rightIcons
        self.showDropdown = showDropdown
        self.autoResolveLeftIcon = autoResolveLeftIcon
        self.rightLinkDisabled = rightLinkDisabled
        self.onLeftIconTap = onLeftIconTap
        self.onLeftLinkTap = onLeftLinkTap
        self.onRightIconTap = onRightIconTap
        self.onRightLinkTap = onRightLinkTap
        self.onDropdownTap = onDropdownTap
    }

    var body: some View {
        VStack(spacing: 0) {
            // Push content below the overlaid drag indicator (24px) in modals
            if modalProvidesDragIndicator {
                Spacer()
                    .frame(height: 16)
            }

            // Main content
            ZStack {
                HStack(spacing: 8) {
                    // Left content
                    if let leftIcon = resolvedLeftIcon {
                        Button(action: {
                            dismissKeyboardAndRun(onLeftIconTap)
                        }) {
                            Image(systemName: leftIcon)
                                .font(Typography.s17)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    } else if let leftLink = leftLink {
                        Button(action: {
                            dismissKeyboardAndRun(onLeftLinkTap)
                        }) {
                            Text(leftLink)
                                .font(Typography.s17)
                                .foregroundColor(Color.brandPrimary)
                                .frame(height: 44)
                                .padding(.horizontal, 8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Right content
                    if let rightIcons = rightIcons, !rightIcons.isEmpty {
                        // Multiple right icons
                        HStack(spacing: 0) {
                            ForEach(rightIcons) { iconAction in
                                Button(action: {
                                    dismissKeyboardAndRun(iconAction.action)
                                }) {
                                    Image(systemName: iconAction.icon)
                                        .font(Typography.s17)
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 44)
                                        .overlay(alignment: .topTrailing) {
                                            if iconAction.showBadge {
                                                Circle()
                                                    .fill(Color.red)
                                                    .frame(width: 10, height: 10)
                                                    .overlay(
                                                        Circle().stroke(Color.appBackground, lineWidth: 1.5)
                                                    )
                                                    .offset(x: -8, y: 8)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else if let rightLink = rightLink {
                        Button(action: {
                            dismissKeyboardAndRun(onRightLinkTap)
                        }) {
                            Text(rightLink)
                                .font(Typography.s17)
                                .foregroundColor(rightLinkDisabled ? Color.brandPrimary.opacity(0.3) : Color.brandPrimary)
                                .frame(height: 44)
                                .padding(.horizontal, 8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(rightLinkDisabled)
                    } else if let rightIcon = rightIcon {
                        Button(action: {
                            dismissKeyboardAndRun(onRightIconTap)
                        }) {
                            Image(systemName: rightIcon)
                                .font(Typography.s17)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Centered title (always centered regardless of other content)
                if let title = title {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(Typography.s17Bold)
                            .foregroundColor(.white)

                        // Dropdown chevron (if enabled)
                        if showDropdown {
                            Button(action: {
                                dismissKeyboardAndRun(onDropdownTap)
                            }) {
                                Image(systemName: "chevron.down")
                                    .font(Typography.s14)
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
}

// MARK: - Convenience Initializers

extension PageTitle {
    /// Icon + Title variant (most common: back navigation)
    /// When icon is nil (default), auto-resolves from isModalRoot environment
    static func iconTitle(
        title: String,
        icon: String? = nil,
        onIconTap: @escaping () -> Void
    ) -> PageTitle {
        PageTitle(
            title: title,
            leftIcon: icon,
            autoResolveLeftIcon: icon == nil,
            onLeftIconTap: onIconTap
        )
    }

    /// Icon + Title + Link variant
    /// When leftIcon is nil (default), auto-resolves from isModalRoot environment
    static func iconTitleLink(
        title: String,
        leftIcon: String? = nil,
        rightLink: String = "Done",
        rightLinkDisabled: Bool = false,
        onLeftIconTap: @escaping () -> Void,
        onRightLinkTap: @escaping () -> Void
    ) -> PageTitle {
        PageTitle(
            title: title,
            leftIcon: leftIcon,
            rightLink: rightLink,
            autoResolveLeftIcon: leftIcon == nil,
            rightLinkDisabled: rightLinkDisabled,
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

    /// Icon + Title + Multiple Icons variant
    /// Use for headers needing multiple action buttons (e.g., Group home: invite, members, calendar, settings)
    /// When leftIcon is nil (default), auto-resolves from isModalRoot environment
    static func iconTitleIcons(
        title: String,
        leftIcon: String? = nil,
        rightIcons: [IconAction],
        onLeftIconTap: @escaping () -> Void
    ) -> PageTitle {
        PageTitle(
            title: title,
            leftIcon: leftIcon,
            rightIcons: rightIcons,
            autoResolveLeftIcon: leftIcon == nil,
            onLeftIconTap: onLeftIconTap
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

    /// Link + Title + Link variant
    static func linkTitleLink(
        title: String,
        leftLink: String,
        rightLink: String,
        rightLinkColor: Color? = nil,
        onLeftLinkTap: @escaping () -> Void,
        onRightLinkTap: @escaping () -> Void
    ) -> PageTitle {
        PageTitle(
            title: title,
            leftLink: leftLink,
            rightLink: rightLink.isEmpty ? nil : rightLink,
            rightLinkDisabled: false,
            onLeftLinkTap: onLeftLinkTap,
            onRightLinkTap: onRightLinkTap
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

    /// Back link + Title variant (chevron + text as back button, centered title)
    /// Use for navigation where back shows context (e.g., "< Dec" with "Dec 2025" title)
    static func backLinkTitle(
        title: String,
        backText: String,
        onBackTap: @escaping () -> Void
    ) -> some View {
        BackLinkPageTitle(
            title: title,
            backText: backText,
            onBackTap: onBackTap
        )
    }

    /// Title only variant (no icons or buttons)
    /// Use when no navigation controls are needed (e.g., main tab content)
    static func titleOnly(title: String) -> PageTitle {
        PageTitle(title: title)
    }
}

// MARK: - Back Link Page Title (Custom Component)

/// Special PageTitle variant with chevron + text as a single back action
private struct BackLinkPageTitle: View {
    let title: String
    let backText: String
    let onBackTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Left: back button with chevron + text
                HStack {
                    Button(action: {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        onBackTap()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(Typography.s14Semibold)
                            Text(backText)
                                .font(Typography.s17)
                        }
                        .foregroundColor(Color.brandPrimary)
                    }
                    .padding(.leading, 8)

                    Spacer()
                }

                // Center: title
                Text(title)
                    .font(Typography.s17Bold)
                    .foregroundColor(.white)
            }
            .frame(height: 56)
            .padding(.horizontal, 8)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: 24) {
                // Icon + Title + Multiple Icons (Group Home style)
                PageTitle.iconTitleIcons(
                    title: "",
                    leftIcon: "xmark",
                    rightIcons: [
                        IconAction(icon: "paperplane") { print("Invite") },
                        IconAction(icon: "person.2") { print("Members") },
                        IconAction(icon: "calendar") { print("Calendar") },
                        IconAction(icon: "gearshape") { print("Settings") }
                    ],
                    onLeftIconTap: { print("Close") }
                )

                Divider().background(Color.white.opacity(0.1))

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
            }
            .padding(.bottom, 40)
        }
    }
}
