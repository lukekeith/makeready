import SwiftUI

/// invite-member D10: the send and its error routing, apart from the view so it is testable.
enum InviteMemberSend {
    static let fallbackMessage = "Couldn't send the invite"

    @MainActor
    static func run(groupId: String, name: String, phone: String,
                    actions: InviteActions = InviteActions(), state: AppState? = nil) async -> Bool {
        let state = state ?? AppState.shared
        do {
            _ = try await actions.sendInvite(groupId: groupId, recipientPhone: phone, recipientName: name)
            return true
        } catch {
            let serverMessage: String? = { if case APIError.serverError(let m) = error { return m } else { return nil } }()
            state.recordError(error, context: "InviteMemberContainer.send", surface: true,
                              friendlyMessage: serverMessage ?? fallbackMessage)
            return false
        }
    }
}

/// invite-member D1: hosts the d2m-built `InviteMemberScreen` for one group. Owns the send's
/// in-flight flag and moves the screen to `sent` after a successful send (D7b); View invite is
/// hidden (D4, D7a). Exits per D11: Cancel / Done / step-3 back pop the whole flow to
/// `returnDepth`; step-1 back pops one page.
struct InviteMemberContainer: View {
    let groupId: String
    let returnDepth: Int

    @Environment(\.ui2Navigator) private var navigator
    @State private var step = "name"
    @State private var sentName = ""
    @State private var sentDigits = ""
    @State private var sending = false

    var body: some View {
        InviteMemberScreen(
            state: .init(step: step, inviteeName: sentName, digits: sentDigits, sending: sending),
            showsViewInvite: false,
            onBack: { navigator.pop() },
            onCancel: { navigator.popTo(returnDepth) },
            onSendInvite: { name, phone in send(name: name, phone: phone) },
            onDone: { navigator.popTo(returnDepth) }
        )
        .ui2PushedPageFill()
    }

    private func send(name: String, phone: String) {
        guard !sending else { return }                          // §3 sending: one request in flight
        sending = true
        Task { @MainActor in
            let ok = await InviteMemberSend.run(groupId: groupId, name: name, phone: phone)
            sending = false
            if ok {
                sentName = name
                sentDigits = String(phone.dropFirst(2))          // "+1" + 10 digits → the 10 digits
                step = "sent"
            }
        }
    }
}
