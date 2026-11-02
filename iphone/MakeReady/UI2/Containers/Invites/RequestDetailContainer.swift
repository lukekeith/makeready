import SwiftUI

/// UI-only confirmation and completion ownership. AppState remains the owner of all server data/busy locks.
@MainActor @Observable
final class InvitationDetailInteraction {
    enum Mutation { case resend, withdraw, accept, reject }
    struct Prompt {
        let title: String
        let message: String
        let label: String
        let destructive: Bool
    }
    private let api: APIClientProtocol
    private let stateOverride: AppState?
    private var state: AppState { stateOverride ?? .shared }
    private var lifetime = UUID()
    private var operationID: UUID?
    private(set) var operation: Mutation?
    private(set) var confirmation: Mutation?
    private var displayedPrompt: Prompt?

    init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil) {
        self.api = api
        self.stateOverride = state
    }
    func retire() {
        lifetime = UUID()
        confirmation = nil
        operationID = nil
        operation = nil
    }
    func cancelConfirmation() { confirmation = nil }
    func requestConfirmation(_ action: Mutation, id: String) {
        guard action != .resend, eligible(action, id: id) else { return }
        confirmation = action
        displayedPrompt = makePrompt(id: id)
    }
    // C066 keeps the panel mounted until onHidden, even after confirmation is consumed/cancelled.
    func prompt(id: String) -> Prompt? { displayedPrompt }
    func confirmationHidden() { if confirmation == nil { displayedPrompt = nil } }
    private func makePrompt(id: String) -> Prompt? {
        guard let action = confirmation, let detail = state.invitationDetails[id] else { return nil }
        let phone = InviteDetailMapper.phone(detail.recipientPhone)
        let group = InviteDetailMapper.text(detail.selectedInvitation?.groupName, fallback: "No group")
        switch action {
        case .accept: return Prompt(title: "Accept join request?", message: "\(phone) will be added to \(group).", label: "Accept", destructive: false)
        case .reject: return Prompt(title: "Reject join request?", message: "\(phone) will not be added to \(group).", label: "Reject", destructive: true)
        case .withdraw: return Prompt(title: "Withdraw invitation?", message: "\(phone) will no longer be able to join with this invitation.", label: "Withdraw", destructive: true)
        case .resend: return nil
        }
    }
    /// Synchronous dispatch captures ownership before the task can yield to navigation.
    @discardableResult
    func startConfirmation(id: String, navigator: UI2Navigator,
                           onUnauthorized: @escaping @MainActor () async -> Void = {}) -> Task<Void, Never>? {
        guard let action = confirmation else { return nil }
        confirmation = nil
        return dispatch(action, id: id, navigator: navigator, onUnauthorized: onUnauthorized)
    }
    @discardableResult
    func startResend(id: String, navigator: UI2Navigator,
                     onUnauthorized: @escaping @MainActor () async -> Void = {}) -> Task<Void, Never>? {
        dispatch(.resend, id: id, navigator: navigator, onUnauthorized: onUnauthorized)
    }
    func confirm(id: String, navigator: UI2Navigator,
                 onUnauthorized: @escaping @MainActor () async -> Void = {}) async {
        await startConfirmation(id: id, navigator: navigator, onUnauthorized: onUnauthorized)?.value
    }
    func resend(id: String, navigator: UI2Navigator,
                onUnauthorized: @escaping @MainActor () async -> Void = {}) async {
        await startResend(id: id, navigator: navigator, onUnauthorized: onUnauthorized)?.value
    }
    private func eligible(_ action: Mutation, id: String) -> Bool {
        guard operation == nil, !state.invitationMutationPending(id), !state.invitationDetailsStale.contains(id),
              let detail = state.invitationDetails[id], let selected = detail.selectedInvitation else { return false }
        switch action {
        case .resend: return detail.kind == .invite && detail.canResend
        case .withdraw: return detail.kind == .invite && detail.canWithdraw
        case .accept, .reject: return detail.kind == .request && selected.status == .requested && selected.groupId != nil
        }
    }
    private func dispatch(_ action: Mutation, id: String, navigator: UI2Navigator,
                         onUnauthorized: @escaping @MainActor () async -> Void) -> Task<Void, Never>? {
        guard !Task.isCancelled, eligible(action, id: id) else { return nil }
        let groupID = state.invitationDetails[id]?.selectedInvitation?.groupId
        let generation = state.initialLoad.generation
        let presentation = lifetime
        let navigation = navigator.ownership()
        let token = UUID()
        operationID = token
        operation = action
        let ownsPresentation: @MainActor () -> Bool = { [self] in
            state.initialLoad.isCurrent(generation) && lifetime == presentation && operationID == token
                && navigator.ownership() == navigation && !Task.isCancelled
        }
        return Task { @MainActor in
            guard ownsPresentation() else { return } // Navigation/session retired before the POST began.
            let actions = InvitationActions(api: api, state: state, onUnauthorized: onUnauthorized,
                                            shouldSurfaceMutationError: ownsPresentation)
            let result: Result<Void, InvitationActionError>
            switch action {
            case .resend: result = await actions.resendInvitation(id)
            case .withdraw: result = await actions.withdrawInvitation(id)
            case .accept, .reject:
                // Admission above requires the selected row's real group; never fabricate a path ID.
                guard let groupID else { operationID = nil; operation = nil; return }
                if action == .accept { result = await actions.approveRequest(id: id, groupId: groupID) }
                else { result = await actions.rejectRequest(id: id, groupId: groupID) }
            }
            guard ownsPresentation() else { return }
            operationID = nil
            operation = nil
            guard case .success = result else { return } // Actions already own errors; busy/cancelled stay quiet.
            switch action {
            case .resend: state.showNotice("Invitation resent", context: "InviteDetailContainer.resend")
            case .accept, .reject: navigator.popIfTop(.requestDetail(id: id))
            case .withdraw: break // The authoritative C2 response supplies the withdrawn chips.
            }
        }
    }
}

