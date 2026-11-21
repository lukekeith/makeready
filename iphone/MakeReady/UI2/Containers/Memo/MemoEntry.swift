import SwiftUI

/// memo-screens D2, D3, D14: where the Add menu's "Voice memo" row goes — the recorder sheet, over the
/// whole shell, on the live engine.
enum MemoEntry {
    static let rowLabel = "Voice memo"

    /// D14: one recording at a time — a second choice while the sheet is up does nothing.
    static func shouldStart(recorderPresented: Bool) -> Bool { !recorderPresented }

    /// D6, D17: the toast's View opens the memo that is still in the upload queue, by its local id.
    static func viewDestination(localId: String) -> UI2Destination {
        .memoDetail(memoId: "local:\(localId)")
    }

    /// A session on the microphone, speech transcriber and draft store, titled `Memo n`, whose result
    /// goes to the signed-in user's upload queue. Nil, with a banner, when the memo folder cannot be made.
    @MainActor
    static func makeSession(userId: String) -> RecorderSession? {
        let state = AppState.shared
        guard let uploads = state.startMemoUploads(userId: userId) else {
            state.recordError(MemoEngineError.writeFailed, context: "MemoEntry.makeSession", surface: true,
                              friendlyMessage: "Couldn't start the recording")
            return nil
        }
        do {
            let folder = try MemoStorage.folder(environment: AppState.memoEnvironmentName, userId: userId)
            let drafts = MemoDraftStore(directory: MemoStorage.draftsFolder(in: folder), ownerUserId: userId,
                                        environment: AppState.memoEnvironmentName)
            let engine = MemoRecorderEngine(input: LiveAudioInput(), transcriber: MemoTranscriber(),
                                            directory: drafts.directory, drafts: drafts)
            return RecorderSession(engine: engine, title: state.nextMemoTitle(),
                                   enqueue: { try uploads.enqueue($0) }, now: Date.init, calendar: .current)
        } catch {
            state.recordError(error, context: "MemoEntry.makeSession", surface: true,
                              friendlyMessage: "Couldn't start the recording")
            return nil
        }
    }
}

/// memo-screens D6: the "Saved to Library · View" toast's state. A toast stays for `visibleFor`; a newer
/// toast is never hidden by an older toast's timer.
@MainActor @Observable
final class SavedToastPresenter {
    struct Toast: Equatable {
        let id: UUID
        let localId: String
    }

    static let visibleFor: Duration = .seconds(4)

    private(set) var current: Toast?

    func show(localId: String) {
        current = Toast(id: UUID(), localId: localId)
    }

    func dismiss() {
        current = nil
    }

    /// Waits `visibleFor`, then dismisses the toast `id` — and only that one.
    func expire(id: UUID, sleep: (Duration) async -> Void = { try? await Task.sleep(for: $0) }) async {
        await sleep(Self.visibleFor)
        guard !Task.isCancelled, current?.id == id else { return }
        dismiss()
    }
}
