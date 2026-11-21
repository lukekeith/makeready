import XCTest
@testable import MakeReady

final class NoteDocumentCodecTests: XCTestCase {
    static let corpus = [
        "# Title only",
        "# Walk\n\nA plain body line.",
        "# T\n\n**bold** *italic* ~~strike~~ <u>under</u>",
        "# T\n\n***bold italic*** and ~~**<u>all</u>**~~",
        "# T\n\n- one\n- two\n\nafter",
        "# T\n\n1. first\n2. second",
        "# T\n\nescapes \\* \\_ \\~ \\= \\< \\> \\# \\\\ done",
        "# T\n\n\\- not a list\n\n1\\. not numbered",
        // Escapes beyond D4's floor: markdown syntax a user can type must survive an open + autosave.
        "# T\n\nticks \\`x\\` link \\[a\\](b) img \\!\\[i\\] amp \\&amp; pipe \\| done",
        "# T\n\n- \\`x\\` \\[a\\]\n- \\&amp;",
        // Edge whitespace is carried as numeric character references (never stripped, never code).
        "# T\n\n&#32;&#32;&#32;&#32;four leading",
        "# T\n\ntrailing&#32;&#32;",
        "# T\n\n&#9;tab lead\n\n- &#32;item&#32;",
    ]

    func testCorpusRoundTripsExactly() {
        for md in Self.corpus {
            let doc = NoteDocumentCodec.parse(md)
            XCTAssertEqual(NoteDocumentCodec.serialize(doc), md, md)
            XCTAssertEqual(NoteDocumentCodec.parse(NoteDocumentCodec.serialize(doc)), doc, md)
        }
    }

    func testTitleAndStylesLandOnTheRightRuns() {
        let runs = NoteDocumentCodec.runs(NoteDocumentCodec.parse("# Walk\n\n**bold** plain\n\n- item"))
        XCTAssertEqual(runs.first, NoteRun(block: 0, text: "Walk", paragraph: .title))
        XCTAssertTrue(runs.contains(NoteRun(block: 1, text: "bold", paragraph: .body, bold: true)))
        XCTAssertEqual(runs.last?.paragraph, .bulleted)
    }

    func testSpacesMoveOutsideMarkersAndEmptyParagraphsDrop() {
        let spaced = NoteDocumentCodec.document([NoteRun(block: 0, text: "T", paragraph: .title),
                                                 NoteRun(block: 1, text: "a ", paragraph: .body, bold: true),
                                                 NoteRun(block: 1, text: "b", paragraph: .body),
                                                 NoteRun(block: 2, text: "", paragraph: .body),
                                                 NoteRun(block: 3, text: "end", paragraph: .body)])
        XCTAssertEqual(NoteDocumentCodec.serialize(spaced), "# T\n\n**a** b\n\nend")
    }

    func testHighlightParsesToPlainTextAndMemoLinksToText() {
        XCTAssertEqual(NoteDocumentCodec.serialize(NoteDocumentCodec.parse("# T\n\n==glow== on")), "# T\n\nglow on")
        XCTAssertEqual(NoteDocumentCodec.serialize(NoteDocumentCodec.parse("# T\n\n[Memo](makeready://memo/m1)")), "# T\n\nMemo")
    }

    func testLaterHeadingsBecomeBodyAndLiteralEqualsSignsSurvive() {
        XCTAssertEqual(NoteDocumentCodec.serialize(NoteDocumentCodec.parse("# T\n\n## Later")), "# T\n\nLater")
        let md = "# T\n\nkeep \\=\\= literal"
        XCTAssertEqual(NoteDocumentCodec.serialize(NoteDocumentCodec.parse(md)), md)
    }

    func testEdgeWhitespaceAndWhitespaceOnlyParagraphs() {
        let doc = NoteDocumentCodec.document([
            NoteRun(block: 0, text: "T", paragraph: .title),
            NoteRun(block: 1, text: "    four leading", paragraph: .body),
            NoteRun(block: 2, text: "trailing  ", paragraph: .body),
            NoteRun(block: 3, text: " bold ", paragraph: .body, bold: true),
            NoteRun(block: 4, text: "   ", paragraph: .body),
            NoteRun(block: 5, text: "\t", paragraph: .bulleted),
            NoteRun(block: 6, text: "x ", paragraph: .numbered),
        ])
        let md = NoteDocumentCodec.serialize(doc)
        XCTAssertFalse(md.contains("\n\n\n"), md)
        // Whitespace-only paragraphs are empty and drop; the rest survive a reload verbatim.
        let reloaded = NoteDocumentCodec.runs(NoteDocumentCodec.parse(md)).map(\.text)
        XCTAssertEqual(reloaded, ["T", "    four leading", "trailing  ", " ", "bold", " ", "x "], md)
        XCTAssertEqual(NoteDocumentCodec.serialize(NoteDocumentCodec.parse(md)), md)
    }

    func testSingleNewlineInAParagraphBecomesTwoParagraphs() {
        XCTAssertEqual(NoteDocumentCodec.serialize(NoteDocumentCodec.parse("# T\n\nline one\nline two")), "# T\n\nline one\n\nline two")
    }
}
