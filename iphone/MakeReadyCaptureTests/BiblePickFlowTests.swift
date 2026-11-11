import XCTest
@testable import MakeReady

/// bible-verse-picker D2/D25: the picker's flow record and the mailbox its pick returns through.
@MainActor
final class BiblePickFlowTests: XCTestCase {
    private static let pick = BiblePick(
        passage: BiblePassage(bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3, verseEnd: 18,
                              startOffset: nil, endOffset: nil, translation: "ENGKJV"),
        verses: [BibleVerse(verse: 16, text: "For God so loved the world"), BibleVerse(verse: 17, text: "For God sent not"),
                 BibleVerse(verse: 18, text: "He that believeth on him")],
        bookName: "John")

    private var state: AppState { AppState.shared }

    override func tearDown() {
        state.biblePickFlows = [:]
        super.tearDown()
    }

    func testAPickIsTakenOnceAndClearsItsFlow() {
        let f = UUID()
        state.biblePickFlows[f] = BiblePickFlow(caller: .change(activityId: "a"), returnDepth: 2, used: [], initial: nil)
        BiblePassagePick.shared.deliver(Self.pick, for: f)
        XCTAssertEqual(BiblePassagePick.shared.take(for: f), Self.pick)
        XCTAssertNil(state.biblePickFlows[f])
        XCTAssertNil(BiblePassagePick.shared.take(for: f))
    }

    /// D15: Back from Books delivers nothing, so there is nothing to take.
    func testNothingIsTakenForAFlowThatDeliveredNothing() {
        let f = UUID()
        state.biblePickFlows[f] = BiblePickFlow(caller: .newActivity(lessonId: "l", afterActivityId: nil),
                                                returnDepth: 1, used: [], initial: nil)
        XCTAssertNil(BiblePassagePick.shared.take(for: f))
    }

    func testPicksStayWithTheirOwnFlow() {
        let a = UUID(), b = UUID()
        BiblePassagePick.shared.deliver(Self.pick, for: a)
        XCTAssertNil(BiblePassagePick.shared.take(for: b))
        XCTAssertEqual(BiblePassagePick.shared.take(for: a), Self.pick)
    }

    func testClearingTheSessionDropsOpenFlows() {
        let session = AppState()
        session.biblePickFlows[UUID()] = BiblePickFlow(caller: .change(activityId: "a"), returnDepth: 2, used: [], initial: nil)
        session.clearAllData()
        XCTAssertTrue(session.biblePickFlows.isEmpty)
    }
}
