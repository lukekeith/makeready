import Foundation

/// bible-verse-picker D14: the ordered save of a picked passage. A split passage is several `bible` activities
/// and there is no batch endpoint, so the save is a list of requests that stops at the first failure and
/// resumes from it: POST every new part, `PATCH …/order` to place them, and (a changed passage) PUT the
/// original last — so a half-done save leaves the original untouched.
enum BibleSave {
    /// What to send, in order. `order` names the created parts by `slot(_:)` until their ids exist.
    struct Plan {
        let version: String
        /// One document per POST, in order.
        let posts: [ActivityDocument]
        /// The version's full order, `slot(i)` standing for the i-th created activity; nil = no reorder.
        let order: [String]?
        /// A changed passage's original, replaced last with its first part.
        let put: (activityId: String, document: ActivityDocument)?
    }

    /// A stopped save: the failed request (Retry resumes from it) and the ids already created.
    struct Failure: Error {
        let step: Int
        let created: [String]
        let underlying: Error
    }

    /// The placeholder for the i-th created activity inside `Plan.order`.
    static func slot(_ index: Int) -> String { "\u{1}created-\(index)" }

    // MARK: Planning

    /// A new passage: every part is POSTed, then placed right after `after` among `existing`. With no `after` (or
    /// one not in `existing`) the parts go last — the New Activity page's placeholder slot (D15) — where the server
    /// already appends them, so no reorder is sent; inserting after the last activity is the same append.
    static func plan(new parts: [BiblePick], version: String, existing: [String], after: String?,
                     background: ActivityBackground? = nil) -> Plan {
        let documents = parts.map { BibleScripture.document(for: $0, background: background) }
        var order = existing
        let at = after.flatMap { existing.firstIndex(of: $0) }.map { $0 + 1 } ?? existing.count
        order.insert(contentsOf: documents.indices.map(slot), at: at)
        return Plan(version: version, posts: documents, order: at == existing.count ? nil : order, put: nil)
    }

    /// A changed passage: parts after the first are POSTed and placed right after `activityId`, which is then
    /// PUT with the first part. A passage that did not split posts nothing and only PUTs.
    static func plan(change activityId: String, parts: [BiblePick], version: String, existing: [String],
                     background: ActivityBackground? = nil) -> Plan {
        let documents = parts.map { BibleScripture.document(for: $0, background: background) }
        let extra = Array(documents.dropFirst())
        var order = existing
        if !extra.isEmpty, let at = existing.firstIndex(of: activityId) {
            order.insert(contentsOf: extra.indices.map(slot), at: at + 1)
        }
        return Plan(version: version, posts: extra, order: extra.isEmpty ? nil : order,
                    put: documents.first.map { (activityId, $0) })
    }

    /// The document's fallback title — the citation without the translation (D10).
    static func title(of document: ActivityDocument) -> String {
        if case .string(let title)? = document.raw[path: ["fallback", "title"]] { return title }
        return ""
    }

    /// `plan.order` with each slot replaced by the id created for it.
    static func resolvedOrder(_ plan: Plan, created: [String]) -> [String]? {
        plan.order?.map { id in
            created.indices.first(where: { slot($0) == id }).map { created[$0] } ?? id
        }
    }

    // MARK: Running

    /// Runs the requests from `step` on: steps `0..<posts.count` are the POSTs, then the reorder, then the PUT.
    /// `created` carries the ids a stopped run already made, so a resume never re-POSTs them.
    @MainActor
    static func run(_ plan: Plan, actions: ActivityNewContainer.Actions, from step: Int,
                    created: [String] = []) async -> Result<[String], Failure> {
        var created = created
        var index = step
        do {
            while index < plan.posts.count {
                let document = plan.posts[index]
                created.append(try await actions.create(plan.version, "bible", title(of: document), document))
                index += 1
            }
            if index == plan.posts.count {
                if let order = resolvedOrder(plan, created: created) { try await actions.reorder(plan.version, order) }
                index += 1
            }
            if let put = plan.put {
                try await actions.update(put.activityId, title(of: put.document), put.document)
            }
            return .success(created)
        } catch {
            return .failure(Failure(step: index, created: created, underlying: error))
        }
    }
}
