import CoreGraphics

/// video-recorder D20: when the Library's video list asks for its next page. Pure, so it is tested without a view.
enum LibraryVideoPaging {
    /// A floor for one row's height, below any row at the default text size: the list's content height is
    /// estimated as `rowCount * rowHeightFloor`. An underestimate only brings the next page in sooner (a tall
    /// row, such as a large Dynamic Type size, shrinks the real distance to the end less than the estimate
    /// says), so paging errs eager, never late.
    static let rowHeightFloor: CGFloat = 56

    /// The look-ahead is one viewport, and never less than this many floor-height rows, so a viewport that is
    /// not measured yet (0) still pages.
    private static let minimumLookAheadRows: CGFloat = 8

    /// True when the end of the estimated content is within one look-ahead of the bottom of the viewport.
    static func isNearEnd(offset: CGFloat, viewport: CGFloat, rowCount: Int) -> Bool {
        let lookAhead = max(viewport, minimumLookAheadRows * rowHeightFloor)
        return offset + viewport + lookAhead >= CGFloat(rowCount) * rowHeightFloor
    }

    /// Whether to fetch the next page now. A failed page waits for the user (Retry, refresh or reappearing)
    /// instead of looping on a dead network.
    static func shouldLoadNext(hasMore: Bool, windowMatchesQuery: Bool, videosShown: Bool, isLoading: Bool,
                               lastPageFailed: Bool, offset: CGFloat, viewport: CGFloat, rowCount: Int) -> Bool {
        hasMore && windowMatchesQuery && videosShown && !isLoading && !lastPageFailed
            && isNearEnd(offset: offset, viewport: viewport, rowCount: rowCount)
    }
}

/// video-recorder D17: what a swipe-delete on a Library video row does. The screen already asked
/// "Delete this video?"; this reads the decision, deletes at once or asks the second confirm, and sends a
/// failure to the error banner with the row left in place. The server and queue calls are seams so a test
/// scripts them.
@MainActor
struct LibraryVideoDeletion {
    /// The row id prefix of a queued video (`LibraryHomeMapper.visibleVideos`, D27).
    static let localPrefix = "local:"

    /// A video lessons use, waiting for the second confirm.
    struct Removal: Equatable {
        let id: String
        let decision: VideoDeleteDecision
        /// The queue item to drop once the server row is gone, when the row was a queued video.
        let localId: String?
    }

    var decide: (String) async throws -> VideoDeleteDecision
    var perform: (String, VideoDeleteDecision) async throws -> Void
    /// A queued video's server row, when its upload already created one.
    var serverId: (String) -> String?
    var removeQueued: (String) async throws -> Void
    var askAgain: (Removal) -> Void
    var surface: (_ error: Error, _ context: String, _ message: String, _ retry: @escaping () -> Void) -> Void

    /// A row's swipe. A queued video with no server row is dropped from the queue; one with a server row goes
    /// through the server flow, then leaves the queue.
    func delete(id: String) async {
        var localId: String?
        var serverRowId = id
        if id.hasPrefix(Self.localPrefix) {
            let local = String(id.dropFirst(Self.localPrefix.count))
            guard let existing = serverId(local) else {
                await dropQueued(local)
                return
            }
            localId = local
            serverRowId = existing
        }
        do {
            let decision = try await decide(serverRowId)
            let removal = Removal(id: serverRowId, decision: decision, localId: localId)
            switch decision {
            case .delete: try await run(removal)
            case .removeFromLibrary: askAgain(removal)
            }
        } catch {
            surface(error, "LibraryHomeContainer.deleteVideo", "Couldn't delete this video") { [self] in
                Task { await delete(id: id) }
            }
        }
    }

    /// The second confirm's action.
    func confirm(_ removal: Removal) async {
        do {
            try await run(removal)
        } catch {
            surface(error, "LibraryHomeContainer.confirmRemoval", "Couldn't remove this video from your Library") { [self] in
                Task { await confirm(removal) }
            }
        }
    }

    private func run(_ removal: Removal) async throws {
        try await perform(removal.id, removal.decision)
        if let localId = removal.localId { await dropQueued(localId) }
    }

    /// An item that finished meanwhile is gone already (`CancellationError`): nothing is left to remove.
    private func dropQueued(_ localId: String) async {
        do {
            try await removeQueued(localId)
        } catch is CancellationError {
            return
        } catch {
            surface(error, "LibraryHomeContainer.removeQueuedVideo", "Couldn't delete this video") { [self] in
                Task { await dropQueued(localId) }
            }
        }
    }
}
