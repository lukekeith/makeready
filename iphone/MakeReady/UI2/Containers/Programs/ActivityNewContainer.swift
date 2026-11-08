import SwiftUI

/// Where the Text tile sends the leader once the activity exists: swaps the picker for the editor in place.
@MainActor
protocol ActivityNewNavigating: AnyObject {
    func replace(with destination: UI2Destination)
}

/// program-lesson-add-activity D10/D17, text-activity D15/D16/D39: the `.activityNew` destination — the
/// activity-type picker for one lesson. The Text tile creates a `text` activity on the lesson's draft and swaps to
/// the editor; the other tiles stay visible, dimmed and inert (`unavailableTypes`); a slide tap opens that activity
/// through `ActivityEntry`; back pops.
struct ActivityNewContainer: View {
    let programId: String
    let lessonId: String

    /// D15: Bible verse, Video, YouTube, Write and Poll — C-086 raw case names.
    static let unavailableTypes = ["bibleVerse", "video", "youtube", "write", "poll"]

    @Environment(\.ui2Navigator) private var navigator
    @State private var model: Model

    init(programId: String, lessonId: String) {
        self.programId = programId
        self.lessonId = lessonId
        _model = State(initialValue: Model(lessonId: lessonId))
    }

    var body: some View {
        ActivityNewScreen(
            state: ActivityNewMapper.state(lesson: AppState.shared.lessons[lessonId], pendingType: model.pendingType),
            onBack: { navigator.pop() },
            onSelect: { type in
                guard type == .text else { return }
                Task { await model.selectText() }
            },
            onSelectSlide: { id in openSlide(id) }
        )
        .ui2PushedPageFill()
        .onAppear { model.navigator = LiveNavigator(navigator: navigator, current: .activityNew(programId: programId, lessonId: lessonId)) }
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
    }

    // MARK: - Starter document

    /// D16: the new Text activity's document — an empty canvas on the first C-094 preset (White), a share chrome,
    /// and 02 §2's fallback. `title` is the fallback's title.
    static func textDocument(title: String) -> ActivityDocument {
        ActivityDocument(raw: .object([
            "schemaVersion": .number(1),
            "kind": .string("text"),
            "background": .object(["color": .string("#FFFFFF")]),
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

        private(set) var isCreating = false

        /// C-086 `pendingType`: the tile whose request is in flight; "" = interactive.
        var pendingType: String { isCreating ? ActivityTypeGrid.ActivityType.text.rawValue : "" }

        init(lessonId: String, actions: Actions = .live, navigator: ActivityNewNavigating? = nil,
             report: @escaping (Error) -> Void = Model.surface) {
            self.lessonId = lessonId
            self.actions = actions
            self.navigator = navigator
            self.report = report
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
                navigator?.replace(with: .activitiesEditor(activityId: id))
            } catch {
                if UI2ImageLoader.isCancellation(error) { return }
                report(error)
            }
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

    static func state(lesson: Lesson?, pendingType: String = "") -> ActivityNewScreen.State {
        let activities = (lesson?.activities ?? []).sorted { $0.position < $1.position }
        return ActivityNewScreen.State(
            slideIDs: activities.map(\.id) + [placeholderID],
            slideLabels: activities.map(\.title) + [placeholderLabel],
            activeID: placeholderID,
            pendingType: pendingType,
            unavailableTypes: ActivityNewContainer.unavailableTypes,
            createFailed: false
        )
    }
}
