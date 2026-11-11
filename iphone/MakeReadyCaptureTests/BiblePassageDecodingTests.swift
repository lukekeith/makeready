import XCTest
@testable import MakeReady

final class BiblePassageDecodingTests: XCTestCase {
    private static func document(passages: String, objects: String) -> String {
        #"""
        {"schemaVersion":1,"kind":"bible","background":{"color":"#000000"},
         "content":{"type":"canvas","objects":[\#(objects)],"passages":[\#(passages)]},"actions":[]}
        """#
    }

    private static let transform = #""transform":{"x":220,"y":478,"width":392,"scale":1,"rotation":0}"#

    static let d10JSON = document(
        passages: #"{"bookNumber":43,"chapterStart":3,"verseStart":16,"chapterEnd":3,"verseEnd":18,"startOffset":9,"translation":"ENGKJV","extra":"keep"}"#,
        objects: """
        {"id":"o1","role":"scripture","text":"loved the world\\nsecond","listStyle":"bibleVerse","startNumber":16,\(transform),
         "reference":{"start":{"book":43,"chapter":3,"verse":16,"offset":9},"end":{"book":43,"chapter":3,"verse":18},"translation":"ENGKJV"}},
        {"id":"o2","role":"citation","text":"John 3:16b-18 ENGKJV",\(transform)}
        """)

    static let legacyJSON = document(
        passages: #"{"bookNumber":43,"chapterStart":3,"verseStart":16,"chapterEnd":3,"verseEnd":16}"#,
        objects: """
        {"id":"o1","role":"scripture","text":"16 For God so loved the world",\(transform)},
        {"id":"o2","role":"citation","text":"John 3:16",\(transform)}
        """)

    static let malformedReferenceJSON = document(
        passages: #"{"bookNumber":43,"chapterStart":3,"verseStart":16,"chapterEnd":3}"#,
        objects: #"{"id":"o1","role":"scripture","text":"x","reference":{"start":"nope"},\#(transform)}"#)

    private func fixture(_ json: String) throws -> ActivityDocument {
        try JSONDecoder().decode(ActivityDocument.self, from: Data(json.utf8))
    }

    func testAD10PassageAndReferenceDecode() throws {
        let doc = try fixture(Self.d10JSON)
        XCTAssertEqual(doc.passages, [BiblePassage(bookNumber: 43, chapterStart: 3, verseStart: 16, chapterEnd: 3,
            verseEnd: 18, startOffset: 9, endOffset: nil, translation: "ENGKJV")])
        let s = doc.textObjects.first { $0.role == "scripture" }!
        XCTAssertEqual(s.listStyle, "bibleVerse"); XCTAssertEqual(s.startNumber, 16)
        XCTAssertEqual(s.reference?.start.offset, 9); XCTAssertEqual(s.reference?.translation, "ENGKJV")
        XCTAssertEqual(s.reference?.start.book, 43)
        XCTAssertTrue(s.isLockedScripture)
        XCTAssertTrue(doc.textObjects.first { $0.role == "citation" }!.isLockedScripture)
    }

    func testALegacyPassageHasNoTranslationAndIsNotLocked() throws {
        let doc = try fixture(Self.legacyJSON)
        XCTAssertNil(doc.passages.first?.translation)
        XCTAssertFalse(doc.textObjects.contains { $0.isLockedScripture })
    }

    func testPassagesRoundTripUnknownKeys() throws {
        var doc = try fixture(Self.d10JSON)
        doc.passages = doc.passages
        XCTAssertEqual(doc.raw[path: ["content", "passages", 0, "extra"]], .string("keep"))
        XCTAssertEqual(doc.raw[path: ["content", "passages", 0, "startOffset"]], .number(9))
    }

    func testAPassageMissingARequiredIntIsSkipped() throws {
        let doc = try fixture(Self.malformedReferenceJSON)
        XCTAssertEqual(doc.passages, [])
    }

    func testAMalformedReferenceDecodesNilAndStaysInTheRawJSON() throws {
        let doc = try fixture(Self.malformedReferenceJSON)
        let s = doc.textObjects.first!
        XCTAssertNil(s.reference)
        XCTAssertFalse(s.isLockedScripture)
        XCTAssertEqual(doc.raw[path: ["content", "objects", 0, "reference", "start"]], .string("nope"))
    }
}
