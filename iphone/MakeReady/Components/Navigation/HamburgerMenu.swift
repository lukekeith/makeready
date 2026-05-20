//
//  HamburgerMenu.swift
//  MakeReady
//
//  Hamburger menu content - presented via overlayManager.presentMenu()
//  ManagedMenuView provides: dark overlay, slide-up animation, swipe-to-dismiss
//

import SwiftUI

struct HamburgerMenu: View {
    var onNavigateToStudyPrograms: ((Int) -> Void)?
    var onNavigateToSearch: (() -> Void)?

    @Environment(OverlayManager.self) private var overlayManager
    @Environment(\.dismissOverlay) private var dismissOverlay

    var body: some View {
        // Menu content only - ManagedMenuView provides chrome
        VStack(spacing: 0) {
            // Menu items
            VStack(spacing: 0) {
                HamburgerMenuItem(
                    icon: "book.closed.fill",
                    title: "Bible"
                ) {
                    dismissMenu()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        overlayManager.presentModal(id: OverlayID.bibleReader) {
                            BibleReaderModal(
                                overlayManager: overlayManager,
                                onDismiss: {
                                    overlayManager.dismiss(id: OverlayID.bibleReader)
                                }
                            )
                        }
                    }
                }

                HamburgerMenuItem(
                    icon: "magnifyingglass",
                    title: "Search"
                ) {
                    dismissMenu()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onNavigateToSearch?()
                    }
                }

                HamburgerMenuItem(
                    icon: "text.book.closed.fill",
                    title: "Study Programs"
                ) {
                    dismissMenu()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onNavigateToStudyPrograms?(0)
                    }
                }

                HamburgerMenuItem(
                    icon: "calendar.badge.clock",
                    title: "Enrollments"
                ) {
                    dismissMenu()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onNavigateToStudyPrograms?(1)
                    }
                }

            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Close button
            Button(action: {
                dismissMenu()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            }
            .padding(.horizontal, 16)
        }
    }

    /// Dismiss menu using ManagedMenuView's animated dismissal
    private func dismissMenu() {
        dismissOverlay?()
    }
}

// Hamburger menu item
struct HamburgerMenuItem: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Title
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                // Icon on the right
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(Color(hex: "#7c7cff"))
                    .frame(width: 32, height: 32)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    // Preview shows HamburgerMenu content (in production, wrapped by ManagedMenuView)
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack {
            Spacer()
            HamburgerMenu()
                .environment(OverlayManager())
        }
    }
}
