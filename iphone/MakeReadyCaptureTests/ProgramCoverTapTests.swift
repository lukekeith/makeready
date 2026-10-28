import XCTest
import UIKit
@testable import MakeReady

/// ui2-programs D11: the program cover uses the group cover flow — the tap, the Edit reopening,
/// the viewer, the route and the save.
@MainActor
final class ProgramCoverTapTests: XCTestCase {
    private func fields(cover: String?, original: String? = nil, framing: ImageFraming? = nil) -> CoverOwner.Fields {
        .init(coverImageUrl: cover, coverOriginalUrl: original, coverFraming: framing)
    }

    func testTapIsInertUntilLoadedThenPickerOrMenu() {
        XCTAssertEqual(CoverOwner.coverTap(nil), GroupDetailContainer.CoverTap.none)
        XCTAssertEqual(CoverOwner.coverTap(fields(cover: nil)), .picker)
        XCTAssertEqual(CoverOwner.coverTap(fields(cover: "")), .picker)
        XCTAssertEqual(CoverOwner.coverTap(fields(cover: "https://c")), .menu)
    }

    func testEditReopensTheOriginalAtItsFramingElseTheCover() {
        let framing = ImageFraming(scale: 2, rotation: 0, offsetX: 1, offsetY: 1)
        let original = EditGroupCoverContainer.opening(fields(cover: "c", original: "o", framing: framing))
        XCTAssertEqual(original?.url, "o")
        XCTAssertEqual(original?.framing, framing)
        XCTAssertEqual(original?.hasOriginal, true)
        let coverOnly = EditGroupCoverContainer.opening(fields(cover: "c"))
        XCTAssertEqual(coverOnly?.url, "c")
        XCTAssertEqual(coverOnly?.framing, .identity)
        XCTAssertNil(EditGroupCoverContainer.opening(fields(cover: nil)))
    }

    func testViewerShowsTheOriginalElseTheCover() {
        XCTAssertEqual(CoverOwner.viewerURL(fields(cover: "c", original: "o")), "o")
        XCTAssertEqual(CoverOwner.viewerURL(fields(cover: "c")), "c")
        XCTAssertNil(CoverOwner.viewerURL(fields(cover: nil)))
    }

    func testTheProgramOwnersRouteAndStoredFields() {
        XCTAssertEqual(CoverOwner.program("p1").destination(.stored), .editProgramCover(programId: "p1", source: .stored))
        XCTAssertEqual(CoverOwner.group("g1").destination(.stored), .editGroupCover(groupId: "g1", source: .stored))
        StatePersistence.shared.clear()
        AppState.shared.programs.upsert(StudyProgram(id: "pct1", name: "Walk", coverImageUrl: "https://c", coverOriginalUrl: "https://o"))
        defer { AppState.shared.programs.remove("pct1") }
        XCTAssertEqual(CoverOwner.program("pct1").fields, fields(cover: "https://c", original: "https://o"))
        XCTAssertNil(CoverOwner.program("missing").fields)
    }
}
