//
//  ComponentsPage.swift
//  MakeReady
//
//  Component showcase page for testing UI components
//

import SwiftUI

struct ComponentsPage: View {
    @Environment(\.dismiss) var dismiss
    @State private var activeTab = 0

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page title
                PageTitle.iconTitle(
                    title: "Components",
                    icon: "chevron.left",
                    onIconTap: {
                        dismiss()
                    }
                )

                // Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ComponentTabButton(
                            title: "Fields",
                            isActive: activeTab == 0,
                            onTap: {
                                withAnimation {
                                    activeTab = 0
                                }
                            }
                        )

                        ComponentTabButton(
                            title: "Buttons",
                            isActive: activeTab == 1,
                            onTap: {
                                withAnimation {
                                    activeTab = 1
                                }
                            }
                        )

                        ComponentTabButton(
                            title: "Members",
                            isActive: activeTab == 2,
                            onTap: {
                                withAnimation {
                                    activeTab = 2
                                }
                            }
                        )

                        ComponentTabButton(
                            title: "Contacts",
                            isActive: activeTab == 3,
                            onTap: {
                                withAnimation {
                                    activeTab = 3
                                }
                            }
                        )
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 8)

                // Content
                ScrollView {
                    Group {
                        if activeTab == 0 {
                            FieldsTabContent()
                        } else if activeTab == 1 {
                            ButtonsTabContent()
                        } else if activeTab == 2 {
                            MembersTabContent()
                        } else {
                            ContactsTabContent()
                        }
                    }
                }
            }
        }
    }
}

// Tab button component
struct ComponentTabButton: View {
    let title: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(isActive ? .white : .white.opacity(0.7))

                Rectangle()
                    .fill(Color(hex: "#6c47ff"))
                    .frame(height: 2)
                    .opacity(isActive ? 1 : 0)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Fields Tab Content

struct FieldsTabContent: View {
    @State private var textValue = ""
    @State private var multilineValue = ""
    @State private var togglePrivate = false
    @State private var toggleInvites = true
    @State private var toggleWelcome = false
    @State private var dateValue = Date()
    @State private var menuValue = "Unlimited"
    @State private var nameValue = ""
    @State private var emailValue = ""
    @State private var phoneValue = ""

    // Large input states
    @State private var largeTextValue = ""
    @State private var largePhoneValue = ""
    @State private var largeEmailValue = ""
    @State private var largeIntegerValue = ""
    @State private var largeFloatValue = ""
    @State private var largeCurrencyValue = ""
    @State private var largePercentageValue = ""

    // Validation errors
    @State private var phoneError: String? = nil
    @State private var emailError: String? = nil
    @State private var integerError: String? = nil
    @State private var currencyError: String? = nil

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Text Input (Placeholder)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                FieldGroup {
                    TextInput(placeholder: "Enter group name", text: $textValue)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Text Input (Labeled with Icons)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                FieldGroup {
                    TextInput(label: "Name", icon: "person.fill", text: $nameValue)
                    Divider().background(Color.white.opacity(0.1)).padding(.leading, 52)
                    TextInput(label: "Email", icon: "envelope.fill", text: $emailValue)
                    Divider().background(Color.white.opacity(0.1)).padding(.leading, 52)
                    TextInput(label: "Phone", icon: "phone.fill", text: $phoneValue, keyboardType: .phonePad)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Multiline Text Input")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                FieldGroup {
                    MultilineTextInput(
                        placeholder: "Describe the purpose of the group",
                        text: $multilineValue
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Toggle Controls")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                ToggleGroup {
                    ToggleControl(
                        title: "Private",
                        description: "Only members can see members and their activity in the group.",
                        isOn: $togglePrivate
                    )

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.leading, 16)

                    ToggleControl(
                        title: "Allow members to send invites",
                        description: "Enable this option to send invites from their mobile web portal",
                        isOn: $toggleInvites
                    )

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.leading, 16)

                    ToggleControl(
                        title: "Send welcome message",
                        description: "Send a welcome message to every member when they join the group",
                        isOn: $toggleWelcome
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Date Picker")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                FieldGroup {
                    DatePickerField(label: "Date", date: $dateValue)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Menu Input")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                FieldGroup {
                    MenuInput(
                        label: "Max members",
                        options: ["Unlimited", "10", "25", "50", "100"],
                        selectedOption: $menuValue
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Large Text Input - Data Types")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .padding(.top, 20)

                Text("These inputs automatically format and validate based on their type")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.bottom, 8)
            }

            VStack(alignment: .leading, spacing: 20) {
                // Phone
                VStack(alignment: .leading, spacing: 4) {
                    Text("Phone - Auto-formats as (###) ###-####")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                    LargeTextInput(
                        label: "Phone",
                        inputType: .phone,
                        text: $largePhoneValue,
                        validationError: $phoneError
                    )
                }

                // Integer
                VStack(alignment: .leading, spacing: 4) {
                    Text("Integer - Numbers only")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                    LargeTextInput(
                        label: "Age",
                        inputType: .integer,
                        text: $largeIntegerValue,
                        validationError: $integerError
                    )
                }

                // Float
                VStack(alignment: .leading, spacing: 4) {
                    Text("Float - Decimal numbers")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                    LargeTextInput(
                        label: "Weight (lbs)",
                        inputType: .float,
                        text: $largeFloatValue
                    )
                }

                // Currency
                VStack(alignment: .leading, spacing: 4) {
                    Text("Currency - $ icon, thousand separators, 2 decimals")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                    LargeTextInput(
                        label: "Amount",
                        inputType: .currency,
                        text: $largeCurrencyValue,
                        validationError: $currencyError
                    )
                }

                // Email
                VStack(alignment: .leading, spacing: 4) {
                    Text("Email - Validates email format")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                    LargeTextInput(
                        label: "Email",
                        inputType: .email,
                        text: $largeEmailValue,
                        validationError: $emailError
                    )
                }

                // Percentage
                VStack(alignment: .leading, spacing: 4) {
                    Text("Percentage - 0-100 with % icon")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                    LargeTextInput(
                        label: "Completion",
                        inputType: .percentage,
                        text: $largePercentageValue
                    )
                }

                // Alphanumeric (default)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Alphanumeric - Any characters (default)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                    LargeTextInput(
                        label: "Full name",
                        inputType: .alphanumeric,
                        text: $largeTextValue
                    )
                }
            }

