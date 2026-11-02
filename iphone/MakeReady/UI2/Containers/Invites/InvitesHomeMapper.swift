import Foundation

/// The feed window owns ordering and membership; the entity store can retain older rows.
enum InvitesHomeMapper {
    enum Dimension: String { case org = "Orgs", group = "Groups", leader = "Leaders", status = "Status" }
    enum InvitationRowSelection: Equatable { case invite(id: String), request(id: String) }
    enum Mode { case empty, noResults, populated }
    struct Selection: Equatable {
        var search = ""
        var orgID: String?
        var groupID: String?
        var leaderID: String?
        var status: InvitationDisplayStatus?
        var query: InvitationQuery { .init(orgId: orgID, groupId: groupID, leaderId: leaderID, status: status) }
    }
    struct Output {
        let state: InvitesHomeScreen.State
        let rows: [InvitationRowSelection]
        let mode: Mode
        func selection(atRow row: Int) -> InvitationRowSelection? { rows.indices.contains(row) ? rows[row] : nil }
        func rowDate(at row: Int) -> String? { state.inviteDates.indices.contains(row) ? state.inviteDates[row] : nil }
    }
    static let allID = "__all__"
    static func options(_ dimension: Dimension, filters: InvitationFilters?) -> [FilterMenuOverlay.Option] {
        let options: [(String, String)]
        switch dimension {
        case .org: options = (filters?.orgs ?? []).map { ($0.id, $0.name) }
        case .group: options = (filters?.groups ?? []).map { ($0.id, $0.name) }
        case .leader: options = (filters?.leaders ?? []).map { ($0.id, $0.name) }
        case .status: options = InvitationDisplayStatus.allCases.map { ($0.rawValue, $0.rawValue.capitalized) }
        }
        return [.init(id: allID, label: "All \(dimension.rawValue)")] + options.map { .init(id: $0.0, label: $0.1) }
    }
    static func selectedID(_ dimension: Dimension, _ selection: Selection) -> String? {
        switch dimension {
        case .org: return selection.orgID
        case .group: return selection.groupID
        case .leader: return selection.leaderID
        case .status: return selection.status?.rawValue
        }
    }
    static func saving(_ ids: Set<String>, in dimension: Dimension, selection: Selection) -> Selection {
        var next = selection
        let id = ids.first.flatMap { $0 == allID ? nil : $0 }
        switch dimension {
        case .org: next.orgID = id
        case .group: next.groupID = id
        case .leader: next.leaderID = id
        case .status: next.status = id.flatMap(InvitationDisplayStatus.init(rawValue:))
        }
        return next
    }
    static func output(window: InvitationFeedWindow?, entities: [String: InvitationFeedItem], filters: InvitationFilters?,
                       selection: Selection, now: Date, timeZone: TimeZone, loading: Bool = false) -> Output {
        let needle = selection.search.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchingWindow = window.flatMap { $0.query == selection.query ? $0 : nil }
        let digits = needle.filter(\.isNumber)
        let phoneQuery = !digits.isEmpty && needle.allSatisfy { $0.isNumber || "+()-. ".contains($0) }
        let items = (matchingWindow?.orderedIDs ?? []).compactMap { entities[$0] }.filter { item in
            let phone = item.recipientPhone ?? ""
            return needle.isEmpty || phone.localizedCaseInsensitiveContains(needle)
                || InputMask.phone.format(phone).localizedCaseInsensitiveContains(needle)
                || (phoneQuery && phone.filter(\.isNumber).contains(digits))
                || (item.groupName?.localizedCaseInsensitiveContains(needle) ?? false)
        }
        func label(_ dimension: Dimension) -> String {
            let menu = options(dimension, filters: filters)
            return menu.first { $0.id == selectedID(dimension, selection) }?.label ?? menu[0].label
        }
        let state = InvitesHomeScreen.State(
            searchText: selection.search, orgFilterLabel: label(.org), groupFilterLabel: label(.group),
            leaderFilterLabel: label(.leader), statusFilterLabel: label(.status), loading: loading && matchingWindow == nil,
            inviteRecipients: items.map { $0.recipientPhone.map { InputMask.phone.format($0) } ?? "No phone number" },
            inviteStatuses: items.map { $0.status.rawValue }, inviteGroupNames: items.map { $0.groupName ?? "No group" },
            inviteDates: items.map { dateLabel($0.date, now: now, timeZone: timeZone) })
        let rows = items.map { $0.kind == .invite ? InvitationRowSelection.invite(id: $0.id) : .request(id: $0.id) }
        let narrowed = !needle.isEmpty || selection.query != InvitationQuery()
        return Output(state: state, rows: rows, mode: items.isEmpty ? (narrowed ? .noResults : .empty) : .populated)
    }
    static func dateLabel(_ iso: String, now: Date, timeZone: TimeZone) -> String {
        guard let date = MembersHomeMapper.parseDate(iso) else { return "" }
        if now.timeIntervalSince(date) >= 0 && now.timeIntervalSince(date) < 60 { return "Just now" }
        return MembersHomeMapper.mediumDate(date, timeZone: timeZone)
    }
}
