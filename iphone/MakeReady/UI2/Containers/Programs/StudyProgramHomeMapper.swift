import Foundation

/// ui2-programs D5/D6 + study-program-home §2/§3: the program page from `AppState`. Pure.
enum StudyProgramHomeMapper {
    struct Input {
        /// The list-known title, shown while the program loads.
        var name: String
        var program: StudyProgram?
        /// Ordered by `dayNumber` (`AppState.lessonsFor(programId:)`).
        var lessons: [Lesson]
        /// As the endpoint returns them (D16).
        var enrollments: [ProgramEnrollment]
        /// D5: the program load failed this visit.
        var failed: Bool
        /// D7: the selected DayChip.
        var activeDay: Int
    }

    static func state(_ input: Input, timeZone: TimeZone) -> StudyProgramHomeScreen.State {
        let p = input.program
        let lessons = input.lessons.sorted { $0.dayNumber < $1.dayNumber }
        return StudyProgramHomeScreen.State(
            coverURL: p?.coverImageUrl ?? "",
            createdLabel: p.map { MembersHomeMapper.mediumDate($0.createdAt, timeZone: timeZone) } ?? "",
            authorName: p?.creatorName ?? "",
            leaderName: p.map { $0.leaderName ?? $0.creatorName ?? "" } ?? "",
            lessonCount: lessons.count,
            programName: p?.name ?? input.name,
            programDescription: p?.description ?? "",
            visibility: p.map { GroupDetailMapper.visibilityLabel($0.isPrivate ?? false) } ?? "",
            ageRange: p.map { GroupDetailMapper.ageLabel(ageRange($0)) } ?? "",
            maximumMembers: p.map { GroupDetailMapper.maxMembersLabel($0.maxMembers) } ?? "",
            memberDirectoryAccess: p.map {
                GroupDetailMapper.directoryAccessLabel($0.memberDirectoryAccess, memberDirectory: true)
            } ?? "",
            enrollmentNames: input.enrollments.map { $0.group?.name ?? "" },
            enrollmentPhotoURLs: input.enrollments.map { $0.group?.coverImageUrl ?? "" },
            enrollmentLeaders: input.enrollments.map { MemberProfileMapper.leaderShortName($0.group?.creator?.name) },
            enrollmentMemberCounts: input.enrollments.map { $0.group?._count?.members ?? 0 },
            dayCount: lessons.count,
            activeDay: min(max(input.activeDay, 1), max(lessons.count, 1)),
            lessonNumbers: lessons.map(\.dayNumber),
            lessonTitles: lessons.map { $0.title ?? "" },
            lessonDurations: lessons.map { lessonDuration($0.estimatedMinutes) },
            lessonSlideImages: lessons.map { $0.activities.sorted { $0.orderNumber < $1.orderNumber }.map(slideImage) },
            lessonSlideLabels: lessons.map { $0.activities.sorted { $0.orderNumber < $1.orderNumber }.map { $0.title ?? "" } },
            // D5: skeletons only with nothing cached; a failure over a cache keeps the page.
            loading: p == nil && !input.failed,
            failed: p == nil && input.failed
        )
    }

    /// D11: the row's meta — "N mins", "1 min" singular, "0 mins" for 0 or no estimate.
    static func lessonDuration(_ minutes: Int?) -> String {
        let n = minutes ?? 0
        return n == 1 ? "1 min" : "\(n) mins"
    }

    /// D6: the program's two flat bounds as Group's AgeRange (nil when neither is set).
    static func ageRange(_ program: StudyProgram) -> AgeRange? {
        guard program.ageRangeMin != nil || program.ageRangeMax != nil else { return nil }
        return AgeRange(min: program.ageRangeMin, max: program.ageRangeMax)
    }

    /// D6/OQ-8: a slide's image — the YouTube thumbnail, else the video's; "" = the themed placeholder.
    static func slideImage(_ activity: StudyActivity) -> String {
        activity.youtubeThumbnailUrl ?? activity.video?.thumbnailUrl ?? ""
    }
}