            Spacer(minLength: 80)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
}

// MARK: - Buttons Tab Content

struct ButtonsTabContent: View {
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Purple variant")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                HStack(spacing: 12) {
                    GroupButton(label: "Poll", icon: "chart.bar.fill", variant: .purple) {
                        print("Poll tapped")
                    }

                    GroupButton(label: "Invite", variant: .purple) {
                        print("Invite tapped")
                    }

                    GroupButton(icon: "chart.bar.fill", variant: .purpleIcon) {
                        print("Chart tapped")
                    }

                    Spacer()
                }

                HStack(spacing: 12) {
                    GroupButton(label: "Add", icon: "plus.circle", variant: .purple) {
                        print("Add tapped")
                    }

                    GroupButton(label: "Send", icon: "paperplane.fill", variant: .purple) {
                        print("Send tapped")
                    }

                    GroupButton(icon: "star.fill", variant: .purpleIcon) {
                        print("Star tapped")
                    }

                    Spacer()
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("White variant")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)

                HStack(spacing: 12) {
                    GroupButton(label: "Settings", icon: "gearshape", variant: .white) {
                        print("Settings tapped")
                    }

                    GroupButton(label: "Edit", variant: .white) {
                        print("Edit tapped")
                    }

                    GroupButton(icon: "ellipsis", variant: .whiteIcon) {
                        print("More tapped")
                    }

                    Spacer()
                }

                HStack(spacing: 12) {
                    GroupButton(label: "Delete", icon: "trash", variant: .white) {
                        print("Delete tapped")
                    }

                    GroupButton(label: "Share", icon: "square.and.arrow.up", variant: .white) {
                        print("Share tapped")
                    }

                    GroupButton(icon: "heart.fill", variant: .whiteIcon) {
                        print("Heart tapped")
                    }

                    Spacer()
                }
            }

            Spacer(minLength: 80)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
}

// MARK: - Members Tab Content

struct MembersTabContent: View {
    // Sample member data
    let members = [
        Member(
            firstName: "Sarah",
            lastName: "Johnson",
            avatarURL: "https://i.pravatar.cc/150?img=5",
            birthDate: Calendar.current.date(byAdding: .year, value: -25, to: Date()),
            joinDate: Calendar.current.date(from: DateComponents(year: 2024, month: 8, day: 15)),
            groups: ["Young adults"]
        ),
        Member(
            firstName: "Michael",
            lastName: "Chen",
            avatarURL: "https://i.pravatar.cc/150?img=12",
            birthDate: Calendar.current.date(byAdding: .year, value: -32, to: Date()),
            joinDate: Calendar.current.date(from: DateComponents(year: 2023, month: 11, day: 3)),
            groups: ["Worship team", "Young adults"]
        ),
        Member(
            firstName: "Emma",
            lastName: "Williams",
            avatarURL: nil,
            birthDate: Calendar.current.date(byAdding: .year, value: -28, to: Date()),
            joinDate: Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 20)),
            groups: ["Young adults"]
        ),
        Member(
            firstName: "David",
            lastName: "Martinez",
            avatarURL: "https://i.pravatar.cc/150?img=33",
            birthDate: Calendar.current.date(byAdding: .year, value: -45, to: Date()),
            joinDate: Calendar.current.date(from: DateComponents(year: 2022, month: 5, day: 10)),
            groups: ["Leadership"]
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                MemberListItem(
                    member: member,
                    variant: member.groups.count > 1 ? .memberMultipleGroups : .memberWithInvite,
                    onInviteTap: {
                        print("Invite \(member.fullName)")
                    }
                )

                if index < members.count - 1 {
                    Divider()
                        .background(Color.white.opacity(0.1))
                }
            }

            Spacer(minLength: 80)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
}

// MARK: - Contacts Tab Content

struct ContactsTabContent: View {
    // Sample contact data
    let contacts = [
        Contact(
            firstName: "Jessica",
            lastName: "Brown",
            avatarURL: "https://i.pravatar.cc/150?img=9"
        ),
        Contact(
            firstName: "Ryan",
            lastName: "Taylor",
            avatarURL: nil
        ),
        Contact(
            firstName: "Ashley",
            lastName: "Anderson",
            avatarURL: "https://i.pravatar.cc/150?img=20"
        ),
        Contact(
            firstName: "Christopher",
            lastName: "Lee",
            avatarURL: nil
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(contacts.enumerated()), id: \.element.id) { index, contact in
                MemberListItem(
                    contact: contact,
                    onInviteTap: {
                        print("Invite contact \(contact.fullName)")
                    }
                )

                if index < contacts.count - 1 {
                    Divider()
                        .background(Color.white.opacity(0.1))
                }
            }

            Spacer(minLength: 80)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }
}

#Preview {
    ComponentsPage()
}
