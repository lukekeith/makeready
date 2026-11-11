import Foundation

/// bible-verse-picker D15, D29: the ordered save of a picked passage. A pick is one `bible` activity, but a new
/// one is still two requests (POST, then `PATCH …/order` into its slot), so the save is a list of requests that
/// stops at the first failure and resumes from it; a changed passage is one PUT of the original.
enum BibleSave {
    /// What to send, in order. `order` names the created activity by `slot(_:)` until its id exists.
    struct Plan {
        let version: String
        /// One document per POST, in order.
        let posts: [ActivityDocument]
        /// The version's full order, `slot(0)` standing for the created activity; nil = no reorder.
        let order: [String]?
        /// A changed passage's original, replaced with the new document.
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

    /// A new passage: POSTed, then placed right after `after` among `existing`. With no `after` (or one not in
    /// `existing`) it goes last — the New Activity page's placeholder slot (D15) — where the server already
    /// appends it, so no reorder is sent; inserting after the last activity is the same append.
    static func plan(new pick: BiblePick, version: String, existing: [String], after: String?,
                     background: ActivityBackground? = nil) -> Plan {
        let document = BibleScripture.document(for: pick, background: background)
        var order = existing
        let at = after.flatMap { existing.firstIndex(of: $0) }.map { $0 + 1 } ?? existing.count
        order.insert(slot(0), at: at)
        return Plan(version: version, posts: [document], order: at == existing.count ? nil : order, put: nil)
    }

    /// A changed passage (D15): the original `activityId` is PUT with the new document; nothing is POSTed.
    static func plan(change activityId: String, pick: BiblePick, version: String,
                     background: ActivityBackground? = nil) -> Plan {
        Plan(version: version, posts: [], order: nil,
             put: (activityId, BibleScripture.document(for: pick, background: background)))
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
