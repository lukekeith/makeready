{{-- EnrolledStudyCard — an enrolled study's cover + the member's current/next lesson --}}
{{-- Figma: Make-Ready-Mobile "Study home page" → EnrolledStudyCard (node 3120:29927) --}}
@props([
    'studyTitle'       => '',
    'studyDescription' => null,
    'coverImageUrl'    => null,
    'nextLesson'       => null,   // ['title','dayNumber','scheduledDate']
    'href'             => null,   // link to the lesson player
    'badgeLabel'       => null,   // overrides the computed badge text
    'badgeVariant'     => null,   // overrides the computed badge color: 'default' | 'overdue'
])

@php
    // Date chip parts from the lesson's scheduled date
    $monthStr = '';
    $dayStr   = '';
    $scheduled = null;
    if (!empty($nextLesson['scheduledDate'])) {
        try {
            $d         = new DateTime($nextLesson['scheduledDate']);
            $monthStr  = $d->format('M');
            $dayStr    = $d->format('j');
            $scheduled = $d->format('Y-m-d');
        } catch (\Exception $e) {
            // leave blank on unparseable dates
        }
    }

    // Lesson badge state (Figma node 3118:29768):
    //   • scheduled today, incomplete           → TODAY'S LESSON (indigo)
    //   • available (past), not today, incomplete → COMPLETE NEXT (indigo)
    //   • more than a week overdue, incomplete    → OVERDUE       (orange)
    $badge   = $badgeLabel;
    $variant = $badgeVariant;
    if ($badge === null && $nextLesson) {
        $today = date('Y-m-d');
        if ($scheduled) {
            $daysLate = (strtotime($today) - strtotime($scheduled)) / 86400;
            if ($daysLate > 7) {
                $badge   = 'OVERDUE';
                $variant = $variant ?? 'overdue';
            } elseif ($scheduled === $today) {
                $badge = "TODAY'S LESSON";
            } else {
                $badge = 'COMPLETE NEXT';
            }
        } else {
            $badge = "TODAY'S LESSON";
        }
    }
    $variant = $variant ?: 'default';

    $Tag = $href ? 'a' : 'div';
@endphp

<{{ $Tag }}
    @if($href) href="{{ $href }}" @endif
    {{ $attributes->merge(['class' => 'EnrolledStudyCard']) }}
>
    @if($coverImageUrl)
        <img src="{{ $coverImageUrl }}" alt="{{ $studyTitle }}" class="EnrolledStudyCard__cover" />
    @endif

    <div class="EnrolledStudyCard__body">
        <div class="EnrolledStudyCard__details">
            <p class="EnrolledStudyCard__title">{{ $studyTitle }}</p>
            @if($studyDescription)
                <p class="EnrolledStudyCard__description">{{ $studyDescription }}</p>
            @endif
        </div>

        @if($nextLesson)
            <div class="EnrolledStudyCard__lesson">
                <div class="EnrolledStudyCard__date">
                    @if($monthStr !== '')
                        <span class="EnrolledStudyCard__month">{{ $monthStr }}</span>
                        <span class="EnrolledStudyCard__day">{{ $dayStr }}</span>
                    @elseif(isset($nextLesson['dayNumber']))
                        <span class="EnrolledStudyCard__month">DAY</span>
                        <span class="EnrolledStudyCard__day">{{ $nextLesson['dayNumber'] }}</span>
                    @endif
                </div>

                <div class="EnrolledStudyCard__lesson-info">
                    @if($badge)
                        <span class="EnrolledStudyCard__badge EnrolledStudyCard__badge--{{ $variant }}">{{ $badge }}</span>
                    @endif
                    <p class="EnrolledStudyCard__lesson-title">{{ $nextLesson['title'] ?? '' }}</p>
                </div>
            </div>
        @endif
    </div>
</{{ $Tag }}>
