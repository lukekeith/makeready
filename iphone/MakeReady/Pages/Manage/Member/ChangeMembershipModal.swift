//
//  ChangeMembershipModal.swift
//  MakeReady
//
//  Full-screen, fade-in modal for changing a member's membership in a group.
//  Presented via `overlayManager.present(.changeMembership)` (.raw chrome +
//  .topLevel priority) — it owns its own background and fade animation, like
//  MemberRequestRespondModal / ConfirmationOverlay.
//
//  Internally it has two panels (main → confirm). Moving forward, the current
//  title + buttons slide UP and fade out while the next set slides UP and fades
//  in; going back, they slide DOWN and fade. Buttons are full-width with the
//  label on the left and an icon on the right.
//

import SwiftUI

struct ChangeMembershipModal: View {
    enum Mode { case joined, removed }

    /// A group the member could be transferred into (one they're not in yet).
    struct TransferGroup: Identifiable {
        let id: String
        let name: String
        let coverImageUrl: String?
        let memberCount: Int
        let activeStudies: Int
    }

    let memberName: String
    let groupName: String
    let mode: Mode
    /// Groups in the leader's org the member is NOT already a member of.
    let transferCandidates: [TransferGroup]

    /// Called when the user confirms removal. The callback dismisses the overlay
    /// and performs the work (the parent owns the OverlayManager + state).
    let onRemoveConfirmed: () -> Void
    /// Called when the user confirms rejoining.
    let onRejoinConfirmed: () -> Void
    /// Called when the user confirms transferring the member into another group
    /// (passes the target group id).
    let onTransferConfirmed: (String) -> Void
    /// Called when the user cancels out of the whole modal.
    let onCancel: () -> Void

    private enum Panel { case main, confirm, transfer }
    private enum ConfirmKind { case remove, rejoin, transfer }

    @State private var panel: Panel = .main
    @State private var confirmKind: ConfirmKind = .remove
    /// Where the confirm panel's Cancel returns to (main for remove/rejoin,
    /// transfer for a transfer confirmation).
    @State private var returnPanel: Panel = .main
    /// The group selected for transfer (drives the transfer confirmation copy).
    @State private var selectedTransfer: TransferGroup?
    @State private var goingForward = true
    /// Drives the top "swipe down to go back" chevron's pulse + bounce.
    @State private var chevronPulse = false
    // Interactive (gesture-driven) back transition for the Select-a-group panel:
    // the panel follows the finger via `transferOffset` (committed) + the live
    // `transferDrag` (@GestureState), and commits or cancels on release.
    @State private var transferOffset: CGFloat = 0
    @GestureState private var transferDrag: CGFloat = 0

    // Whole-modal fade-in (matches the other full-screen modals)
    @State private var contentOpacity: Double = 0
    @State private var contentScale: CGFloat = 0.9
    @State private var backgroundOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.appBackground
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture { } // Swallow taps — dismissal is via the buttons.

            ZStack {
                // Underlay: the main panel shown behind the Select-a-group panel
                // while it's being interactively dragged back down, so you see
                // where the gesture leads. Hidden at rest (offset 0), so it never
                // double-renders during the forward (button) transition.
                if panel == .transfer && (transferOffset + transferDrag) > 0.5 {
                    // Sits directly above the Select-a-group panel and moves with
                    // it, so dragging down brings Change membership in from the top
                    // as one connected pair.
                    mainPanel
                        .offset(y: (transferOffset + transferDrag) - Screen.bounds.height)
                }

                switch panel {
                case .main:
                    mainPanel.transition(panelTransition)
                case .confirm:
                    confirmPanel.transition(panelTransition)
                case .transfer:
                    transferPanel
                        .background(Color.appBackground)
                        .offset(y: transferOffset + transferDrag)
                        .transition(panelTransition)
                }
            }
            // Full height so the transfer panel can host a scrollable, edge-faded
            // list; the compact main/confirm panels add their own padding and
            // stay centered within this frame.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(contentOpacity)
            .scaleEffect(contentScale)

