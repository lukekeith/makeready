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

    // --- Group pager (only meaningful with >1 group) ---
    $groupCount = count($memberGroups);
    $currentIndex = 0;
    foreach ($memberGroups as $i => $g) {
        if (($g['id'] ?? null) === $groupId) { $currentIndex = $i; break; }
    }
    $prevGroup = $groupCount > 1 ? $memberGroups[($currentIndex - 1 + $groupCount) % $groupCount] : null;
    $nextGroup = $groupCount > 1 ? $memberGroups[($currentIndex + 1) % $groupCount] : null;
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
                    {{-- Group pager --}}
                    @if($groupCount > 1)
                        <div class="GroupHome__pager">
                            <a class="GroupHome__pager-btn"
                               href="{{ route('group.home', ['groupId' => $prevGroup['id']]) }}"
                               aria-label="Previous group">
                                <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
                                    <path d="M12.5 15L7.5 10L12.5 5" stroke="white" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"/>
                                </svg>
                            </a>
                            <div class="GroupHome__pager-label">
                                <span class="GroupHome__pager-count">
                                    <span>{{ $currentIndex + 1 }}</span>
                                    <span class="GroupHome__pager-sep">/</span>
                                    <span>{{ $groupCount }}</span>
                                </span>
                                <span class="GroupHome__pager-word">GROUPS</span>
                            </div>
                            <a class="GroupHome__pager-btn"
                               href="{{ route('group.home', ['groupId' => $nextGroup['id']]) }}"
                               aria-label="Next group">
                                <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
                                    <path d="M7.5 5L12.5 10L7.5 15" stroke="white" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"/>
                                </svg>
                            </a>
                        </div>
                    @endif

                    {{-- Leader --}}
                    @if($leaderName)
                        <div class="GroupHome__leader">
                            <div class="GroupHome__leader-avatar">
                                @if($leaderPicture)
                                    <img src="{{ $leaderPicture }}" alt="{{ $leaderName }}" />
                                @else
                                    <span>{{ strtoupper(substr($leaderName, 0, 1)) }}</span>
                                @endif
                            </div>
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
                <div class="GroupHome__panel-header">
                    <h1 class="GroupHome__group-name">{{ $groupName }}</h1>
                    @if($orgName)
                        <p class="GroupHome__group-org">{{ $orgName }}</p>
                    @endif
                    <div class="GroupHome__group-meta">
                        <span class="GroupHome__group-privacy">
                            <svg width="16" height="16" viewBox="0 0 20 20" fill="none">
                                @if($isPrivate)
                                    <rect x="4.5" y="9" width="11" height="7.5" rx="1.5" stroke="currentColor" stroke-width="1.5"/>
                                    <path d="M6.75 9V6.5C6.75 4.70507 8.20507 3.25 10 3.25C11.7949 3.25 13.25 4.70507 13.25 6.5V9" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
                                @else
                                    <rect x="4.5" y="9" width="11" height="7.5" rx="1.5" stroke="currentColor" stroke-width="1.5"/>
                                    <path d="M6.75 9V6.5C6.75 4.70507 8.20507 3.25 10 3.25C11.4476 3.25 12.674 4.19668 13.0944 5.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
                                @endif
                            </svg>
                            {{ $isPrivate ? 'Private group' : 'Public group' }}
                        </span>
                        <span class="GroupHome__group-count">
                            <strong>{{ $memberCount }}</strong> {{ \Illuminate\Support\Str::plural('member', $memberCount) }}
                        </span>
                    </div>
                </div>

                @if(count($studies) > 0)
                    <div class="GroupHome__divider"></div>
                    <p class="GroupHome__upnext-label">Your studies</p>
                    <div class="GroupHome__upnext">
                        @foreach($studies as $study)
                            @php
                                $studyHref = (!empty($study['id']))
                                    ? route('study.home', ['groupId' => $groupId, 'studyEnrollmentId' => $study['id']])
                                    : null;
                            @endphp
                            <x-domain.enrolled-study-card
                                :studyTitle="$study['title']"
                                :studyDescription="$study['description']"
                                :coverImageUrl="$study['cover']"
                                :nextLesson="$study['next']"
                                :href="$studyHref"
                            />
                        @endforeach
                    </div>
                @endif
            </div>

            {{-- Posts feed --}}
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
                @endif
            </div>

            @if(count($postsData) > 0)
                <div class="GroupHome__end-of-feed">You&rsquo;re all caught up!</div>
            @endif
            </div>{{-- /.GroupHome__body --}}

        </div>{{-- /.GroupHome__scroll-container --}}
    </div>{{-- /.GroupHome__viewport --}}
</div>{{-- /.GroupHome --}}
@endsection
