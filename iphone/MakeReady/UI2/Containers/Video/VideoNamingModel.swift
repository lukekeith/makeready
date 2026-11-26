import Foundation

/// video-naming D3-D5, D15-D18: the naming page's logic. It waits for the transcript, asks for suggestions,
/// holds the two fields, and hands the typed title and description to `save`. It stores nothing in `AppState`:
/// the suggestions belong to this page alone.
@MainActor @Observable
final class VideoNamingModel {
    /// D18: the same limits D6 puts on a suggestion.
    static let titleLimit = 80
    static let descriptionLimit = 300
    /// D3: the rows the block shows.
    static let rowLimit = 3

    enum Block: Equatable {
        case generating, list, regenerating, prompt, empty
    }

    /// D18: the automatic "Video N", shown while the Title is empty.
    let titlePlaceholder: String
    private(set) var title = ""
    private(set) var description = ""
    private(set) var block: Block = .generating
    private(set) var suggestions: [VideoDetailSuggestion] = []

    private let transcript: () async -> String?
    private let suggest: (String) async throws -> [VideoDetailSuggestion]
    private let save: (String, String) async -> Bool
    private let back: () -> Void

    /// The text every ask sends: the transcript cut to the server's limit (D15).
    private var askedText = ""
    /// Bumped by every ask, `leave`, the check and Back: an answer that finds it changed is stale (D17).
    private var generation = 0
    private var isSaving = false
    private var hasSaved = false

    /// - Parameters:
    ///   - transcript: the clip's transcript text, nil when there is none
    ///   - suggest: asks the server for suggestions from the transcript text
    ///   - save: stores the typed title and description; true when it went through
    ///   - back: leaves the page without saving
    init(titlePlaceholder: String,
         transcript: @escaping () async -> String?,
         suggest: @escaping (String) async throws -> [VideoDetailSuggestion],
         save: @escaping (String, String) async -> Bool,
         back: @escaping () -> Void) {
        self.titlePlaceholder = titlePlaceholder
        self.transcript = transcript
        self.suggest = suggest
        self.save = save
        self.back = back
    }

    /// The copy the block shows when it has no rows to show.
    var promptCopy: String? {
        switch block {
        case .empty: "No speech to suggest from"
        case .prompt: "Couldn't get suggestions"
        default: nil
        }
    }

    // MARK: - Suggestions

    /// D5: waits for the transcript, then asks. No speech leaves the block `empty` and nothing is asked.
    func open() {
        block = .generating
        generation += 1
        let mine = generation
        Task {
            let text = await transcript()
            guard mine == generation else { return }
            guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                block = .empty
                return
            }
            askedText = VideoTranscriptLimits.prefix(text, units: VideoTranscriptLimits.maxTextUnits)
            ask(failureBlock: .prompt)
        }
    }

    /// D16: from the rows → `regenerating` with the rows still pickable; from the prompt → `generating`.
    func regenerate() {
        switch block {
        case .list:
            block = .regenerating
            ask(failureBlock: .list)
        case .prompt:
            block = .generating
            ask(failureBlock: .prompt)
        case .generating, .regenerating, .empty:
            break
        }
    }

    /// D3, D17: a pick replaces both fields; the list stays. An index with no row does nothing.
    func pick(_ index: Int) {
        guard suggestions.indices.contains(index) else { return }
        title = Self.cut(suggestions[index].title, to: Self.titleLimit)
        description = Self.cut(suggestions[index].description, to: Self.descriptionLimit)
    }

    private func ask(failureBlock: Block) {
        generation += 1
        let mine = generation
        let text = askedText
        Task {
            do {
                let answer = try await suggest(text)
                guard mine == generation else { return }
                suggestions = Array(answer.prefix(Self.rowLimit))
                block = .list
            } catch {
                guard mine == generation else { return }
                // D16: suggestions are optional help, so a failure is console-only (a 401 follows the app's sign-out rule).
                Log.ui.error("naming suggestions failed: \(error.localizedDescription, privacy: .public)")
                block = failureBlock
            }
        }
    }

    // MARK: - Fields

    func setTitle(_ text: String) { title = Self.cut(text, to: Self.titleLimit) }
    func setDescription(_ text: String) { description = Self.cut(text, to: Self.descriptionLimit) }

    private static func cut(_ text: String, to limit: Int) -> String { String(text.prefix(limit)) }

    // MARK: - Leaving

    /// D4, D17: one save at a time, and none after one that went through; a failed one can be tapped again.
    /// An answer that lands after the check is dropped.
    func saveTapped() {
        guard !isSaving, !hasSaved else { return }
        isSaving = true
        generation += 1
        let (title, description) = (title, description)
        // Immediate: the guard above must see a save that finishes without waiting as already finished.
        Task.immediate {
            let went = await save(title, description)
            isSaving = false
            hasSaved = went
        }
    }

    func backTapped() {
        generation += 1
        back()
    }

    /// The page left the screen another way: nothing it asked for may land.
    func leave() {
        generation += 1
    }
}
