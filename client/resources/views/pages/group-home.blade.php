{{-- resources/views/pages/group-home.blade.php --}}
{{-- Member group home — hero, group pager, leader, group panel, Up next studies, posts --}}
{{-- Figma: Make-Ready-Mobile "Study home page" (node 3104:29472) --}}
@extends('layouts.home')

@section('title', ($groupData['name'] ?? 'Group') . ' — MakeReady')

@php
    // --- Inputs (tolerant of both the live controller and capture fixtures) ---
    $member        = $member        ?? [];
    $groupData     = $groupData     ?? [];
    $postsData     = $postsData     ?? [];
    $memberGroups  = $memberGroups  ?? [];
    $enrollments   = $enrollments   ?? null;   // new: array of enrolled studies
    $enrollmentData = $enrollmentData ?? null; // legacy: single enrollment

    $groupName   = $groupData['name'] ?? '';
    $coverImage  = $groupData['coverImageUrl'] ?? $groupData['avatarUrl'] ?? null;
    $memberCount = $groupData['memberCount'] ?? 0;
    $isPrivate   = $groupData['isPrivate'] ?? false;
    $orgName     = $groupData['organizationName'] ?? $groupData['orgName'] ?? null;
    $creator     = $groupData['creator'] ?? null;
    $leaderSince = $groupData['createdAt'] ?? $groupData['leaderSince'] ?? null;

    $leaderName    = $creator['name'] ?? null;
    $leaderPicture = $creator['picture'] ?? $creator['avatarUrl'] ?? null;
    $leaderSinceLabel = null;
    if ($leaderSince) {
        try { $leaderSinceLabel = (new DateTime($leaderSince))->format('F j, Y'); }
        catch (\Exception $e) { $leaderSinceLabel = null; }
    }

    // --- Normalize enrollments for the MemberStudiesIsland (study meta + full
    // lessons with hrefs). The island computes the next lesson, its state, and
    // the status badge using the same lesson-state logic as the study-home page,
    // so there's no duplicated next-lesson logic here. ---
    $studies = [];
    $mapStudy = function ($e) use ($groupId) {
        // Live API returns lessons[]; fixtures provide a single nextLesson.
        $rawLessons = $e['lessons'] ?? (!empty($e['nextLesson']) ? [$e['nextLesson']] : []);
        $lessons = [];
        foreach ($rawLessons as $l) {
            if (empty($l['id'])) continue;
            $lessons[] = [
                'id'               => $l['id'],
                'dayNumber'        => $l['dayNumber'] ?? null,
                'title'            => $l['title'] ?? '',
                'scheduledDate'    => $l['scheduledDate'] ?? null,
                'completedAt'      => $l['completedAt'] ?? null,
                'estimatedMinutes' => $l['estimatedMinutes'] ?? null,
                'href'             => route('lesson.show', ['groupId' => $groupId, 'lessonScheduleId' => $l['id'], 'step' => 1]),
            ];
        }
        return [
            'id'            => $e['id'] ?? null,
            'title'         => $e['studyTitle'] ?? $e['study']['title'] ?? '',
            'description'   => $e['studyDescription'] ?? $e['study']['description'] ?? null,
            'coverImageUrl' => $e['coverImageUrl'] ?? $e['study']['coverImageUrl'] ?? null,
            'studyHref'     => !empty($e['id']) ? route('study.home', ['groupId' => $groupId, 'studyEnrollmentId' => $e['id']]) : null,
            'lessons'       => $lessons,
        ];
    };

    if (is_array($enrollments)) {
        foreach ($enrollments as $e) { $studies[] = $mapStudy($e); }
    } elseif ($enrollmentData) {
        $studies[] = $mapStudy($enrollmentData);
    }

    // Hero image: group cover, else first study cover
    $heroImage = $coverImage ?? ($studies[0]['coverImageUrl'] ?? null);

    // --- Group switcher (header opens a modal of every group the member is in) ---
    $switcherGroups = [];
    foreach ($memberGroups as $g) {
        $gid = $g['id'] ?? null;
        if (!$gid) continue;
        $switcherGroups[] = [
            'id'            => $gid,
            'name'          => $g['name'] ?? 'Group',
            'memberCount'   => $g['memberCount'] ?? 0,
            'isPrivate'     => (bool) ($g['isPrivate'] ?? false),
            'coverImageUrl' => $g['coverImageUrl'] ?? $g['avatarUrl'] ?? null,
            'href'          => route('group.home', ['groupId' => $gid]),
            'isCurrent'     => $gid === $groupId,
        ];
    }

    $switcherProps = [
        'current' => [
            'name'        => $groupName,
            'orgName'     => $orgName,
            'memberCount' => $memberCount,
            'isPrivate'   => (bool) $isPrivate,
        ],
        'groups' => $switcherGroups,
    ];
