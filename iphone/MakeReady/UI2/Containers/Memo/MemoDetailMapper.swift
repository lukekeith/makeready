import Foundation

/// memo-screens D4, D16, D17, T3: a memo (stored or still queued) and the player's values →
/// `MemoDetailScreen.State`. Pure: the clock and calendar come in, so a test does not depend on the day it runs.
enum MemoDetailMapper {

    /// A stored memo. `ready` reads its segments, or its whole transcript as one paragraph; `pending` is
    /// transcribing; `failed`, `none` and `unknown` have no transcript to show (D16).
    static func state(memo: VoiceMemo, elapsed: Double, playing: Bool, playerReady: Bool, now: Date, calendar: Calendar)
        -> MemoDetailScreen.State {
        var state = base(title: memo.title, recordedAt: memo.recordedAt, durationMs: memo.durationMs, elapsed: elapsed,
                         playing: playing, playerReady: playerReady, now: now, calendar: calendar)
        switch memo.transcriptStatus {
        case .ready:
            let segments = memo.transcriptSegments ?? []
            if !segments.isEmpty {
                state.transcript = .paragraphs
                (state.paragraphStarts, state.paragraphTexts) = paragraphs(segments)
            } else if let text = memo.transcript, !text.isEmpty {
                state.transcript = .paragraphs
                (state.paragraphStarts, state.paragraphTexts) = ([0], [text])
            } else {
                state.transcript = .unavailable
            }
        case .pending:
            state.transcript = .transcribing
        case .failed, .none, .unknown:
            state.transcript = .unavailable
        }
        return state
    }

    /// A queued memo shows its on-device transcript's segments when it has some, else transcribing (D17).
    static func state(queued: MemoQueueItem, elapsed: Double, playing: Bool, playerReady: Bool, now: Date, calendar: Calendar)
        -> MemoDetailScreen.State {
        var state = base(title: queued.title, recordedAt: NoteTimestamp.parse(queued.recordedAt) ?? now,
                         durationMs: queued.durationMs, elapsed: elapsed, playing: playing, playerReady: playerReady,
                         now: now, calendar: calendar)
        if let segments = queued.transcript?.segments, !segments.isEmpty {
            state.transcript = .paragraphs
            (state.paragraphStarts, state.paragraphTexts) = paragraphs(segments)
        } else {
            state.transcript = .transcribing
        }
        return state
    }

    /// D4: `Today 7:43 PM` — the day part is Today or Yesterday, else the notes row's date label; the
    /// screen appends the duration itself.
    static func metaDate(_ date: Date, now: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        let day: String
        switch days {
        case ...0: day = "Today"
        case 1: day = "Yesterday"
        default: day = NotesSectioning.dateLabel(date, now: now, calendar: calendar)
        }
        return day + " " + time(date, calendar: calendar)
    }

    // MARK: Private

    private static func base(title: String, recordedAt: Date, durationMs: Int?, elapsed: Double, playing: Bool,
                             playerReady: Bool, now: Date, calendar: Calendar) -> MemoDetailScreen.State {
        MemoDetailScreen.State(
            title: title, dateLabel: metaDate(recordedAt, now: now, calendar: calendar),
            duration: Double(durationMs ?? 0) / 1000, elapsed: elapsed, playing: playing, playerReady: playerReady)
    }

    private static func paragraphs(_ segments: [TranscriptSegment]) -> ([Double], [String]) {
        (segments.map { Double($0.startMs / 1000) }, segments.map(\.text))
    }

    private static let timeFormatter = DateFormatter()
    private static let timeLock = NSLock()

    private static func time(_ date: Date, calendar: Calendar) -> String {
        timeLock.lock()
        defer { timeLock.unlock() }
        timeFormatter.calendar = calendar
        timeFormatter.timeZone = calendar.timeZone
        timeFormatter.locale = calendar.locale ?? Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "h:mm a"
        return timeFormatter.string(from: date)
    }
}
