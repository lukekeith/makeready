import SwiftUI

/// SPEC D8/D9: Home section content. Cache-first (D20): renders the snapshot at once and
/// refreshes in `.task`, after the shell's initial load (D24) so the queries carry the org.
struct HomeDashboardContainer: View {
    /// home-dashboard §3: the Sessions dropdown's closed option list.
    static let sessionRanges = ["All time", "Year", "Month", "Week"]

    @Environment(AuthManager.self) private var authManager
    @State private var sessionRange = sessionRanges[0]

    var body: some View {
        // The screen has no root ScrollView by design (its canvas is the content's full
        // length); the shell's page scroll (HomeSectionLayout, SPEC D14 revised 2026-10-25)
        // scrolls it vertically.
        HomeDashboardScreen(
            state: HomeDashboardMapper.state(
                from: AppState.shared.dashboard, today: Date(),
                timeZone: .current, sessionRange: sessionRange
            ),
            onPickMetrics: {},                                   // D9 no-op
            onJumpToToday: {},                                   // D31: the screen eases back itself
            onSelectSessionRange: { sessionRange = $0 },         // D13: re-maps Sessions from the snapshot, no fetch
            onOpenEngagement: {},                                // D9 no-op
            onFollowEnrollment: {},                              // D9 no-op
            onProgramMenu: { _ in },                             // D9 no-op
            onOpenGroup: { _ in },                               // D9 no-op
            introsEnabled: true                                  // dashboard-chart-intros D7
        )
        .task { await Self.refresh(authManager: authManager) }
        .pageRefresh { [authManager] in await Self.refresh(authManager: authManager) }
    }

    /// Home's data fetch — on first appearance, and on the page's pull-to-refresh
    /// (home-dashboard-data D24, declared with `pageRefresh`).
    @MainActor
    static func refresh(authManager: AuthManager) async {
        await AppState.shared.loadInitialData()                      // D24: waits for the org
        await DashboardActions(onUnauthorized: { [authManager] in
            // D27: a 401 ends the session; UI2Root then shows Login.
            do { try await authManager.signOut() } catch {
                AppState.shared.recordError(error, context: "HomeDashboardContainer.signOut", surface: false)
            }
        }).refresh()
    }
}
