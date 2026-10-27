import SwiftUI

/// invite-member D3: the group pick before the invite, for a leader of 2+ groups. Hosts the
/// d2m-built `EnrollmentSelectGroupScreen` unchanged; rows come from AppState (D14), search and
/// the Leaders filter are local UI state, the Orgs chip never shows (D16). T8: each listed group's
/// enrollments load in the background so the third chip fills in as they land.
struct InviteSelectGroupContainer: View {
    let returnDepth: Int

    @Environment(\.ui2Navigator) private var navigator
    @State private var query = ""
    @State private var leader: String?
    @State private var leaderMenuOpen = false

    var body: some View {
        let app = AppState.shared
        let groups = app.groups.all
        let output = InviteSelectGroupMapper.output(.init(
            groups: groups,
            enrollmentCounts: Dictionary(uniqueKeysWithValues: groups.map { ($0.id, app.enrollmentsFor(groupId: $0.id).count) }),
            query: query,
            leader: leader,
            loading: groups.isEmpty && app.loadingStates.isLoading(.groups),
            failed: false
        ))
        EnrollmentSelectGroupScreen(
            state: output.state,
            onBack: { navigator.pop() },
            onSelect: { index in
                guard output.groupIds.indices.contains(index) else { return }
                navigator.push(.inviteMember(groupId: output.groupIds[index], returnDepth: returnDepth))
            },
            onSearch: { query = $0 },
            onOpenLeaderFilter: { leaderMenuOpen = true }
        )
        .filterMenuPresentation(isPresented: leaderMenuOpen, onDismiss: { leaderMenuOpen = false }) {
            FilterMenuOverlay(
                options: output.leaderOptions.map { FilterMenuOverlay.Option(id: $0, label: $0) },
                selectionMode: .single,
                selectedIDs: leader.map { [$0] } ?? [],
                onSelect: { option in
                    leader = (leader == option.id) ? nil : option.id   // re-tapping the chosen leader clears it
                    leaderMenuOpen = false
                },
                onClose: { leaderMenuOpen = false }
            )
        }
        .task { await Self.loadEnrollmentCounts(for: groups.map(\.id)) }
    }

    /// T8: no list endpoint carries an enrollment count, so each group without cached
    /// enrollments loads its own, concurrently. Background: failures stay console-only.
    @MainActor
    static func loadEnrollmentCounts(for groupIds: [String], state: AppState? = nil, api: APIClientProtocol? = nil) async {
        let state = state ?? AppState.shared
        let api = api ?? APIClient.shared
        let missing = groupIds.filter { !state.groupEnrollmentIndex.hasChildren($0) }
        await withTaskGroup(of: Void.self) { tasks in
            for id in missing {
                tasks.addTask { @MainActor in
                    do {
                        _ = try await EnrollmentActions(api: api, state: state).loadEnrollments(groupId: id)
                    } catch {
                        state.recordError(error, context: "InviteSelectGroupContainer.loadEnrollmentCounts")
                    }
                }
            }
        }
    }
}
