@props([
    'mode'       => 'Default',
    'firstDate'  => null,
    'lastDate'   => null,
    'activeDays' => [],
])

@php
    $classes = cva('StudyScheduleCard', [
        'variants' => [
            'mode' => [
                'Default' => 'StudyScheduleCard--default',
            ],
        ],
        'defaultVariants' => ['mode' => 'Default'],
    ], ['mode' => $mode]);

    $dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    $firstMonth = '';
    $firstDay   = '';
    $lastMonth  = '';
    $lastDay    = '';
    if ($firstDate) {
        $d          = is_string($firstDate) ? new DateTime($firstDate) : $firstDate;
        $firstMonth = strtoupper($d->format('M'));
        $firstDay   = $d->format('j');
    }
    if ($lastDate) {
        $d         = is_string($lastDate) ? new DateTime($lastDate) : $lastDate;
        $lastMonth = strtoupper($d->format('M'));
        $lastDay   = $d->format('j');
    }
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    <div class="StudyScheduleCard__date-section StudyScheduleCard__date-section--left">
        <span class="StudyScheduleCard__date-label">FIRST</span>
        <div class="StudyScheduleCard__date-value">
            <span class="StudyScheduleCard__month">{{ $firstMonth }}</span>
            <span class="StudyScheduleCard__day-number">{{ $firstDay }}</span>
        </div>
    </div>

    <div class="StudyScheduleCard__days">
        @foreach($dayLabels as $index => $label)
            @php
                $dayClass = 'StudyScheduleCard__day';
                if (in_array($index, $activeDays)) $dayClass .= ' StudyScheduleCard__day--active';
            @endphp
            <div class="{{ $dayClass }}">
                <span class="StudyScheduleCard__day-label">{{ $label }}</span>
            </div>
        @endforeach
    </div>

    <div class="StudyScheduleCard__date-section StudyScheduleCard__date-section--right">
        <span class="StudyScheduleCard__date-label">LAST</span>
        <div class="StudyScheduleCard__date-value">
            <span class="StudyScheduleCard__month">{{ $lastMonth }}</span>
            <span class="StudyScheduleCard__day-number">{{ $lastDay }}</span>
        </div>
    </div>
</div>
