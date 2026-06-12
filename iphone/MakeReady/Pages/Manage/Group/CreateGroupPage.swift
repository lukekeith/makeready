//
//  CreateGroupPage.swift
//  MakeReady
//
//  Single-screen form for creating a new group
//

import SwiftUI

struct CreateGroupPage: View {
    let overlayManager: OverlayManager
    let onGroupCreated: ((UserGroup) -> Void)?

    // Form state
    @State private var groupName = ""
    @State private var description = ""
    @State private var coverImage: UIImage?
    @State private var isPrivate = false
    @State private var allowInvites = true
    @State private var memberDirectory = true
    @State private var sendWelcomeMessage = false
    @State private var welcomeMessage = ""
    @State private var ageMin: String = "18"
    @State private var ageMax: String = "34"
    @State private var maxMembers: String = "Unlimited"

    // Loading state
    @State private var isCreating = false

    // Focus management
    @FocusState private var focusedField: FormField?

    enum FormField {
        case groupName
        case description
        case welcomeMessage
        case maxMembers
    }

    init(
        overlayManager: OverlayManager,
        onGroupCreated: ((UserGroup) -> Void)? = nil
    ) {
        self.overlayManager = overlayManager
        self.onGroupCreated = onGroupCreated
    }

    // Computed properties
    private var isFormValid: Bool {
        !groupName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var ageRange: AgeRange? {
        guard let min = Int(ageMin), let max = Int(ageMax) else { return nil }
        return AgeRange(min: min, max: max)
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                PageTitle.iconTitleLink(
                    title: "New Group",
                    leftIcon: "xmark",
                    rightLink: "Create",
                    rightLinkDisabled: !isFormValid,
                    onLeftIconTap: {
                        overlayManager.dismiss(.createGroup)
                    },
                    onRightLinkTap: {
                        if isFormValid {
                            createGroup()
                        }
                    }
                )

                // Scrollable content with all fields
                ScrollView {
                    VStack(spacing: 20) {
                        // Cover image
                        CoverImagePicker(
                            selectedImage: $coverImage,
                            programName: groupName,
                            programDescription: description
                        )
                        .padding(.top, 0)

                        // Group name
                        FieldGroup {
                            TextInput(
                                floatingLabel: "Group name",
                                autocorrect: true,
                                text: $groupName
                            )
                            .focused($focusedField, equals: .groupName)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .description
                            }
                        }
                        .padding(.horizontal, 16)

                        // Description
                        FieldGroup {
                            MultilineTextInput(
                                placeholder: "Describe the purpose of the group",
                                text: $description,
                                minHeight: 130
                            )
                            .focused($focusedField, equals: .description)
                        }
                        .padding(.horizontal, 16)

                        // Privacy toggles
                        ToggleGroup {
                            ToggleControl(
                                title: "Private",
                                description: "Only members can see members and their activity in the group.",
                                isOn: $isPrivate
                            )

                            ToggleControl(
                                title: "Allow members to send invites",
                                description: "Enable this option to send invites from their mobile web portal",
                                isOn: $allowInvites
                            )

                            ToggleControl(
                                title: "Member directory",
                                description: "Allow members to see other members in the group",
                                isOn: $memberDirectory
                            )

                            ToggleControl(
                                title: "Send welcome message",
                                description: "Send a welcome message to every member when they join the group",
                                isOn: $sendWelcomeMessage
                            )
                        }
                        .padding(.horizontal, 16)

                        // Age range with side-by-side number pickers
                        FieldGroup {
                            AgeRangeInput(
                                label: "Age range",
                                minAge: $ageMin,
                                maxAge: $ageMax
                            )
                        }
                        .padding(.horizontal, 16)

                        // Max members
                        FieldGroup {
                            MenuInput(
                                label: "Max members",
                                options: ["Unlimited"] + (1...100).map { "\($0)" },
                                selectedOption: $maxMembers,
                                style: .wheel
                            )
                        }
                        .padding(.horizontal, 16)

                        // Welcome message (only shown if sendWelcomeMessage is enabled)
                        if sendWelcomeMessage {
                            FieldGroup {
                                MultilineTextInput(
                                    placeholder: "Enter a welcome message",
                                    text: $welcomeMessage,
                                    minHeight: 130
                                )
                                .focused($focusedField, equals: .welcomeMessage)
                            }
                            .padding(.horizontal, 16)
                        }

                        Spacer()
                            .frame(height: 40)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            // Loading overlay
            if isCreating {
                Color.appBackground
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)

                    Text("Creating Group")
                        .font(Typography.s17Semibold)
                        .foregroundColor(.white)
                }
            }
        }
        .keyboardManaged()
        .simultaneousGesture(
            TapGesture().onEnded {
                focusedField = nil
            }
        )
    }

    // MARK: - Actions

    private func createGroup() {
        guard !isCreating else { return }
        isCreating = true

        NSLog("Creating group:")
        NSLog("  Name: \(groupName)")
        NSLog("  Description: \(description)")
        NSLog("  Private: \(isPrivate)")
        NSLog("  Allow Invites: \(allowInvites)")
        NSLog("  Has cover image: \(coverImage != nil)")

        Task {
            do {
                // First, create the group without cover image to get the ID
                // Convert maxMembers - "Unlimited" means nil
                let maxMembersValue = maxMembers == "Unlimited" ? nil : Int(maxMembers)

                let group = try await GroupActions().createGroup(
                    name: groupName,
                    description: description.isEmpty ? nil : description,
                    coverImageUrl: nil,
                    isPrivate: isPrivate,
                    allowInvites: allowInvites,
                    memberDirectory: memberDirectory,
                    welcomeMessage: welcomeMessage.isEmpty ? nil : welcomeMessage,
                    ageRange: ageRange,
                    maxMembers: maxMembersValue
                )

                // If we have a cover image, upload it
                var finalGroup = group
                if let image = coverImage {
                    do {
                        let coverImageUrl = try await GroupActions().uploadCoverImage(
                            groupId: group.id,
                            image: image
                        )
                        // Refresh group to get updated data with cover image URL
                        finalGroup = try await GroupActions().getGroup(id: group.id)
                        NSLog("Cover image uploaded: \(coverImageUrl)")
                    } catch {
                        // Group was created; only the cover upload failed —
                        // continue with the created group but tell the user.
                        // No retry: re-running the flow would create a
                        // duplicate group.
                        await MainActor.run {
                            AppState.shared.recordError(
                                error,
                                context: "CreateGroupPage.createGroup (cover upload)",
                                surface: true,
                                friendlyMessage: "Couldn't upload the cover image"
                            )
                        }
                    }
                }

                await MainActor.run {
                    isCreating = false
                    onGroupCreated?(finalGroup)
                    overlayManager.dismiss(.createGroup)
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    // User tapped Create — surface. The form stays up with
                    // its values intact, so the Create button is the retry.
                    AppState.shared.recordError(
                        error,
                        context: "CreateGroupPage.createGroup",
                        surface: true,
                        friendlyMessage: "Couldn't create the group"
                    )
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CreateGroupPreview()
}

/// Helper view to preview all create group fields with sample data
private struct CreateGroupPreview: View {
    @State private var groupName = "Young Professionals"
    @State private var description = "A community for young professionals to connect, network, and grow together."
    @State private var coverImage: UIImage?
    @State private var isPrivate = false
    @State private var allowInvites = true
    @State private var memberDirectory = true
    @State private var sendWelcomeMessage = true
    @State private var welcomeMessage = "Welcome to Young Professionals! We're excited to have you join our community."
    @State private var ageMin: String = "21"
    @State private var ageMax: String = "35"
    @State private var maxMembers: String = "Unlimited"

    var body: some View {
        ZStack(alignment: .top) {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                PageTitle.iconTitleLink(
                    title: "New Group",
                    leftIcon: "xmark",
                    rightLink: "Create",
                    onLeftIconTap: { },
                    onRightLinkTap: { }
                )

                // Scrollable content
                ScrollView {
                    VStack(spacing: 20) {
                        // Cover image
                        CoverImagePicker(
                            selectedImage: $coverImage,
                            programName: groupName,
                            programDescription: description
                        )
                        .padding(.top, 0)

                        // Group name
                        FieldGroup {
                            TextInput(
                                floatingLabel: "Group name",
                                autocorrect: true,
                                text: $groupName
                            )
                        }
                        .padding(.horizontal, 16)

                        // Description
                        FieldGroup {
                            MultilineTextInput(
                                placeholder: "Describe the purpose of the group",
                                text: $description,
                                minHeight: 130
                            )
                        }
                        .padding(.horizontal, 16)

                        // Privacy toggles
                        ToggleGroup {
                            ToggleControl(
                                title: "Private",
                                description: "Only members can see members and their activity in the group.",
                                isOn: $isPrivate
                            )

                            ToggleControl(
                                title: "Allow members to send invites",
                                description: "Enable this option to send invites from their mobile web portal",
                                isOn: $allowInvites
                            )

                            ToggleControl(
                                title: "Member directory",
                                description: "Allow members to see other members in the group",
                                isOn: $memberDirectory
                            )

                            ToggleControl(
                                title: "Send welcome message",
                                description: "Send a welcome message to every member when they join the group",
                                isOn: $sendWelcomeMessage
                            )
                        }
                        .padding(.horizontal, 16)

                        // Age range with side-by-side number pickers
                        FieldGroup {
                            AgeRangeInput(
                                label: "Age range",
                                minAge: $ageMin,
                                maxAge: $ageMax
                            )
                        }
                        .padding(.horizontal, 16)

                        // Max members
                        FieldGroup {
                            MenuInput(
                                label: "Max members",
                                options: ["Unlimited"] + (1...100).map { "\($0)" },
                                selectedOption: $maxMembers,
                                style: .wheel
                            )
                        }
                        .padding(.horizontal, 16)

                        // Welcome message (shown because sendWelcomeMessage is true)
                        if sendWelcomeMessage {
                            FieldGroup {
                                MultilineTextInput(
                                    placeholder: "Enter a welcome message",
                                    text: $welcomeMessage,
                                    minHeight: 130
                                )
                            }
                            .padding(.horizontal, 16)
                        }

                        Spacer()
                            .frame(height: 40)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}
