//
//  EnrollmentEditModels.swift
//  MakeReady
//
//  The brain of the edit-enrollment flow (monday#12270302158), kept view-free
//  so it is unit-testable. `EnrollmentEditModel` holds the original snapshot +
//  the leader's pending edits, derives what changed, and builds the API bodies.
//  The SwiftUI edit screen only renders this model and mutates its pending
//  fields — "Cancel = nothing saved" is just discarding the model; "Save"
//  sends `patchBody`.
//

import Foundation

/// Server dry-run of an enrollment edit — powers the warning banner + the
/// Save-confirmation copy. Mirrors POST /api/enrollments/:id/edit/preview.
struct EnrollmentEditPreview: Decodable, Equatable {
    struct GroupChange: Decodable, Equatable {
        let fromName: String
        let toName: String
    }
    struct Reschedule: Decodable, Equatable {
        let lessonsShifted: Int
        let lockedUnchanged: Int
    }
    struct StudySwap: Decodable, Equatable {
        let fromName: String
        let toName: String
        let lessonsRemoved: Int
        let lessonsArchived: Int
        let lessonsAdded: Int
    }

    let groupChange: GroupChange?
    let reschedule: Reschedule?
    let studySwap: StudySwap?
    let destructive: Bool
    let summary: [String]

    /// Copy for the Save-confirmation dialog (the server already returns a
    /// sensible default line when nothing destructive is happening).
    var confirmationMessage: String { summary.joined(separator: "\n") }
}

/// The staged edit. Pending fields start equal to the original; the view edits
/// them and reads the `*Changed` / `has*` derivations to drive UI.
struct EnrollmentEditModel: Equatable {
    let enrollmentId: String

    // Immutable original snapshot
    let originalGroupId: String
    let originalStudyProgramId: String
    let originalStartDate: Date
    let originalEnabledDays: Set<Int> // 0=Sun … 6=Sat
    let originalSmsTime: String? // "HH:mm"
    let originalRequireResponse: Bool

    // Pending (edited) values
    var groupId: String
    var studyProgramId: String
    var startDate: Date
    var enabledDays: Set<Int>
    var smsTime: String?
    var requireResponse: Bool

    init(
        enrollmentId: String,
        groupId: String,
        studyProgramId: String,
        startDate: Date,
        enabledDays: Set<Int>,
        smsTime: String?,
        requireResponse: Bool
    ) {
        self.enrollmentId = enrollmentId
        self.originalGroupId = groupId
        self.originalStudyProgramId = studyProgramId
        self.originalStartDate = startDate
        self.originalEnabledDays = enabledDays
        self.originalSmsTime = smsTime
        self.originalRequireResponse = requireResponse
        self.groupId = groupId
        self.studyProgramId = studyProgramId
        self.startDate = startDate
        self.enabledDays = enabledDays
        self.smsTime = smsTime
        self.requireResponse = requireResponse
    }

    /// Prefill from an existing enrollment (the flow's entry point).
    init(enrollment: EnrollmentWithProgram) {
        self.init(
            enrollmentId: enrollment.id,
            groupId: enrollment.groupId,
            studyProgramId: enrollment.studyProgramId,
            startDate: enrollment.startDate,
            enabledDays: EnrollmentEditModel.daySet(fromJSON: enrollment.enabledDays),
            smsTime: enrollment.smsTime,
            requireResponse: enrollment.requireResponse ?? false
        )
    }

    // MARK: - Change detection

    var groupChanged: Bool { groupId != originalGroupId }
    var studyChanged: Bool { studyProgramId != originalStudyProgramId }
    var scheduleChanged: Bool { startDate != originalStartDate || enabledDays != originalEnabledDays }
    var requireResponseChanged: Bool { requireResponse != originalRequireResponse }
    var smsTimeChanged: Bool { smsTime != originalSmsTime }

    /// Changes that hit the server's structural edit path (reschedule / group /
    /// study swap) — these drive the preview + warning banner.
    var hasStructuralChanges: Bool { groupChanged || studyChanged || scheduleChanged }
    /// Any change at all (structural or scalar) — enables the Save button.
    var hasChanges: Bool { hasStructuralChanges || requireResponseChanged || smsTimeChanged }

    /// Discard all pending edits (the Cancel affordance).
    mutating func reset() {
        groupId = originalGroupId
        studyProgramId = originalStudyProgramId
        startDate = originalStartDate
        enabledDays = originalEnabledDays
        smsTime = originalSmsTime
        requireResponse = originalRequireResponse
    }

    // MARK: - API bodies

    var enabledDayNames: [String] { EnrollmentEditModel.dayNames(from: enabledDays) }

    /// Body for PATCH /api/enrollments/:id — ONLY the fields that changed.
    func patchBody() -> [String: Any] {
        var body = structuralBody()
        if requireResponseChanged { body["requireResponse"] = requireResponse }
        if smsTimeChanged, let smsTime { body["smsTime"] = smsTime }
        return body
    }

    /// Body for the preview endpoint — structural changes only (scalars never
    /// warn, so they don't need a dry-run).
    func previewBody() -> [String: Any] { structuralBody() }

    private func structuralBody() -> [String: Any] {
        var body: [String: Any] = [:]
        if groupChanged { body["groupId"] = groupId }
        if studyChanged { body["studyProgramId"] = studyProgramId }
        if scheduleChanged {
            body["startDate"] = EnrollmentEditModel.isoFormatter.string(from: startDate)
            body["enabledDays"] = enabledDayNames
        }
        return body
    }

    // MARK: - Day-of-week mapping (index = JS getDay(): Sun=0 … Sat=6)

    static let dayAbbrevs = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    static func dayNames(from set: Set<Int>) -> [String] {
        set.sorted().compactMap { (0..<dayAbbrevs.count).contains($0) ? dayAbbrevs[$0] : nil }
    }

    /// Parse the stored enabledDays JSON (e.g. `["Mon","Wed"]`) into weekday ints.
    static func daySet(fromJSON string: String?) -> Set<Int> {
        guard let string, let data = string.data(using: .utf8),
              let names = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        let indexByName = Dictionary(uniqueKeysWithValues: dayAbbrevs.enumerated().map { ($1, $0) })
        return Set(names.compactMap { indexByName[$0] })
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
