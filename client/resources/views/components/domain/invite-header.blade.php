@props([
    'size'             => 'Default',
    'coverImageUrl'    => null,
    'groupName'        => '',
    'groupDescription' => null,
])

@php
    $classes = cva('InviteHeader', [
        'variants' => [
            'size' => [
                'Default' => 'InviteHeader--size-default',
                'Compact' => 'InviteHeader--size-compact',
            ],
        ],
        'defaultVariants' => ['size' => 'Default'],
    ], ['size' => $size]);
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    <div class="InviteHeader__image-container">
        @if($coverImageUrl)
            <img src="{{ $coverImageUrl }}" alt="{{ $groupName }}" class="InviteHeader__image" />
        @else
            <div class="InviteHeader__image-placeholder">
                <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                    <circle cx="9" cy="7" r="4" />
                    <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                    <path d="M16 3.13a4 4 0 0 1 0 7.75" />
                </svg>
            </div>
        @endif
        <div class="InviteHeader__gradient"></div>
    </div>
    <div class="InviteHeader__content">
        <h1 class="InviteHeader__title">{{ $groupName }}</h1>
        @if($groupDescription)
            <p class="InviteHeader__description">{{ $groupDescription }}</p>
        @endif
    </div>
</div>
