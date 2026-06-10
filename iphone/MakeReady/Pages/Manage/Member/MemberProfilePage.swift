//
//  MemberProfilePage.swift
//  MakeReady
//
//  Member profile presented as a slide-up modal with swipe-to-dismiss.
//  Photo fills page with gradient overlay; no photo shows large initials circle.
//  Content scrolls from halfway down.
//

import SwiftUI
import ContactsUI

struct MemberProfilePage: View {
    let memberId: String
    var onDismiss: (() -> Void)?

    @State private var profile: MemberProfile?
    @State private var isLoading = true
    @State private var error: String?
    @State private var showAddContact = false
    @State private var showCallDialog = false
    @State private var showTextDialog = false
    @State private var showEmailDialog = false

    // MARK: - Computed Properties

    private var hasPhoto: Bool {
        guard let url = profile?.avatarUrl, !url.isEmpty else { return false }
        return true
    }

    private var initials: String {
        let first = profile?.firstName?.prefix(1).uppercased() ?? ""
        let last = profile?.lastName?.prefix(1).uppercased() ?? ""
        return first + last
    }

    private var keyValueItems: [InfoPanelItem] {
        guard let profile = profile else { return [] }
        var items: [InfoPanelItem] = []

        if let joinDate = profile.earliestJoinDate {
            items.append(InfoPanelItem(label: "Joined", value: DateFormatters.monthDayYear.string(from: joinDate)))
        }
        if let age = profile.age {
            items.append(InfoPanelItem(label: "Age", value: "\(age)"))
        }
        return items
    }

    private var groupItems: [InfoPanelItem] {
        guard let profile = profile else { return [] }
        let formatter = DateFormatters.monthDayYear
        return profile.groups.map { group in
            InfoPanelItem(label: group.name, value: "Joined \(formatter.string(from: group.joinedAt))")
        }
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
                // Layer 1: Base background (always present from frame 1)
                Color.appBackground

                // Layer 1b: Photo image (appears when loaded, behind gradient)
                if hasPhoto, let urlString = profile?.avatarUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            Color.clear
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                }

                // Layer 1c: Gradient overlay (ALWAYS present — never inside a conditional)
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.appBackground.opacity(0.2), location: 0),
                        .init(color: Color.appBackground.opacity(0.6), location: 0.5),
                        .init(color: Color.appBackground, location: 0.75)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Layer 1d: Initials circle (when no photo)
                if !hasPhoto {
                    VStack {
                        Spacer()
                            .frame(height: geometry.size.height * 0.12)
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 240, height: 240)
                            .overlay(
                                Text(initials)
                                    .font(.system(size: 80, weight: .bold))
                                    .foregroundColor(.white.opacity(0.3))
                            )
                        Spacer()
                    }
                }

                // Layer 2: Scrollable content (always present, hidden until loaded)
                ScrollView {
                    VStack(spacing: 16) {
                        Color.clear
                            .frame(height: geometry.size.height * 0.45)

                        if let profile = profile {
                            Text(profile.displayName)
                                .font(.system(size: 32, weight: .bold))
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

                            if !dataItems.isEmpty {
                                InfoPanel(items: dataItems, mode: .data)
                            }

                            if !groupItems.isEmpty {
                                InfoPanel(items: groupItems, mode: .data)
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

                // Layer 5: Action dialogs
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

                // Back/close button overlay
                if onDismiss != nil {
                    VStack {
                        HStack {
                            Button {
                                onDismiss?()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.black.opacity(0.3))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.leading, 16)
                            .padding(.top, 8)
                            Spacer()
                        }
                        Spacer()
                    }
                }
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
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))

            Text(message)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task { await loadProfile() }
            }
            .foregroundColor(Color(hex: "#6c47ff"))
        }
        .padding(32)
    }


    // MARK: - Helpers

    private func formatPhoneNumber(_ phone: String) -> String {
        // Format E.164 (+12138623686) to readable (213.862.3686)
        let digits = phone.filter(\.isNumber)
        guard digits.count == 11, digits.hasPrefix("1") else { return phone }
        let local = String(digits.dropFirst())
        let area = local.prefix(3)
        let mid = local.dropFirst(3).prefix(3)
        let last = local.suffix(4)
        return "\(area).\(mid).\(last)"
    }
}

// MARK: - Add Contact View

/// UIKit wrapper for CNContactViewController to add a new contact
struct AddContactView: UIViewControllerRepresentable {
    let profile: MemberProfile
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let contact = CNMutableContact()

        if let first = profile.firstName {
            contact.givenName = first
        }
        if let last = profile.lastName {
            contact.familyName = last
        }

        contact.phoneNumbers = [
            CNLabeledValue(label: CNLabelPhoneNumberMobile,
                           value: CNPhoneNumber(stringValue: profile.phoneNumber))
        ]

        if let email = profile.displayEmail {
            contact.emailAddresses = [
                CNLabeledValue(label: CNLabelHome, value: email as NSString)
            ]
        }

        let vc = CNContactViewController(forUnknownContact: contact)
        vc.contactStore = CNContactStore()
        vc.delegate = context.coordinator
        vc.allowsActions = false
        vc.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: context.coordinator,
            action: #selector(Coordinator.cancelTapped)
        )

        let nav = UINavigationController(rootViewController: vc)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    class Coordinator: NSObject, CNContactViewControllerDelegate {
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        @objc func cancelTapped() {
            dismiss()
        }

        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            dismiss()
        }
    }
}

// MARK: - Previews

#Preview("With Photo") {
    MemberProfilePage(memberId: "preview-1")
}

#Preview("Without Photo") {
    MemberProfilePage(memberId: "preview-2")
}
