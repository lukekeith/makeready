//
//  CardContact.swift
//  MakeReady
//
//  Contact card component with avatar, name, and invite button
//

import SwiftUI

struct CardContact<TrailingContent: View>: View {
    let data: CardContactData
    let cornerRadius: CGFloat
    let showBackground: Bool
    let trailingContent: TrailingContent?

    init(data: CardContactData, cornerRadius: CGFloat = 4, showBackground: Bool = true, @ViewBuilder trailingContent: () -> TrailingContent) {
        self.data = data
        self.cornerRadius = cornerRadius
        self.showBackground = showBackground
        self.trailingContent = trailingContent()
    }

    var body: some View {
        Button {
            data.onTap?()
        } label: {
            HStack(spacing: 8) {
                // Left: Avatar (40×40)
                avatarView
                    .frame(width: 40, height: 40)

                // Middle: Name
                Text(data.fullName)
                    .font(Typography.s17Bold)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer(minLength: 0)

                // Right: Trailing content (optional button or other view)
                if let trailingContent = trailingContent {
                    trailingContent
                }
            }
            .padding(16)
            .background(showBackground ? Color.cardBackground : Color.clear)
            .cornerRadius(cornerRadius)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Avatar View

    @ViewBuilder
    private var avatarView: some View {
        if let imageData = data.imageData, let uiImage = UIImage(data: imageData) {
            // Use local image data (from device contacts)
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipped()
                .clipShape(Circle())
        } else if let avatarURL = data.avatarURL, !avatarURL.isEmpty {
            // Use remote URL
            AsyncImage(url: URL(string: avatarURL)) { phase in
                switch phase {
                case .empty:
                    initialsView
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipped()
                        .clipShape(Circle())
                case .failure:
                    initialsView
                @unknown default:
                    initialsView
                }
            }
        } else {
            initialsView
        }
    }

    private var initialsView: some View {
        Circle()
            .fill(Color.brandPrimary)
            .frame(width: 40, height: 40)
            .overlay(
                Text(initials)
                    .font(Typography.s16Bold)
                    .foregroundColor(.white)
            )
    }

    private var initials: String {
        let first = data.firstName.prefix(1).uppercased()
        let last = data.lastName.prefix(1).uppercased()
        return "\(first)\(last)"
    }
}

// MARK: - Convenience Init (no trailing content)

extension CardContact where TrailingContent == EmptyView {
    init(data: CardContactData, cornerRadius: CGFloat = 4, showBackground: Bool = true) {
        self.data = data
        self.cornerRadius = cornerRadius
        self.showBackground = showBackground
        self.trailingContent = nil
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 12) {
            Text("Contact Cards")
                .font(Typography.s13Semibold)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)

            CardContact(
                data: CardContactData(
                    id: "contact-1",
                    firstName: "Emily",
                    lastName: "Davis",
                    avatarURL: "https://picsum.photos/72/72",
                    onTap: { print("Tapped contact") }
                )
            ) {
                ActionButton(label: "Invite", variant: .purple) {
                    print("Invite tapped")
                }
            }

            CardContact(
                data: CardContactData(
                    id: "contact-2",
                    firstName: "David",
                    lastName: "Wilson",
                    onTap: { print("Tapped contact") }
                )
            ) {
                ActionButton(label: "Invite", variant: .purple) {
                    print("Invite tapped")
                }
            }

            CardContact(
                data: CardContactData(
                    id: "contact-3",
                    firstName: "Jennifer",
                    lastName: "Martinez",
                    avatarURL: "https://picsum.photos/74/74",
                    onTap: { print("Tapped contact") }
                )
            )
        }
        .padding(20)
    }
}
