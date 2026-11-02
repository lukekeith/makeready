import SwiftUI

struct InviteDetailContainer: View {
    let id: String
    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    @State private var interaction = InvitationDetailInteraction()
    @State private var imagesSeeded = 0

    var body: some View {
        let app = AppState.shared
        let busy = app.invitationMutationPending(id) || app.invitationDetailsStale.contains(id) || interaction.operation != nil
        let output = app.invitationDetails[id].flatMap { InviteDetailMapper.output($0, busy: busy, timeZone: .current) }
        let urls = output.map { [$0.state.avatarURL] + $0.state.groupPhotoURLs } ?? []
        let _ = imagesSeeded
        VStack(spacing: 0) {
            PageHeader(style: .twoIcons, title: "Invite", showTitle: true, showIcons: false,
                       leadingGlyph: .back, rightButtons: [], onLeading: leave)
            ScrollView(.vertical) {
                if let output {
                    InviteHomeScreen(state: cachedImages(output.state), onBack: leave,
                        onOpenMember: { if let target = output.memberDestination { navigator.push(target) } },
                        onResendInvitation: { interaction.startResend(id: id, navigator: navigator, onUnauthorized: signOut) },
                        onWithdrawInvitation: { interaction.requestConfirmation(.withdraw, id: id) },
                        canResend: output.canResend, canWithdraw: output.canWithdraw,
                        resending: busy && interaction.operation != .withdraw, withdrawing: interaction.operation == .withdraw,
                        showsHeader: false)
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
                    actions: [.init(glyph: "", label: prompt.label, tone: .destructive)], doneLabel: "Cancel",
                    onSelect: { _ in interaction.startConfirmation(id: id, navigator: navigator, onUnauthorized: signOut) },
                    onDone: interaction.cancelConfirmation)
            }
        }
        .task(id: id) { _ = await actions.loadInvitation(id) }
        .task(id: urls) {
            if await UI2ImageLoader.seed(urls, context: "InviteDetailContainer") { imagesSeeded += 1 }
        }
        .onChange(of: navigator.ownership()) { _, _ in interaction.retire() }
        .onDisappear { interaction.retire() }
    }
    private var actions: InvitationActions { InvitationActions(onUnauthorized: signOut) }
    private func signOut() async {
        do { try await authManager.signOut() } catch {
            AppState.shared.recordError(error, context: "InviteDetailContainer.signOut", surface: false)
        }
    }
    private func leave() { interaction.retire(); navigator.pop() }
    private func cachedImages(_ state: InviteHomeScreen.State) -> InviteHomeScreen.State {
        var result = state
        result.avatarURL = InvitationDetailImages.cached(state.avatarURL)
        result.groupPhotoURLs = state.groupPhotoURLs.map(InvitationDetailImages.cached)
        return result
    }
}

/// Match the existing UI2 image-seeding pattern; missing images retain the screen's fallback.
enum InvitationDetailImages {
    @MainActor static func cached(_ raw: String) -> String {
        guard let url = URL(string: raw), Ui2ImageCache.shared.image(for: url) != nil else { return "" }
        return raw
    }
}
