//
//  EditGroupPage.swift
//  MakeReady
//
//  Single-screen form for editing an existing group
//

import SwiftUI

struct EditGroupPage: View {
    let overlayManager: OverlayManager
    let group: UserGroup
    let onGroupUpdated: ((UserGroup) -> Void)?

    // Form state (pre-populated from group)
    @State private var groupName: String
    @State private var description: String
    @State private var coverImage: UIImage?
    @State private var existingCoverUrl: String?
    @State private var isPrivate: Bool
    @State private var allowInvites: Bool
    @State private var memberDirectory: Bool
    @State private var sendWelcomeMessage: Bool
    @State private var welcomeMessage: String
    @State private var ageMin: String
    @State private var ageMax: String
    @State private var maxMembers: String

    // Loading state
    @State private var isSaving = false

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
        group: UserGroup,
        onGroupUpdated: ((UserGroup) -> Void)? = nil
    ) {
        self.overlayManager = overlayManager
        self.group = group
        self.onGroupUpdated = onGroupUpdated

        // Initialize state with group values
        _groupName = State(initialValue: group.name)
        _description = State(initialValue: group.description ?? "")
        _existingCoverUrl = State(initialValue: group.coverImageUrl)
        _isPrivate = State(initialValue: group.isPrivate)
        _allowInvites = State(initialValue: group.allowInvites)
        _memberDirectory = State(initialValue: group.memberDirectory)
        _sendWelcomeMessage = State(initialValue: group.welcomeMessage != nil)
        _welcomeMessage = State(initialValue: group.welcomeMessage ?? "")
        _ageMin = State(initialValue: group.ageRange?.min != nil ? "\(group.ageRange!.min!)" : "18")
        _ageMax = State(initialValue: group.ageRange?.max != nil ? "\(group.ageRange!.max!)" : "34")
        _maxMembers = State(initialValue: group.maxMembers != nil ? "\(group.maxMembers!)" : "Unlimited")
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
                    title: "Edit Group",
                    leftIcon: "xmark",
                    rightLink: "Save",
                    rightLinkDisabled: !isFormValid,
                    onLeftIconTap: {
                        overlayManager.dismiss(id: OverlayID.editGroup)
                    },
                    onRightLinkTap: {
                        if isFormValid {
                            saveGroup()
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
                            programDescription: description,
                            existingImageUrl: existingCoverUrl
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
            if isSaving {
                Color.appBackground
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)

                    Text("Saving Changes")
                        .font(.system(size: 17, weight: .semibold))
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

    private func saveGroup() {
        guard !isSaving else { return }
        isSaving = true

        NSLog("Saving group:")
        NSLog("  Name: \(groupName)")
        NSLog("  Description: \(description)")
        NSLog("  Private: \(isPrivate)")
        NSLog("  Allow Invites: \(allowInvites)")
        NSLog("  Has new cover image: \(coverImage != nil)")

        Task {
            do {
                // Convert maxMembers - "Unlimited" means nil
                let maxMembersValue = maxMembers == "Unlimited" ? nil : Int(maxMembers)

                let updatedGroup = try await GroupActions().updateGroup(
                    id: group.id,
                    name: groupName,
                    description: description.isEmpty ? nil : description,
                    isPrivate: isPrivate,
                    allowInvites: allowInvites,
                    memberDirectory: memberDirectory,
                    welcomeMessage: sendWelcomeMessage && !welcomeMessage.isEmpty ? welcomeMessage : nil,
                    ageRange: ageRange,
                    maxMembers: maxMembersValue
                )

                // If we have a new cover image, upload it
                var finalGroup = updatedGroup
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
                        NSLog("Failed to upload cover image (continuing anyway): \(error)")
                    }
                }

                await MainActor.run {
                    isSaving = false
                    onGroupUpdated?(finalGroup)
                    overlayManager.dismiss(id: OverlayID.editGroup)
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
                NSLog("Failed to update group: \(error)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EditGroupPage(
        overlayManager: OverlayManager(),
        group: UserGroup(
            id: "preview-1",
            code: "ABC123",
            name: "Young Professionals",
            description: "A community for young professionals to connect, network, and grow together.",
            coverImageUrl: nil,
            isPrivate: false,
            allowInvites: true,
            memberDirectory: true,
            welcomeMessage: "Welcome to the group!",
            ageRange: AgeRange(min: 21, max: 35),
            maxMembers: nil,
            memberCount: 27,
            creatorId: "preview-user",
            createdAt: Date(),
            updatedAt: Date()
        )
    )
}
