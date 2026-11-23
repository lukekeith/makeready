import Foundation

/// memo-screens D5, T5: library-home's search runs the notes, memos and videos searches together and
/// keeps whichever side answered. The videos search lands in the Library window (D20), so it returns nothing.
enum LibraryHomeSearch {

    struct Result {
        let noteIds: [String]
        let memos: [VoiceMemoSummary]
        /// True when a side threw, so the caller can surface it while still showing the other side.
        let failed: Bool
    }

    /// A side that throws contributes nothing and sets `failed`. A `CancellationError` from any side
    /// is rethrown: a newer search or leaving the page cancelled this one, which is not a failure.
    static func run(
        q: String,
        loadNotes: () async throws -> [String],
        loadMemos: () async throws -> [VoiceMemoSummary],
        loadVideos: () async throws -> Void = {}
    ) async throws -> Result {
        async let notes = attempt(loadNotes)
        async let memos = attempt(loadMemos)
        async let videos = attempt(loadVideos)
        let (noteOutcome, memoOutcome, videoOutcome) = try await (notes, memos, videos)
        return Result(noteIds: noteOutcome ?? [], memos: memoOutcome ?? [],
                      failed: noteOutcome == nil || memoOutcome == nil || videoOutcome == nil)
    }

    /// The loader's value, or nil when it threw anything but a cancellation.
    private static func attempt<T>(_ load: () async throws -> T) async throws -> T? {
        do {
            return try await load()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Silent here: the caller sees `failed` and decides how to surface it.
            return nil
        }
    }
}
