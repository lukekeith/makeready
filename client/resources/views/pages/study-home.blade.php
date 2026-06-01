{{-- resources/views/pages/study-home.blade.php --}}
{{-- Study home page — redesigned interactive island (StudyHomeIsland) --}}
@extends('layouts.home')

@section('title', ($studyData['studyTitle'] ?? $studyData['study']['title'] ?? $studyData['title'] ?? 'Study') . ' — MakeReady')

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

    // Formatted enrollment fields (see GET /api/groups/{groupId}/study-enrollment/{enrollmentId})
    $study      = $studyData['study'] ?? $studyData;
    $studyTitle = $studyData['studyTitle'] ?? $study['title'] ?? 'Study';
    $studyCover = $studyData['coverImageUrl'] ?? $study['coverImageUrl'] ?? null;
    $lessons    = $studyData['lessons'] ?? [];
    $firstDate  = $studyData['firstDate'] ?? null;
    $lastDate   = $studyData['lastDate'] ?? null;
    $activeDays = $studyData['activeDays'] ?? [];

    // Build the lessons payload for the island, attaching the lesson-player href per lesson.
    $islandLessons = array_map(function ($lesson) use ($groupId) {
        $scheduleId = $lesson['id'] ?? null;
        return [
            'id'               => $scheduleId,
            'dayNumber'        => $lesson['dayNumber'] ?? null,
            'title'            => $lesson['title'] ?? '',
            'scheduledDate'    => $lesson['scheduledDate'] ?? null,
            'estimatedMinutes' => $lesson['estimatedMinutes'] ?? null,
            'activities'       => $lesson['activities'] ?? [],
            'href'             => $scheduleId
                ? route('lesson.show', ['groupId' => $groupId, 'lessonScheduleId' => $scheduleId, 'step' => 1])
                : null,
        ];
    }, $lessons);

    $islandProps = [
        'title'         => $studyTitle,
        'coverImageUrl' => $studyCover,
        'backHref'      => route('group.home', ['groupId' => $groupId]),
        'isPreview'     => false,
        'lessons'       => $islandLessons,
        'firstDate'     => $firstDate,
        'lastDate'      => $lastDate,
        'activeDays'    => $activeDays,
    ];
@endphp

@section('content')
<div class="StudyHome">
    <div class="StudyHome__viewport">

        <div data-vue="StudyHomeIsland" data-props="{{ json_encode($islandProps, JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP) }}"></div>

        {{-- Fixed Navigation --}}
        <div class="StudyHome__navigation" data-vue="NavigationIsland" data-props="{{ json_encode([
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

    </div>{{-- /.StudyHome__viewport --}}
</div>{{-- /.StudyHome --}}
@endsection
