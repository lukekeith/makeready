@props([
    'buttonLayout'  => 'Vertical',
    'coverImageUrl' => '',
    'studyName'     => '',
    'dayInfo'       => null,
    'groupName'     => null,
])

@php
    $classes = cva('StudyInfoCard', [
        'variants' => [
            'buttonLayout' => [
                'Horizontal' => 'StudyInfoCard--button-layout-horizontal',
                'Vertical'   => 'StudyInfoCard--button-layout-vertical',
            ],
        ],
        'defaultVariants' => ['buttonLayout' => 'Vertical'],
    ], ['buttonLayout' => $buttonLayout]);
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    <div class="StudyInfoCard__photo">
        <img src="{{ $coverImageUrl }}" alt="{{ $studyName }}" class="StudyInfoCard__photo-image" />
        <div class="StudyInfoCard__gradient">
            <div class="StudyInfoCard__details">
                <h2 class="StudyInfoCard__name">{{ $studyName }}</h2>
                <div class="StudyInfoCard__meta">
                    @if($dayInfo)
                        <span class="StudyInfoCard__day">{{ $dayInfo }}</span>
                    @endif
                    @if($groupName)
                        <span class="StudyInfoCard__group">with {{ $groupName }}</span>
                    @endif
                </div>
            </div>
        </div>
    </div>

    @if($slot->isNotEmpty())
        <div class="StudyInfoCard__actions">{{ $slot }}</div>
    @endif
</div>
