//
//  GroupsEnrollProgramScreen.swift
//  UI2Preview — the UI 2.0 preview module
//
//  Built from screen groups-enroll-program in d2m (§2 layout, §3 states, §4 components).
//  §5 endpoints, cited only — this view calls none: POST /api/enrollments
//  (`lessonAccess` and the schedule overrides are API-GAP-1/2 in §5).
//  PREVIEW ONLY: referenced by no app screen, route, tab, flag or navigation case.
//

import SwiftUI

/// Enrollment — a pushed checklist page: six steps done in any order, then Enroll, then the
/// completion state in place (§2, §3). Composed only of §4's C-040, C-125 (→ C-038, C-057),
/// C-124 (→ C-123), C-109 and C-048. Standalone: the screen is not minted from a collection
/// (`identifiedFrom` is null), so no D7 template applies.
struct GroupsEnrollProgramScreen: View {

    /// §3's three page phases. The checklist states differ only in which rows are done.
    enum Phase: String {
        case checklist
        case processing
        case enrolled
    }

    /// §3's closed six rows, in their fixed order (§2 checklist 2).
    enum Step: CaseIterable {
        case group
        case studyProgram
        case schedule
        case inviteTime
        case sync
        case accessibility
    }

    /// One §3 state's inputs. Every §3 state is reachable by these alone. A row is done when
    /// its draft value is present — `""` means the row is to do and its value is not used
    /// (§3 draft rule 1: a value that fails its check "arrives not done").
    struct State {
        /// `checklist` (empty … ready), `processing` or `enrolled`. An unknown word renders
        /// `checklist`.
        var phase: String
        // Row 1 — the draft's group.
        var groupName: String
        var groupInitials: String
        var groupImageURL: String
        /// "Created on «Month Do, YYYY»" — the date as displayed.
        var groupCreatedOn: String
        var groupActiveMembers: Int
        // Row 2 — the draft's study program.
        var programName: String
        var programDescription: String
        var programImageURL: String
        // Row 3 — the draft's schedule, as displayed. `scheduleStartDay` "" = not done.
        var scheduleStartWeekday: String
        var scheduleStartMonth: String
        var scheduleStartDay: String
        /// The start date is today (C-123 `date(today:)`).
        var scheduleStartToday: Bool
        /// The enabled weekdays, full names in week order.
        var scheduleWeekdays: [String]
        /// The derived end date, "«Month Do, YYYY»".
        var scheduleEndDate: String
        // Row 4 — the draft's invite time, 'HH:mm' (§5 `smsTime`).
        var smsTime: String
        // Row 5 — `AUTO` | `OFF` (§5 `syncMode`).
        var syncMode: String
        // Row 6 — `all-at-once` | `one-at-a-time` (§5 `lessonAccess`).
        var lessonAccess: String
    }

    let state: State
    /// C-109 `animated` — `true` live, `false` in captures (§4).
    var confirmationAnimated: Bool = true
    // §3 interactions that leave the screen — each an on<Verb> closure with R-03's no-op default.
    var onBack: () -> Void = {}                     // checklist back → caller, draft discarded (OQ-004)
    var onSelectStep: (Step) -> Void = { _ in }     // row tap → that row's picker (§6)
    var onEnroll: () -> Void = {}                   // header Enroll → POST /api/enrollments
    var onDone: () -> Void = {}                     // Done (header, button, back on `enrolled`) → caller

    init(
        state: State,
        confirmationAnimated: Bool = true,
        onBack: @escaping () -> Void = {},
        onSelectStep: @escaping (Step) -> Void = { _ in },
        onEnroll: @escaping () -> Void = {},
        onDone: @escaping () -> Void = {}
    ) {
        self.state = state
        self.confirmationAnimated = confirmationAnimated
        self.onBack = onBack
        self.onSelectStep = onSelectStep
        self.onEnroll = onEnroll
        self.onDone = onDone
    }

    // MARK: - §2 / §3 constants

    private static let title = "Enrollment"
    private static let enrollLabel = "Enroll"
    private static let doneLabel = "Done"
    private static let enrolledTitle = "Group enrolled"
    private static let processingAnnouncement = "Enrolling"
    /// §2: `totalSteps` = 6.
    private static let totalSteps = Step.allCases.count

