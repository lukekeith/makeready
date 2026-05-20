//
//  ActionCardMenu.swift
//  MakeReady
//
//  Slide-up menu with card items for contextual actions.
//  Presented via overlayManager.presentMenu() - ManagedMenuView provides chrome.
//

import SwiftUI

struct ActionCardMenuItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let action: () -> Void
}

struct ActionCardMenu: View {
    let title: String
    let items: [ActionCardMenuItem]

    @Environment(\.dismissOverlay) private var dismissOverlay

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(items) { item in
                    Button {
                        dismissOverlay?()
                        item.action()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: item.icon)
                                .font(.system(size: 18))
                                .foregroundColor(Color(hex: "#7c7cff"))
                                .frame(width: 36, height: 36)
                                .background(Color(hex: "#7c7cff").opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)

                                Text(item.description)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.5))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Close button
            Button {
                dismissOverlay?()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            }
            .padding(.horizontal, 16)
        }
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack {
            Spacer()
            ActionCardMenu(
                title: "Create New",
                items: [
                    ActionCardMenuItem(icon: "book.fill", title: "Study Program", description: "Create a new study program") {},
                    ActionCardMenuItem(icon: "calendar.badge.plus", title: "Enrollment", description: "Enroll a group in a program") {},
                    ActionCardMenuItem(icon: "photo.on.rectangle", title: "Media", description: "Upload photos or videos") {},
                ]
            )
        }
    }
}
