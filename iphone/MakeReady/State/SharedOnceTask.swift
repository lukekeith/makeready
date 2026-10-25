import Foundation

/// Runs a piece of async work at most once until `reset()`, and lets every caller await that
/// one run — a caller that arrives while it is in flight waits for it instead of returning
/// early. SPEC D24: `HomeDashboardContainer`'s first analytics query waits for the shell's
/// `loadInitialData()` (it sets `AppState.organizationId`, which every Home query filters by).
@MainActor
final class SharedOnceTask {
    private var task: Task<Void, Never>?
    /// Bumped by every `reset()`. The work receives the generation it started in, so a result
    /// that lands after a reset can tell it is stale (`isCurrent`) and drop itself.
    private(set) var generation = 0

    func run(_ work: @escaping @MainActor (_ generation: Int) async -> Void) async {
        if let task { await task.value; return }
        let started = generation
        let next = Task { @MainActor in await work(started) }
        task = next
        await next.value
    }

    func isCurrent(_ generation: Int) -> Bool { generation == self.generation }

    /// The next `run` starts fresh (sign-out, environment switch). An in-flight run is
    /// cancelled and its generation retired.
    func reset() {
        task?.cancel()
        task = nil
        generation += 1
    }
}
