import Foundation
import Observation

/// bible-verse-picker D2: one open Bible picker — who asked, where Select returns to, and what the lesson
/// already uses. Memory-only in `AppState.biblePickFlows`, keyed by the flow id the four picker routes carry
/// (the enrollment-draft precedent); it ends when its pick is taken.
struct BiblePickFlow: Equatable {
    /// Who asked for a passage, so the caller — not the picker — does the create or replace (D2, D15).
    enum Caller: Equatable {
        /// A new `bible` activity in a lesson, after `afterActivityId` (nil = first).
        case newActivity(lessonId: String, afterActivityId: String?)
        /// An existing `bible` activity whose passage is being changed (D12).
        case change(activityId: String)
    }

    var caller: Caller
    /// The caller's stack depth when the picker was opened; Select pops to it in one path write (D2).
    var returnDepth: Int
    /// The lesson's passages already in use, for the D5 outline and D4 underlay (D16).
    var used: [BiblePassage]
    /// The passage being changed, shown selected when the picker opens at it (D12).
    var initial: BiblePassage?
}

/// What Select returns: the passage and the chapter's canonical text for it (D8, D9).
struct BiblePick: Equatable {
    let passage: BiblePassage
    /// The chapter's verses `verseStart...verseEnd`, whole — the offsets in `passage` trim the first and last.
    let verses: [BibleVerse]
    let bookName: String
}

/// How Select returns a pick to its caller. A destination is `Hashable` and cannot hold a closure, so the
/// pick is delivered here keyed by the flow id (as `ActivityBackgroundPick`); the caller reads it with
/// `take(for:)` once the picker is gone, which clears it and ends the flow (D2).
@Observable
@MainActor
final class BiblePassagePick {
    static let shared = BiblePassagePick()

    /// The picks waiting for their caller, by flow id.
    private(set) var pending: [UUID: BiblePick] = [:]

    func deliver(_ pick: BiblePick, for flowId: UUID) {
        pending[flowId] = pick
    }

    /// The pick for `flowId`, once. Taking it removes the flow record.
    func take(for flowId: UUID) -> BiblePick? {
        guard let pick = pending.removeValue(forKey: flowId) else { return nil }
        AppState.shared.endBiblePickFlow(flowId)
        return pick
    }
}
