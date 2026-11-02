import Foundation

enum RequestDetailMapper {
    struct Output {
        var state: RequestDetailScreen.State
        let groupID: String?
        let groupDestination: UI2Destination?
    }
    static func output(_ detail: InvitationDetail, busy: Bool, timeZone: TimeZone) -> Output? {
        guard let selected = detail.selectedInvitation else { return nil }
        let status: String
        switch selected.status {
        case .requested: status = "pending"
        case .accepted: status = "approved"
        case .rejected: status = "rejected"
        default: status = selected.status.rawValue
        }
        let phone = InviteDetailMapper.phone(detail.recipientPhone)
        let events = detail.events.map { InviteDetailMapper.event($0, phone: phone, timeZone: timeZone) }
        let name = InviteDetailMapper.text(selected.groupName, fallback: "No group")
        return Output(state: .init(
            phone: phone, requestDate: InviteDetailMapper.date(detail.createdAt, timeZone: timeZone),
            requestTime: time(detail.createdAt, timeZone: timeZone), groupName: name,
            groupPhotoURL: selected.groupPicture ?? "", status: status,
            statusDate: InviteDetailMapper.date(selected.date, timeZone: timeZone), loading: false,
            eventDates: events.map(\.date), eventTexts: events.map(\.text), eventHighlights: events.map(\.highlight),
            responding: busy), groupID: selected.groupId,
            groupDestination: selected.groupId.map { .groupDetail(id: $0, name: name) })
    }
    private static func time(_ iso: String, timeZone: TimeZone) -> String {
        guard let date = MembersHomeMapper.parseDate(iso) else { return "—" }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return "\(hour % 12 == 0 ? 12 : hour % 12):\(String(format: "%02d", minute))\(hour < 12 ? "am" : "pm")"
    }
}