@endphp

@section('content')
<div class="GroupHome">
    <div class="GroupHome__viewport">
        <div class="GroupHome__scroll-container">

            {{-- Hero: cover image fading into the page, with pager + leader on top --}}
            <div class="GroupHome__header">
                @if($heroImage)
                    <img src="{{ $heroImage }}" alt="" class="GroupHome__hero-image" />
                @endif
                <div class="GroupHome__hero-overlay"></div>

                <div class="GroupHome__header-content">
                    {{-- Leader --}}
                    @if($leaderName)
                        <div class="GroupHome__leader">
                            <x-primitive.avatar
                                :src="$leaderPicture"
                                :name="$leaderName"
                                :alt="$leaderName"
                                :size="80"
                                class="GroupHome__leader-avatar"
                            />
                            <div class="GroupHome__leader-info">
                                <p class="GroupHome__leader-name">{{ $leaderName }}</p>
                                <p class="GroupHome__leader-meta">
                                    @if($orgName)<span class="GroupHome__leader-org">{{ $orgName }}</span> @endif
                                    <span class="GroupHome__leader-muted">group leader{{ $leaderSinceLabel ? ' since' : '' }}</span>
                                    @if($leaderSinceLabel)<span class="GroupHome__leader-date"> {{ $leaderSinceLabel }}</span>@endif
                                </p>
                            </div>
                        </div>
                    @endif
                </div>
            </div>

            <div class="GroupHome__body">
            {{-- Group panel --}}
            <div class="GroupHome__panel">
                <div class="GroupSwitcher" data-vue="GroupSwitcherIsland" data-props="{{ json_encode($switcherProps, JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP) }}">
                    {{-- Server-rendered fallback (matches the island's current-group header)
                         so the panel isn't blank before the Vue island mounts. --}}
                    <div class="GroupSwitcher__current GroupSwitcher__current--static">
                        <div class="GroupSwitcher__title">
                            <span class="GroupSwitcher__name">{{ $groupName }}</span>
                        </div>
                        @if($orgName)
                            <p class="GroupSwitcher__org">{{ $orgName }}</p>
                        @endif
                        <div class="GroupSwitcher__meta">
                            <span class="GroupSwitcher__privacy">
                                <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
                                    <rect x="4.5" y="9" width="11" height="7.5" rx="1.5" stroke="currentColor" stroke-width="1.5"/>
                                    @if($isPrivate)
                                        <path d="M6.75 9V6.5C6.75 4.70507 8.20507 3.25 10 3.25C11.7949 3.25 13.25 4.70507 13.25 6.5V9" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
                                    @else
                                        <path d="M6.75 9V6.5C6.75 4.70507 8.20507 3.25 10 3.25C11.4476 3.25 12.674 4.19668 13.0944 5.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
                                    @endif
                                </svg>
                                {{ $isPrivate ? 'Private group' : 'Public group' }}
                            </span>
                            <span class="GroupSwitcher__count">
                                {{ $memberCount }} {{ \Illuminate\Support\Str::plural('member', $memberCount) }}
                            </span>
                        </div>
                    </div>
                </div>

                @if(count($studies) > 0)
                    <p class="GroupHome__upnext-label">Your studies</p>
                    <div class="GroupHome__upnext" data-vue="MemberStudiesIsland" data-props="{{ json_encode(['studies' => $studies], JSON_HEX_TAG | JSON_HEX_APOS | JSON_HEX_QUOT | JSON_HEX_AMP) }}"></div>
                @endif
            </div>

            </div>{{-- /.GroupHome__body --}}

        </div>{{-- /.GroupHome__scroll-container --}}
    </div>{{-- /.GroupHome__viewport --}}
</div>{{-- /.GroupHome --}}
@endsection
