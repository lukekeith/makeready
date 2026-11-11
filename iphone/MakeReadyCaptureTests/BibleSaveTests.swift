import XCTest
@testable import MakeReady

/// bible-verse-picker Task 13 (D14): the ordered, resumable multi-request save of a split passage.
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
    static let twoParts = [pick(1), pick(2)]
    static let threeParts = [pick(1), pick(2), pick(3)]
    static var plan3: BibleSave.Plan { BibleSave.plan(new: threeParts, version: "v", existing: ["a", "b"], after: "a") }

    func testANewSplitPassagePostsInOrderThenReorders() async {
        let r = await BibleSave.run(BibleSave.plan(new: Self.threeParts, version: "v", existing: ["a", "b"], after: "a"), actions: stub.actions, from: 0)
        XCTAssertEqual(stub.log, ["POST", "POST", "POST", "PATCH a,p1,p2,p3,b"]); XCTAssertEqual(try r.get(), ["p1", "p2", "p3"])
    }

    func testAChangeSplitPutsTheOriginalLast() async {
        _ = await BibleSave.run(BibleSave.plan(change: "a", parts: Self.twoParts, version: "v", existing: ["a", "b"]), actions: stub.actions, from: 0)
        XCTAssertEqual(stub.log, ["POST", "PATCH a,p1,b", "PUT a"])
    }

    func testRetryResumesFromTheFailedStep() async {
        stub.failAt = 1
        guard case .failure(let f) = await BibleSave.run(Self.plan3, actions: stub.actions, from: 0) else { return XCTFail() }
        XCTAssertEqual(f.step, 1); stub.failAt = nil
        _ = await BibleSave.run(Self.plan3, actions: stub.actions, from: f.step, created: f.created)
        XCTAssertEqual(stub.log.filter { $0 == "POST" }.count, 3)
    }

    /// The order a resumed run sends still carries the part created before the failure.
    func testAResumedRunOrdersWithThePartCreatedBeforeTheFailure() async {
        stub.failAt = 1
        guard case .failure(let f) = await BibleSave.run(Self.plan3, actions: stub.actions, from: 0) else { return XCTFail() }
        stub.failAt = nil
        _ = await BibleSave.run(Self.plan3, actions: stub.actions, from: f.step, created: f.created)
        XCTAssertEqual(stub.log.last, "PATCH a,p1,p2,p3,b")
    }

    /// D15: with no insert point (the New Activity page) the parts take the placeholder slot at the end, where the
    /// server appends them, so no reorder is sent.
    func testANewPassageWithNoInsertPointGoesLastWithoutAReorder() async {
        let plan = BibleSave.plan(new: Self.twoParts, version: "v", existing: ["a", "b"], after: nil)
        XCTAssertNil(plan.order)
        _ = await BibleSave.run(plan, actions: stub.actions, from: 0)
        XCTAssertEqual(stub.log, ["POST", "POST"])
    }

    /// Inserting after the last activity is the same append.
    func testANewPassageAfterTheLastActivitySendsNoReorder() {
        XCTAssertNil(BibleSave.plan(new: Self.twoParts, version: "v", existing: ["a", "b"], after: "b").order)
    }

    func testAPartDocumentIsABibleDocumentTitledByItsCitation() {
        let plan = BibleSave.plan(new: [Self.pick(1)], version: "v", existing: [], after: nil)
        XCTAssertEqual(plan.posts[0].raw[path: ["kind"]], .string("bible"))
        XCTAssertEqual(BibleSave.title(of: plan.posts[0]), "John 3:1")
    }
}
