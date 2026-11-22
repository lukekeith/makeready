import SwiftUI

/// memo-screens D3 (record tap, owner 2026-11-21), D7, D11: d2m's `RecorderSheet` over a `RecorderSession`. It prepares the recording
/// when it appears and reports how it ended; the shell hosts it (no `.sheet`, no `.fullScreenCover`).
struct RecorderSheetContainer: View {
    let session: RecorderSession
    let onEnd: (RecorderSession.Outcome) -> Void
    @Environment(\.openURL) private var openURL
    /// C-016 owns its slide (hosted overlays get no presenting transaction): false slides it out,
    /// and its `onHidden` reports the outcome once it is gone (owner 2026-11-21).
    @State private var visible = true

    var body: some View {
        RecorderSheet(
            expansion: session.expansion,
            onExpansionChange: session.settle,
            title: RecorderSession.displayTitle,
            startTime: session.startTime,
            elapsed: session.elapsed,
            samples: session.samples,
            // Smooth scroll (owner 2026-11-21): the newest sample's time, and whether it advances.
            sampleTime: session.elapsed,
            isRunning: session.hasStarted && session.phase == .recording,
            // Owner 2026-11-21: the recorder waits for the record tap.
            isReady: !session.hasStarted && session.phase != .micDenied && session.outcome == nil,
            onRecord: { Task { await session.record() } },
            phase: session.phase,
            menu: session.menu,
            visible: visible,
            onHidden: { if let outcome = session.outcome { onEnd(outcome) } },
            onDismiss: dismiss,
            onStop: { Task { await session.finish() } },
            onMore: session.openMenu,
            onDone: { Task { await session.finish() } },
            onPause: session.pause,
            onResume: session.resume,
            onDiscardRequest: session.requestDiscard,
            onDiscard: { Task { await session.confirmDiscard() } },
            onDismissMenu: session.dismissMenu,
            onOpenSettings: openSettings,
            onClose: session.close
        )
        .task { await session.begin() }
        .onChange(of: session.engineFailed) { _, failed in
            if failed { session.failIfEngineFailed() }
        }
        .onChange(of: session.outcome) { _, outcome in
            if outcome != nil { visible = false }
        }
    }

    /// The dim tap or a swipe down (like the + menu, owner 2026-11-21): before recording it closes
    /// and keeps nothing; while recording it saves, as Done does — a stray tap never loses a memo.
    private func dismiss() {
        if session.hasStarted {
            Task { await session.finish() }
        } else {
            session.close()
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}
