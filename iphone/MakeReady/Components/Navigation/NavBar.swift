//
//  NavBar.swift
//  MakeReady
//
//  Created by MakeReady Team
//

import SwiftUI

enum NavBarTab {
    case home
    case groups
    case library
    case calendar
    case search
    case profile
    case none
}

struct NavBar: View {
    var activeTab: NavBarTab = .none
    var avatarURL: String?
    var onHomeTap: (() -> Void)?
    var onGroupsTap: (() -> Void)?
    var onLibraryTap: (() -> Void)?
    var onCalendarTap: (() -> Void)?
    var onSearchTap: (() -> Void)?
    var onProfileTap: (() -> Void)?

    private let selectedColor = Color.brandPrimary
    private let inactiveColor = Color.white.opacity(0.7)

    var body: some View {
        HStack(spacing: 0) {
            // Home
            NavBarButton(
                icon: "IconHome",
                label: "Home",
                isActive: activeTab == .home,
                selectedColor: selectedColor,
                inactiveColor: inactiveColor
            ) {
                onHomeTap?()
            }

            // Groups
            NavBarButton(
                icon: "IconPeople",
                label: "Groups",
                isActive: activeTab == .groups,
                selectedColor: selectedColor,
                inactiveColor: inactiveColor
            ) {
                onGroupsTap?()
            }

            // Library
            NavBarButton(
                icon: "IconLibrary",
                label: "Library",
                isActive: activeTab == .library,
                selectedColor: selectedColor,
                inactiveColor: inactiveColor
            ) {
                onLibraryTap?()
            }

            // Calendar
            NavBarButton(
                icon: "IconCalendar",
                label: "Calendar",
                isActive: activeTab == .calendar,
                selectedColor: selectedColor,
                inactiveColor: inactiveColor
            ) {
                onCalendarTap?()
            }

            // Search
            NavBarButton(
                icon: "IconSearch",
                label: "Search",
                isActive: activeTab == .search,
                selectedColor: selectedColor,
                inactiveColor: inactiveColor
            ) {
                onSearchTap?()
            }

            // Profile (avatar)
            NavBarAvatarButton(
                avatarURL: avatarURL,
                label: "Profile",
                isActive: activeTab == .profile,
                selectedColor: selectedColor,
                inactiveColor: inactiveColor
            ) {
                onProfileTap?()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 48)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .background(Color.appBackground.opacity(0.5))
        .clipped()
        .ignoresSafeArea(edges: .bottom)
    }
}

struct NavBarButton: View {
    let icon: String
    let label: String
    var isActive: Bool = false
    var selectedColor: Color = Color.brandPrimary
    var inactiveColor: Color = .white.opacity(0.7)
    let action: () -> Void

    private var iconColor: Color {
        isActive ? selectedColor : inactiveColor
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(icon)
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .foregroundColor(iconColor)

                Text(label)
                    .font(Typography.s10Medium)
                    .foregroundColor(iconColor)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }
}

struct NavBarAvatarButton: View {
    let avatarURL: String?
    let label: String
    var isActive: Bool = false
    var selectedColor: Color = Color.brandPrimary
    var inactiveColor: Color = .white.opacity(0.7)
    let action: () -> Void

    private var labelColor: Color {
        isActive ? selectedColor : inactiveColor
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                CachedAsyncImage(
                    url: avatarURL.flatMap { URL(string: $0) },
                    size: 22,
                    fallbackIcon: "person.crop.circle.fill"
                )
                .overlay(
                    Circle()
                        .stroke(isActive ? selectedColor : .clear, lineWidth: 1.5)
                )

                Text(label)
                    .font(Typography.s10Medium)
                    .foregroundColor(labelColor)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        Spacer()
        NavBar(
            activeTab: .home,
            avatarURL: nil,
            onHomeTap: { print("Home") },
            onGroupsTap: { print("Groups") },
            onLibraryTap: { print("Library") },
            onCalendarTap: { print("Calendar") },
            onSearchTap: { print("Search") },
            onProfileTap: { print("Profile") }
        )
    }
    .background(Color.appBackground)
}
