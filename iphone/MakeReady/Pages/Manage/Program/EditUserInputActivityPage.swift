//
//  EditUserInputActivityPage.swift
//  MakeReady
//
//  Form page for editing USER_INPUT activity fields:
//  title, helpTitle, helpDescription, and helpIcon.
//

import SwiftUI

struct EditUserInputActivityPage: View {
    let activity: StudyActivity
    let programId: String?
    let onCancel: () -> Void
    let onSave: (String?, Bool, Bool, String?, String?, String?) -> Void

    @EnvironmentObject var authManager: AuthManager

    /// True when the signed-in user is the program creator. Drives the
    /// save/done switch and disables every input below so non-creators can
    /// view the form but never mutate it.
    private var canEdit: Bool {
        guard let programId else { return false }
        return AppState.shared.programs[programId]?.isEditable(by: authManager.currentUser?.id) ?? false
    }

    @State private var title: String = ""
    @State private var isHelpEnabled: Bool = false
    @State private var helpAlwaysVisible: Bool = true
    @State private var helpTitle: String = ""
    @State private var helpDescription: String = ""
    @State private var helpIcon: String = "None"

    // Snapshot of values at last-saved-or-opened — drives the Save/Done
    // toggle. `hasChanges` compares live state to this snapshot; saving
    // refreshes it so the button flips back to Done.
    @State private var originalTitle: String = ""
    @State private var originalIsHelpEnabled: Bool = false
    @State private var originalHelpAlwaysVisible: Bool = true
    @State private var originalHelpTitle: String = ""
    @State private var originalHelpDescription: String = ""
    @State private var originalHelpIcon: String = "None"

    @State private var isSaving = false

    // Preview state
    @State private var showPreviewModal = false

    private var hasChanges: Bool {
        title != originalTitle ||
        isHelpEnabled != originalIsHelpEnabled ||
        helpAlwaysVisible != originalHelpAlwaysVisible ||
        helpTitle != originalHelpTitle ||
        helpDescription != originalHelpDescription ||
        helpIcon != originalHelpIcon
    }

    private let iconOptions = [
        "lightbulb.fill",
        "questionmark.circle.fill",
        "pencil",
        "book.fill",
        "text.cursor",
        "hand.raised.fill",
        "heart.fill",
        "eye.fill",
        "star.fill",
        "bolt.fill",
        "flame.fill",
        "leaf.fill"
    ]

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if canEdit {
                    PageTitle.linkTitleLink(
                        title: "Edit Activity",
                        leftLink: "Cancel",
                        rightLink: isSaving ? "Saving..." : (hasChanges ? "Save" : "Done"),
                        rightLinkColor: isSaving ? .white.opacity(0.3) : nil,
                        onLeftLinkTap: { onCancel() },
                        onRightLinkTap: {
                            guard !isSaving else { return }
                            if hasChanges {
                                // Save in place — the button flips to "Done" on success.
                                guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                                save()
                            } else {
                                // Already saved (or nothing to save) — dismiss via parent.
                                onSave(
                                    title,
                                    isHelpEnabled,
                                    isHelpEnabled ? helpAlwaysVisible : true,
                                    isHelpEnabled ? (helpTitle.isEmpty ? nil : helpTitle) : nil,
                                    isHelpEnabled ? (helpDescription.isEmpty ? nil : helpDescription) : nil,
                                    isHelpEnabled ? (helpIcon == "None" ? nil : helpIcon) : nil
                                )
                            }
                        }
                    )
                } else {
                    PageTitle.iconTitle(
                        title: "Activity",
                        icon: "chevron.left",
                        onIconTap: { onCancel() }
                    )
                }