            // Fixed close button — top right. Lives outside the panel ZStack so
            // it never slides with the up/down panel transitions, and dismisses
            // the whole modal from any step (main / confirm / transfer).
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismissModal(onCancel)
                    } label: {
                        Image(systemName: "xmark")
                            .font(Typography.s16Semibold)
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                Spacer()
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
            .opacity(contentOpacity)
        }
        .onAppear {
            ModalAnimations.animateContentAppear(
                scale: $contentScale,
                opacity: $contentOpacity,
                blurOpacity: $backgroundOpacity
            )
        }
    }

    // MARK: - Panels

    private var mainPanel: some View {
        VStack(spacing: 32) {
            titleBlock(
                headline: "Change membership",
                body: "\(memberName)'s membership in \(groupName)"
            )

            VStack(spacing: 8) {
                switch mode {
                case .joined:
                    actionRow(label: "Transfer groups", icon: "arrow.left.arrow.right",
                              tier: .secondary) { goToTransfer() }
                    actionRow(label: "Remove from group", icon: "person.badge.minus",
                              tier: .destructive) { goToConfirm(.remove, from: .main) }
                case .removed:
                    actionRow(label: "Rejoin group", icon: "arrow.uturn.left",
                              tier: .primary) { goToConfirm(.rejoin, from: .main) }
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var confirmPanel: some View {
        VStack(spacing: 32) {
            titleBlock(headline: confirmHeadline, body: confirmBody)

            VStack(spacing: 8) {
                actionRow(
                    label: "Confirm",
                    icon: "checkmark",
                    tier: confirmKind == .remove ? .destructive : .primary
                ) {
                    confirmAction()
                }
                actionRow(label: "Cancel", icon: "xmark", tier: .muted) { back(to: returnPanel) }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func confirmAction() {
        switch confirmKind {
        case .remove:
            dismissModal(onRemoveConfirmed)
        case .rejoin:
            dismissModal(onRejoinConfirmed)
        case .transfer:
            let targetId = selectedTransfer?.id
            dismissModal { if let targetId { onTransferConfirmed(targetId) } }
        }
    }

    /// Height of the top/bottom fade zones (the bottom one also hosts the
    /// swipe-up chevron).
    private let fadeZoneHeight: CGFloat = 64

    private var transferPanel: some View {
        VStack(spacing: 16) {
            Text("Select a group")
                .font(Typography.s18Bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
                .padding(.top, 72) // clear the top-center chevron (+16)

            if transferCandidates.isEmpty {
                Spacer()
                Text("\(memberName) is already a member of every group in the organization.")
                    .font(Typography.s17)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(transferCandidates) { candidate in
                            CardGroup(data: CardGroupData(
                                id: candidate.id,
                                title: candidate.name,
                                imageStyle: transferImageStyle(candidate),
                                metadata: transferMetadata(candidate),
                                onTap: { selectTransfer(candidate) }
                            ))
                        }
                    }
                    .padding(.horizontal, 32)
                    // Top inset so the first card scrolls into (and fades within)
                    // the top gradient zone; normal bottom padding.
                    .padding(.top, fadeZoneHeight)
                    .padding(.bottom, 32)
                }
                .mask(scrollFadeMask)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) { swipeDownAffordance }
    }

    /// Transparent at the top edge so the group list fades out there (below the
    /// chevron), fully opaque below.
    private var scrollFadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: fadeZoneHeight)
            Color.black
        }
    }

    /// Top-center down-chevron that slowly pulses + bounces. Swiping down on it
    /// goes back to the main panel (replaces the Back button).
    private var swipeDownAffordance: some View {
        Image(systemName: "chevron.down")
            .font(Typography.s20Semibold)
            .foregroundColor(.white)
            .opacity(chevronPulse ? 0.9 : 0.3)
            .offset(y: chevronPulse ? 8 : 0)
            .frame(maxWidth: .infinity)
            .frame(height: fadeZoneHeight)
            .contentShape(Rectangle())
            // Interactive back transition: the panel follows the finger as you
            // drag down (and back up if you reverse), committing or springing
            // back on release based on distance/velocity.
            .gesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .global)
                    .updating($transferDrag) { value, state, _ in
                        if value.translation.height > 0 {
                            state = value.translation.height
                        }
                    }
                    .onEnded { value in
                        let commit = value.translation.height > 120
                            || value.predictedEndTranslation.height > 280
                        if commit {
                            // Carry the live drag into the committed offset so the
                            // panel doesn't snap back when @GestureState resets,
                            // then finish sliding it off-screen and switch panels.
                            transferOffset += value.translation.height
                            withAnimation(Motion.standard) {
                                transferOffset = Screen.bounds.height
                            } completion: {
                                panel = .main
                                transferOffset = 0
                            }
                        }
                        // Otherwise @GestureState springs transferDrag back to 0,
                        // returning the panel to rest.
                    }
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    chevronPulse = true
                }
            }
    }

    private func transferImageStyle(_ candidate: TransferGroup) -> CardImageStyle {
        if let url = candidate.coverImageUrl, !url.isEmpty {
            return .photo(imageURL: url)
        }
        return .icon(systemName: "person.2.fill")
    }

    private func transferMetadata(_ candidate: TransferGroup) -> [DataItem] {
        var items = [DataItem(number: "\(candidate.memberCount)", label: "Members")]
        if candidate.activeStudies > 0 {
            items.append(DataItem(
                number: "\(candidate.activeStudies)",
                label: candidate.activeStudies == 1 ? "Active Study" : "Active Studies"
            ))
        }
        return items
    }

    private var confirmHeadline: String {
        switch confirmKind {
        case .remove: return "Remove from group?"
        case .rejoin: return "Rejoin group?"
        case .transfer: return "Transfer to \(selectedTransfer?.name ?? "group")?"
        }
    }

    private var confirmBody: String {
        switch confirmKind {
        case .remove:
            return "Removing the member from this group will only remove \(memberName)'s membership in the group."
        case .rejoin:
            return "Rejoining will restore \(memberName)'s membership in the group."
        case .transfer:
            return "\(memberName) will be moved from \(groupName) to \(selectedTransfer?.name ?? "the selected group")."
        }
    }

    private func titleBlock(headline: String, body: String?) -> some View {
        VStack(spacing: 8) {
            Text(headline)
                .font(Typography.s18Bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                // Allow the full title to wrap to its natural height — inside a
                // transitioning ZStack an unfixed Text can be height-constrained
                // and truncate with an ellipsis.
                .fixedSize(horizontal: false, vertical: true)

            if let body {
                Text(body)
                    .font(Typography.s17)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Buttons (full-width, label left + icon right)

    private enum Tier { case primary, destructive, secondary, muted }

    private func actionRow(label: String, icon: String, tier: Tier, action: @escaping () -> Void) -> some View {
        let textColor: Color = tier == .muted ? .white.opacity(0.5) : .white
        let background: Color = {
            switch tier {
            case .primary: return Color.brandPrimary
            case .destructive: return Color.destructive
            case .secondary: return Color.white.opacity(0.1)
            case .muted: return Color.white.opacity(0.05)
            }
        }()

        return Button(action: action) {
            HStack(spacing: 12) {
                Text(label)
                    .font(Typography.s12Bold)
                    .foregroundColor(textColor)
                    .tracking(0.1)
                Spacer()
                Image(systemName: icon)
                    .font(Typography.s16)
                    .foregroundColor(textColor)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(background)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Panel transitions

    /// Forward (main → confirm): slide UP + fade. Back: slide DOWN + fade.
    private var panelTransition: AnyTransition {
        goingForward
            ? .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity))
            : .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity))
    }

    private func goToConfirm(_ kind: ConfirmKind, from: Panel) {
        confirmKind = kind
        returnPanel = from
        goingForward = true
        withAnimation(Motion.standard) { panel = .confirm }
    }

    private func goToTransfer() {
        goingForward = true
        withAnimation(Motion.standard) { panel = .transfer }
    }

    private func selectTransfer(_ candidate: TransferGroup) {
        selectedTransfer = candidate
        goToConfirm(.transfer, from: .transfer)
    }

    private func back(to target: Panel) {
        goingForward = false
        withAnimation(Motion.standard) { panel = target }
    }

    // MARK: - Whole-modal dismissal

    private func dismissModal(_ completion: @escaping () -> Void) {
        ModalAnimations.animateContentDismiss(
            scale: $contentScale,
            opacity: $contentOpacity,
            blurOpacity: $backgroundOpacity,
            targetScale: 0.9
        ) {
            completion()
        }
    }
}

#Preview("Joined") {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        ChangeMembershipModal(
            memberName: "John Smith",
            groupName: "Young Professionals",
            mode: .joined,
            transferCandidates: [
                .init(id: "g2", name: "Bible Study", coverImageUrl: nil, memberCount: 12, activeStudies: 1),
                .init(id: "g3", name: "Men's Group", coverImageUrl: nil, memberCount: 8, activeStudies: 0)
            ],
            onRemoveConfirmed: {},
            onRejoinConfirmed: {},
            onTransferConfirmed: { _ in },
            onCancel: {}
        )
    }
}

#Preview("Removed") {
    ZStack {
        Color.appBackground.ignoresSafeArea()
        ChangeMembershipModal(
            memberName: "John Smith",
            groupName: "Young Professionals",
            mode: .removed,
            transferCandidates: [],
            onRemoveConfirmed: {},
            onRejoinConfirmed: {},
            onTransferConfirmed: { _ in },
            onCancel: {}
        )
    }
}