struct RequestDetailContainer: View {
    let id: String
    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    @State private var interaction = InvitationDetailInteraction()
    @State private var imagesSeeded = 0

    var body: some View {
        let app = AppState.shared
        let output = app.invitationDetails[id].flatMap {
            RequestDetailMapper.output($0, busy: app.invitationMutationPending(id)
                || app.invitationDetailsStale.contains(id) || interaction.operation != nil, timeZone: .current)
        }
        let _ = imagesSeeded
        VStack(spacing: 0) {
            PageHeader(style: .twoIcons, title: "Join request", showTitle: true, showIcons: false,
                       leadingGlyph: .back, rightButtons: [], onLeading: leave)
            ScrollView(.vertical) {
                if let output {
                    RequestDetailScreen(state: cachedImages(output.state), onBack: leave,
                        onOpenGroup: { if let target = output.groupDestination { navigator.push(target) } },
                        onApprove: { interaction.requestConfirmation(.accept, id: id) },
                        onReject: { interaction.requestConfirmation(.reject, id: id) }, showsHeader: false)
                }
            }
            .scrollIndicators(.hidden)
            .pullDownRefresh { _ = await actions.loadInvitation(id) }
        }
        .ui2PushedPageFill()
        .actionMenuPresentation(isPresented: interaction.confirmation != nil, onDismiss: interaction.cancelConfirmation,
                                onHidden: interaction.confirmationHidden) {
            if let prompt = interaction.prompt(id: id) {
                ActionMenuOverlay(title: prompt.title, message: prompt.message,
                    actions: [.init(glyph: "", label: prompt.label, tone: prompt.destructive ? .destructive : .standard)],
                    doneLabel: "Cancel", onSelect: { _ in
                        interaction.startConfirmation(id: id, navigator: navigator, onUnauthorized: signOut)
                    }, onDone: interaction.cancelConfirmation)
            }
        }
        .task(id: id) { _ = await actions.loadInvitation(id) }
        .task(id: output?.state.groupPhotoURL) {
            if await UI2ImageLoader.seed([output?.state.groupPhotoURL ?? ""], context: "RequestDetailContainer") { imagesSeeded += 1 }
        }
        .onChange(of: navigator.ownership()) { _, _ in interaction.retire() }
        .onDisappear { interaction.retire() }
    }
    private var actions: InvitationActions { InvitationActions(onUnauthorized: signOut) }
    private func signOut() async {
        do { try await authManager.signOut() } catch {
            AppState.shared.recordError(error, context: "RequestDetailContainer.signOut", surface: false)
        }
    }
    private func leave() { interaction.retire(); navigator.pop() }
    private func cachedImages(_ state: RequestDetailScreen.State) -> RequestDetailScreen.State {
        var result = state
        result.groupPhotoURL = InvitationDetailImages.cached(state.groupPhotoURL)
        return result
    }
}