                ScrollView {
                    VStack(spacing: 20) {
                        FieldGroup {
                            TextInput(
                                floatingLabel: "Activity title",
                                autocorrect: true,
                                text: $title
                            )
                        }
                        .padding(.horizontal, 16)
                        .disabled(!canEdit)

                        ToggleGroup {
                            ToggleControl(
                                title: "Enable context help",
                                description: "Enabling this feature provides a helpful link on the lesson activity designed to provide additional context or help to the member who is completing the activity.",
                                isOn: $isHelpEnabled
                            )
                            if isHelpEnabled {
                                ToggleControl(
                                    title: "Always visible",
                                    description: "When enabled, context help is displayed inline on the activity instead of hidden behind a link.",
                                    isOn: $helpAlwaysVisible
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .disabled(!canEdit)

                        if isHelpEnabled {

                            VStack(alignment: .leading, spacing: 12) {
                                FieldGroup {
                                    TextInput(
                                        floatingLabel: "Help title",
                                        autocorrect: true,
                                        text: $helpTitle
                                    )
                                    FieldGroupDivider()
                                    MultilineTextInput(
                                        placeholder: "Help description",
                                        text: $helpDescription,
                                        minHeight: 130,
                                        autocorrect: true
                                    )
                                }
                                .padding(.horizontal, 16)
                            }
                            .disabled(!canEdit)

                            // Icon picker grid
                            VStack(alignment: .leading, spacing: 12) {
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                                    // "None" option
                                    Button {
                                        helpIcon = "None"
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(helpIcon == "None" ? Color(hex: "#6c47ff").opacity(0.2) : Color.white.opacity(0.05))
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(helpIcon == "None" ? Color(hex: "#6c47ff") : Color.white.opacity(0.08), lineWidth: 1.5)
                                            Image(systemName: "xmark")
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(helpIcon == "None" ? Color(hex: "#6c47ff") : .white.opacity(0.3))
                                        }
                                        .frame(height: 48)
                                    }
                                    .buttonStyle(.plain)

                                    // Icon options
                                    ForEach(iconOptions, id: \.self) { icon in
                                        Button {
                                            helpIcon = icon
                                        } label: {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(helpIcon == icon ? Color(hex: "#6c47ff").opacity(0.2) : Color.white.opacity(0.05))
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(helpIcon == icon ? Color(hex: "#6c47ff") : Color.white.opacity(0.08), lineWidth: 1.5)
                                                Image(systemName: icon)
                                                    .font(.system(size: 18, weight: .medium))
                                                    .foregroundColor(helpIcon == icon ? Color(hex: "#6c47ff") : .white.opacity(0.5))
                                            }
                                            .frame(height: 48)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .disabled(!canEdit)
                        }

                        // Preview button — only shown when programId is available
                        if programId != nil {
                            BoxButton(
                                action: { openPreview() },
                                label: "Preview",
                                icon: "eye",
                                iconPosition: .right,
                                variant: .secondary,
                                style: .solid,
                                size: .lg,
                                fullWidth: true,
                                iconOpacity: 0.5
                            )
                            .padding(.horizontal, 16)
                        }

                        Spacer()
                            .frame(height: 16)
                    }
                    .padding(.top, 16)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .fullScreenCover(isPresented: $showPreviewModal) {
            ReadActivityPreviewModal(activityId: activity.id, isPresented: $showPreviewModal)
        }
        .onAppear {
            NSLog("EditUserInput onAppear - activity.id: \(activity.id), title: \(activity.title ?? "nil"), helpIcon: \(activity.helpIcon ?? "nil")")
            title = activity.title ?? activity.type.displayName
            isHelpEnabled = activity.isHelpEnabled ?? false
            helpAlwaysVisible = activity.helpAlwaysVisible ?? true
            helpTitle = activity.helpTitle ?? ""
            helpDescription = activity.helpDescription ?? ""
            helpIcon = activity.helpIcon ?? "None"

            // Snapshot matches initial values → hasChanges is false, so the
            // right-link opens as "Done". Any edit flips it to "Save".
            originalTitle = title
            originalIsHelpEnabled = isHelpEnabled
            originalHelpAlwaysVisible = helpAlwaysVisible
            originalHelpTitle = helpTitle
            originalHelpDescription = helpDescription
            originalHelpIcon = helpIcon
        }
    }

    // MARK: - Save

    /// Persist current edits to the server in place — doesn't dismiss.
    /// On success, updates the snapshot so `hasChanges` flips to false and
    /// the right-link becomes "Done". On failure, the button reverts to
    /// "Save" so the user can retry.
    private func save() {
        isSaving = true
        let pendingTitle = title
        let pendingIsHelpEnabled = isHelpEnabled
        let pendingHelpAlwaysVisible = isHelpEnabled ? helpAlwaysVisible : true
        let pendingHelpTitle = isHelpEnabled ? (helpTitle.isEmpty ? nil : helpTitle) : nil
        let pendingHelpDescription = isHelpEnabled ? (helpDescription.isEmpty ? nil : helpDescription) : nil
        let pendingHelpIcon = isHelpEnabled ? (helpIcon == "None" ? nil : helpIcon) : nil

        Task {
            do {
                _ = try await ProgramActions().updateActivityContent(
                    activityId:     activity.id,
                    title:          pendingTitle,
                    isHelpEnabled:  pendingIsHelpEnabled,
                    helpAlwaysVisible: pendingHelpAlwaysVisible,
                    helpTitle:      pendingHelpTitle,
                    helpDescription: pendingHelpDescription,
                    helpIcon:       pendingHelpIcon
                )
                await MainActor.run {
                    originalTitle = pendingTitle
                    originalIsHelpEnabled = pendingIsHelpEnabled
                    originalHelpAlwaysVisible = helpAlwaysVisible
                    originalHelpTitle = helpTitle
                    originalHelpDescription = helpDescription
                    originalHelpIcon = helpIcon
                    isSaving = false
                }
            } catch {
                NSLog("❌ EditUserInput: save failed — \(error.localizedDescription)")
                await MainActor.run { isSaving = false }
            }
        }
    }

    // MARK: - Preview

    private func openPreview() {
        showPreviewModal = true
    }
}

#Preview {
    EditUserInputActivityPage(
        activity: StudyActivity(
            id: "preview-1",
            type: .userInput,
            status: .complete,
            orderNumber: 1,
            title: "Observation",
            helpTitle: "What do you see?",
            helpDescription: "Write down what stands out to you in the passage.",
            helpIcon: "eye.fill"
        ),
        programId: nil,
        onCancel: { print("Cancel") },
        onSave: { title, isHelpEnabled, helpAlwaysVisible, helpTitle, helpDesc, helpIcon in
            print("Save: \(title ?? "nil"), helpEnabled=\(isHelpEnabled), alwaysVisible=\(helpAlwaysVisible), \(helpTitle ?? "nil"), \(helpDesc ?? "nil"), \(helpIcon ?? "nil")")
        }
    )
}
