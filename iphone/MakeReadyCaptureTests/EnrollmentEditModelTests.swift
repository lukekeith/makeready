//
//  EnrollmentEditModelTests.swift
//  MakeReadyCaptureTests
//
//  Unit coverage for the edit-enrollment brain (monday#12270302158):
//  staging, change-detection, "Cancel discards", only-changed-fields payloads,
//  day-of-week mapping, and preview decoding. Pure logic — no simulator needed.
//

import XCTest
@testable import MakeReady

final class EnrollmentEditModelTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 2_051_222_400) // 2035-01-01

    private func makeModel() -> EnrollmentEditModel {
        EnrollmentEditModel(
            enrollmentId: "e1",
            groupId: "g1",
            studyProgramId: "p1",
            startDate: start,
            enabledDays: [1, 2, 3, 4, 5], // Mon–Fri
            smsTime: "07:30",
            requireResponse: false
        )
    }

    // MARK: - Staging / change detection

    func testFreshModelHasNoChanges() {
        let m = makeModel()
        XCTAssertFalse(m.hasChanges)
        XCTAssertFalse(m.hasStructuralChanges)
        XCTAssertTrue(m.patchBody().isEmpty)
        XCTAssertTrue(m.previewBody().isEmpty)
    }

    func testGroupChangeIsStructuralAndInBody() {
        var m = makeModel()
        m.groupId = "g2"
        XCTAssertTrue(m.groupChanged)
        XCTAssertTrue(m.hasStructuralChanges)
        XCTAssertEqual(m.patchBody()["groupId"] as? String, "g2")
        XCTAssertEqual(m.previewBody()["groupId"] as? String, "g2")
    }

    func testStudyChangeIsStructuralAndInBody() {
        var m = makeModel()
        m.studyProgramId = "p2"
        XCTAssertTrue(m.studyChanged)
        XCTAssertTrue(m.hasStructuralChanges)
        XCTAssertEqual(m.patchBody()["studyProgramId"] as? String, "p2")
    }

    func testStartDateChangeCarriesStartDateAndEnabledDays() {
        var m = makeModel()
        m.startDate = start.addingTimeInterval(86_400)
        XCTAssertTrue(m.scheduleChanged)
        let body = m.patchBody()
        XCTAssertNotNil(body["startDate"] as? String)
        XCTAssertEqual((body["enabledDays"] as? [String])?.sorted(), ["Fri", "Mon", "Thu", "Tue", "Wed"])
    }

    func testEnabledDaysChangeIsDetected() {
        var m = makeModel()
        m.enabledDays = [1] // Mondays only
        XCTAssertTrue(m.scheduleChanged)
        XCTAssertEqual(m.patchBody()["enabledDays"] as? [String], ["Mon"])
    }

    func testRequireResponseChangeIsScalarNotStructural() {
        var m = makeModel()
        m.requireResponse = true
        XCTAssertTrue(m.hasChanges)
        XCTAssertFalse(m.hasStructuralChanges)
        XCTAssertEqual(m.patchBody()["requireResponse"] as? Bool, true)
        XCTAssertTrue(m.previewBody().isEmpty) // scalars never warn
    }

    func testSmsTimeChangeIsScalar() {
        var m = makeModel()
        m.smsTime = "09:00"
        XCTAssertTrue(m.smsTimeChanged)
        XCTAssertFalse(m.hasStructuralChanges)
        XCTAssertEqual(m.patchBody()["smsTime"] as? String, "09:00")
    }

    func testResetDiscardsAllEdits() {
        var m = makeModel()
        m.groupId = "g2"
        m.studyProgramId = "p2"
        m.enabledDays = [0]
        m.requireResponse = true
        m.reset()
        XCTAssertFalse(m.hasChanges)
        XCTAssertEqual(m.groupId, "g1")
        XCTAssertEqual(m.enabledDays, [1, 2, 3, 4, 5])
    }

    func testPatchBodyOnlyIncludesChangedFields() {
        var m = makeModel()
        m.groupId = "g2"
        m.requireResponse = true
        let body = m.patchBody()
        XCTAssertEqual(Set(body.keys), ["groupId", "requireResponse"])
        XCTAssertNil(body["studyProgramId"])
        XCTAssertNil(body["startDate"])
    }

    // MARK: - Day-of-week mapping

    func testDayNamesFromSet() {
        XCTAssertEqual(EnrollmentEditModel.dayNames(from: [1, 3, 5]), ["Mon", "Wed", "Fri"])
        XCTAssertEqual(EnrollmentEditModel.dayNames(from: [0, 6]), ["Sun", "Sat"])
        XCTAssertEqual(EnrollmentEditModel.dayNames(from: [9]), []) // out of range ignored
    }

    func testDaySetFromJSON() {
        XCTAssertEqual(EnrollmentEditModel.daySet(fromJSON: "[\"Mon\",\"Wed\"]"), [1, 3])
        XCTAssertEqual(EnrollmentEditModel.daySet(fromJSON: nil), [])
        XCTAssertEqual(EnrollmentEditModel.daySet(fromJSON: "not-json"), [])
    }

    // MARK: - Prefill from an existing enrollment

    func testPrefillFromEnrollment() throws {
        let json = """
        {
          "id": "e9",
          "groupId": "gA",
          "programId": "pA",
          "startedAt": "2035-01-01T12:00:00Z",
          "completedAt": "2035-01-10T12:00:00Z",
          "enabledDays": "[\\"Mon\\",\\"Wed\\"]",
          "smsTime": "08:15",
          "requireResponse": true
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let enrollment = try decoder.decode(EnrollmentWithProgram.self, from: Data(json.utf8))

        let m = EnrollmentEditModel(enrollment: enrollment)
        XCTAssertEqual(m.groupId, "gA")
        XCTAssertEqual(m.studyProgramId, "pA")
        XCTAssertEqual(m.enabledDays, [1, 3])
        XCTAssertEqual(m.smsTime, "08:15")
        XCTAssertTrue(m.requireResponse)
        XCTAssertFalse(m.hasChanges)
    }

    // MARK: - Preview decoding + confirmation copy

    func testPreviewDecodesAndBuildsConfirmationMessage() throws {
        let json = """
        {
          "groupChange": null,
          "reschedule": null,
          "studySwap": { "fromName": "A", "toName": "B", "lessonsRemoved": 2, "lessonsArchived": 1, "lessonsAdded": 3 },
          "destructive": true,
          "summary": ["Switches the study from \\"A\\" to \\"B\\".", "3 new lessons will be scheduled."]
        }
        """
        let preview = try JSONDecoder().decode(EnrollmentEditPreview.self, from: Data(json.utf8))
        XCTAssertTrue(preview.destructive)
        XCTAssertEqual(preview.studySwap?.lessonsArchived, 1)
        XCTAssertEqual(preview.studySwap?.lessonsAdded, 3)
        XCTAssertNil(preview.groupChange)
        XCTAssertTrue(preview.confirmationMessage.contains("Switches the study"))
        XCTAssertTrue(preview.confirmationMessage.contains("\n"))
    }

    func testNonDestructivePreviewDefaultCopy() throws {
        let json = """
        {
          "groupChange": null, "reschedule": null, "studySwap": null,
          "destructive": false,
          "summary": ["This will update the existing enrollment to match your changes."]
        }
        """
        let preview = try JSONDecoder().decode(EnrollmentEditPreview.self, from: Data(json.utf8))
        XCTAssertFalse(preview.destructive)
        XCTAssertEqual(preview.confirmationMessage, "This will update the existing enrollment to match your changes.")
    }
}
