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
        let state = MemberProfileMapper.state(
            .init(name: name, detail: app.memberDetails[memberId], groups: app.memberGroupsById[memberId],
                  engagement: app.memberEngagementById[memberId], days: app.memberDaysById[memberId],
                  organizationId: app.organizationId),
            today: Date(), timeZone: .current
        )
        let _ = coversSeeded
        ScrollView(.vertical) {
            MembersProfileScreen(
                state: state,
                onBack: { navigator.pop() }       // members-profile §3: back pops to the presenter
                // D3/D5: field rows, group rows, program rows, both `add`s and the day cards do
                // nothing in this child — the screen's no-op defaults.
            )
        }
        .scrollIndicators(.hidden)
        .background(Token.layoutBackground.ignoresSafeArea())
        .task { await Self.load(memberId: memberId, authManager: authManager) }
        .task(id: state.programCoverURLs) {
            if await Self.seedCovers(state.programCoverURLs) { coversSeeded += 1 }
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
