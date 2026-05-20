@props([
    'type'           => 'ANNOUNCEMENT',
    'title'          => null,
    'content'        => '',
    'imageUrl'       => null,
    'authorName'     => '',
    'authorAvatarUrl' => null,
    'createdAt'      => '',
    'viewCount'      => 0,
    'shareCount'     => 0,
    'pollOptions'    => [],
    'videoUrl'       => null,
    'eventDate'      => null,
    'eventLocation'  => null,
    'eventTitle'     => null,
    'attendeeCount'  => 0,
])

@php
    $typeVariantMap = [
        'WELCOME'      => 'Welcome',
        'POLL'         => 'Poll',
        'VIDEO'        => 'Video',
        'EVENT'        => 'Event',
        'ANNOUNCEMENT' => 'Announcement',
    ];

    $classes = cva('GroupPostCard', [
        'variants' => [
            'type' => [
                'Welcome'      => 'GroupPostCard--welcome',
                'Poll'         => 'GroupPostCard--poll',
                'Video'        => 'GroupPostCard--video',
                'Event'        => 'GroupPostCard--event',
                'Announcement' => 'GroupPostCard--announcement',
            ],
        ],
        'defaultVariants' => ['type' => 'Announcement'],
    ], ['type' => $typeVariantMap[$type] ?? 'Announcement']);

    // Compute initials
    $parts    = explode(' ', trim($authorName));
    $initials = '';
    if (count($parts) >= 2) {
        $initials = strtoupper(substr($parts[0], 0, 1) . substr($parts[1], 0, 1));
    } else {
        $initials = strtoupper(substr($authorName, 0, 2));
    }

    // Relative time
    $relativeValue = 'Just';
    $relativeUnit  = 'now';
    if ($createdAt) {
        $date    = new DateTime($createdAt);
        $seconds = time() - $date->getTimestamp();
        $minutes = (int)($seconds / 60);
        $hours   = (int)($minutes / 60);
        $days    = (int)($hours / 24);
        if ($days > 0)         { $relativeValue = (string)$days;    $relativeUnit = $days === 1 ? 'day ago' : 'days ago'; }
        elseif ($hours > 0)    { $relativeValue = (string)$hours;   $relativeUnit = $hours === 1 ? 'hour ago' : 'hours ago'; }
        elseif ($minutes > 0)  { $relativeValue = (string)$minutes; $relativeUnit = $minutes === 1 ? 'minute ago' : 'minutes ago'; }
    }

    // Event date formatting
    $eventDay   = '';
    $eventMonth = '';
    if ($eventDate) {
        $d          = new DateTime($eventDate);
        $eventDay   = $d->format('j');
        $eventMonth = strtoupper($d->format('M'));
    }

    $totalVotes = max(1, array_sum(array_column($pollOptions, 'voteCount')));
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    <div class="GroupPostCard__author-row">
        <div class="GroupPostCard__avatar">
            @if($authorAvatarUrl)
                <img src="{{ $authorAvatarUrl }}" alt="{{ $authorName }}" />
            @else
                <span>{{ $type === 'WELCOME' ? 'MR' : $initials }}</span>
            @endif
        </div>
        <div class="GroupPostCard__author-info">
            <span class="GroupPostCard__author-name">{{ $type === 'WELCOME' ? 'MakeReady' : $authorName }}</span>
            <div class="GroupPostCard__timestamp">
                <span class="GroupPostCard__timestamp-value">{{ $relativeValue }}</span>
                <span class="GroupPostCard__timestamp-unit">{{ $relativeUnit }}</span>
            </div>
        </div>
    </div>

    @if($content)
        <p class="GroupPostCard__content">{{ $content }}</p>
    @endif

    @if($type === 'EVENT')
        <div class="GroupPostCard__event-card">
            @if($imageUrl)
                <img src="{{ $imageUrl }}" alt="{{ $eventTitle ?? 'Event' }}" class="GroupPostCard__event-image" />
            @else
                <div class="GroupPostCard__event-image-placeholder">
                    <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                        <rect x="3" y="4" width="18" height="18" rx="2" /><path d="M3 10H21" /><path d="M8 2V6" /><path d="M16 2V6" />
                    </svg>
                </div>
            @endif
            <div class="GroupPostCard__event-details">
                @if($eventDate)
                    <div class="GroupPostCard__event-date-column">
                        <span class="GroupPostCard__event-day">{{ $eventDay }}</span>
                        <span class="GroupPostCard__event-month">{{ $eventMonth }}</span>
                    </div>
                @endif
                <div class="GroupPostCard__event-info">
                    <span class="GroupPostCard__event-title">{{ $eventTitle ?? $title ?? 'Event' }}</span>
                    <div class="GroupPostCard__event-attendees">
                        <span class="GroupPostCard__event-attendee-count">{{ $attendeeCount }}</span>
                        <span class="GroupPostCard__event-attendee-label">people are going</span>
                    </div>
                </div>
            </div>
        </div>
    @endif

    @if(in_array($type, ['WELCOME', 'ANNOUNCEMENT']) && $imageUrl)
        <img src="{{ $imageUrl }}" alt="Post" class="GroupPostCard__post-image" />
    @endif

    @if($type === 'POLL' && count($pollOptions) > 0)
        <div class="GroupPostCard__poll">
            @foreach($pollOptions as $option)
                @php
                    $percentage = round(($option['voteCount'] / $totalVotes) * 100);
                    $hasVoted   = $option['hasVoted'] ?? false;
                @endphp
                <div class="GroupPostCard__poll-option">
                    <div class="GroupPostCard__poll-bar" style="width: {{ $percentage }}%;"></div>
                    <div class="GroupPostCard__poll-indicator{{ $hasVoted ? ' GroupPostCard__poll-indicator--voted' : '' }}"></div>
                    <span class="GroupPostCard__poll-text">{{ $option['text'] }}</span>
                    <span class="GroupPostCard__poll-count">{{ $option['voteCount'] }}</span>
                </div>
            @endforeach
        </div>
    @endif

    @if($type === 'VIDEO' && $videoUrl)
        <div class="GroupPostCard__video">
            <div class="GroupPostCard__video-thumbnail">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="white">
                    <polygon points="5,3 19,12 5,21" />
                </svg>
            </div>
            <span class="GroupPostCard__video-label">Tap to play video</span>
        </div>
    @endif

    @if($type !== 'EVENT')
        <div class="GroupPostCard__action-bar">
            <div class="GroupPostCard__action-bar-left">
                <div class="GroupPostCard__action-item">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                        <circle cx="12" cy="12" r="3" />
                    </svg>
                    <span>{{ $viewCount }}</span>
                </div>
                <div class="GroupPostCard__action-item">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <polyline points="17 1 21 5 17 9" />
                        <path d="M3 11V9a4 4 0 0 1 4-4h14" />
                        <polyline points="7 23 3 19 7 15" />
                        <path d="M21 13v2a4 4 0 0 1-4 4H3" />
                    </svg>
                    <span>{{ $shareCount }}</span>
                </div>
            </div>
            <div class="GroupPostCard__action-bar-right">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z" />
                </svg>
            </div>
        </div>
    @endif
</div>
