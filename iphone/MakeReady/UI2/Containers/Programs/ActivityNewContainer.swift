import SwiftUI

/// Where the Text tile sends the leader once the activity exists: swaps the picker for the editor in place.
@MainActor
protocol ActivityNewNavigating: AnyObject {
    func replace(with destination: UI2Destination)
    /// bible-verse-picker D2/D15: the Bible tile pushes Books, returning to this page's depth.
    func push(_ destination: UI2Destination)
    var depth: Int { get }
}

extension ActivityNewNavigating {
    func push(_ destination: UI2Destination) {}
    var depth: Int { 0 }
}

/// program-lesson-add-activity D10/D17, text-activity D15/D16/D39: the `.activityNew` destination — the
/// activity-type picker for one lesson. The Text tile creates a `text` activity on the lesson's draft and swaps to
/// the editor; the other tiles stay visible, dimmed and inert (`unavailableTypes`); a slide tap opens that activity
/// through `ActivityEntry`; back pops.
struct ActivityNewContainer: View {
    let programId: String
    let lessonId: String

    /// D15 (Bible verse is enabled by bible-verse-picker D15): Video, YouTube, Write and Poll — C-086 raw case names.
    static let unavailableTypes = ["video", "youtube", "write", "poll"]

    @Environment(\.ui2Navigator) private var navigator
    @State private var model: Model
    /// Bumped when a chip screenshot lands in the image cache, so the strip re-reads it.
    @State private var imagesSeeded = 0

    init(programId: String, lessonId: String) {
        self.programId = programId
        self.lessonId = lessonId
        _model = State(initialValue: Model(lessonId: lessonId))
    }

    var body: some View {
        let _ = imagesSeeded
        return ActivityNewScreen(
            state: ActivityNewMapper.state(lesson: AppState.shared.lessons[lessonId], media: AppState.shared.mediaMap,
                                           pendingType: model.pendingType),
            onBack: { navigator.pop() },
            onSelect: { type in
                switch type {
                case .text: Task { await model.selectText() }
                case .bibleVerse: model.selectBible()
                default: return
                }
            },
            onSelectSlide: { id in openSlide(id) }
        )
        .ui2PushedPageFill()
        // The chips' screenshots, seeded as the editor seeds its own: rendered thumbnails for canvas kinds,
        // posters and stills otherwise. A seed re-renders the page through `imagesSeeded`.
        .task(id: chipImageKey) {
            let app = AppState.shared
            let activities = app.lessons[lessonId]?.activities ?? []
            var seeded = await ActivityThumbnail.seed(activities, media: app.mediaMap)
            if await UI2ImageLoader.seed(chipImageKey.filter { $0.hasPrefix("http") }, context: "ActivityNewContainer.chips") {
                seeded = true
            }
            if seeded { imagesSeeded += 1 }
        }
        // D2: Select returns the pick through the mailbox once the picker has popped.
        .onChange(of: model.pendingFlowId.flatMap { BiblePassagePick.shared.pending[$0] }) { _, pick in
            if pick != nil { Task { await model.receiveBiblePick() } }
        }
        .onAppear { model.navigator = LiveNavigator(navigator: navigator, current: .activityNew(programId: programId, lessonId: lessonId)) }
    }

    /// Changes whenever a chip's screenshot could.
    private var chipImageKey: [String] {
        ActivityNewMapper.state(lesson: AppState.shared.lessons[lessonId], media: AppState.shared.mediaMap).slideImages
    }

    /// D39: a slide tap opens that activity; the placeholder chip is the one being created and does nothing.
    private func openSlide(_ id: String) {
        guard let activity = AppState.shared.lessons[lessonId]?.activities.first(where: { $0.id == id }) else { return }
        ActivityEntry.open(kind: activity.kind, activityId: activity.id, push: navigator.push)
    }

    /// The live seam: `UI2Navigator.replaceTop` needs the page being replaced.
    @MainActor
    private final class LiveNavigator: ActivityNewNavigating {
        let navigator: UI2Navigator
        let current: UI2Destination

        init(navigator: UI2Navigator, current: UI2Destination) {
            self.navigator = navigator
            self.current = current
        }

        func replace(with destination: UI2Destination) { navigator.replaceTop(current, destination) }
        func push(_ destination: UI2Destination) { navigator.push(destination) }
        var depth: Int { navigator.depth() }
    }

    // MARK: - Starter document

    /// D16: the new Text activity's document — an empty canvas on a generated blob gradient
    /// (text-activity-v2 D3/D5), a share chrome, and 02 §2's fallback. `title` is the fallback's title.
    static func textDocument(title: String) -> ActivityDocument {
        var rng = SystemRandomNumberGenerator()
        return textDocument(title: title, palette: nil, rng: &rng)
    }

