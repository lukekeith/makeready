//
//  MemberRequestProfilePage.swift
//  MakeReady
//
//  Profile for a join request member, presented as a slide-up modal.
//  Always shows initials background (no photo).
//  Displays everything known about the person plus request context.
//

import SwiftUI
import ContactsUI

struct MemberRequestProfilePage: View {
    let memberId: String
    let groupId: String
    let groupName: String
    let requestId: String
    let requestDate: Date
    let requestMessage: String?
    var onApprove: (() -> Void)?

    private var state: AppState { AppState.shared }
    @Environment(OverlayManager.self) private var overlayManager

    @State private var profile: MemberProfile?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showAddContact = false
    @State private var showCallDialog = false
    @State private var showTextDialog = false
    @State private var showEmailDialog = false
    @State private var showApproveConfirmation = false

    // MARK: - Computed Properties

    private var group: UserGroup? {
        state.groups[groupId]
    }

    private var initials: String {
        let first = profile?.firstName?.prefix(1).uppercased() ?? ""
        let last = profile?.lastName?.prefix(1).uppercased() ?? ""
        return first + last
    }

    private var keyValueItems: [InfoPanelItem] {
        guard let profile = profile else { return [] }
        var items: [InfoPanelItem] = []

        if let age = profile.age {
            items.append(InfoPanelItem(label: "Age", value: "\(age)"))
        }
        if let gender = profile.gender {
            items.append(InfoPanelItem(label: "Gender", value: gender.capitalized))
        }

        items.append(InfoPanelItem(label: "Requested", value: DateFormatters.monthDayYear.string(from: requestDate)))

        return items
    }

    private var groupInfoItems: [InfoPanelItem] {
        var items: [InfoPanelItem] = []
        items.append(InfoPanelItem(label: "Group", value: groupName))
        if let group = group {
            items.append(InfoPanelItem(label: "Members", value: "\(group.memberCount)"))
            if group.isPrivate {
                items.append(InfoPanelItem(label: "Visibility", value: "Private"))
            }
            if let ageRange = group.ageRange {
                items.append(InfoPanelItem(label: "Ages", value: ageRange.displayString))
            }
        }
        return items
    }

    private var dataItems: [InfoPanelItem] {
        guard let profile = profile else { return [] }
        var items: [InfoPanelItem] = []
        items.append(InfoPanelItem(label: "Phone", value: formatPhoneNumber(profile.phoneNumber), onTap: {
            showCallDialog = true
        }))
        if let email = profile.displayEmail {
            items.append(InfoPanelItem(label: "Email", value: email, onTap: {
                showEmailDialog = true
            }))
        }
        return items
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Layer 1: Background (always present for stable animation)
                initialsBackground(height: geometry.size.height)

                // Layer 2: Scrollable content (always present, hidden until loaded)
                ScrollView {
                    VStack(spacing: 16) {
                        Color.clear
                            .frame(height: geometry.size.height * 0.45)

                        if let profile = profile {
                            Text(profile.displayName)
                                .font(Typography.s32Bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 16) {
                                ActionButton(icon: "bubble.left.and.bubble.right", variant: .circleBlur) {
                                    showTextDialog = true
                                }
                                ActionButton(icon: "phone.fill", variant: .circleBlur) {
                                    showCallDialog = true
                                }
                                ActionButton(icon: "person.badge.plus", variant: .circleBlur) {
                                    showAddContact = true
                                }
                            }

                            if !keyValueItems.isEmpty {
                                InfoPanel(items: keyValueItems, mode: .keyValue)
                            }

                            if let message = requestMessage, !message.isEmpty {
                                InfoPanel(items: [
                                    InfoPanelItem(label: "Message", value: message)
                                ], mode: .data)
                            }

                            if !dataItems.isEmpty {
                                InfoPanel(items: dataItems, mode: .data)
                            }

                            if !groupInfoItems.isEmpty {
                                InfoPanel(items: groupInfoItems, mode: .data)
                            }

                            if let description = group?.description, !description.isEmpty {
                                InfoPanel(items: [
                                    InfoPanelItem(label: "About Group", value: description)
                                ], mode: .data)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }

                // Layer 3: Loading overlay (on top of stable background)
                if isLoading {
                    Color.appBackground.opacity(0.8)
                    ProgressView()
                        .tint(.white)
                }

                // Layer 4: Error overlay
                if let error = error, !isLoading {
                    Color.appBackground.opacity(0.9)
                    errorView(error)
                }

                // Layer 5: Close button + Approve link (always present)
                VStack {
                    PageTitle.iconTitleLink(
                        title: "",
                        leftIcon: "xmark",
                        rightLink: "Approve",
                        onLeftIconTap: {
                            overlayManager.dismiss(.memberRequestProfile)
                        },
                        onRightLinkTap: {
                            showApproveConfirmation = true
                        }
                    )
                    Spacer()
                }

                // Layer 6: Action dialogs
                DialogOverlay(isPresented: $showCallDialog, buttons: [
                    DialogButtonConfig("Call: \(formatPhoneNumber(profile?.phoneNumber ?? ""))", style: .primary) {
                        if let phone = profile?.phoneNumber { callPhone(phone) }
                    },
                    DialogButtonConfig("Cancel", style: .secondary) {}
                ])

                DialogOverlay(isPresented: $showTextDialog, buttons: [
                    DialogButtonConfig("Text: \(formatPhoneNumber(profile?.phoneNumber ?? ""))", style: .primary) {
                        if let phone = profile?.phoneNumber { openMessages(phone) }
                    },
                    DialogButtonConfig("Cancel", style: .secondary) {}
                ])

                DialogOverlay(isPresented: $showEmailDialog, buttons: [
                    DialogButtonConfig("Email: \(profile?.displayEmail ?? "")", style: .primary) {
                        if let email = profile?.displayEmail { openEmail(email) }
                    },
                    DialogButtonConfig("Cancel", style: .secondary) {}
                ])
            }
        }
        .task {
            await loadProfile()
        }
        .sheet(isPresented: $showAddContact) {
            if let profile = profile {
                AddContactView(profile: profile)
            }
        }
        .alert("Accept Request", isPresented: $showApproveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Accept") {
                Task { await approveRequest() }
            }
        } message: {
            let name = profile?.displayName ?? "this person"
            Text("Accept \(name) as a member of \(groupName)?")
        }
    }

