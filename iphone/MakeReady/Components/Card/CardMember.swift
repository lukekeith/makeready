//
//  CardMember.swift
//  MakeReady
//
//  Member card component with avatar, name, metadata, and groups
//

import SwiftUI

struct CardMember<TrailingContent: View>: View {
    let data: CardMemberData
    let cornerRadius: CGFloat
    let trailingContent: TrailingContent?

    init(data: CardMemberData, cornerRadius: CGFloat = 4, @ViewBuilder trailingContent: () -> TrailingContent) {
        self.data = data
        self.cornerRadius = cornerRadius
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

                // Middle: Content
                VStack(alignment: .leading, spacing: 0) {
                    // Name
                    Text(data.fullName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    // Metadata row (age, joined date, etc.)
                    if !data.metadata.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(data.metadata) { item in
                                DataComponent(item: item)
                            }
                        }
                        .padding(.top, 1)
                    }

                    // Group badges
                    if !data.groups.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(data.groups, id: \.self) { group in
                                Text(group)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color(hex: "#6c47ff"))
                            }
                        }
                        .padding(.top, 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                // Right: Trailing content (optional button or other view)
                if let trailingContent = trailingContent {
                    trailingContent
                }
            }
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(cornerRadius)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Avatar View

    @ViewBuilder
    private var avatarView: some View {
        if let avatarURL = data.avatarURL, !avatarURL.isEmpty {
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
            .fill(Color(hex: "#6c47ff"))
            .frame(width: 40, height: 40)
            .overlay(
                Text(initials)
                    .font(.system(size: 16, weight: .bold))
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

extension CardMember where TrailingContent == EmptyView {
    init(data: CardMemberData, cornerRadius: CGFloat = 4) {
        self.data = data
        self.cornerRadius = cornerRadius
        self.trailingContent = nil
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        VStack(spacing: 12) {
            Text("Member Cards")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)

            CardMember(
                data: CardMemberData(
                    id: "member-1",
                    firstName: "John",
                    lastName: "Smith",
                    avatarURL: "https://picsum.photos/72/72",
                    metadata: [
                        DataItem(label: "Age", value: "28"),
                        DataItem(label: "Joined", value: "Jan 2025")
                    ],
                    groups: ["Young Professionals"],
                    onTap: { print("Tapped member") }
                )
            ) {
                ActionButton(label: "Invite", variant: .purple) {
                    print("Invite tapped")
                }
            }

            CardMember(
                data: CardMemberData(
                    id: "member-2",
                    firstName: "Sarah",
                    lastName: "Johnson",
                    metadata: [
                        DataItem(label: "Age", value: "32")
                    ],
                    groups: ["Bible Study", "Worship Team"],
                    onTap: { print("Tapped member") }
                )
            )

            CardMember(
                data: CardMemberData(
                    id: "member-3",
                    firstName: "Michael",
                    lastName: "Brown",
                    avatarURL: "https://picsum.photos/73/73",
                    onTap: { print("Tapped member") }
                )
            ) {
                ActionButton(label: "Invite", variant: .purple) {
                    print("Invite tapped")
                }
            }
        }
        .padding(20)
    }
}
