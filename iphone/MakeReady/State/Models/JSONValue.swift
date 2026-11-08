//
//  JSONValue.swift
//  MakeReady
//
//  A type-erased JSON value: decodes any JSON, re-encodes it unchanged, and can be edited by path.
//

import Foundation

/// A type-erased JSON value for decoding arbitrary JSON structures.
enum JSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else if let v = try? container.decode(Double.self) { self = .number(v) }
        else if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode([String: JSONValue].self) { self = .object(v) }
        else if let v = try? container.decode([JSONValue].self) { self = .array(v) }
        else if container.decodeNil() { self = .null }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value") }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .number(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - Path access

/// One step of a `JSONValue` path: an object key or an array index.
enum JSONPathComponent: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral {
    case key(String)
    case index(Int)

    init(stringLiteral value: String) { self = .key(value) }
    init(integerLiteral value: Int) { self = .index(value) }
}

extension JSONValue {
    /// Reads or writes the value at `path`. A write creates missing objects along a key path,
    /// removes the key when given `nil`, and does nothing when an array index is out of range.
    subscript(path path: [JSONPathComponent]) -> JSONValue? {
        get {
            var current: JSONValue = self
            for step in path {
                switch (step, current) {
                case (.key(let key), .object(let dict)):
                    guard let next = dict[key] else { return nil }
                    current = next
                case (.index(let i), .array(let items)):
                    guard items.indices.contains(i) else { return nil }
                    current = items[i]
                default:
                    return nil
                }
            }
            return current
        }
        set {
            self = replacing(path[...], with: newValue)
        }
    }

    private func replacing(_ path: ArraySlice<JSONPathComponent>, with newValue: JSONValue?) -> JSONValue {
        guard let step = path.first else { return newValue ?? .null }
        let rest = path.dropFirst()
        switch (step, self) {
        case (.key(let key), .object(var dict)):
            if rest.isEmpty, newValue == nil {
                dict.removeValue(forKey: key)
            } else {
                dict[key] = (dict[key] ?? .null).replacing(rest, with: newValue)
            }
            return .object(dict)
        case (.key(let key), .null):
            guard let newValue else { return self }
            return .object([key: JSONValue.null.replacing(rest, with: newValue)])
        case (.index(let i), .array(var items)) where items.indices.contains(i):
            items[i] = items[i].replacing(rest, with: newValue)
            return .array(items)
        default:
            return self
        }
    }
}
