//
//  ProgramDecodingTests.swift
//  MakeReadyCaptureTests
//
//  ui2-programs Task 8 (§Contract, D15): StudyProgram reads the settings, leader, org and
//  cover-framing fields the program endpoints now return — and a cached program written before
//  them, or a malformed value, still decodes (the disk cache must never be lost to a new key).
//

import XCTest
@testable import MakeReady

final class ProgramDecodingTests: XCTestCase {

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func decode(_ json: String) throws -> StudyProgram {
        try makeDecoder().decode(StudyProgram.self, from: Data(json.utf8))
    }

    private let base = """
    "id":"p1","title":"Walk","createdAt":"2026-10-28T00:00:00Z","updatedAt":"2026-10-28T00:00:00Z"
    """

    func testEveryNewKeyAbsentDecodesAsNil() throws {
        let program = try decode("{\(base)}")
        XCTAssertNil(program.creatorName)
        XCTAssertNil(program.leaderName)
        XCTAssertNil(program.leaderId)
        XCTAssertNil(program.organizationId)
        XCTAssertNil(program.organizationName)
        XCTAssertNil(program.coverOriginalUrl)
        XCTAssertNil(program.isPrivate)
        XCTAssertNil(program.ageRangeMin)
        XCTAssertNil(program.ageRangeMax)
        XCTAssertNil(program.maxMembers)
        XCTAssertNil(program.memberDirectoryAccess)
        XCTAssertNil(program.coverFraming)
    }

    func testEveryNewKeyPresentDecodesItsValue() throws {
        let program = try decode("""
        {\(base),"creatorName":"Luke Keith","leaderName":"Nathan","leaderId":"u2",
         "organizationId":"o1","organizationName":"Grace","coverOriginalUrl":"https://cdn/o.jpg",
         "isPrivate":true,"ageRangeMin":18,"ageRangeMax":35,"maxMembers":40,
         "memberDirectoryAccess":"NAMES_ONLY",
         "coverFraming":{"scale":2,"rotation":0.5,"offsetX":10,"offsetY":-4}}
        """)
        XCTAssertEqual(program.creatorName, "Luke Keith")
        XCTAssertEqual(program.leaderName, "Nathan")
        XCTAssertEqual(program.leaderId, "u2")
        XCTAssertEqual(program.organizationId, "o1")
        XCTAssertEqual(program.organizationName, "Grace")
        XCTAssertEqual(program.coverOriginalUrl, "https://cdn/o.jpg")
        XCTAssertEqual(program.isPrivate, true)
        XCTAssertEqual(program.ageRangeMin, 18)
        XCTAssertEqual(program.ageRangeMax, 35)
        XCTAssertEqual(program.maxMembers, 40)
        XCTAssertEqual(program.memberDirectoryAccess, "NAMES_ONLY")
        XCTAssertEqual(program.coverFraming, ImageFraming(scale: 2, rotation: 0.5, offsetX: 10, offsetY: -4))
    }

    func testMalformedFramingAndDirectoryAccessDecodeAsNilWithoutThrowing() throws {
        let program = try decode("""
        {\(base),"coverFraming":"not-an-object","memberDirectoryAccess":7}
        """)
        XCTAssertNil(program.coverFraming)
        XCTAssertNil(program.memberDirectoryAccess)
    }

    func testRoundTripKeepsEveryNewField() throws {
        let original = StudyProgram(
            id: "p1", name: "Walk",
            creatorName: "Luke Keith", leaderName: "Nathan", leaderId: "u2",
            organizationId: "o1", organizationName: "Grace", coverOriginalUrl: "https://cdn/o.jpg",
            isPrivate: true, ageRangeMin: 18, ageRangeMax: 35, maxMembers: 40,
            memberDirectoryAccess: "HIDDEN",
            coverFraming: ImageFraming(scale: 1.5, rotation: 0, offsetX: 3, offsetY: 4)
        )
        let copy = try makeDecoder().decode(StudyProgram.self, from: makeEncoder().encode(original))
        XCTAssertEqual(copy.creatorName, original.creatorName)
        XCTAssertEqual(copy.leaderName, original.leaderName)
        XCTAssertEqual(copy.leaderId, original.leaderId)
        XCTAssertEqual(copy.organizationId, original.organizationId)
        XCTAssertEqual(copy.organizationName, original.organizationName)
        XCTAssertEqual(copy.coverOriginalUrl, original.coverOriginalUrl)
        XCTAssertEqual(copy.isPrivate, original.isPrivate)
        XCTAssertEqual(copy.ageRangeMin, original.ageRangeMin)
        XCTAssertEqual(copy.ageRangeMax, original.ageRangeMax)
        XCTAssertEqual(copy.maxMembers, original.maxMembers)
        XCTAssertEqual(copy.memberDirectoryAccess, original.memberDirectoryAccess)
        XCTAssertEqual(copy.coverFraming, original.coverFraming)
    }

    /// An edit to a settings field must re-render the page, so equality sees it.
    func testEqualityNoticesASettingsEdit() {
        let a = StudyProgram(id: "p1", name: "Walk", maxMembers: 10)
        var b = a
        b.maxMembers = 20
        XCTAssertNotEqual(a, b)
    }
}
