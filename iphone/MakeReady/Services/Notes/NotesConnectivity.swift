//
//  NotesConnectivity.swift
//  MakeReady
//
//  notes D13, D24: flushes the note save queue each time the network comes back.
//

import Foundation
import Network

@MainActor
final class NotesConnectivity {

    /// Runs on each transition into `.satisfied`, never on a repeat of it.
    var onSatisfied: () -> Void = {}

    private var lastStatus: NWPath.Status?
    private var monitor: NWPathMonitor?

    /// Feeds one path status in; fires `onSatisfied` when it is a transition into `.satisfied`.
    func handle(_ status: NWPath.Status) {
        defer { lastStatus = status }
        guard status == .satisfied, lastStatus != .satisfied else { return }
        onSatisfied()
    }

    /// Starts the one path monitor and points `onSatisfied` at `queue.flush()`. A second call is a no-op.
    func start(queue: NoteSaveQueue) {
        guard monitor == nil else { return }
        onSatisfied = { Task { @MainActor in _ = await queue.flush() } }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let status = path.status
            Task { @MainActor in self?.handle(status) }
        }
        monitor.start(queue: DispatchQueue(label: "com.makeready.notes.connectivity", qos: .utility))
        self.monitor = monitor
    }
}