    // GAP — groups-enroll-program §2 checklist 1: "Figma wraps it in a 408×319 box with 16pt
    // padding (C-125 deviation 1)" — the call site's inset, no spacing token names it.
    private static let progressHeaderInset: CGFloat = 16
    // FLAGGED LITERAL — groups-enroll-program §2 FL-3: 64 (result-block gap, same value as
    // invite-member FL-1).
    private static let resultGap: CGFloat = 64
    // GAP — groups-enroll-program §2 completion 1: "C-109 ConfirmationMark … 100×100" — C-109's
    // diameter is set by the call site; no size token (the invite-member precedent).
    private static let markSize: CGFloat = 100
    // FLAGGED LITERAL — groups-enroll-program §2 FL-1: completion title SF Pro Regular 24 / 28,
    // no token (nearest `type-hero-title` 24/24, `type-value-hero` 24/32).
    private static let completionTitleStyle = DesignTextStyle(weight: .regular, size: 24, lineHeight: 28, tracking: 0)
    // FLAGGED LITERAL — groups-enroll-program §2 FL-2: completion body SF Pro Regular 14 / 28,
    // no token (nearest `type-body-sm` 14/20).
    private static let completionBodyStyle = DesignTextStyle(weight: .regular, size: 14, lineHeight: 28, tracking: 0)

    // MARK: - Body (§2 top → bottom)