    // MARK: - Data Loading

    private func loadProfile() async {
        isLoading = true
        error = nil

        do {
            profile = try await GroupActions().loadMemberProfile(memberId: memberId)
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    private func approveRequest() async {
        do {
            // Synchronous AppState removal inside the action so the red-dot
            // indicators update instantly when this is the last pending
            // request for the group.
            try await GroupActions().approveJoinRequest(
                groupId: groupId,
                requestId: requestId
            )
            overlayManager.dismiss(.memberRequestProfile)
            onApprove?()
        } catch {
            // User tapped Accept — surface; approval by id is safe to re-run
            // (the page only dismisses on success, so the ids are still valid).
            state.recordError(
                error,
                context: "MemberRequestProfilePage.approveRequest",
                surface: true,
                friendlyMessage: "Couldn't approve the request",
                retry: { Task { await approveRequest() } }
            )
        }
    }

    // MARK: - Actions

    private func openMessages(_ phoneNumber: String) {
        if let url = URL(string: "sms:\(phoneNumber)") {
            UIApplication.shared.open(url)
        }
    }

    private func callPhone(_ phoneNumber: String) {
        if let url = URL(string: "tel:\(phoneNumber)") {
            UIApplication.shared.open(url)
        }
    }

    private func openEmail(_ email: String) {
        if let url = URL(string: "mailto:\(email)") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(Typography.s40)
                .foregroundColor(.white.opacity(0.3))

            Text(message)
                .font(Typography.s15)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task { await loadProfile() }
            }
            .foregroundColor(Color.brandPrimary)
        }
        .padding(32)
    }

    // MARK: - Initials Background

    @ViewBuilder
    private func initialsBackground(height: CGFloat) -> some View {
        ZStack {
            Color.appBackground

            VStack {
                Spacer()
                    .frame(height: height * 0.12)

                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 240, height: 240)
                    .overlay(
                        Text(initials)
                            .font(Typography.s80Bold)
                            .foregroundColor(.white.opacity(0.3))
                    )

                Spacer()
            }
        }
    }

    // MARK: - Helpers

    private func formatPhoneNumber(_ phone: String) -> String {
        let digits = phone.filter(\.isNumber)
        guard digits.count == 11, digits.hasPrefix("1") else { return phone }
        let local = String(digits.dropFirst())
        let area = local.prefix(3)
        let mid = local.dropFirst(3).prefix(3)
        let last = local.suffix(4)
        return "\(area).\(mid).\(last)"
    }
}

// MARK: - Previews

#Preview("Request Profile") {
    MemberRequestProfilePage(
        memberId: "preview-1",
        groupId: "group-1",
        groupName: "Young Professionals",
        requestId: "request-1",
        requestDate: Date().addingTimeInterval(-86400 * 3),
        requestMessage: "Hi! I'd love to join your group."
    )
    .environment(OverlayManager())
}

#Preview("Request Profile - No Message") {
    MemberRequestProfilePage(
        memberId: "preview-2",
        groupId: "group-2",
        groupName: "Bible Study",
        requestId: "request-2",
        requestDate: Date().addingTimeInterval(-86400),
        requestMessage: nil
    )
    .environment(OverlayManager())
}
