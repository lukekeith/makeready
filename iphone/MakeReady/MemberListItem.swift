//
//  MemberListItem.swift
//  MakeReady
//
//  Member/Contact list item component
//

import SwiftUI

// Member data model
struct Member: Identifiable {
    let id = UUID()
    let firstName: String
    let lastName: String
    let avatarURL: String?
    let birthDate: Date?
    let joinDate: Date?
    let groups: [String]

    var fullName: String {
        "\(firstName) \(lastName)"
    }

    var age: Int? {
        guard let birthDate = birthDate else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        return ageComponents.year
    }
}

// Contact data model (simpler - just name and photo)
struct Contact: Identifiable {
    let id = UUID()
    let firstName: String
    let lastName: String
    let avatarURL: String?

    var fullName: String {
        "\(firstName) \(lastName)"
    }
}

enum MemberListItemVariant {
    case contact                    // Contact name only with invite button
    case memberWithInvite          // Member with invite button and in a group
    case member                    // Member in a group (no invite button)
    case memberMultipleGroups      // Member in multiple groups with invite button
}

struct MemberListItem: View {
    let member: Member?
    let contact: Contact?
    let variant: MemberListItemVariant
    let onInviteTap: (() -> Void)?
    let onTap: (() -> Void)?

    // For Member
    init(
        member: Member,
        variant: MemberListItemVariant = .memberWithInvite,
        onInviteTap: (() -> Void)? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.member = member
        self.contact = nil
        self.variant = variant
        self.onInviteTap = onInviteTap
        self.onTap = onTap
    }

    // For Contact
    init(
        contact: Contact,
        onInviteTap: (() -> Void)? = nil,
        onTap: (() -> Void)? = nil
    ) {
        self.member = nil
        self.contact = contact
        self.variant = .contact
        self.onInviteTap = onInviteTap
        self.onTap = onTap
    }

    var body: some View {
        Button(action: {
            onTap?()
        }) {
            HStack(spacing: 8) {
                // Avatar
                if let avatarURL = member?.avatarURL ?? contact?.avatarURL,
                   let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Text(getInitials(firstName: member?.firstName ?? contact?.firstName, lastName: member?.lastName ?? contact?.lastName))
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                } else {
                    // Default avatar with initials
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(getInitials(firstName: member?.firstName ?? contact?.firstName, lastName: member?.lastName ?? contact?.lastName))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        )
                }

                // Details
                VStack(alignment: .leading, spacing: 2) {
                    // Name
                    Text(member?.fullName ?? contact?.fullName ?? "Unknown")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)

                    // Demographics (age and joined) - only for members
                    if variant != .contact, let member = member {
                        HStack(spacing: 8) {
                            if let age = member.age {
                                HStack(spacing: 4) {
                                    Text("Age")
                                        .foregroundColor(.white.opacity(0.5))
                                    Text("\(age)")
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .font(.system(size: 11, weight: .regular))
                                .tracking(0.1)
                            }

                            if let joinDate = member.joinDate {
                                HStack(spacing: 4) {
                                    Text("Joined")
                                        .foregroundColor(.white.opacity(0.5))
                                    Text(formatDate(joinDate))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .font(.system(size: 11, weight: .regular))
                                .tracking(0.1)
                            }
                        }

                        // Groups
                        if !member.groups.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(member.groups.prefix(2), id: \.self) { group in
                                    Text(group)
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundColor(Color(hex: "#6c47ff"))
                                        .tracking(0.1)
                                }
                            }
                        }
                    }
                }

                Spacer()

                // Invite button
                if variant == .contact || variant == .memberWithInvite || variant == .memberMultipleGroups {
                    GroupButton(label: "Invite", variant: .purple) {
                        onInviteTap?()
                    }
                }
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func getInitials(firstName: String?, lastName: String?) -> String {
        let first = firstName?.prefix(1).uppercased() ?? ""
        let last = lastName?.prefix(1).uppercased() ?? ""

        if !first.isEmpty && !last.isEmpty {
            return first + last
        } else if !first.isEmpty {
            return first
        } else {
            return "?"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

#Preview {
    ZStack {
        Color.appBackground
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: 0) {
                // Member with invite button and in a group
                MemberListItem(
                    member: Member(
                        firstName: "Bruce",
                        lastName: "Banner",
                        avatarURL: nil,
                        birthDate: Calendar.current.date(byAdding: .year, value: -28, to: Date()),
                        joinDate: Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1)),
                        groups: ["Young adults"]
                    ),
                    variant: .memberWithInvite,
                    onInviteTap: { print("Invite Bruce") }
                )

                Divider().background(Color.white.opacity(0.1))

                // Member in multiple groups with invite
                MemberListItem(
                    member: Member(
                        firstName: "Bruce",
                        lastName: "Banner",
                        avatarURL: nil,
                        birthDate: Calendar.current.date(byAdding: .year, value: -28, to: Date()),
                        joinDate: Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1)),
                        groups: ["Group 1", "Group 2"]
                    ),
                    variant: .memberMultipleGroups,
                    onInviteTap: { print("Invite Bruce") }
                )

                Divider().background(Color.white.opacity(0.1))

                // Member in a group (no invite)
                MemberListItem(
                    member: Member(
                        firstName: "Bruce",
                        lastName: "Banner",
                        avatarURL: nil,
                        birthDate: Calendar.current.date(byAdding: .year, value: -28, to: Date()),
                        joinDate: Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1)),
                        groups: ["Young adults"]
                    ),
                    variant: .member
                )

                Divider().background(Color.white.opacity(0.1))

                // Contact with invite button
                MemberListItem(
                    contact: Contact(
                        firstName: "Bruce",
                        lastName: "Banner",
                        avatarURL: nil
                    ),
                    onInviteTap: { print("Invite contact") }
                )
            }
        }
    }
}
