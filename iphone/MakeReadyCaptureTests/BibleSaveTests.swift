import XCTest
@testable import MakeReady

/// bible-verse-picker Task 13 (D14, D29): the ordered, resumable save of a passage - one activity, never split.
@MainActor
final class BibleSaveTests: XCTestCase {

    /// Records each request as the server would see it; created ids are p1, p2, ...
    final class Stub {
        var log: [String] = []
        var failAt: Int?
        private var calls = 0
        private var created = 0
        struct Down: Error {}

        func step() throws {
            defer { calls += 1 }
            if calls == failAt { throw Down() }
        }

        var actions: ActivityNewContainer.Actions {
            ActivityNewContainer.Actions(
                draftVersionId: { _ in "v" },
                create: { [self] _, _, _, _ in
                    try step(); log.append("POST"); created += 1; return "p\(created)"
                },
                reorder: { [self] _, ids in try step(); log.append("PATCH " + ids.joined(separator: ",")) },
                update: { [self] id, _, _ in try step(); log.append("PUT \(id)") })
        }
    }

    private let stub = Stub()

    private static func pick(_ verse: Int) -> BiblePick {
        BiblePick(
            passage: BiblePassage(bookNumber: 43, chapterStart: 3, verseStart: verse, chapterEnd: 3, verseEnd: verse,
                                  startOffset: nil, endOffset: nil, translation: "KJV"),
            verses: [BibleVerse(verse: verse, text: "text \(verse)")], bookName: "John")
    }
    static var planAfterA: BibleSave.Plan { BibleSave.plan(new: pick(1), version: "v", existing: ["a", "b"], after: "a") }

    /// D29: a whole chapter is one activity, never split.
    func testAWholeChapterIsOneActivity() async {
        _ = await BibleSave.run(BibleSave.plan(new: BibleScriptureTests.john3All, version: "v", existing: ["a", "b"], after: "a"), actions: stub.actions, from: 0)
        XCTAssertEqual(stub.log, ["POST", "PATCH a,p1,b"])
    }

    /// D15: a change PUTs the original only - no POST, no reorder.
    func testAChangePutsTheOriginalOnly() async {
        _ = await BibleSave.run(BibleSave.plan(change: "a", pick: Self.pick(1), version: "v"), actions: stub.actions, from: 0)
        XCTAssertEqual(stub.log, ["PUT a"])
    }

    /// A stopped run resumes from the failed request and never re-POSTs the created activity.
    func testRetryResumesFromTheFailedStepAndOrdersWithTheCreatedId() async {
        stub.failAt = 1
        guard case .failure(let f) = await BibleSave.run(Self.planAfterA, actions: stub.actions, from: 0) else { return XCTFail() }
        XCTAssertEqual(f.step, 1); stub.failAt = nil
        _ = await BibleSave.run(Self.planAfterA, actions: stub.actions, from: f.step, created: f.created)
        XCTAssertEqual(stub.log, ["POST", "PATCH a,p1,b"])
    }

    /// D15: with no insert point (the New Activity page) the parts take the placeholder slot at the end, where the
    /// server appends them, so no reorder is sent.
    func testANewPassageWithNoInsertPointGoesLastWithoutAReorder() async {
        let plan = BibleSave.plan(new: Self.pick(1), version: "v", existing: ["a", "b"], after: nil)
        XCTAssertNil(plan.order)
        _ = await BibleSave.run(plan, actions: stub.actions, from: 0)
        XCTAssertEqual(stub.log, ["POST"])
    }

    /// Inserting after the last activity is the same append.
    func testANewPassageAfterTheLastActivitySendsNoReorder() {
        XCTAssertNil(BibleSave.plan(new: Self.pick(1), version: "v", existing: ["a", "b"], after: "b").order)
    }

    func testAPartDocumentIsABibleDocumentTitledByItsCitation() {
        let plan = BibleSave.plan(new: Self.pick(1), version: "v", existing: [], after: nil)
        XCTAssertEqual(plan.posts[0].raw[path: ["kind"]], .string("bible"))
        XCTAssertEqual(BibleSave.title(of: plan.posts[0]), "John 3:1")
    }
}