    var body: some View {
        // D22: no ScrollView at the root — the checklist is laid out at full length. The status
        // bar (§1 deviation 8) is the harness's.
        VStack(spacing: 0) {
            header

            // §2: content column at y103, padding `space-page-margin`.
            Group {
                switch phase {
                case .checklist, .processing: checklist
                case .enrolled: completion
                }
            }
            .padding(Token.Space.pageMargin)
        }
        // §2: empty `color-layout-background` below; the column stays top-anchored.
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Token.layoutBackground)
        // §3 `processing`: "VoiceOver announces \"Enrolling\"".
        .onChange(of: phase == .processing, initial: true) { _, processing in
            if processing { AccessibilityNotification.Announcement(Self.processingAnnouncement).post() }
        }
    }

    // MARK: - Chrome

    /// §2 chrome 2: C-040 `backAndLink` — back · "Enrollment" · none / Enroll / Done.
    private var header: some View {
        PageHeader(
            style: .backAndLink,
            title: Self.title,
            showTitle: true,
            leadingGlyph: .back,
            rightButtons: [],
            trailingLabel: trailingLabel,
            trailingEnabled: trailingEnabled,
            onLeading: back,
            onDone: phase == .enrolled ? onDone : onEnroll
        )
        .ui2Element("C-040 PageHeader")
    }

    /// §2: no action below 6/6 (`""` — the slot renders nothing), Enroll at 6/6, Done on `enrolled`.
    private var trailingLabel: String {
        switch phase {
        case .enrolled: return Self.doneLabel
        case .checklist, .processing: return allDone ? Self.enrollLabel : ""
        }
    }

    /// §2: Enroll is tappable in `ready` only — `false` (dimmed, OQ-C-040-001) in `processing`;
    /// the empty slot below 6/6 takes no tap.
    private var trailingEnabled: Bool {
        switch phase {
        case .enrolled: return true
        case .checklist: return allDone
        case .processing: return false
        }
    }

    // MARK: - Checklist states

    private var checklist: some View {
        // §2 checklist: vertical stack, gap 16 (`space-stack-gap`).
        VStack(spacing: Token.Space.stackGap) {
            // §2 checklist 1: C-125 in its 16pt-padded box.
            EnrollmentProgressHeader(
                groupName: groupDone ? state.groupName : nil,
                groupImageURL: groupDone ? URL(string: state.groupImageURL) : nil,
                groupInitials: groupDone && !state.groupInitials.isEmpty ? state.groupInitials : nil,
                completedSteps: completedSteps,
                totalSteps: Self.totalSteps
            )
            .ui2Element("C-125 EnrollmentProgressHeader")
            .padding(Self.progressHeaderInset)

            // §2 checklist 2: six C-124 rows, no gap — shared edges read as one hairline.
            VStack(spacing: 0) {
                ForEach(Array(Step.allCases.enumerated()), id: \.offset) { index, step in
                    let row = row(step)
                    ChecklistStepRow(
                        disc: row.disc,
                        title: row.title,
                        description: row.description,
                        status: isDone(step) ? .done : .todo,
                        disabled: isDisabled(step),
                        onTap: { onSelectStep(step) }
                    )
                    .ui2Element(index == 0 ? "C-124 ChecklistStepRow" : "C-124 ChecklistStepRow \(index + 1)")
                }
            }
            // §3 `processing`: "every row ignore[s] taps" — no visual change (C-124's dimmed
            // `disabled` look is for the Row prerequisite only).
            .allowsHitTesting(phase == .checklist)
        }
    }

    // MARK: - Completion state

    private var completion: some View {
        // §2 completion: result block, gap 32 (`space-section-gap`), Done button.
        VStack(spacing: Token.Space.sectionGap) {
            // §2 completion 1: padding 32 (`space-section-gap` value), centred, gap FL-3.
            VStack(spacing: Self.resultGap) {
                ConfirmationMark(tone: .success, animated: confirmationAnimated)
                    .frame(width: Self.markSize)
                    .ui2Element("C-109 ConfirmationMark")

                // §2: completion text — screen-owned, no registry row; gap 16 (`space-stack-gap`).
                VStack(spacing: Token.Space.stackGap) {
                    Text(Self.enrolledTitle)
                        .designTextStyle(Self.completionTitleStyle)
                        .foregroundStyle(Token.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: Self.completionTitleStyle.lineHeight)
                    completionBody
                }
            }
            .padding(Token.Space.sectionGap)
            .frame(maxWidth: .infinity)

            // §2 completion 3: C-048 "Done", `affirmative`, `md` (deviation 5).
            PageActionButton(label: Self.doneLabel, role: .affirmative, size: .md, onTap: onDone)
                .ui2Element("C-048 PageActionButton")
        }
    }

    /// §2: "«group name» was successfully enrolled in the «program name» study program" — names
    /// `color-text-primary`, the rest `color-text-secondary`, one Regular weight, centred and
    /// wrapping. FL-2's 28pt pitch is spent as the line box less SF Pro's natural line (the
    /// C-124 description construction), so n lines are exactly n × 28.
    private var completionBody: some View {
        let style = Self.completionBodyStyle
        let leading = Self.leading(style)
        let text = Text(state.groupName).foregroundStyle(Token.textPrimary)
            + Text(" was successfully enrolled in the ").foregroundStyle(Token.textSecondary)
            + Text(state.programName).foregroundStyle(Token.textPrimary)
            + Text(" study program").foregroundStyle(Token.textSecondary)
        return text
            .font(style.font)
            .tracking(style.tracking)
            .lineSpacing(leading)
            .padding(.vertical, leading / 2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
    }

    private static func leading(_ style: DesignTextStyle) -> CGFloat {
        let natural = UIFont.systemFont(ofSize: style.size, weight: .regular).lineHeight
        return max((style.lineHeight ?? style.size) - natural, 0)
    }

    // MARK: - §3 rules

    private var phase: Phase { Phase(rawValue: state.phase) ?? .checklist }

    private var groupDone: Bool { !state.groupName.isEmpty }

    private func isDone(_ step: Step) -> Bool {
        switch step {
        case .group: return groupDone
        case .studyProgram: return !state.programName.isEmpty
        case .schedule: return !state.scheduleStartDay.isEmpty
        case .inviteTime: return Self.inviteTime(state.smsTime) != nil
        case .sync: return state.syncMode == "AUTO" || state.syncMode == "OFF"
        case .accessibility: return state.lessonAccess == "all-at-once" || state.lessonAccess == "one-at-a-time"
        }
    }

    /// §3 Row prerequisite: "The **Schedule** row (row 3) is the only row with a prerequisite: it
    /// needs the **Study program** row done" — derived on read from the draft (R-30).
    private func isDisabled(_ step: Step) -> Bool {
        step == .schedule && !isDone(.studyProgram)
    }

    private var completedSteps: Int { Step.allCases.filter(isDone).count }

    private var allDone: Bool { completedSteps == Self.totalSteps }

    // §3: back on a checklist → caller (draft discarded); on `enrolled` → as Done; in
    // `processing` → ignored.
    private func back() {
        switch phase {
        case .checklist: onBack()
        case .processing: break
        case .enrolled: onDone()
        }
    }

    // MARK: - §3 Rows table

    private struct Row {
        let disc: TaskDisc.Look
        let title: String
        let description: String
    }

    private func row(_ step: Step) -> Row {
        let done = isDone(step)
        switch step {
        case .group:
            return done
                ? Row(disc: .photo(imageURL: URL(string: state.groupImageURL)),
                      title: state.groupName,
                      description: "Created on \(state.groupCreatedOn) with \(state.groupActiveMembers) active members")
                : Row(disc: .glyph(.groupCarbon),
                      title: "Choose a group",
                      description: "Select the group who will be enrolled in the study program")
        case .studyProgram:
            return done
                ? Row(disc: .photo(imageURL: URL(string: state.programImageURL)),
                      title: state.programName,
                      description: state.programDescription)
                : Row(disc: .glyph(.gridCarbon),
                      title: "Choose a study program",
                      description: "Select a study program from your library or community programs you have added")
        case .schedule:
            return done
                ? Row(disc: .date(weekday: String(state.scheduleStartWeekday.prefix(3)),
                                  month: String(state.scheduleStartMonth.prefix(3)),
                                  day: state.scheduleStartDay,
                                  today: state.scheduleStartToday),
                      title: "Starts on \(state.scheduleStartWeekday), \(state.scheduleStartMonth) \(state.scheduleStartDay)",
                      description: "\(Self.weekdayList(state.scheduleWeekdays)) every week until \(state.scheduleEndDate)")
                : Row(disc: .glyph(.calendarCarbon),
                      title: "Choose a schedule",
                      description: "Select the first day of the enrollment and the week days you want to use")
        case .inviteTime:
            let description = "Every member of the group will receive a link at this time on the enrollment dates"
            guard let time = Self.inviteTime(state.smsTime) else {
                return Row(disc: .glyph(.timeCarbon), title: "Set invite time", description: description)
            }
            // OQ-005: "Every enrollment day at «time»" while the schedule row is not done.
            let days = isDone(.schedule)
                ? state.scheduleWeekdays.map { String($0.prefix(3)) }.joined(separator: ", ")
                : "Every enrollment day"
            return Row(disc: .time(time: time.clock, period: time.period),
                       title: "\(days) at \(time.clock)\(time.period)",
                       description: description)
        case .sync:
            // Deviation 2: "Select sync settings" in every to-do state.
            guard done else {
                return Row(disc: .glyph(.renewCarbon),
                           title: "Select sync settings",
                           description: "Choose if the project will stay in sync with the study program as changes are made")
            }
            return state.syncMode == "AUTO"
                ? Row(disc: .syncOn,
                      title: "Stay in sync with program",
                      description: "Enrolled lesson will stay in sync with any changes made to the study program after enrollment")
                : Row(disc: .syncOff,
                      title: "Private",
                      description: "Enrolled lessons will not change when the study program is updated")
        case .accessibility:
            guard done else {
                return Row(disc: .glyph(.dataSetCarbon),
                           title: "Accessibility",
                           description: "Make the entire enrollment available to members all at once or one at a time")
            }
            return state.lessonAccess == "all-at-once"
                ? Row(disc: .all,
                      title: "All at once",
                      description: "Members can access every lesson in the enrollment at any time")
                : Row(disc: .one,
                      title: "One at a time",
                      description: "Each lesson becomes available to members on its scheduled date and time")
        }
    }

    /// 'HH:mm' → ("7:30", "am"); nil when unset or malformed.
    private static func inviteTime(_ smsTime: String) -> (clock: String, period: String)? {
        let parts = smsTime.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        let clockHour = hour % 12 == 0 ? 12 : hour % 12
        return ("\(clockHour):\(String(format: "%02d", minute))", hour < 12 ? "am" : "pm")
    }

    /// "Monday, Wednesday, and Friday" — the frames' serial-comma list.
    private static func weekdayList(_ days: [String]) -> String {
        switch days.count {
        case 0: return ""
        case 1: return days[0]
        case 2: return "\(days[0]) and \(days[1])"
        default: return days.dropLast().joined(separator: ", ") + ", and " + (days.last ?? "")
        }
    }
}

