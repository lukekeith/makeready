import Foundation

/// Voice memos: `/api/memos` (D39). The only `APIClient` user for memos. Every call refreshes
/// `AppState.voiceMemos` / `voiceMemoDetails` in the same call; failures are logged and thrown
/// to the caller (console-only until a surface exists, D21).
struct MemoActions {
    private static let pageSize = 100
    private static let titlePattern = #"^Memo (\d+)$"#

    private let api: APIClientProtocol
    private let stateOverride: AppState?

    @MainActor private var state: AppState { stateOverride ?? AppState.shared }

    init(api: APIClientProtocol = APIClient.shared, state: AppState? = nil) {
        self.api = api
        self.stateOverride = state
    }

    /// `GET /api/memos`. Without `q` the page replaces `voiceMemos`; with `q` the results are
    /// returned and the store is left alone (D39).
    @MainActor
    func loadMemos(q: String?) async throws -> [VoiceMemoSummary] {
        var endpoint = "/api/memos?limit=\(Self.pageSize)&offset=0"
        if let q, !q.isEmpty {
            var allowed = CharacterSet.urlQueryAllowed
            allowed.remove(charactersIn: "&+=#?")
            let encoded = q.addingPercentEncoding(withAllowedCharacters: allowed) ?? q
            endpoint = "/api/memos?q=\(encoded)&limit=\(Self.pageSize)&offset=0"
        }
        do {
            let response = try await api.get(endpoint, responseType: MemoListResponse.self)
            if q == nil { state.voiceMemos.replaceAll(response.memos) }
            return response.memos
        } catch {
            Log.memo.error("loadMemos failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// `GET /api/memos/:id` — the detail (with its presigned `url`) and its summary row.
    @MainActor
    @discardableResult
    func loadMemo(id: String) async throws -> VoiceMemo {
        do {
            let response = try await api.get("/api/memos/\(id)", responseType: MemoResponse.self)
            store(response.memo)
            return response.memo
        } catch {
            Log.memo.error("loadMemo failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// `PATCH /api/memos/:id` — the returned memo updates both stores.
    @MainActor
    func rename(id: String, title: String) async throws {
        do {
            let response = try await api.patch("/api/memos/\(id)", body: ["title": title], responseType: MemoResponse.self)
            store(response.memo)
        } catch {
            Log.memo.error("rename failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// `DELETE /api/memos/:id` — a 204 has no body, so it goes through `requestWithStatus` (F25).
    @MainActor
    func softDelete(id: String) async throws {
        do {
            _ = try await api.requestWithStatus(endpoint: "/api/memos/\(id)", method: "DELETE", body: nil)
            _ = state.voiceMemos.remove(id)
            _ = state.voiceMemoDetails.remove(id)
        } catch {
            Log.memo.error("softDelete failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// The upload controller's hand-off once `complete` returns.
    @MainActor
    func memoCompleted(_ memo: VoiceMemo) {
        store(memo)
    }

    /// D11 / D43: `Memo n`, n = 1 + the largest integer in `^Memo (\d+)$` among the titles.
    static func nextDefaultTitle(existingTitles: [String]) -> String {
        guard let regex = try? NSRegularExpression(pattern: titlePattern) else { return "Memo 1" }
        let largest = existingTitles.compactMap { title -> Int? in
            let range = NSRange(title.startIndex..., in: title)
            guard let match = regex.firstMatch(in: title, range: range),
                  let digits = Range(match.range(at: 1), in: title) else { return nil }
            return Int(title[digits])
        }.max() ?? 0
        return "Memo \(largest + 1)"
    }

    @MainActor
    private func store(_ memo: VoiceMemo) {
        state.voiceMemoDetails.upsert(memo)
        state.voiceMemos.upsert(VoiceMemoSummary(memo))
    }
}
