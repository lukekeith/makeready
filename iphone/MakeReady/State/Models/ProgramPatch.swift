//
//  ProgramPatch.swift
//  MakeReady
//
//  ui2-programs D10 (§Contract PATCH /api/programs/:id): one program field's PATCH — GroupPatch's
//  shape, plus the program's leader. The iPhone sends one key per request, so a case is the "sent"
//  state, its `nil` payload the "null" state, and every other key stays absent.
//

import Foundation

enum ProgramPatch: Equatable {
    case name(String)
    case description(String?)
    case isPrivate(Bool)
    /// nil clears both bounds; a nil bound inside is sent as null.
    case ageRange(AgeRange?)
    /// nil = no limit.
    case maxMembers(Int?)
    /// "ALLOWED" | "NAMES_ONLY" | "NOT_ALLOWED".
    case memberDirectoryAccess(String)
    /// nil = no leader (D19: display-only on the page today; the key is wired for the contract).
    case leaderId(String?)

    /// The request body. `JSONSerialization` writes `NSNull` as `null`.
    var body: [String: Any] {
        switch self {
        case .name(let v): return ["name": v]
        case .description(let v): return ["description": Self.json(v)]
        case .isPrivate(let v): return ["isPrivate": v]
        case .ageRange(let range):
            guard let range else { return ["ageRange": NSNull()] }
            return ["ageRange": ["min": Self.json(range.min), "max": Self.json(range.max)]]
        case .maxMembers(let v): return ["maxMembers": Self.json(v)]
        case .memberDirectoryAccess(let v): return ["memberDirectoryAccess": v]
        case .leaderId(let v): return ["leaderId": Self.json(v)]
        }
    }

    private static func json<T>(_ value: T?) -> Any { value.map { $0 as Any } ?? NSNull() }
}