// MARK: - Sample data (the previews' props, single-sourced for the #Preview blocks and the
// capture case). "Young Professionals", "Romans in 30 days", July 24 and 7:30am are the frames'
// fixture data (§1 deviation 7); the photos are stand-in URLs (picsum seeds).

extension GroupsEnrollProgramScreen.State {
    private static let none = Self(
        phase: "checklist",
        groupName: "", groupInitials: "", groupImageURL: "", groupCreatedOn: "", groupActiveMembers: 0,
        programName: "", programDescription: "", programImageURL: "",
        scheduleStartWeekday: "", scheduleStartMonth: "", scheduleStartDay: "", scheduleStartToday: false,
        scheduleWeekdays: [], scheduleEndDate: "",
        smsTime: "", syncMode: "", lessonAccess: ""
    )

    /// §3 `empty` — 0/6, every row to do, no header action.
    static let empty = none

    /// §3 `group-preloaded` — the group row done (1/6).
    static let groupPreloaded: Self = {
        var s = none
        s.groupName = "Young Professionals"
        s.groupInitials = "YP"
        s.groupImageURL = "https://picsum.photos/seed/groups-enroll-program-group/256"
        s.groupCreatedOn = "January 3rd, 2025"
        s.groupActiveMembers = 13
        return s
    }()

