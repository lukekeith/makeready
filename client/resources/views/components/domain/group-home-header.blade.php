@props([
    'size'          => 'Default',
    'coverImageUrl' => null,
    'name'          => '',
    'description'   => null,
    'memberCount'   => 0,
    'isPrivate'     => false,
])

@php
    $classes = cva('GroupHomeHeader', [
        'variants' => [
            'size' => [
                'Default' => 'GroupHomeHeader--size-default',
                'Compact' => 'GroupHomeHeader--size-compact',
            ],
        ],
        'defaultVariants' => ['size' => 'Default'],
    ], ['size' => $size]);
@endphp

<div {{ $attributes->merge(['class' => $classes]) }}>
    <div class="GroupHomeHeader__image-container">
        @if($coverImageUrl)
            <img src="{{ $coverImageUrl }}" alt="{{ $name }}" class="GroupHomeHeader__image" />
        @else
            <div class="GroupHomeHeader__image-placeholder">
                <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                    <circle cx="9" cy="7" r="4" />
                    <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                    <path d="M16 3.13a4 4 0 0 1 0 7.75" />
                </svg>
            </div>
        @endif
        <div class="GroupHomeHeader__gradient"></div>
    </div>

    <div class="GroupHomeHeader__content">
        <h1 class="GroupHomeHeader__title">{{ $name }}</h1>
        <div class="GroupHomeHeader__info">
            <div class="GroupHomeHeader__badge">
                @if($isPrivate)
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                        <path d="M7 11V7a5 5 0 0 1 10 0v4" />
                    </svg>
                @else
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <circle cx="12" cy="12" r="10" />
                    </svg>
                @endif
                <span>{{ $isPrivate ? 'Private' : 'Public' }}</span>
            </div>
            <span class="GroupHomeHeader__separator">•</span>
            <div class="GroupHomeHeader__members">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                    <circle cx="9" cy="7" r="4" />
                    <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                    <path d="M16 3.13a4 4 0 0 1 0 7.75" />
                </svg>
                <span>{{ $memberCount }} {{ $memberCount !== 1 ? 'members' : 'member' }}</span>
            </div>
        </div>
        @if($description)
            <p class="GroupHomeHeader__description">{{ $description }}</p>
        @endif
    </div>
</div>