    /// The starter with an injectable palette (nil = a random curated one) and RNG, so tests are deterministic.
    static func textDocument<R: RandomNumberGenerator>(title: String, palette: [String]?, rng: inout R) -> ActivityDocument {
        let gradient = ActivityBackgroundGenerator.make(
            palette: palette ?? ActivityBackgroundGenerator.randomPalette(rng: &rng), rng: &rng)
        return ActivityDocument(raw: .object([
            "schemaVersion": .number(1),
            "kind": .string("text"),
            "background": .object(["color": .string(gradient.base), "gradient": gradient.jsonValue]),
            "content": .object([
                "type": .string("canvas"),
                "verticalAnchor": .string("center"),
                "objects": .array([])
            ]),
            "actions": .array([]),
            "chrome": .object(["topAction": .string("share")]),
            "fallback": .object(["title": .string(title), "body": .string(ActivityDocument.fallbackBody)])
        ]))
    }

    // MARK: - Model

    /// The two calls the Text tile makes, as a seam: the live ones go through `ActivityActions`.
    struct Actions {
        /// The lesson's draft version id, loading the draft first when it is not in state.
        var draftVersionId: @MainActor (_ lessonId: String) async throws -> String
        /// D46: reloads the lesson's draft from the server and returns its id (a cached one was frozen).
        var reloadDraftVersionId: @MainActor (_ lessonId: String) async throws -> String = { _ in throw MissingDraft() }
        /// `POST /api/lesson-versions/:id/activities` → the created activity's id.
        var create: @MainActor (_ versionId: String, _ kind: String, _ title: String, _ document: ActivityDocument) async throws -> String
        /// text-activity-v2 D37: `PATCH /api/lesson-versions/:id/activities/order` — the draft's activities in this order.
        var reorder: @MainActor (_ versionId: String, _ activityIds: [String]) async throws -> Void = { _, _ in }
        /// bible-verse-picker D14: `PUT /api/content-activities/:id` - a changed passage replaces the original, last.
        var update: @MainActor (_ activityId: String, _ title: String?, _ document: ActivityDocument) async throws -> Void = { _, _, _ in }

        static var live: Actions {
            Actions(
                draftVersionId: { lessonId in
                    // The program read names the draft without loading it; a draft not in state is loaded first, so
                    // the created activity's version is known (the rail refreshes and the editor opens from cache).
                    if let id = AppState.shared.draftVersionId(forLesson: lessonId), AppState.shared.lessonVersions[id] != nil {
                        return id
                    }
                    try await ActivityActions().loadDraft(lessonId: lessonId)
                    guard let id = AppState.shared.draftVersionId(forLesson: lessonId) else { throw MissingDraft() }
                    return id
                },
                reloadDraftVersionId: { lessonId in
                    try await ActivityActions().loadDraft(lessonId: lessonId)
                    guard let id = AppState.shared.draftVersionId(forLesson: lessonId) else { throw MissingDraft() }
                    return id
                },
                create: { versionId, kind, title, document in
                    try await ActivityActions().create(versionId: versionId, kind: kind, title: title, document: document).id
                },
                reorder: { versionId, ids in
                    try await ActivityActions().reorder(versionId: versionId, activityIds: ids)
                },
                update: { id, title, document in
                    try await ActivityActions().save(activityId: id, title: title, document: document)
                })
        }
    }

    private struct MissingDraft: Error {}

    /// The Text tile's state: whether its request is in flight, and what to do with the result.
    @MainActor
    @Observable
    final class Model {
        static let textTitle = "Text"

        let lessonId: String
        private let actions: Actions
        var navigator: ActivityNewNavigating?
        private let report: (Error) -> Void
        /// D14: the Bible save's failure, with the Retry the banner offers.
        private let reportBible: (Error, @escaping () -> Void) -> Void

        private(set) var isCreating = false
        private var isCreatingBible = false
        /// The open picker's flow id, until its pick arrives (D2).
        private(set) var pendingFlowId: UUID?
        /// D37: the activity the new one follows (the editor's grid sets it); nil = first.
        var afterActivityId: String?
        /// A stopped Bible save, for Retry to resume (D14).
        private var stopped: (plan: BibleSave.Plan, failure: BibleSave.Failure)?
        /// text-activity-v2 D27: set by the editor's in-place grid — the created activity opens there
        /// instead of replacing the page.
        var onCreated: ((String) -> Void)?

        /// C-086 `pendingType`: the tile whose request is in flight; "" = interactive.
        var pendingType: String {
            if isCreatingBible { return ActivityTypeGrid.ActivityType.bibleVerse.rawValue }
            return isCreating ? ActivityTypeGrid.ActivityType.text.rawValue : ""
        }

        init(lessonId: String, actions: Actions = .live, navigator: ActivityNewNavigating? = nil,
             report: @escaping (Error) -> Void = Model.surface,
             reportBible: @escaping (Error, @escaping () -> Void) -> Void = Model.surfaceBible) {
            self.lessonId = lessonId
            self.actions = actions
            self.navigator = navigator
            self.report = report
            self.reportBible = reportBible
        }

