import PhotosUI
import SwiftUI

/// ui2-programs §iphone Program page: the pushed `.studyProgramHome` page (D5–D7). It owns its
/// ScrollView and pins C-040 above it (`showsHeader: false`, the GroupDetailContainer precedent);
/// the ScrollView's pull-down reloads — the page's only retry (owner 2026-10-28). Cache-first: the
/// stores render at once under the pushed name while the program (every lesson page) and its
/// enrollments load in parallel.
struct StudyProgramHomeContainer: View {
    let programId: String
    let name: String

    /// D5: the banner when the program turns out to be gone.
    static let goneMessage = "This program is no longer available"
    /// D9: the banner when adding a lesson fails.
    static let addLessonFailedMessage = "Couldn't add a lesson"
    /// program-lesson-add-activity D8/D9/D16: the delete confirmation and the failure banner.
    static let deleteLessonConfirmTitle = "Delete lesson?"
    static let deleteLessonConfirmMessage = "This lesson and its activities will be permanently deleted."
    static let deleteLessonFailedMessage = "Couldn't delete the lesson"
    static let deleteLessonConfirmAction = ActionMenuOverlay.ActionItem(glyph: "", label: "Delete lesson", tone: .destructive)
    /// D5: how long the push takes to settle before a 404 pops it.
    static let pushSettle: Duration = .milliseconds(400)

    @Environment(AuthManager.self) private var authManager
    @Environment(\.ui2Navigator) private var navigator
    /// Bumped when images land in Ui2ImageCache, which SwiftUI does not observe (D6).
    @State private var imagesSeeded = 0
    /// D5: the program load failed this visit (with nothing cached, the page says pull to refresh).
    @State private var failed = false
    /// D7: the selected DayChip.
    @State private var activeDay = 1
    /// D9: one add in flight.
    @State private var addingLesson = false
    /// program-lesson-add-activity D15: one delete in flight.
    @State private var deletingLesson = false
    /// D16: the lesson the chevron was tapped on — held so a background reload can't retarget the action.
    @State private var heldLessonId: String?
    @State private var lessonMenuOpen = false
    /// True from the menu's dismissal until `onHidden` — taps reach the page during the slide-out.
    @State private var lessonMenuHiding = false
    @State private var lessonMenuRows = StudyProgramHomeContainer.lessonMenuRows(lessonCount: 2)
    @State private var pendingLessonChoice: LessonMenuChoice?
    @State private var deleteConfirmOpen = false
    // activity-slide-menu: the held slide, its menu, the chosen row and the delete confirmation.
    @State private var heldActivity: ActivitySummary?
    @State private var heldActivityLessonId: String?
    @State private var activityMenuOpen = false
    @State private var activityMenuHiding = false
    @State private var pendingActivityChoice: ActivitySlideMenu.Choice?
    @State private var activityDeleteConfirmOpen = false
    /// D11 (group-cover-image D1–D3): the system photo picker and its selection.
    @State private var pickerOpen = false
    @State private var pickedItem: PhotosPickerItem?
    /// D11: the cover menu, and the row chosen in it — acted on once the menu has slid out.
    @State private var coverMenuOpen = false
    /// media-library D9: the rows the cover menu shows — with a cover, or the no-cover pair.
    @State private var coverMenuRows = GroupDetailContainer.coverActions
    @State private var pendingCoverChoice: GroupDetailContainer.CoverChoice?
    /// D11: the viewer's URL while it is up.
    @State private var viewerURL: String?
    /// image-viewer-zoom-dismiss: the cover's on-screen frame — the viewer grows from it and flies
    /// back into it.
    @State private var coverFrame: CGRect?

