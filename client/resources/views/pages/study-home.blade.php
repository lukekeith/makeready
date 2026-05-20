{{-- resources/views/pages/study-home.blade.php --}}
{{-- Study home page — shows study info and lesson list --}}
@extends('layouts.home')

@section('title', ($studyData['study']['title'] ?? $studyData['title'] ?? 'Study') . ' — MakeReady')

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

    // Study data may be nested under 'study' key or at top level depending on API response
    $study       = $studyData['study'] ?? $studyData;
    $studyTitle  = $study['title'] ?? 'Study';
    $studyDesc   = $study['description'] ?? null;
    $studyCover  = $study['coverImageUrl'] ?? null;
    $lessons     = $studyData['lessons'] ?? $study['lessons'] ?? [];
    $dayNumber   = $studyData['dayNumber'] ?? null;
    $progress    = $studyData['progress'] ?? null;

    // Schedule data for StudyScheduleCard
    $schedule    = $studyData['schedule'] ?? null;
    $firstDate   = $schedule['firstDate'] ?? null;
    $lastDate    = $schedule['lastDate'] ?? null;
    $activeDays  = $schedule['activeDays'] ?? [];
@endphp

@section('content')
{{-- Root class: StudyHome (React uses StudyHome, not StudyHomePage) --}}
<div class="StudyHome">
    <div class="StudyHome__viewport">

        {{-- Study Content --}}
        {{-- Scrollable content area --}}
        <div class="StudyHome__scroll-container">

            {{-- Study Header Section --}}
            <div class="StudyHome__header">

                {{-- Header Card — React renders StudyCard mode="Header" with back button --}}
                <x-domain.study-card
                    mode="Header"
                    :title="$studyTitle"
                    :description="$studyDesc"
                    :coverImageUrl="$studyCover"
                    :backHref="route('group.home', ['groupId' => $groupId])"
                />

                {{-- Schedule Card — React conditionally renders when firstDate and lastDate exist --}}
                @if($firstDate && $lastDate)
                    <x-domain.study-schedule-card
                        :firstDate="$firstDate"
                        :lastDate="$lastDate"
                        :activeDays="$activeDays"
                    />
                @endif

                {{-- Lessons List — no <h2> heading, React renders as plain list --}}
                <div class="StudyHome__lessons">
                    @if(count($lessons) > 0)
                        @foreach($lessons as $lesson)
                            @php
                                $lessonTitle      = $lesson['title'] ?? '';
                                $lessonDayNumber  = $lesson['dayNumber'] ?? null;
                                $lessonStatus     = $lesson['status'] ?? null;
                                $lessonScheduleId = $lesson['lessonScheduleId'] ?? $lesson['id'] ?? null;
                                $lessonHref       = $lessonScheduleId
                                    ? route('lesson.show', ['groupId' => $groupId, 'lessonScheduleId' => $lessonScheduleId, 'step' => 1])
                                    : null;
                            @endphp

                            @if($lessonHref)
                                <a href="{{ $lessonHref }}" class="StudyHome__lesson-link">
                            @endif

                            <x-domain.study-card
                                mode="LessonList"
                                :title="$lessonTitle"
                                :dayNumber="$lessonDayNumber"
                                :status="$lessonStatus"
                            />

                            @if($lessonHref)
                                </a>
                            @endif
                        @endforeach
                    @else
                        <x-primitive.empty-state
                            title="No lessons yet"
                            description="Lessons will appear here once the study schedule is set up."
                        />
                    @endif
                </div>

            </div>{{-- /.StudyHome__header --}}

            {{-- Bottom spacer for navigation clearance --}}
            <div class="StudyHome__bottom-spacer"></div>

        </div>{{-- /.StudyHome__scroll-container --}}

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
