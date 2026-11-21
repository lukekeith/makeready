import SwiftUI

/// memo-screens D3, D7, D11: d2m's `RecorderSheet` over a `RecorderSession`. It starts the recording
/// when it appears and reports how it ended; the shell hosts it (no `.sheet`, no `.fullScreenCover`).
struct RecorderSheetContainer: View {
    let session: RecorderSession
    let onEnd: (RecorderSession.Outcome) -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        RecorderSheet(
            expansion: session.expansion,
            onExpansionChange: session.settle,
            title: session.title,
            startTime: session.startTime,
            elapsed: session.elapsed,
            samples: session.samples,
            phase: session.phase,
            menu: session.menu,
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
            if let outcome { onEnd(outcome) }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}
