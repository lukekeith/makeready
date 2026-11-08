import Foundation

/// ui2-programs D5/D6 + study-program-home §2/§3: the program page from `AppState`. Pure.
enum StudyProgramHomeMapper {
    struct Input {
        /// The list-known title, shown while the program loads.
        var name: String
        var program: StudyProgram?
        /// Ordered by `position` (`AppState.lessonsFor(programId:)`).
        var lessons: [Lesson]
        /// As the endpoint returns them (D16).
        var enrollments: [ProgramEnrollment]
        /// D5: the program load failed this visit.
        var failed: Bool
        /// D7: the selected DayChip.
        var activeDay: Int
        /// The media the lessons' documents name (`AppState.mediaMap`), for the rail thumbnails.
        var media: [String: MediaMapEntry] = [:]
    }

    static func state(_ input: Input, timeZone: TimeZone) -> StudyProgramHomeScreen.State {
        let p = input.program
        let lessons = input.lessons.sorted { $0.position < $1.position }
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
            lessonNumbers: lessons.map(\.position),
            lessonTitles: lessons.map { $0.title ?? "" },
            lessonDurations: lessons.map { lessonDuration(minutes(fromSeconds: $0.estimatedSeconds)) },
            lessonSlideImages: lessons.map { lesson in
                lesson.activities.sorted { $0.position < $1.position }.map { slideImage($0, media: input.media) }
            },
            lessonSlideLabels: lessons.map { $0.activities.sorted { $0.position < $1.position }.map(\.title) },
            // D5: skeletons only with nothing cached; a failure over a cache keeps the page.
            loading: p == nil && !input.failed,
            failed: p == nil && input.failed
        )
    }

    /// The lesson's estimate in whole minutes, rounded up (`ceil(seconds / 60)`); nil without one.
    static func minutes(fromSeconds seconds: Int?) -> Int? {
        guard let seconds, seconds > 0 else { return nil }
        return (seconds + 59) / 60
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

    /// A slide's thumbnail URL: a canvas kind's rendered page (D26, the `ActivityThumbnail` key), else a video's
    /// poster, else a YouTube clip's thumbnail; "" = the themed placeholder.
    static func slideImage(_ activity: ActivitySummary, media: [String: MediaMapEntry]) -> String {
        let rendered = ActivityThumbnail.key(for: activity)
        if !rendered.isEmpty { return rendered }
        switch activity.document.renderable {
        case .video(let video):
            return video.posterMediaId.flatMap { media[$0]?.posterUrl ?? media[$0]?.url } ?? ""
        case .youtube(let clip):
            return "https://img.youtube.com/vi/\(clip.youtubeVideoId)/hqdefault.jpg"
        default:
            return ""
        }
    }
}