    var body: some View {
        let app = AppState.shared
        let mapped = StudyProgramHomeMapper.state(
            .init(name: name, program: app.programs[programId], lessons: app.lessonsFor(programId: programId),
                  enrollments: app.programEnrollmentsFor(programId: programId), failed: failed, activeDay: activeDay, media: app.mediaMap),
            timeZone: .current
        )
        let _ = imagesSeeded
        let state = Self.cachedImages(mapped)
        VStack(spacing: 0) {
            PageHeader(
                style: .twoIcons,
                title: "Study program",
                showTitle: true,
                showIcons: false,
                leadingGlyph: .back,
                rightButtons: [],
                onLeading: { navigator.pop() }
            )
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    StudyProgramHomeScreen(
                        state: state,
                        showsHeader: false,
                        onBack: { navigator.pop() },
                        // D10: a settings row → that field's edit page ("Lessons" maps to nothing, D7).
                        onEditField: { label in
                            guard let next = Self.editDestination(programId: programId, label: label,
                                                                  program: AppState.shared.programs[programId]) else { return }
                            navigator.push(next)
                        },
                        // ui2-enrollment-create D2: enrollments `add` → the checklist with this program preloaded.
                        onAddEnrollment: { EnrollEntry.open(groupId: nil, studyProgramId: programId, push: navigator.push) },
                        onAddLesson: { Task { await addLesson() } },
                        // D7/OQ-11: select the chip and bring that day's card into view.
                        onSelectDay: { day in
                            activeDay = day
                            withAnimation { proxy.scrollTo(StudyProgramHomeScreen.lessonScrollID(day), anchor: .top) }
                        },
                        // text-activity D39: a canvas-kind slide opens the editor; any other kind says it can't be edited yet.
                        onOpenActivity: { lessonIndex, slideIndex in
                            let lessons = AppState.shared.lessonsFor(programId: programId)
                            guard let lessonId = Self.lessonID(at: lessonIndex, in: lessons),
                                  let activity = Self.activity(at: slideIndex, inLesson: lessonId) else { return }
                            ActivityEntry.open(kind: activity.kind, activityId: activity.id, push: navigator.push)
                        },
                        // D11: no cover → the picker; a cover → Edit · Change · View.
                        onCoverTap: { handleCoverTap() },
                        onRetry: { Task { await reload() } },
                        onCoverFrameChange: { coverFrame = $0 },
                        // D2: the "+" card pushes the picker at once.
                        onAddActivity: { index in
                            guard let lessonId = Self.lessonID(at: index, in: AppState.shared.lessonsFor(programId: programId)) else { return }
                            navigator.push(.activityNew(programId: programId, lessonId: lessonId))
                        },
                        // D4/D16: the chevron holds that lesson's id and opens the menu.
                        onOpenLessonMenu: { index in
                            // One lesson at a time: ignore a tap while a menu is open or sliding out,
                            // or a choice or confirmation is pending, so the held id can't be retargeted.
                            guard !lessonMenuOpen, !lessonMenuHiding, pendingLessonChoice == nil, !deleteConfirmOpen else { return }
                            guard let lessonId = Self.lessonID(at: index, in: AppState.shared.lessonsFor(programId: programId)) else { return }
                            heldLessonId = lessonId
                            lessonMenuRows = Self.lessonMenuRows(lessonCount: state.lessonCount)
                            lessonMenuOpen = true
                        },
                        // activity-slide-menu: touch-and-hold a slide → Edit · Duplicate · Delete.
                        onActivityMenu: { lessonIndex, slideIndex in
                            guard !activityMenuOpen, !activityMenuHiding, pendingActivityChoice == nil,
                                  !activityDeleteConfirmOpen, !lessonMenuOpen, !deleteConfirmOpen else { return }
                            let lessons = AppState.shared.lessonsFor(programId: programId)
                            guard let lessonId = Self.lessonID(at: lessonIndex, in: lessons),
                                  let activity = Self.activity(at: slideIndex, inLesson: lessonId) else { return }
                            heldActivity = activity
                            heldActivityLessonId = lessonId
                            activityMenuOpen = true
                        }
                    )
                }
                .scrollIndicators(.hidden)
                .pullDownRefresh { await reload() }
            }
        }
        .background(Token.layoutBackground.ignoresSafeArea())
        // D11 (group-cover-image D2): the chosen row runs after the menu has finished hiding — the
        // overlay host keeps only the first presented overlay.
        .actionMenuPresentation(isPresented: coverMenuOpen, onDismiss: { coverMenuOpen = false },
                                onHidden: { runPendingCoverChoice() }) {
            ActionMenuOverlay(
                actions: coverMenuRows,
                onSelect: { item in
                    pendingCoverChoice = GroupDetailContainer.CoverChoice(label: item.label)
                    coverMenuOpen = false
                },
                onDone: { coverMenuOpen = false }
            )
        }
        // program-lesson-add-activity D4/D16: Add activity · Delete lesson; Done stays. The chosen row
        // runs once the menu has hidden, as the cover menu does.
        .actionMenuPresentation(isPresented: lessonMenuOpen, onDismiss: { closeLessonMenu() },
                                onHidden: { runPendingLessonChoice() }) {
            ActionMenuOverlay(
                actions: lessonMenuRows,
                onSelect: { item in
                    pendingLessonChoice = LessonMenuChoice(rawValue: item.label)
                    closeLessonMenu()
                },
                onDone: { closeLessonMenu() },
                menuTitle: heldLessonId.flatMap { AppState.shared.lessons[$0] }.map {
                    Self.lessonMenuTitle(dayNumber: $0.position, title: $0.title)
                }
            )
        }
        // activity-slide-menu: Edit · Duplicate · Delete; the chosen row runs once the menu has hidden.
        .actionMenuPresentation(isPresented: activityMenuOpen, onDismiss: { closeActivityMenu() },
                                onHidden: { runPendingActivityChoice() }) {
            ActionMenuOverlay(
                actions: ActivitySlideMenu.rows,
                onSelect: { item in
                    pendingActivityChoice = ActivitySlideMenu.Choice(rawValue: item.label)
                    closeActivityMenu()
                },
                onDone: { closeActivityMenu() },
                menuTitle: heldActivity?.title
            )
        }
        // activity-slide-menu: the delete confirmation — one destructive action, Cancel keeps it.
        .actionMenuPresentation(isPresented: activityDeleteConfirmOpen, onDismiss: { cancelActivityDelete() }) {
            ActionMenuOverlay(
                title: ActivitySlideMenu.deleteConfirmTitle,
                message: ActivitySlideMenu.deleteConfirmMessage,
                actions: [ActivitySlideMenu.deleteConfirmAction],
                doneLabel: "Cancel",
                onSelect: { _ in confirmActivityDelete() },
                onDone: { cancelActivityDelete() }
            )
        }
        // D8/D16: the delete confirmation — one destructive action, Cancel keeps the lesson.
        .actionMenuPresentation(isPresented: deleteConfirmOpen, onDismiss: { cancelDelete() }) {
            ActionMenuOverlay(
                title: Self.deleteLessonConfirmTitle,
                message: Self.deleteLessonConfirmMessage,
                actions: [Self.deleteLessonConfirmAction],
                doneLabel: "Cancel",
                onSelect: { _ in confirmDelete() },
                onDone: { cancelDelete() }
            )
        }
        // The system picker — a modifier, not .sheet/.fullScreenCover; no permission prompt.
        .photosPicker(isPresented: $pickerOpen, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            pickedItem = nil
            Task { await openPicked(item) }
        }
        .coverViewerPresentation(url: viewerURL, sourceFrame: coverFrame, accessibilityLabel: "Program cover", onClose: { viewerURL = nil })
        .task { await reload() }
        .task(id: Self.imageURLs(mapped)) {
            if await UI2ImageLoader.seed(Self.imageURLs(mapped), context: "StudyProgramHomeContainer") { imagesSeeded += 1 }
        }
        // text-activity D26: canvas-kind rail slides render their document once and cache it under the slide's key.
        .task(id: mapped.lessonSlideImages.flatMap { $0 }) {
            let slides = app.lessonsFor(programId: programId).flatMap(\.activities)
            if await ActivityThumbnail.seed(slides, media: app.mediaMap) { imagesSeeded += 1 }
        }
        .task(id: mapped.enrollmentPhotoURLs) {
            if await CoverImageLoader.seedList(mapped.enrollmentPhotoURLs) { imagesSeeded += 1 }
        }
    }

    // MARK: - Load (D5)

    /// What a failed program load means for the page.
    enum LoadFailure: Equatable { case cancelled, signOut, gone, failed }

    static func loadFailure(for error: Error) -> LoadFailure {
        if GroupActions.isCancellation(error) { return .cancelled }
        if AuthStatusPolicy.shouldSignOut(after: error) { return .signOut }
        if let http = error as? APIHTTPError, http.status == 404 { return .gone }
        return .failed
    }

    /// D5: the program (every lesson page) and its enrollments, at once.
    @MainActor
    private func reload() async {
        async let enrollments: () = loadEnrollments()
        do {
            try await ProgramActions().loadProgram(id: programId)
            failed = false
        } catch {
            await handleProgramFailure(error)
        }
        _ = await enrollments
    }

    @MainActor
    private func handleProgramFailure(_ error: Error) async {
        switch Self.loadFailure(for: error) {
        case .cancelled:
            return
        case .signOut:
            await signOut()
        case .gone:
            // D5: forget it and go back to the list once the push has settled.
            ProgramActions().forgetProgram(id: programId)
            AppState.shared.recordError(error, context: "StudyProgramHomeContainer.loadProgram", surface: true,
                                        friendlyMessage: Self.goneMessage)
            try? await Task.sleep(for: Self.pushSettle)
            navigator.popTo(0)
        case .failed:
            failed = true
            AppState.shared.recordError(error, context: "StudyProgramHomeContainer.loadProgram", surface: false)
        }
    }

    /// D5/D16: a failure keeps the rest of the page and is recorded, console-only.
    @MainActor
    private func loadEnrollments() async {
        do {
            _ = try await ProgramActions().getProgramEnrollments(programId: programId, forceRefresh: true)
        } catch {
            switch Self.loadFailure(for: error) {
            case .cancelled: return
            case .signOut: await signOut()
            case .gone, .failed:
                AppState.shared.recordError(error, context: "StudyProgramHomeContainer.loadEnrollments", surface: false)
            }
        }
    }

    // MARK: - Cover (D11)

    private var coverOwner: CoverOwner { .program(programId) }

    private func handleCoverTap() {
        switch CoverOwner.coverTap(coverOwner.fields) {
        case .none: break
        case .picker:
            coverMenuRows = GroupDetailContainer.noCoverActions
            coverMenuOpen = true
        case .menu:
            coverMenuRows = GroupDetailContainer.coverActions
            coverMenuOpen = true
        }
    }

    private func runPendingCoverChoice() {
        guard let choice = pendingCoverChoice else { return }
        pendingCoverChoice = nil
        switch choice {
        case .change, .photos: pickerOpen = true
        case .library: navigator.push(.chooseCoverFromLibrary(owner: coverOwner))
        case .edit: navigator.push(coverOwner.destination(.stored))
        case .view: viewerURL = coverOwner.fields.flatMap(CoverOwner.viewerURL)
        }
    }

    /// Load the pick, make it upright and ≤ 2400px, then Edit cover. Dismissing the picker changes
    /// nothing; an unreadable pick surfaces a banner and stays here.
    @MainActor
    private func openPicked(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = CoverImageRendering.uprightDownsampled(data) else {
                throw APIError.invalidResponse
            }
            navigator.push(coverOwner.destination(.newPick(image, takenAt: CaptureDate.read(from: data))))
        } catch {
            if GroupActions.isCancellation(error) { return }
            AppState.shared.recordError(error, context: "StudyProgramHomeContainer.openPicked", surface: true,
                                        friendlyMessage: "Couldn't open that photo")
        }
    }

    // MARK: - Lessons + (D9)

    @MainActor
    private func addLesson() async {
        guard !addingLesson, AppState.shared.programs[programId] != nil else { return }
        addingLesson = true
        defer { addingLesson = false }
        do {
            _ = try await ProgramActions().addLesson(programId: programId)
            await reload()
        } catch {
            switch Self.loadFailure(for: error) {
            case .cancelled: return
            case .signOut: await signOut()
            case .gone, .failed:
                AppState.shared.recordError(error, context: "StudyProgramHomeContainer.addLesson", surface: true,
                                            friendlyMessage: Self.addLessonFailedMessage,
                                            retry: { Task { await addLesson() } })
            }
        }
    }

    // MARK: - Lesson menu (program-lesson-add-activity D4, D8, D15, D16)

    // MARK: - activity-slide-menu

    private func closeActivityMenu() {
        activityMenuOpen = false
        activityMenuHiding = true
    }

    private func runPendingActivityChoice() {
        activityMenuHiding = false
        guard let choice = pendingActivityChoice, let activity = heldActivity, let lessonId = heldActivityLessonId else {
            clearHeldActivity(); return
        }
        pendingActivityChoice = nil
        switch choice {
        case .edit:
            ActivityEntry.open(kind: activity.kind, activityId: activity.id, push: navigator.push)
            clearHeldActivity()
        case .duplicate:
            clearHeldActivity()
            Task { await duplicateActivity(activityKey: activity.activityKey, lessonId: lessonId) }
        case .delete:
            activityDeleteConfirmOpen = true
        }
    }

    private func clearHeldActivity() {
        heldActivity = nil
        heldActivityLessonId = nil
    }

    private func cancelActivityDelete() {
        activityDeleteConfirmOpen = false
        clearHeldActivity()
    }

    private func confirmActivityDelete() {
        let key = heldActivity?.activityKey
        let lessonId = heldActivityLessonId
        cancelActivityDelete()
        guard let key, let lessonId else { return }
        Task { await deleteActivity(activityKey: key, lessonId: lessonId) }
    }

    /// The leader asked for it, so a failure is the banner with a retry (/ios-error-surface); the page reloads either way.
    @MainActor
    private func duplicateActivity(activityKey: String, lessonId: String) async {
        do {
            try await ActivitySlideMenu.duplicate(activityKey: activityKey, lessonId: lessonId)
        } catch {
            if UI2ImageLoader.isCancellation(error) { return }
            AppState.shared.recordError(error, context: "StudyProgramHomeContainer.duplicateActivity", surface: true,
                                        friendlyMessage: ActivitySlideMenu.duplicateFailedMessage,
                                        retry: { Task { await duplicateActivity(activityKey: activityKey, lessonId: lessonId) } })
        }
        await reload()
    }

    @MainActor
    private func deleteActivity(activityKey: String, lessonId: String) async {
        do {
            try await ActivitySlideMenu.delete(activityKey: activityKey, lessonId: lessonId)
        } catch {
            if UI2ImageLoader.isCancellation(error) { return }
            AppState.shared.recordError(error, context: "StudyProgramHomeContainer.deleteActivity", surface: true,
                                        friendlyMessage: ActivitySlideMenu.deleteFailedMessage,
                                        retry: { Task { await deleteActivity(activityKey: activityKey, lessonId: lessonId) } })
        }
        await reload()
    }

    private func closeLessonMenu() {
        lessonMenuOpen = false
        lessonMenuHiding = true
    }

    private func runPendingLessonChoice() {
        lessonMenuHiding = false
        guard let choice = pendingLessonChoice else { heldLessonId = nil; return }
        pendingLessonChoice = nil
        switch choice {
        case .addActivity:
            if let lessonId = heldLessonId { navigator.push(.activityNew(programId: programId, lessonId: lessonId)) }
            heldLessonId = nil
        case .deleteLesson:
            deleteConfirmOpen = true
        }
    }

    /// D8: Cancel (button, scrim or swipe) keeps the lesson, sends nothing and clears the held id.
    private func cancelDelete() {
        deleteConfirmOpen = false
        heldLessonId = nil
    }

    private func confirmDelete() {
        let lessonId = heldLessonId
        cancelDelete()
        guard let lessonId else { return }
        Task { await deleteLesson(lessonId) }
    }

    /// D15: success is the server's `{ success: true }`; the page then reloads. A failure shows the
    /// banner and reloads too, so a row deleted elsewhere or a stale count corrects itself.
    @MainActor
    private func deleteLesson(_ lessonId: String) async {
        guard !deletingLesson else { return }
        deletingLesson = true
        defer { deletingLesson = false }
        do {
            try await ProgramActions().deleteLesson(programId: programId, lessonId: lessonId)
            await reload()
        } catch {
            switch Self.deleteFailure(for: error) {
            case .silent: return
            case .signOut: await signOut()
            case .banner:
                AppState.shared.recordError(error, context: "StudyProgramHomeContainer.deleteLesson", surface: true,
                                            friendlyMessage: Self.deleteLessonFailedMessage,
                                            retry: { Task { await deleteLesson(lessonId) } })
                await reload()
            }
        }
    }

    /// ui2-shell D27: a 401 ends the session; UI2Root then shows Login.
    @MainActor
    private func signOut() async {
        do { try await authManager.signOut() } catch {
            AppState.shared.recordError(error, context: "StudyProgramHomeContainer.signOut", surface: false)
        }
    }

    // MARK: - Pure helpers

    /// D4/D16: the chevron menu's choices, by row label.
    enum LessonMenuChoice: String {
        case addActivity = "Add activity"
        case deleteLesson = "Delete lesson"
    }

    /// D4/D5/D16: Add activity, then Delete lesson unless it is the only lesson.
    static func lessonMenuRows(lessonCount: Int) -> [ActionMenuOverlay.ActionItem] {
        var rows = [ActionMenuOverlay.ActionItem(glyph: "add-large-carbon", label: LessonMenuChoice.addActivity.rawValue)]
        if lessonCount > 1 {
            rows.append(.init(glyph: "trash-2", label: LessonMenuChoice.deleteLesson.rawValue, tone: .destructive))
        }
        return rows
    }

    /// program-day-rail-sticky: the menu's title — "Day 15 · It is evident", or "Day 15" alone when
    /// the lesson has no title, so no dot hangs off the end.
    static func lessonMenuTitle(dayNumber: Int, title: String?) -> String {
        let name = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Day \(dayNumber)" : "Day \(dayNumber) · \(name)"
    }

    /// D16: the id at a screen index — the screen's lesson arrays run in `dayNumber` order.
    static func lessonID(at index: Int, in lessons: [Lesson]) -> String? {
        let ordered = lessons.sorted { $0.position < $1.position }
        return ordered.indices.contains(index) ? ordered[index].id : nil
    }

    /// D39: the activity a rail slide stands for — the lesson's activities run in `position` order, as the slides do.
    @MainActor
    static func activity(at index: Int, inLesson lessonId: String) -> ActivitySummary? {
        let ordered = (AppState.shared.lessons[lessonId]?.activities ?? []).sorted { $0.position < $1.position }
        return ordered.indices.contains(index) ? ordered[index] : nil
    }

    /// D15: what a failed delete means — cancelled is silent, 401 signs out, anything else (a 404
    /// included) is the banner.
    enum DeleteFailure: Equatable { case silent, signOut, banner }

    static func deleteFailure(for error: Error) -> DeleteFailure {
        switch loadFailure(for: error) {
        case .cancelled: return .silent
        case .signOut: return .signOut
        case .gone, .failed: return .banner
        }
    }

    /// D10: the row label's edit page — nil for "Lessons"/unknown labels, or while the program has
    /// not loaded (nothing to edit yet).
    static func editDestination(programId: String, label: String, program: StudyProgram?) -> UI2Destination? {
        guard program != nil, let field = ProgramField(label: label) else { return nil }
        return .editProgramField(programId: programId, field: field)
    }

    /// D6: the full-size images the container seeds — the cover (≤1200px) and the lesson slides.
    /// The enrollment rows' group covers are list copies (cover-image-sizes, CoverImageLoader).
    static func imageURLs(_ state: StudyProgramHomeScreen.State) -> [String] {
        ([state.coverURL] + state.lessonSlideImages.flatMap { $0 }).filter { !$0.isEmpty }
    }

    /// Each image URL already in Ui2ImageCache, else "" (the component's empty look until it lands).
    @MainActor
    static func cachedImages(_ mapped: StudyProgramHomeScreen.State) -> StudyProgramHomeScreen.State {
        var s = mapped
        s.coverURL = MemberProfileContainer.cachedCoverURLs([mapped.coverURL]).first ?? ""
        s.lessonSlideImages = mapped.lessonSlideImages.map { MemberProfileContainer.cachedCoverURLs($0) }
        s.enrollmentPhotoURLs = CoverImageLoader.cachedListURLs(mapped.enrollmentPhotoURLs)
        return s
    }
}
