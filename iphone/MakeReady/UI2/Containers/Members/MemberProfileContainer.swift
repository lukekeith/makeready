import SwiftUI

/// ui2-members-browse §iphone Member page: the pushed `.memberDetail` page (D1). It owns its
/// ScrollView (the screen has no root scroll); C-040 back pops its tab's stack. Cache-first for
/// the session (D21): the stores render at once — the list-known name heads the page while it
/// loads (F5) — and four loads refresh them; a failure keeps what is shown.
struct MemberProfileContainer: View {
    let memberId: String
    let name: String

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    /// Bumped when program covers land in Ui2ImageCache, which SwiftUI does not observe.
    @State private var coversSeeded = 0

    var body: some View {
        let app = AppState.shared
        let mapped = MemberProfileMapper.state(
            .init(name: name, detail: app.memberDetails[memberId], groups: app.memberGroupsById[memberId],
                  engagement: app.memberEngagementById[memberId], days: app.memberDaysById[memberId],
                  organizationId: app.organizationId),
            today: Date(), timeZone: .current
        )
        let _ = coversSeeded
        // The screen reads covers from Ui2ImageCache, which SwiftUI does not observe — so a cover
        // reaches it only once cached, and its arrival changes the screen's input (round 1).
        let state = {
            var state = mapped
            state.programCoverURLs = Self.cachedCoverURLs(mapped.programCoverURLs)
            state.fieldsEditable = app.memberDetails[memberId] != nil     // ui2-members-edit D27
            return state
        }()
        // D22: C-040 stays pinned above the scroll; the screen is told not to draw it again.
        VStack(spacing: 0) {
            PageHeader(
                style: .twoIcons,
                title: state.memberName,
                showTitle: true,
                showIcons: false,
                leadingGlyph: .back,
                rightButtons: [],
                onLeading: { navigator.pop() }    // members-profile §3: back pops to the presenter
            )
            ScrollView(.vertical) {
                MembersProfileScreen(
                    state: state,
                    showsHeader: false,
                    // ui2-members-edit D2: a field row pushes its edit page on this tab's stack.
                    onEditField: { navigator.push(.editMemberField(memberId: memberId, field: $0)) },
                    // ui2-groups-browse D7: a group row opens that group's page. Program rows, both
                    // `add`s and the day cards stay no-ops (browse D5).
                    onOpenGroup: { row in
                        guard let page = Self.groupDestination(app.memberGroupsById[memberId], row: row) else { return }
                        navigator.push(page)
                    }
                )
            }
            .scrollIndicators(.hidden)
        }
        .background(Token.layoutBackground.ignoresSafeArea())
        .task { await Self.load(memberId: memberId, authManager: authManager) }
        .task(id: mapped.programCoverURLs) {
            if await Self.seedCovers(mapped.programCoverURLs) { coversSeeded += 1 }
        }
    }

    @MainActor
    static func load(memberId: String, authManager: AuthManager) async {
        await AppState.shared.loadInitialData()                      // the org for the rail's scope
        let actions = MemberActions(onUnauthorized: { [authManager] in
            // ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "MemberProfileContainer.signOut", surface: false)
            }
        })
        async let detail: () = actions.loadMember(memberId)
        async let groups: () = actions.loadMemberGroups(memberId)
        async let engagement: () = actions.loadEngagement(memberId)
        async let days: () = actions.loadMemberDays(memberId)
        _ = await (detail, groups, engagement, days)
    }

    /// Each URL already in Ui2ImageCache, else "" (C-059's missing-cover box until it lands).
    @MainActor
    static func cachedCoverURLs(_ urls: [String]) -> [String] {
        urls.map { raw in
            guard let url = URL(string: raw), Ui2ImageCache.shared.image(for: url) != nil else { return "" }
            return raw
        }
    }

    /// ui2-groups-browse D7: the page a group row opens — rows are `memberGroupsById` in order
    /// (MemberProfileMapper maps them one-for-one).
    static func groupDestination(_ groups: [MemberGroupItem]?, row: Int) -> UI2Destination? {
        guard let groups, groups.indices.contains(row) else { return nil }
        return .groupDetail(id: groups[row].id, name: groups[row].name)
    }

    /// C-059 §4 `cover: Image?` is caller-resolved: the screen reads Ui2ImageCache only
    /// (`MembersProfileScreen.cachedImage`), so the page puts each program cover there. A cover
    /// that fails to load keeps C-059's missing-cover box. Returns whether any cover landed.
    @MainActor
    static func seedCovers(_ urls: [String]) async -> Bool {
        var seeded = false
        for raw in urls {
            guard let url = URL(string: raw), url.scheme?.hasPrefix("http") == true,
                  Ui2ImageCache.shared.image(for: url) == nil else { continue }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    Ui2ImageCache.shared.seed(image, for: url)
                    seeded = true
                }
            } catch {
                if error is CancellationError || (error as? URLError)?.code == .cancelled { return seeded }
                AppState.shared.recordError(error, context: "MemberProfileContainer.seedCovers", surface: false)
            }
        }
        return seeded
    }
}
