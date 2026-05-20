@props([
    'interactive' => 'False',
    'selected'    => 'False',
    'name'        => '',
    'description' => null,
    'memberCount' => 0,
    'imageUrl'    => null,
    'isActive'    => true,
])

@php
    $classes = cva('GroupListCard', [
        'variants' => [
            'interactive' => [
                'True'  => 'GroupListCard--interactive',
                'False' => '',
            ],
            'selected' => [
                'True'  => 'GroupListCard--selected',
                'False' => '',
            ],
        ],
        'defaultVariants' => [
            'interactive' => 'False',
            'selected'    => 'False',
        ],
    ], ['interactive' => $interactive, 'selected' => $selected]);
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    <div class="GroupListCard__image">
        @if($imageUrl)
            <img src="{{ $imageUrl }}" alt="{{ $name }}" class="GroupListCard__image-photo" />
        @else
            <div class="GroupListCard__image-fallback">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                    <circle cx="9" cy="7" r="4" />
                    <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                    <path d="M16 3.13a4 4 0 0 1 0 7.75" />
                </svg>
            </div>
        @endif
        @if($selected === 'True')
            <div class="GroupListCard__image-selected">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                    <path d="M20 6L9 17L4 12" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                </svg>
            </div>
        @endif
    </div>

    <div class="GroupListCard__content">
        <h4 class="GroupListCard__name">{{ $name }}</h4>
        <div class="GroupListCard__metadata">
            <span class="GroupListCard__member-count">
                <span class="GroupListCard__member-number">{{ $memberCount }}</span>
                <span class="GroupListCard__member-label">{{ $memberCount === 1 ? 'Member' : 'Members' }}</span>
            </span>
        </div>
    </div>
</div>
