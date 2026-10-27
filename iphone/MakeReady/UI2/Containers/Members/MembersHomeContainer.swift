import SwiftUI

/// ui2-members-browse §iphone Members: the Home tab's Members section (P12, D6, D7/D15, D19).
/// Cache-first for the session (D21): renders the directory store at once and loads after the
/// shell's initial load, so the org id is known (D18). The screen has no root scroll — the
/// shell's page scroll (HomeSectionLayout) scrolls it. A row tap pushes the member page (D1).
struct MembersHomeContainer: View {
    /// members-home §3 / T13: search waits this long after the last keystroke.
    static let searchDebounce: Duration = .milliseconds(300)

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    @State private var selection = MembersHomeMapper.Selection()
    /// The one in-flight directory load; a newer keystroke or pick cancels it (T13: Task cancel +
    /// `Task.sleep`, never `asyncAfter`).
    @State private var loadTask: Task<Void, Never>?
    /// members-search-pinned: while search is active the shell's TopNav moves off screen.
    @State private var searchActive = false

    var body: some View {
        let app = AppState.shared
        let output = MembersHomeMapper.output(
            directory: app.organizationId.flatMap { app.orgMembersByOrgId[$0] },
            groups: Self.groupOptions(app.groups.all),
            leaders: Self.leaderOptions(app.groupLeaders),
            selection: selection, today: Date(), timeZone: .current
        )
        MembersHomeScreen(
            state: output.state,
            onSearch: { text in
                var next = selection
                next.search = text
                selection = next
                reload(next, after: Self.searchDebounce)
            },
            onSelectGroup: { label in
                var next = selection
                switch output.groupPick(label) {
                case .all: next.groupId = nil
                case .option(let id): next.groupId = id
                case .unknown: return
                }
                selection = next
                reload(next, after: nil)
            },
            onSelectLeader: { label in
                var next = selection
                switch output.leaderPick(label) {
                case .all: next.leaderId = nil
                case .option(let id): next.leaderId = id
                case .unknown: return
                }
                selection = next
                reload(next, after: nil)
            },
            onOpenMember: { row in
                guard let id = output.memberId(atRow: row) else { return }
                navigator.push(.memberDetail(id: id, name: output.state.memberNames[row]))
            },
            onSearchActiveChange: { searchActive = $0 }
        )
        .preference(key: UI2HidesTopNavKey.self, value: searchActive)
        .task {
            reload(selection, after: nil)
            await actions.loadFilterOptions()
        }
        .onDisappear { loadTask?.cancel() }
    }

    /// members-home §5: the Groups options, by name.
    static func groupOptions(_ groups: [UserGroup]) -> [MembersHomeMapper.Option] {
        groups
            .map { MembersHomeMapper.Option(id: $0.id, label: $0.name) }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    /// members-home §5: the Leaders options, in `/api/group-leaders` order; the id is the
    /// leader's `User.id` the list's `leaderId` filter takes.
    static func leaderOptions(_ leaders: [GroupLeader]) -> [MembersHomeMapper.Option] {
        leaders.map { MembersHomeMapper.Option(id: $0.id, label: $0.displayName) }
    }

    private var actions: MemberActions {
        MemberActions(onUnauthorized: { [authManager] in
            // ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "MembersHomeContainer.signOut", surface: false)
            }
        })
    }

    private func reload(_ next: MembersHomeMapper.Selection, after delay: Duration?) {
        loadTask?.cancel()
        let memberActions = self.actions
        loadTask = Task { @MainActor in
            if let delay {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
            }
            await Self.load(next, actions: memberActions)
        }
    }

    @MainActor
    static func load(_ selection: MembersHomeMapper.Selection, actions: MemberActions) async {
        await AppState.shared.loadInitialData()                      // D18: waits for the org
        guard let orgId = AppState.shared.organizationId else { return }
        await actions.loadDirectory(orgId: orgId, search: selection.search,
                                    groupIds: Set([selection.groupId].compactMap { $0 }),
                                    leaderIds: Set([selection.leaderId].compactMap { $0 }))
    }
}
