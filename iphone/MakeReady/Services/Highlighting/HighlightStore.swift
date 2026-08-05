//
//  HighlightStore.swift
//  MakeReady
//
//  ONE way to read and write highlights, for both activity contexts.
//
//  Program activities live at `/api/activities/:id/highlights` and enrollment
//  ("scheduled") activities at `/api/scheduled-activities/:id/highlights`. The
//  two have IDENTICAL shapes (03 §2) — the only difference is the path prefix —
//  so the difference is one stored string, not two implementations. Before this
//  there were eight near-identical Action methods, four per context, and every
//  contract change had to be made twice.
//
//  This does NOT replace `ReadActivityActionProvider` /
//  `ExegesisActivityActionProvider` (D11): those seams already solve
//  program-vs-enrollment correctly for everything else an editor does. A store
//  is handed to them; it does not supersede them.
//
//  See docs/features/highlighting/03-data-and-api.md §2 (the frozen contract)
//  and 06-iphone.md §AppState & Actions.
//

import Foundation

// MARK: - Contract shapes

/// `GET …/highlights` (03 §2.1).
struct HighlightListResult: Equatable {
    /// Every locked block on the activity, in `orderNumber` order.
    ///
    /// **Use this, never the response's singular `readBlockId`** — that field is
    /// deprecated and names only the FIRST locked block, which is wrong for a
    /// READ activity with several verse blocks (03 §2.1).
    let blockIds: [String]
    let highlights: [ContentHighlight]
}

/// `POST …/highlights` (03 §2.2).
///
/// The server merges server-side: a new range absorbs every highlight it
/// overlaps, the result spans the union, and the absorbed rows are DELETED.
/// `absorbedIds` names them. A consumer that ignores it keeps dead entities —
/// and, if it keys anything by highlight id, orphans that state (09 §C-b).
struct HighlightCreateResult: Equatable {
    let highlight: ContentHighlight
    let absorbedIds: [String]
}

// MARK: - The store

/// Reads and writes the highlights of ONE activity context.
protocol HighlightStore {
    func fetch(activityId: String) async throws -> HighlightListResult

    func create(
        activityId: String,
        readBlockId: String,
        span: HighlightSpan,
        style: String,
        noteMarkdown: String
    ) async throws -> HighlightCreateResult

    func update(
        activityId: String,
        highlightId: String,
        noteMarkdown: String?,
        style: String?
    ) async throws -> ContentHighlight

    func delete(activityId: String, highlightId: String) async throws
}

extension HighlightStore {
    /// The common case: a plain highlight with no note yet.
    func create(
        activityId: String,
        readBlockId: String,
        span: HighlightSpan,
        style: String = ContentHighlight.defaultStyle,
        noteMarkdown: String = ""
    ) async throws -> HighlightCreateResult {
        try await create(
            activityId: activityId,
            readBlockId: readBlockId,
            span: span,
            style: style,
            noteMarkdown: noteMarkdown
        )
    }
}

// MARK: - The API-backed implementation

/// Which family of routes an activity's highlights live under.
///
/// The contract guarantees identical request and response shapes across the
/// two, so this is the ONLY thing that differs between the program and
/// enrollment stores. Keeping it as data rather than as a second type is what
/// stops them drifting the way the eight Action methods did.
enum HighlightRouteContext: String, CaseIterable {
    case program
    case enrollment

    var pathPrefix: String {
        switch self {
        case .program:    return "/api/activities"
        case .enrollment: return "/api/scheduled-activities"
        }
    }

    func highlightsPath(activityId: String) -> String {
        "\(pathPrefix)/\(activityId)/highlights"
    }

    func highlightPath(activityId: String, highlightId: String) -> String {
        "\(highlightsPath(activityId: activityId))/\(highlightId)"
    }
}

/// `HighlightStore` over the real API.
struct APIHighlightStore: HighlightStore {

    let context: HighlightRouteContext
    private let api: APIClientProtocol

    /// `api` is injectable so the round-trip through both contexts can be
    /// tested against a stub rather than only being reasoned about.
    init(context: HighlightRouteContext, api: APIClientProtocol = APIClient.shared) {
        self.context = context
        self.api = api
    }

    static let program = APIHighlightStore(context: .program)
    static let enrollment = APIHighlightStore(context: .enrollment)

    // MARK: Wire types

    private struct ListBody: Decodable {
        let success: Bool
        let blockIds: [String]?
        let highlights: [ContentHighlight]?
        let error: String?
    }

    private struct CreateBody: Decodable {
        let success: Bool
        let highlight: ContentHighlight?
        let absorbedIds: [String]?
        let error: String?
    }

    private struct UpdateBody: Decodable {
        let success: Bool
        let highlight: ContentHighlight?
        let error: String?
    }

    private struct EmptyBody: Decodable {
        let success: Bool
        let error: String?
    }

    // MARK: Operations

    @MainActor
    func fetch(activityId: String) async throws -> HighlightListResult {
        let response: ListBody = try await api.get(
            context.highlightsPath(activityId: activityId),
            responseType: ListBody.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to load highlights")
        }

        // `blockIds` is absent from older server builds; the highlights' own
        // block ids are the honest fallback, and an empty list is a legitimate
        // answer for an activity with no locked blocks.
        let highlights = response.highlights ?? []
        let blockIds = response.blockIds ?? Array(NSOrderedSet(array: highlights.map(\.readBlockId)).compactMap { $0 as? String })

        return HighlightListResult(blockIds: blockIds, highlights: highlights)
    }

    @MainActor
    func create(
        activityId: String,
        readBlockId: String,
        span: HighlightSpan,
        style: String,
        noteMarkdown: String
    ) async throws -> HighlightCreateResult {
        let body: [String: Any] = [
            "readBlockId": readBlockId,
            "start": span.start,
            "end": span.end,
            "style": style,
            "noteMarkdown": noteMarkdown
        ]

        let response: CreateBody = try await api.post(
            context.highlightsPath(activityId: activityId),
            body: body,
            responseType: CreateBody.self
        )

        guard response.success, let highlight = response.highlight else {
            throw APIError.serverError(response.error ?? "Failed to create highlight")
        }

        return HighlightCreateResult(highlight: highlight, absorbedIds: response.absorbedIds ?? [])
    }

    @MainActor
    func update(
        activityId: String,
        highlightId: String,
        noteMarkdown: String?,
        style: String?
    ) async throws -> ContentHighlight {
        var body: [String: Any] = [:]
        if let noteMarkdown { body["noteMarkdown"] = noteMarkdown }
        if let style { body["style"] = style }

        // The server 400s on an empty body (03 §2.3); failing here says so
        // plainly instead of surfacing a generic request error.
        guard !body.isEmpty else {
            throw APIError.serverError("Nothing to update — pass a note, a style, or both")
        }

        let response: UpdateBody = try await api.patch(
            context.highlightPath(activityId: activityId, highlightId: highlightId),
            body: body,
            responseType: UpdateBody.self
        )

        guard response.success, let highlight = response.highlight else {
            throw APIError.serverError(response.error ?? "Failed to update highlight")
        }

        return highlight
    }

    @MainActor
    func delete(activityId: String, highlightId: String) async throws {
        let response: EmptyBody = try await api.delete(
            context.highlightPath(activityId: activityId, highlightId: highlightId),
            responseType: EmptyBody.self
        )

        guard response.success else {
            throw APIError.serverError(response.error ?? "Failed to delete highlight")
        }
    }
}
