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

    // --- Normalize enrollments into a uniform list with a computed next lesson ---
    $studies = [];
    $normalizeNext = function ($lessons) {
        $today = date('Y-m-d');
        $next = null;
        foreach (($lessons ?? []) as $lesson) {
            if (!empty($lesson['completedAt'])) continue;
            $scheduled = substr($lesson['scheduledDate'] ?? '', 0, 10);
            if ($scheduled === '' || $scheduled <= $today) { $next = $lesson; break; }
        }
        // Fall back to the first lesson if none are due yet
        if (!$next && !empty($lessons)) { $next = $lessons[0]; }
        return $next;
    };

    if (is_array($enrollments)) {
        foreach ($enrollments as $e) {
            $next = $e['nextLesson'] ?? $normalizeNext($e['lessons'] ?? []);
            $studies[] = [
                'id'          => $e['id'] ?? null,
                'title'       => $e['studyTitle'] ?? $e['study']['title'] ?? '',
                'description' => $e['studyDescription'] ?? $e['study']['description'] ?? null,
                'cover'       => $e['coverImageUrl'] ?? $e['study']['coverImageUrl'] ?? null,
                'next'        => $next,
            ];
        }
    } elseif ($enrollmentData) {
        $next = $enrollmentData['nextLesson'] ?? $normalizeNext($enrollmentData['lessons'] ?? []);
        $studies[] = [
            'id'          => $enrollmentData['id'] ?? null,
            'title'       => $enrollmentData['studyTitle'] ?? $enrollmentData['study']['title'] ?? '',
            'description' => $enrollmentData['studyDescription'] ?? $enrollmentData['study']['description'] ?? null,
            'cover'       => $enrollmentData['coverImageUrl'] ?? $enrollmentData['study']['coverImageUrl'] ?? null,
            'next'        => $next,
        ];
    }

    // Hero image: group cover, else first study cover
    $heroImage = $coverImage ?? ($studies[0]['cover'] ?? null);

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
                    <div class="GroupHome__upnext">
                        @foreach($studies as $study)
                            @php
                                $studyHref = (!empty($study['id']))
                                    ? route('study.home', ['groupId' => $groupId, 'studyEnrollmentId' => $study['id']])
                                    : null;
                                $lessonHref = (!empty($study['next']['id']))
                                    ? route('lesson.show', ['groupId' => $groupId, 'lessonScheduleId' => $study['next']['id'], 'step' => 1])
                                    : null;
                            @endphp
                            <x-domain.enrolled-study-card
                                :studyTitle="$study['title']"
                                :studyDescription="$study['description']"
                                :coverImageUrl="$study['cover']"
                                :nextLesson="$study['next']"
                                :href="$studyHref"
                                :lessonHref="$lessonHref"
                            />
                        @endforeach
                    </div>
                @endif
            </div>

            </div>{{-- /.GroupHome__body --}}

        </div>{{-- /.GroupHome__scroll-container --}}
    </div>{{-- /.GroupHome__viewport --}}
</div>{{-- /.GroupHome --}}
@endsection
