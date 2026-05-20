@props([
    'interactive'    => 'False',
    'title'          => '',
    'date'           => null,
    'time'           => null,
    'location'       => null,
    'coverImageUrl'  => null,
    'attendeeCount'  => null,
])

@php
    $classes = cva('EventCard', [
        'variants' => [
            'interactive' => [
                'True'  => 'EventCard--interactive',
                'False' => '',
            ],
        ],
        'defaultVariants' => ['interactive' => 'False'],
    ], ['interactive' => $interactive]);

    // Date formatting
    $day   = '';
    $month = '';
    if ($date) {
        $d     = is_string($date) ? new DateTime($date) : $date;
        $day   = $d->format('j');
        $month = strtoupper($d->format('M'));
    }
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    @if($coverImageUrl)
        <div class="EventCard__cover">
            <img src="{{ $coverImageUrl }}" alt="{{ $title }}" class="EventCard__cover-image" />
        </div>
    @endif

    <div class="EventCard__details">
        @if($date)
            <div class="EventCard__date">
                <span class="EventCard__day">{{ $day }}</span>
                <span class="EventCard__month">{{ $month }}</span>
            </div>
        @endif

        <div class="EventCard__info">
            <h4 class="EventCard__title">{{ $title }}</h4>
            @if($time || $location)
                <p class="EventCard__location">
                    @if($time)<span class="EventCard__location-highlight">{{ $time }}</span>@endif
                    @if($time && $location) at @endif
                    @if($location)<span class="EventCard__location-highlight">{{ $location }}</span>@endif
                </p>
            @endif
            @if($attendeeCount !== null)
                <div class="EventCard__attendance">
                    <span class="EventCard__attendance-count">{{ $attendeeCount }}</span>
                    <span class="EventCard__attendance-label">
                        {{ $attendeeCount === 1 ? 'person is going' : 'people are going' }}
                    </span>
                </div>
            @endif
        </div>
    </div>
</div>
