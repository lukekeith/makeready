import Foundation

/// ui2-enrollments-browse T7/F7: §Contract Draft ↔ `EnrollmentDraft`, written once. Dates are
/// `yyyy-MM-dd` in `zone` (the device's), weekdays names ↔ 0…6, access kebab ↔ enum, sync as is;
/// `endDate` is derived from the last schedule date and never sent. An empty set or list is null.
enum EnrollmentDraftMapping {
    static func draft(_ wire: DraftWire, flowId: UUID, zone: TimeZone = .current) -> EnrollmentDraft {
        var d = EnrollmentDraft(id: flowId, groupId: wire.groupId, studyProgramId: wire.studyProgramId)
        d.serverId = wire.id
        d.createdByName = wire.createdBy?.name
        d.serverUpdatedAt = wire.updatedAt
        d.startDate = wire.startDate.flatMap { EnrollmentWire.date(ymd: $0, in: zone) }
        d.enabledDays = Set((wire.enabledDays ?? []).compactMap { EnrollmentWire.dayNames.firstIndex(of: $0) })
        d.overriddenDates = Set((wire.overriddenDates ?? []).compactMap { EnrollmentWire.date(ymd: $0, in: zone) })
        d.scheduleDates = (wire.scheduleDates ?? []).compactMap { EnrollmentWire.date(ymd: $0, in: zone) }
        d.endDate = d.scheduleDates.last
        d.smsTime = wire.smsTime
        d.timezone = wire.timezone
        d.syncMode = wire.syncMode
        d.lessonAccess = EnrollmentWire.lessonAccessLocal(wire.lessonAccess)
        return d
    }

    /// One field's wire value, comparable so a PATCH sends only what changed.
    enum FieldValue: Equatable {
        case null, text(String), list([String])
        var json: Any {
            switch self {
            case .null: return NSNull()
            case .text(let s): return s
            case .list(let l): return l
            }
        }
    }

    /// The §Contract PATCH fields, in a fixed order.
    static let fieldKeys = ["groupId", "studyProgramId", "startDate", "enabledDays", "overriddenDates",
                            "scheduleDates", "smsTime", "timezone", "syncMode", "lessonAccess"]

    static func fieldValues(_ d: EnrollmentDraft, zone: TimeZone = .current) -> [String: FieldValue] {
        func text(_ s: String?) -> FieldValue { s.map(FieldValue.text) ?? .null }
        func list(_ l: [String]) -> FieldValue { l.isEmpty ? .null : .list(l) }
        return [
            "groupId": text(d.groupId),
            "studyProgramId": text(d.studyProgramId),
            "startDate": text(d.startDate.map { EnrollmentWire.ymd($0, in: zone) }),
            "enabledDays": list(EnrollmentWire.dayNames(d.enabledDays)),
            "overriddenDates": list(d.overriddenDates.sorted().map { EnrollmentWire.ymd($0, in: zone) }),
            "scheduleDates": list(d.scheduleDates.map { EnrollmentWire.ymd($0, in: zone) }),
            "smsTime": text(d.smsTime),
            "timezone": text(d.timezone),
            "syncMode": text(d.syncMode),
            "lessonAccess": text(d.lessonAccess.flatMap(EnrollmentWire.lessonAccessWire))
        ]
    }

    /// D3: the first save — both ids and every field already set (unset fields are left out).
    static func createBody(_ d: EnrollmentDraft, zone: TimeZone = .current) -> [String: Any] {
        fieldValues(d, zone: zone).filter { $0.value != .null }.mapValues(\.json)
    }

    /// D4: only the keys whose wire value differs from `baseline`; a cleared value is an explicit
    /// null. A program change always carries `scheduleDates: null` — the local cascade cleared the
    /// dates, and after D23's local-only clear the server may still hold the old ones.
    static func patchBody(from baseline: EnrollmentDraft, to current: EnrollmentDraft,
                          zone: TimeZone = .current) -> [String: Any] {
        let old = fieldValues(baseline, zone: zone)
        let new = fieldValues(current, zone: zone)
        var body: [String: Any] = [:]
        for key in fieldKeys where old[key] != new[key] {
            body[key] = new[key]?.json
        }
        if body["studyProgramId"] != nil, new["scheduleDates"] == .null {
            body["scheduleDates"] = NSNull()
        }
        return body
    }
}
