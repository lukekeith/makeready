import Foundation

/// C2 is already scoped by the server; rendering never joins recipients or invents missing metadata.
enum InviteDetailMapper {
    struct Output {
        var state: InviteHomeScreen.State
        let memberDestination: UI2Destination?
        let canResend: Bool
        let canWithdraw: Bool
        let actionsEnabled: Bool
    }

    static func output(_ detail: InvitationDetail, busy: Bool, timeZone: TimeZone) -> Output? {
        guard detail.selectedInvitation != nil else { return nil }
        let member = detail.member
        let words = (member?.name ?? "").split(separator: " ").map(String.init)
        let events = detail.events.map { event($0, phone: phone(detail.recipientPhone), timeZone: timeZone) }
        let state = InviteHomeScreen.State(
            phone: phone(detail.recipientPhone), memberLinked: member != nil,
            sentDate: date(detail.createdAt, timeZone: timeZone), invitedBy: text(detail.inviterName),
            memberName: text(member?.name), avatarURL: member?.picture ?? "",
            initials: MembersHomeMapper.initials(first: words.first, last: words.count > 1 ? words.last : nil),
            age: member?.age, role: text(member?.role),
            birthday: date(member?.birthday, timeZone: TimeZone(secondsFromGMT: 0) ?? timeZone),
            joined: date(member?.joinedAt, timeZone: timeZone),
            groupTitles: detail.invitations.map { text($0.groupName, fallback: "No group") },
            groupPhotoURLs: detail.invitations.map { $0.groupPicture ?? "" },
            groupStatuses: detail.invitations.map { $0.status.rawValue.capitalized },
            groupStatusDates: detail.invitations.map { date($0.date, timeZone: timeZone) },
            eventDates: events.map(\.date), eventTexts: events.map(\.text),
            eventHighlights: events.map(\.highlight), eventTones: events.map(\.tone))
        return Output(state: state, memberDestination: member.map { .memberDetail(id: $0.id, name: $0.name) },
                      canResend: detail.canResend, canWithdraw: detail.canWithdraw, actionsEnabled: !busy)
    }

    static func text(_ value: String?, fallback: String = "—") -> String {
        MembersHomeMapper.nonEmpty(value?.trimmingCharacters(in: .whitespacesAndNewlines)) ?? fallback
    }
    static func phone(_ value: String?) -> String {
        guard let value = MembersHomeMapper.nonEmpty(value) else { return "No phone number" }
        return InputMask.phone.format(value)
    }
    static func date(_ value: String?, timeZone: TimeZone) -> String {
        value.flatMap(MembersHomeMapper.parseDate).map { MembersHomeMapper.mediumDate($0, timeZone: timeZone) } ?? "—"
    }
    struct Event {
        let date: String
        let text: String
        let highlight: String
        let tone: String
    }
    static func event(_ event: InvitationDetail.Event, phone: String, timeZone: TimeZone) -> Event {
        let group = text(event.groupName, fallback: "No group")
        let description: String
        switch event.type {
        case .sent: description = "Invitation sent to \(phone) for \(group)"
        case .resent: description = "Invitation resent to \(phone) for \(group)"
        case .linkClicked: description = "User clicked invitation link"
        case .accepted: description = "Accepted invitation to \(group)"
        case .withdrawn: description = "Invitation withdrawn for \(group)"
        case .expired: description = "Invitation expired for \(group)"
        case .requested: description = "Requested to join \(group)"
        case .approved: description = "Request approved for \(group)"
        case .rejected: description = "Request rejected for \(group)"
        }
        // Owner 2026-11-02: an event a leader performed names that leader.
        let actor = MembersHomeMapper.nonEmpty(event.actorName?.trimmingCharacters(in: .whitespacesAndNewlines))
            .map { " by \($0)" } ?? ""
        return Event(date: date(event.at, timeZone: timeZone), text: description + actor,
                     highlight: event.type == .accepted ? "Accepted" : "",
                     tone: event.type == .accepted ? "positive" : "neutral")
    }
}