    /// §3 `group-and-program` — group and program rows done (2/6).
    static let groupAndProgram: Self = {
        var s = groupPreloaded
        s.programName = "Romans in 30 days"
        s.programDescription = "A 30 day program that takes a deep dive into the book of Romans"
        s.programImageURL = "https://picsum.photos/seed/groups-enroll-program-program/256"
        return s
    }()

    /// §3 `schedule-done` — group, program and schedule rows done (3/6).
    static let scheduleDone: Self = {
        var s = groupAndProgram
        s.scheduleStartWeekday = "Monday"
        s.scheduleStartMonth = "July"
        s.scheduleStartDay = "24"
        s.scheduleStartToday = true
        s.scheduleWeekdays = ["Monday", "Wednesday", "Friday"]
        s.scheduleEndDate = "October 18th, 2026"
        return s
    }()

    /// §3 `ready` — 6/6; the header shows Enroll.
    static let ready: Self = {
        var s = scheduleDone
        s.smsTime = "07:30"
        s.syncMode = "AUTO"
        s.lessonAccess = "all-at-once"
        return s
    }()

    /// §3 `processing` — as `ready`, Enroll dimmed and every tap ignored.
    static let processing: Self = {
        var s = ready
        s.phase = "processing"
        return s
    }()

    /// §3 `enrolled` — the completion state.
    static let enrolled: Self = {
        var s = ready
        s.phase = "enrolled"
        return s
    }()
}

#Preview("empty") {
    GroupsEnrollProgramScreen(state: .empty, confirmationAnimated: false)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("group-preloaded") {
    GroupsEnrollProgramScreen(state: .groupPreloaded, confirmationAnimated: false)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("group-and-program") {
    GroupsEnrollProgramScreen(state: .groupAndProgram, confirmationAnimated: false)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("schedule-done") {
    GroupsEnrollProgramScreen(state: .scheduleDone, confirmationAnimated: false)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("ready") {
    GroupsEnrollProgramScreen(state: .ready, confirmationAnimated: false)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("processing") {
    GroupsEnrollProgramScreen(state: .processing, confirmationAnimated: false)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}

#Preview("enrolled") {
    GroupsEnrollProgramScreen(state: .enrolled, confirmationAnimated: false)
        .padding(.top, 59)
        .frame(width: 440, alignment: .top)
        .frame(minHeight: 956, alignment: .top)
}
