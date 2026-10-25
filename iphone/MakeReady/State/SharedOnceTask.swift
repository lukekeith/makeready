import Foundation

/// Runs a piece of async work at most once until `reset()`, and lets every caller await that
/// one run — a caller that arrives while it is in flight waits for it instead of returning
/// early. SPEC D24: `HomeDashboardContainer`'s first analytics query waits for the shell's
/// `loadInitialData()` (it sets `AppState.organizationId`, which every Home query filters by).
@MainActor
final class SharedOnceTask {
    private var task: Task<Void, Never>?

    func run(_ work: @escaping @MainActor () async -> Void) async {
        if let task { await task.value; return }
        let next = Task { @MainActor in await work() }
        task = next
        await next.value
    }

    /// The next `run` starts fresh (an environment switch reloads initial data).
    func reset() { task = nil }
}