        /// D16: create the activity at once, titled "Text", then swap to its editor. A second tap while the
        /// request is in flight is ignored; a failure surfaces the banner and leaves the tile enabled.
        func selectText() async {
            guard !isCreating else { return }
            isCreating = true
            defer { isCreating = false }
            do {
                let versionId = try await actions.draftVersionId(lessonId)
                let document = ActivityNewContainer.textDocument(title: Self.textTitle)
                let id: String
                do {
                    id = try await actions.create(versionId, "text", Self.textTitle, document)
                } catch ActivityActionsError.notDraft {
                    // D46: the cached draft was frozen by a publish made elsewhere; reload it and post once more.
                    let fresh = try await actions.reloadDraftVersionId(lessonId)
                    id = try await actions.create(fresh, "text", Self.textTitle, document)
                }
                if let onCreated {
                    onCreated(id)
                } else {
                    navigator?.replace(with: .activitiesEditor(activityId: id))
                }
            } catch {
                if UI2ImageLoader.isCancellation(error) { return }
                report(error)
            }
        }

        // MARK: Bible tile (bible-verse-picker D14, D15)

        /// D15: opens Books for a new activity in this lesson; Back from there creates nothing.
        func selectBible() {
            guard let navigator, pendingFlowId == nil, !isCreatingBible else { return }
            let app = AppState.shared
            let used = app.draftVersionId(forLesson: lessonId)
                .map { BibleScripture.used(in: app.activities(forVersion: $0)) } ?? []
            let flowId = UUID()
            app.biblePickFlows[flowId] = BiblePickFlow(
                caller: .newActivity(lessonId: lessonId, afterActivityId: afterActivityId),
                returnDepth: navigator.depth, used: used, initial: nil)
            pendingFlowId = flowId
            navigator.push(.bibleBooks(flowId: flowId))
        }

        /// D2: takes the pick Select delivered and saves it.
        func receiveBiblePick() async {
            guard let flowId = pendingFlowId, let pick = BiblePassagePick.shared.take(for: flowId) else { return }
            pendingFlowId = nil
            await createBible(pick: pick)
        }

        /// D14: split the pick, POST each part, place them after the insert point, then open the first part.
        /// Select never waits on this (D25); a failure stops with a Retry.
        func createBible(pick: BiblePick) async {
            guard !isCreatingBible else { return }
            isCreatingBible = true
            defer { isCreatingBible = false }
            do {
                let versionId = try await actions.draftVersionId(lessonId)
                let parts = BibleScripture.split(pick) { BibleScripture.fits(verses: $0, width: BibleScripture.textWidth) }
                let existing = AppState.shared.activities(forVersion: versionId).map(\.id)
                let plan = BibleSave.plan(new: parts, version: versionId, existing: existing, after: afterActivityId)
                await runBible(plan, from: 0, created: [])
            } catch {
                if UI2ImageLoader.isCancellation(error) { return }
                report(error)
            }
        }

        /// D14: Retry - resumes from the failed request, never re-POSTing a created part.
        func retryBible() async {
            guard let stopped, !isCreatingBible else { return }
            isCreatingBible = true
            defer { isCreatingBible = false }
            await runBible(stopped.plan, from: stopped.failure.step, created: stopped.failure.created)
        }

        private func runBible(_ plan: BibleSave.Plan, from step: Int, created: [String]) async {
            switch await BibleSave.run(plan, actions: actions, from: step, created: created) {
            case .success(let ids):
                stopped = nil
                guard let first = ids.first else { return }
                if let onCreated { onCreated(first) } else { navigator?.replace(with: .activitiesEditor(activityId: first)) }
            case .failure(let failure):
                stopped = (plan, failure)
                if UI2ImageLoader.isCancellation(failure.underlying) { return }
                reportBible(failure.underlying) { [weak self] in Task { await self?.retryBible() } }
            }
        }

        /// The Bible save's banner, with the Retry that resumes it.
        static func surfaceBible(_ error: Error, retry: @escaping () -> Void) {
            AppState.shared.recordError(error, context: "ActivityNewContainer.createBible", surface: true,
                                        friendlyMessage: "Couldn't add the passage", retry: retry)
        }

        /// The error-banner channel (/ios-error-surface): a failed create is the leader's to retry by tapping again.
        static func surface(_ error: Error) {
            AppState.shared.recordError(error, context: "ActivityNewContainer.selectText", surface: true,
                                        friendlyMessage: "Couldn't add activity")
        }
    }
}

/// The picker's strip: the lesson's activities by `position`, then one placeholder chip, active (D17).
enum ActivityNewMapper {
    static let placeholderID = "placeholder"
    static let placeholderLabel = "New activity"

    static func state(lesson: Lesson?, media: [String: MediaMapEntry] = [:], pendingType: String = "") -> ActivityNewScreen.State {
        let activities = (lesson?.activities ?? []).sorted { $0.position < $1.position }
        return ActivityNewScreen.State(
            slideIDs: activities.map(\.id) + [placeholderID],
            slideLabels: activities.map(\.title) + [placeholderLabel],
            // The existing chips show their screenshots, by the program-home rail's rule; the placeholder has none.
            slideImages: activities.map { StudyProgramHomeMapper.slideImage($0, media: media) } + [""],
            activeID: placeholderID,
            pendingType: pendingType,
            unavailableTypes: ActivityNewContainer.unavailableTypes,
            createFailed: false
        )
    }
}
