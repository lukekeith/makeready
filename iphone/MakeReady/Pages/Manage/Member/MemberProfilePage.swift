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
    let overlayManager: OverlayManager
    /// Seed values from the calling list (avatar + name) so the background image
    /// and name are present from frame 1 and slide up WITH the modal instead of
    /// popping in after it lands (see SWIFTUI_TRANSITIONS.md § Pre-loading Content).
    let seedAvatarUrl: String?
    let seedName: String?
    var onDismiss: (() -> Void)?

    private var state: AppState { AppState.shared }

    @State private var profile: MemberProfile?
    @State private var isLoading: Bool
    @State private var error: String?
    @State private var backgroundImage: UIImage?
    @State private var showAddContact = false
    @State private var showCallDialog = false
    @State private var showTextDialog = false
    @State private var showEmailDialog = false

    init(
        memberId: String,
        overlayManager: OverlayManager,
        seedAvatarUrl: String? = nil,
        seedName: String? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.memberId = memberId
        self.overlayManager = overlayManager
        self.seedAvatarUrl = seedAvatarUrl
        self.seedName = seedName
        self.onDismiss = onDismiss

        // Cache-first: if the avatar is already in the image cache (it was just
        // shown in the members list), render it from the very first frame so it
        // animates in with the modal.
        if let seed = seedAvatarUrl, let url = URL(string: seed),
           let cached = ImageCache.shared.cachedImage(for: url) {
            _backgroundImage = State(initialValue: cached)
        }
        // Only show the blocking spinner when there is nothing at all to display.
        _isLoading = State(initialValue: seedName == nil && seedAvatarUrl == nil)
    }

    // MARK: - Computed Properties

    private var displayAvatarUrl: String? { profile?.avatarUrl ?? seedAvatarUrl }
    private var displayName: String { profile?.displayName ?? seedName ?? "" }

    private var hasPhoto: Bool {
        guard let url = displayAvatarUrl, !url.isEmpty else { return false }
        return true
    }

    private var initials: String {
        let parts = displayName.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? (parts.last?.prefix(1) ?? "") : ""
        return (first + last).uppercased()
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

                // Layer 1b: Photo image. Rendered from a cached UIImage so it is
                // present on the first frame (when warm) and animates in with the
                // modal. On a cold cache it fades in once the .task below loads it.
                if hasPhoto, let backgroundImage {
                    Image(uiImage: backgroundImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .transition(.opacity)
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
                                    .font(Typography.s80Bold)
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

                        // Name shows from the seed immediately so it animates in
                        // with the modal (profile fills in the rest afterwards).
                        if !displayName.isEmpty {
                            Text(displayName)
                                .font(Typography.s32Bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }

                        if profile != nil {
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

                            // Each group the member belongs to, as a group card,
                            // read from centralized state so membership changes
                            // (remove / rejoin / transfer) re-render reactively.
                            if !memberCards.isEmpty {
                                VStack(spacing: 8) {
                                    ForEach(memberCards) { card in
                                        groupCard(card)
                                    }
                                }
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
                                    .font(Typography.s16Semibold)
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
        .task(id: displayAvatarUrl) {
            await loadBackgroundImage()
        }
        .sheet(isPresented: $showAddContact) {
            if let profile = profile {
                AddContactView(profile: profile)
            }
        }
    }

    // MARK: - Data Loading

    private func loadProfile() async {
        // Only show the blocking spinner when there's nothing to display yet
        // (no seed, no prior profile) — a warm refresh must not re-cover content.
        if profile == nil && seedName == nil && seedAvatarUrl == nil {
            isLoading = true
        }
        error = nil

        do {
            profile = try await GroupActions().loadMemberProfile(memberId: memberId)
            isLoading = false
        } catch {
            // Don't replace already-displayed content with the error screen on a
            // background refresh failure.
            if profile == nil { self.error = error.localizedDescription }
            isLoading = false
        }
    }

    private func loadBackgroundImage() async {
        guard backgroundImage == nil,
              let urlString = displayAvatarUrl,
              let url = URL(string: urlString) else { return }
        if let image = try? await ImageCache.shared.fetch(url: url) {
            withAnimation(Motion.standard) { backgroundImage = image }
        }
    }

    // MARK: - Groups

    /// The member's group cards, read from centralized state (keyed by the
    /// canonical member id) so membership changes re-render reactively.
    private var memberCards: [MemberGroupCard] {
        guard let id = profile?.id else { return [] }
        return state.memberGroupCardsById[id] ?? []
    }

    private func groupCard(_ card: MemberGroupCard) -> some View {
        let isRemoved = card.removedAt != nil
        let referenceDate = card.removedAt ?? card.joinedAt
        let prefix = isRemoved ? "Removed" : "Joined"
        return CardGroup(data: CardGroupData(
            id: card.id,
            title: card.name,
            imageStyle: groupImageStyle(coverImageUrl: card.coverImageUrl),
            metadata: [
                DataItem(
                    number: relativeDuration(since: referenceDate),
                    label: "\(prefix) \(DateFormatters.mediumDateShortTime.string(from: referenceDate))"
                )
            ],
            onTap: { handleGroupTap(card) }
        ))
        .opacity(isRemoved ? 0.5 : 1)
        .overlay {
            // Destructive border makes it obvious the member is no longer in
            // this group. (CardGroup uses a 4pt corner radius.)
            if isRemoved {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.destructive, lineWidth: 1.5)
            }
        }
    }

    private func groupImageStyle(coverImageUrl: String?) -> CardImageStyle {
        if let url = coverImageUrl, !url.isEmpty {
            return .photo(imageURL: url)
        }
        return .icon(systemName: "person.2.fill")
    }

    /// Abbreviated elapsed time since `date`, e.g. "3yrs", "2mo", "5d", "today".
    private func relativeDuration(since date: Date) -> String {
        let seconds = max(0, Date().timeIntervalSince(date))
        let day = 86_400.0
        let year = 365 * day
        let month = 30 * day
        if seconds >= year { let y = Int(seconds / year); return "\(y)yr\(y == 1 ? "" : "s")" }
        if seconds >= month { return "\(Int(seconds / month))mo" }
        if seconds >= day { return "\(Int(seconds / day))d" }
        return "today"
    }

    private func handleGroupTap(_ card: MemberGroupCard) {
        let isRemoved = card.removedAt != nil
        let name = displayName.isEmpty ? "this member" : displayName
        // Group-member operations key off the canonical Member id from the
        // loaded profile (the `memberId` param may be a user id).
        let memberRecordId = profile?.id ?? memberId
        // Transfer candidates: every group in the leader's org the member isn't
        // currently an active member of.
        let activeGroupIds = Set(memberCards.filter { $0.removedAt == nil }.map { $0.id })
        let candidates = state.orderedGroups
            .filter { !activeGroupIds.contains($0.id) }
            .map { group in
                ChangeMembershipModal.TransferGroup(
                    id: group.id,
                    name: group.name,
                    coverImageUrl: group.coverImageUrl,
                    memberCount: group.memberCount,
                    activeStudies: state.enrollmentsFor(groupId: group.id).count
                )
            }
        overlayManager.present(.changeMembership) {
            ChangeMembershipModal(
                memberName: name,
                groupName: card.name,
                mode: isRemoved ? .removed : .joined,
                transferCandidates: candidates,
                onRemoveConfirmed: {
                    overlayManager.dismiss(.changeMembership)
                    Task { await performRemove(groupId: card.id, memberId: memberRecordId) }
                },
                onRejoinConfirmed: {
                    overlayManager.dismiss(.changeMembership)
                    Task { await performRejoin(groupId: card.id, memberId: memberRecordId) }
                },
                onTransferConfirmed: { targetId in
                    overlayManager.dismiss(.changeMembership)
                    Task { await performTransfer(fromGroupId: card.id, toGroupId: targetId, memberId: memberRecordId) }
                },
                onCancel: {
                    overlayManager.dismiss(.changeMembership)
                }
            )
        }
    }

    private func performRemove(groupId: String, memberId: String) async {
        do {
            // The action updates AppState on success, so the card re-renders.
            try await GroupActions().removeMember(groupId: groupId, memberId: memberId)
        } catch {
            AppState.shared.recordError(
                error,
                context: "MemberProfilePage.performRemove",
                surface: true,
                friendlyMessage: "Couldn't remove from group"
            )
        }
    }

    private func performRejoin(groupId: String, memberId: String) async {
        do {
            try await GroupActions().rejoinGroup(groupId: groupId, memberId: memberId)
        } catch {
            AppState.shared.recordError(
                error,
                context: "MemberProfilePage.performRejoin",
                surface: true,
                friendlyMessage: "Couldn't rejoin group"
            )
        }
    }

    private func performTransfer(fromGroupId: String, toGroupId: String, memberId: String) async {
        do {
            try await GroupActions().transferMember(
                memberId: memberId,
                fromGroupId: fromGroupId,
                toGroupId: toGroupId
            )
        } catch {
            AppState.shared.recordError(
                error,
                context: "MemberProfilePage.performTransfer",
                surface: true,
                friendlyMessage: "Couldn't transfer to the selected group"
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
    MemberProfilePage(memberId: "preview-1", overlayManager: OverlayManager())
}

#Preview("Without Photo") {
    MemberProfilePage(memberId: "preview-2", overlayManager: OverlayManager())
}
