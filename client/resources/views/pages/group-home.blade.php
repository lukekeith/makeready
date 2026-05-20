{{-- resources/views/pages/group-home.blade.php --}}
{{-- Group home page — group hero, current study, posts feed --}}
@extends('layouts.home')

@section('title', ($groupData['name'] ?? 'Group') . ' — MakeReady')

@php
    $initials = '';
    if (!empty($member['firstName'])) {
        $initials .= strtoupper(substr($member['firstName'], 0, 1));
    }
    if (!empty($member['lastName'])) {
        $initials .= strtoupper(substr($member['lastName'], 0, 1));
    }
    if ($initials === '') {
        $initials = '?';
    }

    $groupName       = $groupData['name'] ?? '';
    $coverImageUrl   = $groupData['coverImageUrl'] ?? $groupData['avatarUrl'] ?? null;
    $memberCount     = $groupData['memberCount'] ?? 0;
    $isPrivate       = $groupData['isPrivate'] ?? false;
    $memberSince     = $groupData['memberSince'] ?? null;

    // Enrollment / study progress — API returns fields at enrollment root level
    $studyTitle       = $enrollmentData['studyTitle'] ?? $enrollmentData['study']['title'] ?? null;
    $studyDescription = $enrollmentData['studyDescription'] ?? $enrollmentData['study']['description'] ?? null;
    $studyCover       = $enrollmentData['coverImageUrl'] ?? $enrollmentData['study']['coverImageUrl'] ?? null;
    $totalLessons     = $enrollmentData['totalLessons'] ?? 0;
    $completedLessons = $enrollmentData['completedLessons'] ?? 0;
    $studyProgress    = $totalLessons > 0 ? round(($completedLessons / $totalLessons) * 100) : 0;
    $enrollmentId     = $enrollmentData['id'] ?? null;

    // Find next lesson: first incomplete lesson scheduled for today or earlier
    $nextLesson = null;
    $lessons = $enrollmentData['lessons'] ?? [];
    $today = date('Y-m-d');
    foreach ($lessons as $lesson) {
        if (!empty($lesson['completedAt'])) continue;
        $scheduled = substr($lesson['scheduledDate'] ?? '', 0, 10);
        if ($scheduled <= $today) {
            $nextLesson = $lesson;
            break;
        }
    }
@endphp

@section('content')
<div class="GroupHome">
    <div class="GroupHome__viewport">

        {{-- Group Content --}}
        {{-- Scrollable Content Area --}}
        <div class="GroupHome__scroll-container">

            {{-- Group Header Card --}}
            <x-domain.group-card
                mode="Header"
                :name="$groupName"
                :coverImageUrl="$coverImageUrl"
                :memberCount="$memberCount"
                :isPrivate="$isPrivate"
                :memberSince="$memberSince"
                :backHref="route('home')"
            />

            {{-- Study Enrollment Section — matches React: progress card + next lesson card --}}
            @if($enrollmentData && $studyTitle)
                <div class="GroupHome__studies CardParent">
                    {{-- Progress Card (clickable → study home) --}}
                    <a href="{{ $enrollmentId ? route('study.home', ['groupId' => $groupId, 'studyEnrollmentId' => $enrollmentId]) : '#' }}">
                        <x-domain.study-card
                            mode="Progress"
                            :title="$studyTitle"
                            :description="$studyDescription"
                            :dayNumber="$totalLessons"
                            dateLabel="day"
                            :progress="$studyProgress"
                            cardDepth="child"
                        />
                    </a>

                    {{-- Next Lesson Card --}}
                    @if($nextLesson)
                        <a href="{{ route('lesson.show', ['groupId' => $groupId, 'lessonScheduleId' => $nextLesson['id'], 'step' => 1]) }}">
                            <x-domain.study-card
                                mode="LessonList"
                                :title="$nextLesson['title'] ?? ''"
                                :dayNumber="$nextLesson['dayNumber'] ?? null"
                                status="next"
                                cardDepth="child"
                            />
                        </a>
                    @endif
                </div>
            @endif

            {{-- Posts Feed — no h2 heading, matches React structure --}}
            <div class="GroupHome__posts">
                @if(count($postsData) > 0)
                    @foreach($postsData as $post)
                        <x-domain.group-post-card
                            :type="$post['type'] ?? 'ANNOUNCEMENT'"
                            :title="$post['title'] ?? null"
                            :content="$post['content'] ?? ''"
                            :imageUrl="$post['imageUrl'] ?? null"
                            :authorName="$post['authorName'] ?? ''"
                            :authorAvatarUrl="$post['authorAvatarUrl'] ?? null"
                            :createdAt="$post['createdAt'] ?? ''"
                            :pollOptions="$post['pollOptions'] ?? []"
                            :videoUrl="$post['videoUrl'] ?? null"
                            :eventDate="$post['eventDate'] ?? null"
                            :eventLocation="$post['eventLocation'] ?? null"
                            :programName="$post['programName'] ?? null"
                            :programImageUrl="$post['programImageUrl'] ?? null"
                        />
                    @endforeach
                @else
                    <div class="GroupHome__empty-state">
                        <p class="GroupHome__empty-title">No posts yet</p>
                        <p class="GroupHome__empty-description">
                            Posts from your group leader will appear here.
                        </p>
                    </div>
                @endif
            </div>

            {{-- End of feed --}}
            @if(count($postsData) > 0)
                <div class="GroupHome__end-of-feed">You&rsquo;re all caught up!</div>
            @endif

            {{-- Bottom spacer for navigation clearance --}}
            <div class="GroupHome__bottom-spacer"></div>

        </div>{{-- /.GroupHome__scroll-container --}}

        {{-- Fixed Navigation --}}
        <div class="GroupHome__navigation" data-vue="NavigationIsland" data-props="{{ json_encode([
            'selected'         => 'home',
            'avatarUrl'        => $member['profilePicture'] ?? $member['avatarUrl'] ?? null,
            'initials'         => $initials ?? '?',
            'homeHref'         => route('home'),
            'profileHref'      => route('profile'),
            'memberName'       => ($member['firstName'] ?? '') . ' ' . ($member['lastName'] ?? ''),
            'memberPhone'      => format_phone($member['phoneNumber'] ?? $member['phone'] ?? null),
            'memberFirstName'  => $member['firstName'] ?? '',
            'memberLastName'   => $member['lastName'] ?? '',
            'memberGender'     => $member['gender'] ?? '',
            'memberBirthday'   => $member['birthday'] ?? '',
            'memberId'         => $member['id'] ?? '',
            'googleEmail'      => $member['googleEmail'] ?? null,
            'googlePicture'    => $member['googlePicture'] ?? $member['profilePicture'] ?? null,
            'logoutUrl'        => route('logout'),
            'csrfToken'        => csrf_token(),
        ], JSON_HEX_TAG) }}"></div>

    </div>{{-- /.GroupHome__viewport --}}
</div>{{-- /.GroupHome --}}
@endsection
