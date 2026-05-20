@props([
    'mode'          => 'Default',
    'interactive'   => 'False',
    'title'         => '',
    'description'   => null,
    'date'          => null,
    'coverImageUrl' => null,
    'activities'    => [],
    'dayNumber'     => null,
    'progress'      => null,
    'dateLabel'     => 'day',
    'sections'      => [],
    'status'        => null,
])

@php
    $classes = cva('StudyCard', [
        'variants' => [
            'mode' => [
                'Default'    => 'StudyCard--default',
                'Lesson'     => 'StudyCard--lesson',
                'Header'     => 'StudyCard--header',
                'Progress'   => 'StudyCard--progress',
                'LessonList' => 'StudyCard--lesson-list',
            ],
            'interactive' => [
                'True'  => 'StudyCard--interactive',
                'False' => '',
            ],
        ],
        'defaultVariants' => [
            'mode'        => 'Default',
            'interactive' => 'False',
        ],
    ], ['mode' => $mode, 'interactive' => $interactive]);

    $isLessonMode     = $mode === 'Lesson';
    $isHeaderMode     = $mode === 'Header';
    $isProgressMode   = $mode === 'Progress';
    $isLessonListMode = $mode === 'LessonList';
    $isComplete       = $status === 'complete';
    $isNext           = $status === 'next';
    $isSpecialMode    = $isLessonMode || $isHeaderMode || $isProgressMode || $isLessonListMode;

    if (!$isSpecialMode) {
        $classes .= $coverImageUrl ? ' StudyCard--with-cover' : ' StudyCard--without-cover';
    }
    if ($isLessonListMode && $isComplete) {
        $classes .= ' StudyCard--lesson-list-complete';
    }

    // Date helpers
    $dayStr   = '';
    $monthStr = '';
    $fullDateStr = '';
    if ($date) {
        $d        = is_string($date) ? new DateTime($date) : $date;
        $dayStr   = $d->format('j');
        $monthStr = strtoupper($d->format('M'));
        $fullDateStr = $d->format('l, M j, Y');
    }

    $displayDayNumber = $dayNumber ?? ($date ? (int)$dayStr : null);

    // Activity icon SVG — shared with iOS (source: public/icons/activity/*.svg)
    // Each entry: ['vb' => viewBox, 'svg' => inner paths]
    $readSvg       = '<path d="M16 28L15.8666 27.8C14.9404 26.4107 14.4773 25.716 13.8655 25.2131C13.3238 24.7679 12.6997 24.4339 12.0288 24.2301C11.271 24 10.4362 24 8.76645 24H6.93335C5.43988 24 4.69314 24 4.12271 23.7094C3.62094 23.4537 3.21299 23.0457 2.95733 22.544C2.66669 21.9735 2.66669 21.2268 2.66669 19.7333V8.26667C2.66669 6.77319 2.66669 6.02646 2.95733 5.45603C3.21299 4.95426 3.62094 4.54631 4.12271 4.29065C4.69314 4 5.43988 4 6.93335 4H7.46669C10.4536 4 11.9471 4 13.088 4.5813C14.0915 5.09262 14.9074 5.90852 15.4187 6.91205C16 8.05291 16 9.54639 16 12.5333M16 28V12.5333M16 28L16.1334 27.8C17.0596 26.4107 17.5227 25.716 18.1346 25.2131C18.6762 24.7679 19.3003 24.4339 19.9712 24.2301C20.729 24 21.5639 24 23.2336 24H25.0667C26.5602 24 27.3069 24 27.8773 23.7094C28.3791 23.4537 28.787 23.0457 29.0427 22.544C29.3334 21.9735 29.3334 21.2268 29.3334 19.7333V8.26667C29.3334 6.77319 29.3334 6.02646 29.0427 5.45603C28.787 4.95426 28.3791 4.54631 27.8773 4.29065C27.3069 4 26.5602 4 25.0667 4H24.5334C21.5464 4 20.0529 4 18.9121 4.5813C17.9085 5.09262 17.0926 5.90852 16.5813 6.91205C16 8.05291 16 9.54639 16 12.5333" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>';
    $videoSvg      = '<path d="M16 29.3334C23.3638 29.3334 29.3334 23.3638 29.3334 16C29.3334 8.63622 23.3638 2.66669 16 2.66669C8.63622 2.66669 2.66669 8.63622 2.66669 16C2.66669 23.3638 8.63622 29.3334 16 29.3334Z" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M13.3334 10.6667L22.6667 16L13.3334 21.3334V10.6667Z" fill="white"/>';
    $writeSvg      = '<path fill-rule="evenodd" clip-rule="evenodd" d="M16.2929 2.29319C17.788 0.798101 20.2121 0.798103 21.7072 2.2932C23.2023 3.78829 23.2023 6.21232 21.7072 7.70741L10.3906 19.024C10.1572 19.2575 9.98059 19.4342 9.78113 19.5889C9.60481 19.7258 9.41735 19.8476 9.2207 19.9532C8.99825 20.0726 8.76513 20.1622 8.45696 20.2806L8.33177 20.3287C8.30046 20.3409 8.26937 20.3528 8.23883 20.3646L2.85901 22.4337C2.49016 22.5756 2.07236 22.4869 1.79292 22.2075C1.60189 22.0164 1.50002 21.7608 1.5 21.5002C1.49998 21.3797 1.52179 21.258 1.56668 21.1413L3.7197 15.5435C3.83815 15.2352 3.92775 15.0021 4.04718 14.7796C4.15273 14.583 4.27456 14.3955 4.41139 14.2192C4.56618 14.0197 4.74283 13.8432 4.97635 13.6098L16.2929 2.29319ZM5.38099 16.7955L4.24108 19.7593L7.20481 18.6194L5.38099 16.7955Z" fill="white"/><path d="M13 20.0005H21C21.5523 20.0005 22 20.4482 22 21.0005C22 21.5528 21.5523 22.0005 21 22.0005H13C12.4477 22.0005 12 21.5528 12 21.0005C12 20.4482 12.4477 20.0005 13 20.0005Z" fill="white"/>';
    $prayerSvg     = '<path d="M16 28C16 28 4 18 4 11.3334C4 8.66669 6 5.33335 10 5.33335C12.48 5.33335 14.5467 6.72002 16 8.66669C17.4534 6.72002 19.52 5.33335 22 5.33335C26 5.33335 28 8.66669 28 11.3334C28 18 16 28 16 28Z" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>';
    $reflectionSvg = '<path d="M28 15.3334C28.0045 16.8932 27.5934 18.4292 26.8 19.7867C25.8592 21.6158 24.4131 23.1323 22.6232 24.1724C20.8334 25.2126 18.7709 25.7326 16.6667 25.6667C15.1069 25.6712 13.5708 25.2601 12.2133 24.4667L4 28L7.53335 19.7867C6.73993 18.4292 6.32884 16.8932 6.33335 15.3334C6.26746 13.2292 6.78747 11.1666 7.82762 9.37679C8.86776 7.58697 10.3843 6.14089 12.2133 5.20002C13.5708 4.40661 15.1069 3.99551 16.6667 4.00002H17.3334C20.1124 4.15336 22.7373 5.32639 24.7055 7.29455C26.6736 9.26272 27.8467 11.8876 28 14.6667V15.3334Z" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>';
    $discussSvg    = '<path d="M22.6667 12C22.6667 17.16 18.1867 21.3334 12.6667 21.3334L11.4267 22.8267L10.6934 23.7067C10.0667 24.4534 8.86669 24.2934 8.45335 23.4L6.66669 19.4667C4.24002 17.76 2.66669 15.0534 2.66669 12C2.66669 6.84002 7.14669 2.66669 12.6667 2.66669C18.1867 2.66669 22.6667 6.84002 22.6667 12Z" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M29.3334 17.1467C29.3334 20.2 27.7601 22.9067 25.3334 24.6134L23.5467 28.5467C23.1334 29.44 21.9334 29.6 21.3067 28.8534L19.3334 26.48C16.1067 26.48 13.2267 24.9467 11.4267 22.6267L12.6667 21.1467C18.1867 21.1467 22.6667 17.64 22.6667 11.8134C22.6667 10.4267 22.3734 9.10669 21.8401 7.92002C26.1734 9.08002 29.3334 12.76 29.3334 17.1467Z" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>';

    $activityIcons = [
        'READ'       => ['vb' => '0 0 32 32', 'svg' => $readSvg],
        'SCRIPTURE'  => ['vb' => '0 0 32 32', 'svg' => $readSvg],
        'SOAP'       => ['vb' => '0 0 32 32', 'svg' => $readSvg],
        'VIDEO'      => ['vb' => '0 0 32 32', 'svg' => $videoSvg],
        'YOUTUBE'    => ['vb' => '0 0 32 32', 'svg' => $videoSvg],
        'USER_INPUT' => ['vb' => '0 0 24 24', 'svg' => $writeSvg],
        'PRAYER'     => ['vb' => '0 0 32 32', 'svg' => $prayerSvg],
        'REFLECTION' => ['vb' => '0 0 32 32', 'svg' => $reflectionSvg],
        'DISCUSS'    => ['vb' => '0 0 32 32', 'svg' => $discussSvg],
    ];

    // Activity type → background color (matches iOS activityTypeColor)
    $activityTypeColors = [
        'READ'       => '#6c47ff',
        'SCRIPTURE'  => '#6c47ff',
        'SOAP'       => '#6c47ff',
        'USER_INPUT' => '#3b82f6',
        'VIDEO'      => '#ef4444',
        'YOUTUBE'    => '#dc2626',
        'PRAYER'     => '#6c47ff',
        'REFLECTION' => '#6c47ff',
        'DISCUSS'    => '#6c47ff',
    ];

    // Max visible icons before showing +N overflow (matches iOS lessonActivityIcons)
    $maxVisibleActivities = 5;
    $activityBoxSize = 32;
    $activityGap = 4;
    $activityIconSize = round($activityBoxSize * 0.4375);
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    @if($coverImageUrl)
        <img
            src="{{ $coverImageUrl }}"
            alt="{{ $title }}"
            class="StudyCard__cover-image{{ ($isLessonMode || $isHeaderMode) ? ' StudyCard__cover-image--faded' : '' }}"
        />
    @endif

    @if($isHeaderMode)
        <div class="StudyCard__header-content">
            <button class="StudyCard__back-button" aria-label="Go back">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                    <path d="M15 18L9 12L15 6" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                </svg>
            </button>
            <div class="StudyCard__header-info">
                <h4 class="StudyCard__title">{{ $title }}</h4>
                @if($description)
                    <p class="StudyCard__description">{{ $description }}</p>
                @endif
            </div>
        </div>

    @elseif($isProgressMode)
        <div class="StudyCard__content">
            <div class="StudyCard__date">
                @if($dateLabel === 'day')
                    <span class="StudyCard__label">DAY</span>
                    <span class="StudyCard__day">{{ $displayDayNumber }}</span>
                @elseif($date)
                    <span class="StudyCard__month">{{ $monthStr }}</span>
                    <span class="StudyCard__day">{{ $dayStr }}</span>
                @endif
            </div>
            <div class="StudyCard__details StudyCard__details--progress">
                <div class="StudyCard__title-section">
                    <h4 class="StudyCard__title">{{ $title }}</h4>
                    @if($description)
                        <p class="StudyCard__description">{{ $description }}</p>
                    @endif
                </div>
                @if($progress !== null)
                    <div class="StudyCard__progress-bar">
                        <div class="StudyCard__progress-fill" style="width: {{ min(100, max(0, $progress)) }}%;"></div>
                    </div>
                @endif
                @if(count($sections) > 0)
                    <div class="StudyCard__sections">
                        @foreach($sections as $section)
                            @php
                                $completed = !empty($section['completedAt']);
                                $sectionIndClass = 'StudyCard__section-indicator';
                                if ($completed) $sectionIndClass .= ' StudyCard__section-indicator--complete';
                            @endphp
                            <div class="StudyCard__section">
                                <div class="{{ $sectionIndClass }}">
                                    @if($completed)
                                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                                            <path d="M20 6L9 17L4 12" stroke="#0d101a" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                                        </svg>
                                    @endif
                                </div>
                                <div class="StudyCard__section-info">
                                    <span class="StudyCard__section-name">{{ $section['name'] }}</span>
                                    @if($completed)
                                        <span class="StudyCard__section-date">{{ $section['completedAt'] }}</span>
                                    @endif
                                </div>
                            </div>
                        @endforeach
                    </div>
                @endif
            </div>
        </div>

    @elseif($isLessonListMode)
        <div class="StudyCard__content">
            <div class="StudyCard__date{{ $isComplete ? ' StudyCard__date--complete' : '' }}">
                <span class="StudyCard__label{{ $isComplete ? ' StudyCard__label--complete' : ' StudyCard__label--active' }}">DAY</span>
                <span class="StudyCard__day">{{ $dayNumber }}</span>
            </div>
            <div class="StudyCard__details StudyCard__details--lesson-list">
                @if($status)
                    @php
                        $badgeClass = 'StudyCard__status-badge';
                        if ($isComplete)     $badgeClass .= ' StudyCard__status-badge--complete';
                        elseif ($isNext)     $badgeClass .= ' StudyCard__status-badge--next';
                        else                 $badgeClass .= ' StudyCard__status-badge--text';
                        $statusText = $isComplete
                            ? 'COMPLETE'
                            : (ucfirst($status));
                    @endphp
                    <div class="{{ $badgeClass }}">
                        <span class="StudyCard__status-text">{{ $statusText }}</span>
                    </div>
                @endif
                <div class="StudyCard__title-section">
                    <h4 class="StudyCard__title">{{ $title }}</h4>
                </div>
                @if(count($activities) > 0)
                    @php
                        $visibleActivities = array_slice($activities, 0, $maxVisibleActivities);
                        $overflowCount = count($activities) - $maxVisibleActivities;
                    @endphp
                    <div class="StudyCard__activities" style="gap: {{ $activityGap }}px;">
                        @foreach($visibleActivities as $activity)
                            @php
                                $type = strtoupper($activity);
                                $iconData = $activityIcons[$type] ?? $activityIcons['READ'];
                                $bgColor = $activityTypeColors[$type] ?? '#6c47ff';
                            @endphp
                            <div class="StudyCard__activity-icon StudyCard__activity-icon--typed" style="width: {{ $activityBoxSize }}px; height: {{ $activityBoxSize }}px; background: {{ $bgColor }};">
                                <svg width="{{ $activityIconSize }}" height="{{ $activityIconSize }}" viewBox="{{ $iconData['vb'] }}" fill="none">
                                    {!! $iconData['svg'] !!}
                                </svg>
                            </div>
                        @endforeach
                        @if($overflowCount > 0)
                            <div class="StudyCard__activity-overflow" style="width: {{ $activityBoxSize }}px; height: {{ $activityBoxSize }}px;">
                                +{{ $overflowCount }}
                            </div>
                        @endif
                    </div>
                @endif
            </div>
        </div>

    @elseif($isLessonMode)
        <div class="StudyCard__content">
            <div class="StudyCard__date">
                <span class="StudyCard__label">DAY</span>
                <span class="StudyCard__day">{{ $displayDayNumber }}</span>
            </div>
            <div class="StudyCard__details StudyCard__details--lesson">
                <div class="StudyCard__title-section">
                    <h4 class="StudyCard__title">{{ $title }}</h4>
                    @if($date)
                        <p class="StudyCard__full-date">{{ $fullDateStr }}</p>
                    @endif
                </div>
                @if(count($activities) > 0)
                    @php
                        $visibleLessonActivities = array_slice($activities, 0, $maxVisibleActivities);
                        $lessonOverflow = count($activities) - $maxVisibleActivities;
                    @endphp
                    <div class="StudyCard__activities" style="gap: {{ $activityGap }}px;">
                        @foreach($visibleLessonActivities as $activity)
                            @php
                                $type = strtoupper($activity);
                                $iconData = $activityIcons[$type] ?? $activityIcons['READ'];
                                $bgColor = $activityTypeColors[$type] ?? '#6c47ff';
                            @endphp
                            <div class="StudyCard__activity-icon StudyCard__activity-icon--typed" style="width: {{ $activityBoxSize }}px; height: {{ $activityBoxSize }}px; background: {{ $bgColor }};">
                                <svg width="{{ $activityIconSize }}" height="{{ $activityIconSize }}" viewBox="{{ $iconData['vb'] }}" fill="none">
                                    {!! $iconData['svg'] !!}
                                </svg>
                            </div>
                        @endforeach
                        @if($lessonOverflow > 0)
                            <div class="StudyCard__activity-overflow" style="width: {{ $activityBoxSize }}px; height: {{ $activityBoxSize }}px;">
                                +{{ $lessonOverflow }}
                            </div>
                        @endif
                    </div>
                @endif
            </div>
        </div>

    @else
        {{-- Default mode --}}
        <div class="StudyCard__overlay">
            <div class="StudyCard__content">
                @if($date)
                    <div class="StudyCard__date">
                        <span class="StudyCard__month">{{ $monthStr }}</span>
                        <span class="StudyCard__day">{{ $dayStr }}</span>
                    </div>
                @endif
                <div class="StudyCard__details">
                    <div class="StudyCard__title-section">
                        <h4 class="StudyCard__title">{{ $title }}</h4>
                        @if($description)
                            <p class="StudyCard__description">{{ $description }}</p>
                        @endif
                    </div>
                </div>
            </div>
        </div>
    @endif
</div>
